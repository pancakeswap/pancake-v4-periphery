// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.0;

import {IInfinityRouter} from "../../interfaces/IInfinityRouter.sol";
import {CalldataDecoder} from "../../libraries/CalldataDecoder.sol";
import {PoolKey} from "infinity-core/src/types/PoolKey.sol";

/// @title Library for abi decoding in cl pool calldata
library CLCalldataDecoder {
    using CalldataDecoder for bytes;

    /// @notice equivalent to SliceOutOfBounds.selector, stored in least-significant bits
    uint256 constant SLICE_ERROR_SELECTOR = 0x3b99b53d;

    /// @dev equivalent to: abi.decode(params, (IInfinityRouter.CLExactInputParams))
    function decodeCLSwapExactInParams(bytes calldata params)
        internal
        pure
        returns (IInfinityRouter.CLSwapExactInputParams calldata swapParams)
    {
        // CLExactInputParams is a variable length struct so we just have to look up its location
        assembly ("memory-safe") {
            // only safety checks for the minimum length, where path is empty
            // 0xa0 = 5 * 0x20 -> 3 elements, path offset, and path length 0
            if lt(params.length, 0xa0) {
                mstore(0, SLICE_ERROR_SELECTOR)
                revert(0x1c, 4)
            }
            swapParams := add(params.offset, calldataload(params.offset))
        }
    }

    /// @dev equivalent to: abi.decode(params, (IInfinityRouter.CLExactInputSingleParams))
    function decodeCLSwapExactInSingleParams(bytes calldata params)
        internal
        pure
        returns (IInfinityRouter.CLSwapExactInputSingleParams calldata swapParams)
    {
        // CLExactInputSingleParams is a variable length struct so we just have to look up its location
        assembly ("memory-safe") {
            // only safety checks for the minimum length, where hookData is empty
            // 0x160 = 11 * 0x20 -> 9 elements, bytes offset, and bytes length 0
            if lt(params.length, 0x160) {
                mstore(0, SLICE_ERROR_SELECTOR)
                revert(0x1c, 4)
            }
            swapParams := add(params.offset, calldataload(params.offset))
        }
    }

    /// @dev equivalent to: abi.decode(params, (IInfinityRouter.CLExactOutputParams))
    function decodeCLSwapExactOutParams(bytes calldata params)
        internal
        pure
        returns (IInfinityRouter.CLSwapExactOutputParams calldata swapParams)
    {
        // CLExactOutputParams is a variable length struct so we just have to look up its location
        assembly ("memory-safe") {
            // only safety checks for the minimum length, where path is empty
            // 0xa0 = 5 * 0x20 -> 3 elements, path offset, and path length 0
            if lt(params.length, 0xa0) {
                mstore(0, SLICE_ERROR_SELECTOR)
                revert(0x1c, 4)
            }
            swapParams := add(params.offset, calldataload(params.offset))
        }
    }

    /// @dev equivalent to: abi.decode(params, (IInfinityRouter.CLExactOutputSingleParams))
    function decodeCLSwapExactOutSingleParams(bytes calldata params)
        internal
        pure
        returns (IInfinityRouter.CLSwapExactOutputSingleParams calldata swapParams)
    {
        // CLExactOutputSingleParams is a variable length struct so we just have to look up its location
        assembly ("memory-safe") {
            // only safety checks for the minimum length, where hookData is empty
            // 0x160 = 9 * 0x20 -> 9 elements, bytes offset, and bytes length 0
            if lt(params.length, 0x160) {
                mstore(0, SLICE_ERROR_SELECTOR)
                revert(0x1c, 4)
            }
            swapParams := add(params.offset, calldataload(params.offset))
        }
    }

    /// @dev equivalent to: abi.decode(params, (uint256, uint256, uint128, uint128, bytes)) in calldata
    function decodeCLModifyLiquidityParams(bytes calldata params)
        internal
        pure
        returns (uint256 tokenId, uint256 liquidity, uint128 amount0, uint128 amount1, bytes calldata hookData)
    {
        // length validation is already handled in `params.toBytes`
        assembly ("memory-safe") {
            tokenId := calldataload(params.offset)
            liquidity := calldataload(add(params.offset, 0x20))
            amount0 := calldataload(add(params.offset, 0x40))
            amount1 := calldataload(add(params.offset, 0x60))
        }

        hookData = params.toBytes(4);
    }

    /// @dev equivalent to: abi.decode(params, (uint256, uint128, uint128, bytes)) in calldata
    function decodeCLIncreaseLiquidityFromDeltasParams(bytes calldata params)
        internal
        pure
        returns (uint256 tokenId, uint128 amount0Max, uint128 amount1Max, bytes calldata hookData)
    {
        // length validation is already handled in `params.toBytes`
        assembly ("memory-safe") {
            tokenId := calldataload(params.offset)
            amount0Max := calldataload(add(params.offset, 0x20))
            amount1Max := calldataload(add(params.offset, 0x40))
        }

        hookData = params.toBytes(3);
    }

    /// @dev equivalent to: abi.decode(params, (PoolKey, int24, int24, uint256, uint128, uint128, address, bytes)) in calldata
    function decodeCLMintParams(bytes calldata params)
        internal
        pure
        returns (
            PoolKey calldata poolKey,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidity,
            uint128 amount0Max,
            uint128 amount1Max,
            address owner,
            bytes calldata hookData
        )
    {
        // length validation is already handled in `params.toBytes`
        assembly ("memory-safe") {
            poolKey := params.offset
            tickLower := calldataload(add(params.offset, 0xc0))
            tickUpper := calldataload(add(params.offset, 0xe0))
            liquidity := calldataload(add(params.offset, 0x100))
            amount0Max := calldataload(add(params.offset, 0x120))
            amount1Max := calldataload(add(params.offset, 0x140))
            owner := calldataload(add(params.offset, 0x160))
        }
        hookData = params.toBytes(12);
    }

    /// @dev equivalent to: abi.decode(params, (PoolKey, int24, int24, uint128, uint128, address, bytes)) in calldata
    function decodeCLMintFromDeltasParams(bytes calldata params)
        internal
        pure
        returns (
            PoolKey calldata poolKey,
            int24 tickLower,
            int24 tickUpper,
            uint128 amount0Max,
            uint128 amount1Max,
            address owner,
            bytes calldata hookData
        )
    {
        // length validation is already handled in `params.toBytes`
        assembly ("memory-safe") {
            poolKey := params.offset
            tickLower := calldataload(add(params.offset, 0xc0))
            tickUpper := calldataload(add(params.offset, 0xe0))
            amount0Max := calldataload(add(params.offset, 0x100))
            amount1Max := calldataload(add(params.offset, 0x120))
            owner := calldataload(add(params.offset, 0x140))
        }

        hookData = params.toBytes(11);
    }

    /// @dev equivalent to: abi.decode(params, (uint256, uint128, uint128, bytes)) in calldata
    function decodeCLBurnParams(bytes calldata params)
        internal
        pure
        returns (uint256 tokenId, uint128 amount0Min, uint128 amount1Min, bytes calldata hookData)
    {
        // length validation is already handled in `params.toBytes`
        assembly ("memory-safe") {
            tokenId := calldataload(params.offset)
            amount0Min := calldataload(add(params.offset, 0x20))
            amount1Min := calldataload(add(params.offset, 0x40))
        }
        hookData = params.toBytes(3);
    }
}
