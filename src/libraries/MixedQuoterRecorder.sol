// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity 0.8.26;

import {PoolKey} from "infinity-core/src/types/PoolKey.sol";

/// @dev Record all token accumulation and swap direction of the transaction for non-infinity pools.
/// @dev Record infinity swap history list for infinity pools.
library MixedQuoterRecorder {
    /// @dev uint256 internal constant SWAP_DIRECTION = uint256(keccak256("MIXED_QUOTER_SWAP_DIRECTION")) - 1;
    uint256 internal constant SWAP_DIRECTION = 0x420071594cddc2905acbd674683749db4c139d373cc290ba8d49c75296a9f1f9;

    /// @dev uint256 internal constant SWAP_TOKEN0_ACCUMULATION = uint256(keccak256("MIXED_QUOTER_SWAP_TOKEN0_ACCUMULATION")) - 1;
    uint256 internal constant SWAP_TOKEN0_ACCUMULATION =
        0x6859b060ba2f84c00df66c40e8848222c89b2fcc89d5edc84074b9878818ea86;

    /// @dev uint256 internal constant SWAP_TOKEN1_ACCUMULATION = uint256(keccak256("MIXED_QUOTER_SWAP_TOKEN1_ACCUMULATION")) - 1;
    uint256 internal constant SWAP_TOKEN1_ACCUMULATION =
        0x8039a0cfe43b448f327ddf378771d67fba431d4dbc5c8f9531fa80f8a45125e9;

    /// @dev uint256 internal SWAP_SS = uint256(keccak256("MIXED_QUOTER_SWAP_SS")) - 1;
    uint256 internal constant SWAP_SS = 0x0b6c8b64c3ab4ac7b96ca59ae1454278ba2d62c99873c03d98ae968df846210a;

    /// @dev uint256 internal SWAP_V2 = uint256(keccak256("MIXED_QUOTER_SWAP_V2")) - 1;
    uint256 internal constant SWAP_V2 = 0xfb50ad98219c08ac49c2f2012c28ee455be42a0adc9a9a5df9e0882de4cf56b5;

    /// @dev uint256 internal constant SWAP_V3 = uint256(keccak256("MIXED_QUOTER_SWAP_V3")) - 1;
    uint256 internal constant SWAP_V3 = 0xd9d373c35d602baa7832c86d4af60fe46a2e18634c87bebc20d0050afb7633b3;

    /// @dev uint256 internal constant SWAP_INFI_CL = uint256(keccak256("MIXED_QUOTER_SWAP_INFI_CL")) - 1;
    uint256 internal constant SWAP_INFI_CL = 0x4feb57dd10cb5162909904ca541d6f7c45508b5d9792044648a6eba88f79d97;

    /// @dev uint256 internal constant SWAP_INFI_BIN = uint256(keccak256("MIXED_QUOTER_SWAP_INFI_BIN")) - 1;
    uint256 internal constant SWAP_INFI_BIN = 0x5f3e6018e8b2ccef782c927f292822290a80de8ee586b625fcd9a2e443bf80b1;

    /// @dev uint256 internal constant SWAP_INFI_LIST = uint256(keccak256("MIXED_QUOTER_SWAP_INFI_LIST")) - 1;
    uint256 internal constant SWAP_INFI_LIST = 0x32f6ae18dd733261edd4a84eefa6e2b1fe927f73449d02df9df6ca8eaba3b6df;

    enum SwapDirection {
        NONE,
        ZeroForOne,
        OneForZero
    }

    error INVALID_SWAP_DIRECTION();

    /// @dev Record and check the swap direction of the transaction.
    /// @dev Only support one direction for same non-infinity pool in one transaction.
    /// @param poolHash The hash of the pool.
    /// @param isZeroForOne The direction of the swap.
    function setAndCheckSwapDirection(bytes32 poolHash, bool isZeroForOne) internal {
        uint256 swapDirection = isZeroForOne ? uint256(SwapDirection.ZeroForOne) : uint256(SwapDirection.OneForZero);

        uint256 currentDirection = getSwapDirection(poolHash);
        if (currentDirection == uint256(SwapDirection.NONE)) {
            uint256 directionSlot = uint256(keccak256(abi.encode(poolHash, SWAP_DIRECTION)));
            assembly ("memory-safe") {
                tstore(directionSlot, swapDirection)
            }
        } else if (currentDirection != swapDirection) {
            revert INVALID_SWAP_DIRECTION();
        }
    }

    /// @dev Get the swap direction of the transaction.
    /// @param poolHash The hash of the pool.
    /// @return swapDirection The direction of the swap.
    function getSwapDirection(bytes32 poolHash) internal view returns (uint256 swapDirection) {
        uint256 directionSlot = uint256(keccak256(abi.encode(poolHash, SWAP_DIRECTION)));
        assembly ("memory-safe") {
            swapDirection := tload(directionSlot)
        }
    }

    /// @dev Record the swap token accumulation of the pool.
    /// @param poolHash The hash of the pool.
    /// @param amountIn The amount of tokenIn.
    /// @param amountOut The amount of tokenOut.
    /// @param isZeroForOne The direction of the swap.
    function setPoolSwapTokenAccumulation(bytes32 poolHash, uint256 amountIn, uint256 amountOut, bool isZeroForOne)
        internal
    {
        uint256 token0Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN0_ACCUMULATION)));
        uint256 token1Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN1_ACCUMULATION)));
        uint256 amount0;
        uint256 amount1;
        if (isZeroForOne) {
            amount0 = amountIn;
            amount1 = amountOut;
        } else {
            amount0 = amountOut;
            amount1 = amountIn;
        }
        assembly ("memory-safe") {
            tstore(token0Slot, amount0)
            tstore(token1Slot, amount1)
        }
    }

    // @dev Get the swap token accumulation of the pool.
    // @param poolHash The hash of the pool.
    // @param isZeroForOne The direction of the swap.
    // @return accAmountIn The accumulation amount of tokenIn.
    // @return accAmountOut The accumulation amount of tokenOut.
    function getPoolSwapTokenAccumulation(bytes32 poolHash, bool isZeroForOne)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 token0Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN0_ACCUMULATION)));
        uint256 token1Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN1_ACCUMULATION)));
        uint256 amount0;
        uint256 amount1;
        assembly ("memory-safe") {
            amount0 := tload(token0Slot)
            amount1 := tload(token1Slot)
        }
        if (isZeroForOne) {
            return (amount0, amount1);
        } else {
            return (amount1, amount0);
        }
    }

    /// @dev Record the swap history list of infinity pool.
    /// @param poolHash The hash of the pool.
    /// @param swapListBytes The swap history list bytes.
    function setInfiPoolSwapList(bytes32 poolHash, bytes memory swapListBytes) internal {
        uint256 swapListSlot = uint256(keccak256(abi.encode(poolHash, SWAP_INFI_LIST)));
        assembly ("memory-safe") {
            // save the length of the bytes
            tstore(swapListSlot, mload(swapListBytes))

            // save data in next slot
            let dataSlot := add(swapListSlot, 1)
            for { let i := 0 } lt(i, mload(swapListBytes)) { i := add(i, 32) } {
                tstore(add(dataSlot, div(i, 32)), mload(add(swapListBytes, add(0x20, i))))
            }
        }
    }

    /// @dev Get the swap history list of infinity pool.
    /// @param poolHash The hash of the pool.
    /// @return swapListBytes The swap history list bytes.
    function getInfiPoolSwapList(bytes32 poolHash) internal view returns (bytes memory swapListBytes) {
        uint256 swapListSlot = uint256(keccak256(abi.encode(poolHash, SWAP_INFI_LIST)));
        assembly ("memory-safe") {
            // get the length of the bytes
            let length := tload(swapListSlot)
            swapListBytes := mload(0x40)
            mstore(swapListBytes, length)
            let dataSlot := add(swapListSlot, 1)
            for { let i := 0 } lt(i, length) { i := add(i, 32) } {
                mstore(add(swapListBytes, add(0x20, i)), tload(add(dataSlot, div(i, 32))))
            }
            mstore(0x40, add(swapListBytes, add(0x20, length)))
        }
    }

    /// @dev Get the stable swap pool hash.
    /// @param token0 The address of token0.
    /// @param token1 The address of token1.
    /// @return poolHash The hash of the pool.
    function getSSPoolHash(address token0, address token1) internal pure returns (bytes32) {
        if (token0 == token1) revert();
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        return keccak256(abi.encode(token0, token1, SWAP_SS));
    }

    /// @dev Get the v2 pool hash.
    /// @param token0 The address of token0.
    /// @param token1 The address of token1.
    /// @return poolHash The hash of the pool.
    function getV2PoolHash(address token0, address token1) internal pure returns (bytes32) {
        if (token0 == token1) revert();
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        return keccak256(abi.encode(token0, token1, SWAP_V2));
    }

    /// @dev Get the v3 pool hash.
    /// @param token0 The address of token0.
    /// @param token1 The address of token1.
    /// @param fee The fee of the pool.
    function getV3PoolHash(address token0, address token1, uint24 fee) internal pure returns (bytes32) {
        if (token0 == token1) revert();
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        return keccak256(abi.encode(token0, token1, fee, SWAP_V3));
    }

    /// @dev Get the infinity cl pool hash.
    /// @param key The pool key.
    /// @return poolHash The hash of the pool.
    function getInfiCLPoolHash(PoolKey memory key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, SWAP_INFI_CL));
    }

    /// @dev Get the infinity bin pool hash.
    /// @param key The pool key.
    /// @return poolHash The hash of the pool.
    function getInfiBinPoolHash(PoolKey memory key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, SWAP_INFI_BIN));
    }
}
