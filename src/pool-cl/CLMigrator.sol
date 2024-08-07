// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.19;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {BaseMigrator, IV3NonfungiblePositionManager} from "../base/BaseMigrator.sol";
import {ICLMigrator, PoolKey} from "./interfaces/ICLMigrator.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {Currency} from "pancake-v4-core/src/types/Currency.sol";

contract CLMigrator is ICLMigrator, BaseMigrator {
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    constructor(address _WETH9, address _nonfungiblePositionManager) BaseMigrator(_WETH9) {
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
    }

    /// @inheritdoc ICLMigrator
    function migrateFromV2(
        V2PoolParams calldata v2PoolParams,
        V4CLPoolParams calldata v4PoolParams,
        uint256 extraAmount0,
        uint256 extraAmount1
    ) external payable override {
        bool shouldReversePair = checkTokensOrderAndMatchFromV2(
            v2PoolParams.pair, v4PoolParams.poolKey.currency0, v4PoolParams.poolKey.currency1
        );

        (uint256 amount0Received, uint256 amount1Received) = withdrawLiquidityFromV2(v2PoolParams, shouldReversePair);

        /// @notice if user mannually specify the price range, they might need to send extra token
        batchAndNormalizeTokens(
            v4PoolParams.poolKey.currency0, v4PoolParams.poolKey.currency1, extraAmount0, extraAmount1
        );

        uint256 amount0In = amount0Received + extraAmount0;
        uint256 amount1In = amount1Received + extraAmount1;
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            poolKey: v4PoolParams.poolKey,
            tickLower: v4PoolParams.tickLower,
            tickUpper: v4PoolParams.tickUpper,
            salt: v4PoolParams.salt,
            amount0Desired: amount0In,
            amount1Desired: amount1In,
            amount0Min: v4PoolParams.amount0Min,
            amount1Min: v4PoolParams.amount1Min,
            recipient: v4PoolParams.recipient
        });
        (,, uint256 amount0Consumed, uint256 amount1Consumed) =
            _addLiquidityToTargetPool(mintParams, v4PoolParams.deadline);

        // refund if necessary, ETH is supported by CurrencyLib
        unchecked {
            if (amount0In > amount0Consumed) {
                v4PoolParams.poolKey.currency0.transfer(v4PoolParams.recipient, amount0In - amount0Consumed);
            }
            if (amount1In > amount1Consumed) {
                v4PoolParams.poolKey.currency1.transfer(v4PoolParams.recipient, amount1In - amount1Consumed);
            }
        }
    }

    /// @inheritdoc ICLMigrator
    function migrateFromV3(
        V3PoolParams calldata v3PoolParams,
        V4CLPoolParams calldata v4PoolParams,
        uint256 extraAmount0,
        uint256 extraAmount1
    ) external payable override {
        bool shouldReversePair = checkTokensOrderAndMatchFromV3(
            v3PoolParams.nfp, v3PoolParams.tokenId, v4PoolParams.poolKey.currency0, v4PoolParams.poolKey.currency1
        );
        (uint256 amount0Received, uint256 amount1Received) = withdrawLiquidityFromV3(v3PoolParams, shouldReversePair);

        /// @notice if user mannually specify the price range, they need to send extra token
        batchAndNormalizeTokens(
            v4PoolParams.poolKey.currency0, v4PoolParams.poolKey.currency1, extraAmount0, extraAmount1
        );

        uint256 amount0In = amount0Received + extraAmount0;
        uint256 amount1In = amount1Received + extraAmount1;
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            poolKey: v4PoolParams.poolKey,
            tickLower: v4PoolParams.tickLower,
            tickUpper: v4PoolParams.tickUpper,
            salt: v4PoolParams.salt,
            amount0Desired: amount0In,
            amount1Desired: amount1In,
            amount0Min: v4PoolParams.amount0Min,
            amount1Min: v4PoolParams.amount1Min,
            recipient: v4PoolParams.recipient
        });
        (,, uint256 amount0Consumed, uint256 amount1Consumed) =
            _addLiquidityToTargetPool(mintParams, v4PoolParams.deadline);

        // refund if necessary, ETH is supported by CurrencyLib
        unchecked {
            if (amount0In > amount0Consumed) {
                v4PoolParams.poolKey.currency0.transfer(v4PoolParams.recipient, amount0In - amount0Consumed);
            }
            if (amount1In > amount1Consumed) {
                v4PoolParams.poolKey.currency1.transfer(v4PoolParams.recipient, amount1In - amount1Consumed);
            }
        }
    }

    /// @dev adding liquidity to target cl pool, collect surplus ETH if necessary
    /// @param params cl position manager add liquidity params
    /// @param deadline the deadline for the transaction
    /// @return tokenId the id of the newly minted position token
    /// @return liquidity the amount of liquidity minted
    /// @return amount0Consumed the actual amount of token0 consumed
    /// @return amount1Consumed the actual amount of token1 consumed
    function _addLiquidityToTargetPool(INonfungiblePositionManager.MintParams memory params, uint256 deadline)
        internal
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0Consumed, uint256 amount1Consumed)
    {
        /// @dev currency1 cant be NATIVE
        bool nativePair = params.poolKey.currency0.isNative();
        if (!nativePair) {
            approveMaxIfNeeded(params.poolKey.currency0, address(nonfungiblePositionManager), params.amount0Desired);
        }
        approveMaxIfNeeded(params.poolKey.currency1, address(nonfungiblePositionManager), params.amount1Desired);

        bytes memory mintData = abi.encode(
            INonfungiblePositionManager.CallbackData(
                INonfungiblePositionManager.CallbackDataType.Mint, abi.encode(params)
            )
        );
        bytes[] memory lockData = new bytes[](1);
        lockData[0] = mintData;

        (tokenId, liquidity, amount0Consumed, amount1Consumed) = abi.decode(
            nonfungiblePositionManager.modifyLiquidities{value: nativePair ? params.amount0Desired : 0}(
                abi.encode(lockData), deadline
            )[0],
            (uint256, uint128, uint256, uint256)
        );

        // receive surplus ETH from positionManager
        if (nativePair && params.amount0Desired > amount0Consumed) {
            nonfungiblePositionManager.refundETH();
        }
    }

    /// @inheritdoc ICLMigrator
    /// @notice Planned to be batched with migration operations through multicall to save gas
    function initialize(PoolKey memory poolKey, uint160 sqrtPriceX96, bytes calldata hookData)
        external
        payable
        override
        returns (int24 tick)
    {
        return nonfungiblePositionManager.initialize(poolKey, sqrtPriceX96, hookData);
    }

    receive() external payable {
        if (msg.sender != address(nonfungiblePositionManager) && msg.sender != WETH9) {
            revert INVALID_ETHER_SENDER();
        }
    }
}
