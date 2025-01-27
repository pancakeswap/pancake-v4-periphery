// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CommonBase} from "forge-std/Base.sol";
import {Currency} from "pancake-v4-core/src/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "pancake-v4-core/src/types/BalanceDelta.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {TickMath} from "pancake-v4-core/src/pool-cl/libraries/TickMath.sol";
import {LiquidityAmounts} from "pancake-v4-core/test/pool-cl/helpers/LiquidityAmounts.sol";
import {SafeCastTemp} from "../../../src/libraries/SafeCast.sol";

import {CLPositionManager} from "../../../src/pool-cl/CLPositionManager.sol";
import {Actions} from "../../../src/libraries/Actions.sol";
import {Planner, Plan} from "../../../src/libraries/Planner.sol";
import {HookSavesDelta} from "./HookSavesDelta.sol";
import {ICLPositionDescriptor} from "../../../src/pool-cl/interfaces/ICLPositionDescriptor.sol";

abstract contract CLLiquidityOperations is CommonBase {
    using SafeCastTemp for uint256;

    CLPositionManager lpm;
    ICLPositionDescriptor positionDescriptor;

    uint256 _deadline = block.timestamp + 1;

    PoolKey _latestPoolKey;

    uint128 constant MAX_SLIPPAGE_INCREASE = type(uint128).max;
    uint128 constant MIN_SLIPPAGE_DECREASE = 0 wei;

    function mint(
        PoolKey memory poolKey,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        address recipient,
        bytes memory hookData
    ) internal {
        bytes memory calls = getMintEncoded(poolKey, tickLower, tickUpper, liquidity, recipient, hookData);
        lpm.modifyLiquidities(calls, _deadline);
    }

    function mintWithNative(
        uint160 sqrtPriceX96,
        PoolKey memory poolKey,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        address recipient,
        bytes memory hookData
    ) internal {
        // determine the amount of ETH to send on-mint
        (uint256 amount0,) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity.toUint128()
        );
        bytes memory calls = getMintEncoded(poolKey, tickLower, tickUpper, liquidity, recipient, hookData);
        // add extra wei because modifyLiquidities may be rounding up, LiquidityAmounts is imprecise?
        lpm.modifyLiquidities{value: amount0 + 1}(calls, _deadline);
    }

    function increaseLiquidity(uint256 tokenId, uint256 liquidityToAdd, bytes memory hookData) internal {
        bytes memory calls = getIncreaseEncoded(tokenId, liquidityToAdd, hookData);
        lpm.modifyLiquidities(calls, _deadline);
    }

    // do not make external call before unlockAndExecute, allows us to test reverts
    function decreaseLiquidity(uint256 tokenId, uint256 liquidityToRemove, bytes memory hookData) internal {
        bytes memory calls = getDecreaseEncoded(tokenId, liquidityToRemove, hookData);
        lpm.modifyLiquidities(calls, _deadline);
    }

    function collect(uint256 tokenId, bytes memory hookData) internal {
        bytes memory calls = getCollectEncoded(tokenId, hookData);
        lpm.modifyLiquidities(calls, _deadline);
    }

    // This is encoded with close calls. Not all burns need to be encoded with closes if there is no liquidity in the position.
    function burn(uint256 tokenId, bytes memory hookData) internal {
        bytes memory calls = getBurnEncoded(tokenId, hookData);
        lpm.modifyLiquidities(calls, _deadline);
    }

    // Helper functions for getting encoded calldata for .modifyLiquidities() or .modifyLiquiditiesWithoutUnlock()
    function getMintEncoded(
        PoolKey memory poolKey,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory) {
        return getMintEncoded(
            poolKey, tickLower, tickUpper, liquidity, MAX_SLIPPAGE_INCREASE, MAX_SLIPPAGE_INCREASE, recipient, hookData
        );
    }

    function getMintEncoded(
        PoolKey memory poolKey,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory) {
        Plan memory planner = Planner.init();
        planner.add(
            Actions.CL_MINT_POSITION,
            abi.encode(poolKey, tickLower, tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData)
        );

        return planner.finalizeModifyLiquidityWithClose(poolKey);
    }

    function getIncreaseEncoded(uint256 tokenId, uint256 liquidityToAdd, bytes memory hookData)
        internal
        view
        returns (bytes memory)
    {
        // max slippage
        return getIncreaseEncoded(tokenId, liquidityToAdd, MAX_SLIPPAGE_INCREASE, MAX_SLIPPAGE_INCREASE, hookData);
    }

    function getIncreaseEncoded(
        uint256 tokenId,
        uint256 liquidityToAdd,
        uint128 amount0Max,
        uint128 amount1Max,
        bytes memory hookData
    ) internal view returns (bytes memory) {
        Plan memory planner = Planner.init();
        planner.add(
            Actions.CL_INCREASE_LIQUIDITY, abi.encode(tokenId, liquidityToAdd, amount0Max, amount1Max, hookData)
        );
        return planner.finalizeModifyLiquidityWithClose(_getLatestPoolKey(tokenId));
    }

    function getDecreaseEncoded(uint256 tokenId, uint256 liquidityToRemove, bytes memory hookData)
        internal
        view
        returns (bytes memory)
    {
        return getDecreaseEncoded(tokenId, liquidityToRemove, MIN_SLIPPAGE_DECREASE, MIN_SLIPPAGE_DECREASE, hookData);
    }

    function getDecreaseEncoded(
        uint256 tokenId,
        uint256 liquidityToRemove,
        uint128 amount0Min,
        uint128 amount1Min,
        bytes memory hookData
    ) internal view returns (bytes memory) {
        Plan memory planner = Planner.init();
        planner.add(
            Actions.CL_DECREASE_LIQUIDITY, abi.encode(tokenId, liquidityToRemove, amount0Min, amount1Min, hookData)
        );
        return planner.finalizeModifyLiquidityWithClose(_getLatestPoolKey(tokenId));
    }

    function getCollectEncoded(uint256 tokenId, bytes memory hookData) internal view returns (bytes memory) {
        return getCollectEncoded(tokenId, MIN_SLIPPAGE_DECREASE, MIN_SLIPPAGE_DECREASE, hookData);
    }

    function getCollectEncoded(uint256 tokenId, uint128 amount0Min, uint128 amount1Min, bytes memory hookData)
        internal
        view
        returns (bytes memory)
    {
        Plan memory planner = Planner.init();
        planner.add(Actions.CL_DECREASE_LIQUIDITY, abi.encode(tokenId, 0, amount0Min, amount1Min, hookData));
        return planner.finalizeModifyLiquidityWithClose(_getLatestPoolKey(tokenId));
    }

    function getBurnEncoded(uint256 tokenId, bytes memory hookData) internal view returns (bytes memory) {
        return getBurnEncoded(tokenId, MIN_SLIPPAGE_DECREASE, MIN_SLIPPAGE_DECREASE, hookData);
    }

    function getBurnEncoded(uint256 tokenId, uint128 amount0Min, uint128 amount1Min, bytes memory hookData)
        internal
        view
        returns (bytes memory)
    {
        Plan memory planner = Planner.init();
        planner.add(Actions.CL_BURN_POSITION, abi.encode(tokenId, amount0Min, amount1Min, hookData));
        // Close needed on burn in case there is liquidity left in the position.
        return planner.finalizeModifyLiquidityWithClose(_getLatestPoolKey(tokenId));
    }

    // expectRevert only detects the next call, so we need to avoid using external getPoolAndPositionInfo in some case
    function _getLatestPoolKey(uint256 tokenId) internal view returns (PoolKey memory poolKey) {
        if (address(_latestPoolKey.poolManager) != address(0)) {
            return _latestPoolKey;
        }
        (poolKey,) = lpm.getPoolAndPositionInfo(tokenId);
    }
}
