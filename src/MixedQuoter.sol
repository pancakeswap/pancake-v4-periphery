// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {Currency, equals} from "pancake-v4-core/src/types/Currency.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {TickMath} from "pancake-v4-core/src/pool-cl/libraries/TickMath.sol";
import {ICLQuoter} from "./pool-cl/interfaces/ICLQuoter.sol";
import {IBinQuoter} from "./pool-bin/interfaces/IBinQuoter.sol";
import {IPancakeV3Pool} from "./interfaces/external/IPancakeV3Pool.sol";
import {IPancakeV3SwapCallback} from "./interfaces/external/IPancakeV3SwapCallback.sol";
import {IStableSwap} from "./interfaces/external/IStableSwap.sol";
import {V3PoolTicksCounter} from "./libraries/external/V3PoolTicksCounter.sol";
import {V3SmartRouterHelper} from "./libraries/external/V3SmartRouterHelper.sol";
import {IMixedQuoter} from "./interfaces/IMixedQuoter.sol";
import {MixedQuoterActions} from "./libraries/MixedQuoterActions.sol";

/// @title Provides on chain quotes for v4, V3, V2, Stable and MixedRoute exact input swaps
/// @notice Allows getting the expected amount out for a given swap without executing the swap
/// @notice Does not support exact output swaps since using the contract balance between exactOut swaps is not supported
/// @dev These functions are not gas efficient and should _not_ be called on chain. Instead, optimistically execute
/// the swap and check the amounts in the callback.
contract MixedQuoter is IMixedQuoter, IPancakeV3SwapCallback {
    // using Path for bytes;
    using SafeCast for *;
    using V3PoolTicksCounter for IPancakeV3Pool;

    address constant ZERO_ADDRESS = address(0);

    // pancake v3 deployer
    address public immutable deployer;
    // pancake v3 factory
    address public immutable factory;
    address public immutable WETH9;

    address public immutable factoryV2;
    address public immutable factoryStable;

    ICLQuoter public immutable clQuoter;
    IBinQuoter public immutable binQuoter;

    constructor(
        address _deployer,
        address _factory,
        address _factoryV2,
        address _factoryStable,
        address _WETH9,
        ICLQuoter _clQuoter,
        IBinQuoter _binQuoter
    ) {
        if (
            _deployer == ZERO_ADDRESS || _factory == ZERO_ADDRESS || _factoryV2 == ZERO_ADDRESS
                || _factoryStable == ZERO_ADDRESS || _WETH9 == ZERO_ADDRESS || address(_clQuoter) == ZERO_ADDRESS
                || address(_binQuoter) == ZERO_ADDRESS
        ) {
            revert INVALID_ADDRESS();
        }
        deployer = _deployer;
        factory = _factory;
        WETH9 = _WETH9;
        factoryV2 = _factoryV2;
        factoryStable = _factoryStable;
        clQuoter = _clQuoter;
        binQuoter = _binQuoter;
    }

    /**
     * V3 *************************************************
     */

    /// @inheritdoc IPancakeV3SwapCallback
    function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes memory data)
        external
        view
        override
    {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        (address tokenIn, address tokenOut, uint24 fee) = abi.decode(data, (address, address, uint24));
        V3SmartRouterHelper.verifyCallback(deployer, tokenIn, tokenOut, fee);

        (bool isExactInput, uint256 amountReceived) = amount0Delta > 0
            ? (tokenIn < tokenOut, uint256(-amount1Delta))
            : (tokenOut < tokenIn, uint256(-amount0Delta));

        IPancakeV3Pool pool = V3SmartRouterHelper.getPool(deployer, tokenIn, tokenOut, fee);
        (uint160 v3SqrtPriceX96After, int24 tickAfter,,,,,) = pool.slot0();

        if (isExactInput) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountReceived)
                mstore(add(ptr, 0x20), v3SqrtPriceX96After)
                mstore(add(ptr, 0x40), tickAfter)
                revert(ptr, 0x60)
            }
        } else {
            /// since we don't support exactOutput, revert here
            revert("Exact output quote not supported");
        }
    }

    /// @dev Parses a revert reason that should contain the numeric quote
    function parseRevertReason(bytes memory reason)
        private
        pure
        returns (uint256 amount, uint160 sqrtPriceX96After, int24 tickAfter)
    {
        if (reason.length != 0x60) {
            if (reason.length < 0x44) revert("Unexpected error");
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        return abi.decode(reason, (uint256, uint160, int24));
    }

    function handleV3Revert(bytes memory reason, IPancakeV3Pool pool, uint256 gasEstimate)
        private
        view
        returns (uint256 amount, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256)
    {
        int24 tickBefore;
        int24 tickAfter;
        (, tickBefore,,,,,) = pool.slot0();
        (amount, sqrtPriceX96After, tickAfter) = parseRevertReason(reason);

        initializedTicksCrossed = pool.countInitializedTicksCrossed(tickBefore, tickAfter);

        return (amount, sqrtPriceX96After, initializedTicksCrossed, gasEstimate);
    }

    /// @dev Fetch an exactIn quote for a V3 Pool on chain
    function quoteExactInputSingleV3(QuoteExactInputSingleV3Params memory params)
        public
        override
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)
    {
        bool zeroForOne = params.tokenIn < params.tokenOut;
        IPancakeV3Pool pool = V3SmartRouterHelper.getPool(deployer, params.tokenIn, params.tokenOut, params.fee);

        uint256 gasBefore = gasleft();
        try pool.swap(
            address(this), // address(0) might cause issues with some tokens
            zeroForOne,
            params.amountIn.toInt256(),
            params.sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : params.sqrtPriceLimitX96,
            abi.encode(params.tokenIn, params.tokenOut, params.fee)
        ) {} catch (bytes memory reason) {
            gasEstimate = gasBefore - gasleft();
            return handleV3Revert(reason, pool, gasEstimate);
        }
    }

    /**
     * V2 *************************************************
     */

    /// @dev Fetch an exactIn quote for a V2 pair on chain
    function quoteExactInputSingleV2(QuoteExactInputSingleV2Params memory params)
        public
        view
        override
        returns (uint256 amountOut)
    {
        (uint256 reserveIn, uint256 reserveOut) =
            V3SmartRouterHelper.getReserves(factoryV2, params.tokenIn, params.tokenOut);
        amountOut = V3SmartRouterHelper.getAmountOut(params.amountIn, reserveIn, reserveOut);
    }

    /**
     * Stable *************************************************
     */

    /// @dev Fetch an exactIn quote for a Stable pair on chain
    function quoteExactInputSingleStable(QuoteExactInputSingleStableParams memory params)
        public
        view
        override
        returns (uint256 amountOut)
    {
        (uint256 i, uint256 j, address swapContract) =
            V3SmartRouterHelper.getStableInfo(factoryStable, params.tokenIn, params.tokenOut, params.flag);
        amountOut = IStableSwap(swapContract).get_dy(i, j, params.amountIn);
    }

    /**
     * Mixed *************************************************
     */
    function quoteMixedExactInput(
        address[] calldata paths,
        bytes calldata actions,
        bytes[] calldata params,
        uint256 amountIn
    ) external override returns (uint256 amountOut) {
        uint256 numActions = actions.length;
        if (numActions == 0) revert NoActions();
        if (numActions != params.length || numActions != paths.length - 1) revert InputLengthMismatch();

        for (uint256 actionIndex = 0; actionIndex < numActions; actionIndex++) {
            address tokenIn = paths[actionIndex];
            address tokenOut = paths[actionIndex + 1];
            if (tokenIn == tokenOut) revert InvalidPath();

            uint256 action = uint256(uint8(actions[actionIndex]));
            if (action == MixedQuoterActions.V2_EXACT_INPUT_SINGLE) {
                // params[actionIndex] is zero bytes
                amountIn = quoteExactInputSingleV2(
                    QuoteExactInputSingleV2Params({tokenIn: tokenIn, tokenOut: tokenOut, amountIn: amountIn})
                );
            } else if (action == MixedQuoterActions.V3_EXACT_INPUT_SINGLE) {
                // params[actionIndex]: abi.encode(fee)
                uint24 fee = abi.decode(params[actionIndex], (uint24));
                (uint256 _amountOut,,,) = quoteExactInputSingleV3(
                    QuoteExactInputSingleV3Params({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        amountIn: amountIn,
                        fee: fee,
                        sqrtPriceLimitX96: 0
                    })
                );
                amountIn = _amountOut;
            } else if (action == MixedQuoterActions.V4_CL_EXACT_INPUT_SINGLE) {
                QuoterMixedV4ExactInputSingleParams memory clParams =
                    abi.decode(params[actionIndex], (QuoterMixedV4ExactInputSingleParams));
                (tokenIn, tokenOut) = convertWETHToV4NativeCurency(clParams.poolKey, tokenIn, tokenOut);
                bool zeroForOne = tokenIn < tokenOut;
                checkV4PoolKeyCurrency(clParams.poolKey, zeroForOne, tokenIn, tokenOut);
                (int128[] memory deltaAmounts,,) = clQuoter.quoteExactInputSingle(
                    ICLQuoter.QuoteExactSingleParams({
                        poolKey: clParams.poolKey,
                        zeroForOne: zeroForOne,
                        exactAmount: amountIn.toUint128(),
                        sqrtPriceLimitX96: 0,
                        hookData: clParams.hookData
                    })
                );
                amountIn = deltaAmounts[1].toUint256();
            } else if (action == MixedQuoterActions.V4_BIN_EXACT_INPUT_SINGLE) {
                QuoterMixedV4ExactInputSingleParams memory clParams =
                    abi.decode(params[actionIndex], (QuoterMixedV4ExactInputSingleParams));
                (tokenIn, tokenOut) = convertWETHToV4NativeCurency(clParams.poolKey, tokenIn, tokenOut);
                bool zeroForOne = tokenIn < tokenOut;
                checkV4PoolKeyCurrency(clParams.poolKey, zeroForOne, tokenIn, tokenOut);
                (int128[] memory deltaAmounts,) = binQuoter.quoteExactInputSingle(
                    IBinQuoter.QuoteExactSingleParams({
                        poolKey: clParams.poolKey,
                        zeroForOne: zeroForOne,
                        exactAmount: amountIn.toUint128(),
                        hookData: clParams.hookData
                    })
                );
                amountIn = deltaAmounts[1].toUint256();
            } else if (action == MixedQuoterActions.SS_2_EXACT_INPUT_SINGLE) {
                // params[actionIndex] is zero bytes
                amountIn = quoteExactInputSingleStable(
                    QuoteExactInputSingleStableParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        amountIn: amountIn,
                        flag: 2
                    })
                );
            } else if (action == MixedQuoterActions.SS_3_EXACT_INPUT_SINGLE) {
                // params[actionIndex] is zero bytes
                amountIn = quoteExactInputSingleStable(
                    QuoteExactInputSingleStableParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        amountIn: amountIn,
                        flag: 3
                    })
                );
            } else {
                revert UnsupportedAction(action);
            }
        }

        return amountIn;
    }

    function checkV4PoolKeyCurrency(PoolKey memory poolKey, bool isZeroForOne, address tokenIn, address tokenOut)
        private
        pure
    {
        Currency currency0;
        Currency currency1;
        if (isZeroForOne) {
            currency0 = Currency.wrap(tokenIn);
            currency1 = Currency.wrap(tokenOut);
        } else {
            currency0 = Currency.wrap(tokenOut);
            currency1 = Currency.wrap(tokenIn);
        }
        if (!equals(poolKey.currency0, currency0) || !equals(poolKey.currency1, currency1)) {
            revert InvalidPoolKeyCurrency();
        }
    }

    function convertWETHToV4NativeCurency(PoolKey memory poolKey, address tokenIn, address tokenOut)
        private
        view
        returns (address, address)
    {
        if (poolKey.currency0.isNative()) {
            if (tokenIn == WETH9) {
                tokenIn = ZERO_ADDRESS;
            }
            if (tokenOut == WETH9) {
                tokenOut = ZERO_ADDRESS;
            }
        }
        return (tokenIn, tokenOut);
    }
}
