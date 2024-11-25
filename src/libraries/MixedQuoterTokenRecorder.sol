// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";

/// @dev Record all inputs and outputs of all transactions in the path.
library MixedQuoterTokenRecorder {
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

    /// @dev uint256 internal constant SWAP_V4_CL = uint256(keccak256("MIXED_QUOTER_SWAP_V4_CL")) - 1;
    uint256 internal constant SWAP_V4_CL = 0x1a7c9a13842b613486d9207eda875c24e33425305b8b8df2e040c19ef2ae3088;

    /// @dev uint256 internal constant SWAP_V4_BIN = uint256(keccak256("MIXED_QUOTER_SWAP_V4_BIN")) - 1;
    uint256 internal constant SWAP_V4_BIN = 0xea33987d3dc3e2595aa727354eec3d9b92d4061c1331c4a19f9862248f2e1040;

    enum SwapType {
        V2,
        V3,
        V4_CL,
        V4_BIN
    }

    enum SwapDirection {
        NONE,
        ZeroForOne,
        OneForZero
    }

    error INVALID_SWAP_DIRECTION();

    /// @dev Record the swap direction of the transaction.
    /// @dev Only support one direction for same pool in one transaction.
    /// @param poolHash The hash of the pool.
    /// @param swapDirection The direction of the swap, default is 0, 1 mean swap from token0 to token1, 2 mean swap from token1 to token0.
    function setAndCheckSwapDirection(bytes32 poolHash, uint256 swapDirection) internal {
        if (swapDirection != uint256(SwapDirection.ZeroForOne) && swapDirection != uint256(SwapDirection.OneForZero)) {
            revert INVALID_SWAP_DIRECTION();
        }
        uint256 currentDirection = getSwapDirection(poolHash);
        if (currentDirection == swapDirection) return;

        if (currentDirection == uint256(SwapDirection.NONE)) {
            uint256 directionSlot = uint256(keccak256(abi.encode(poolHash, SWAP_DIRECTION)));
            assembly {
                tstore(directionSlot, swapDirection)
            }
        } else {
            revert INVALID_SWAP_DIRECTION();
        }
    }

    function getSwapDirection(bytes32 poolHash) internal view returns (uint256) {
        uint256 directionSlot = uint256(keccak256(abi.encode(poolHash, SWAP_DIRECTION)));
        uint256 swapDirection;
        assembly {
            swapDirection := tload(directionSlot)
        }
        return swapDirection;
    }

    /// @dev Record the swap token accumulation of the pool.
    /// @param poolHash The hash of the pool.
    /// @param amount0 The amount of token0.
    /// @param amount1 The amount of token1.
    function setPoolSwapTokenAccumulation(bytes32 poolHash, uint256 amount0, uint256 amount1) internal {
        uint256 token0Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN0_ACCUMULATION)));
        uint256 token1Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN1_ACCUMULATION)));
        (uint256 currentAmount0, uint256 currentAmount1) = getPoolSwapTokenAccumulation(poolHash);
        amount0 += currentAmount0;
        amount1 += currentAmount1;
        assembly {
            tstore(token0Slot, amount0)
            tstore(token1Slot, amount1)
        }
    }

    function setPoolSwapTokenAccumulation(bytes32 poolHash, uint256 amountIn, uint256 amountOut, bool isZeroForOne)
        internal
    {
        uint256 token0Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN0_ACCUMULATION)));
        uint256 token1Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN1_ACCUMULATION)));
        (uint256 currentAmount0, uint256 currentAmount1) = getPoolSwapTokenAccumulation(poolHash);
        uint256 amount0;
        uint256 amount1;
        if (isZeroForOne) {
            amount0 = currentAmount0 + amountIn;
            amount1 = currentAmount1 + amountOut;
        } else {
            amount0 = currentAmount0 + amountOut;
            amount1 = currentAmount1 + amountIn;
        }
        assembly {
            tstore(token0Slot, amount0)
            tstore(token1Slot, amount1)
        }
    }

    /// @dev Get the swap token accumulation of the pool.
    /// @param poolHash The hash of the pool.
    /// @return amount0 The amount of token0.
    /// @return amount1 The amount of token1.
    function getPoolSwapTokenAccumulation(bytes32 poolHash) internal view returns (uint256, uint256) {
        uint256 token0Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN0_ACCUMULATION)));
        uint256 token1Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN1_ACCUMULATION)));
        uint256 amount0;
        uint256 amount1;
        assembly {
            amount0 := tload(token0Slot)
            amount1 := tload(token1Slot)
        }
        return (amount0, amount1);
    }

    function getPoolSwapTokenAccumulation(bytes32 poolHash, bool isZeroForOne)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 token0Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN0_ACCUMULATION)));
        uint256 token1Slot = uint256(keccak256(abi.encode(poolHash, SWAP_TOKEN1_ACCUMULATION)));
        uint256 amount0;
        uint256 amount1;
        assembly {
            amount0 := tload(token0Slot)
            amount1 := tload(token1Slot)
        }
        if (isZeroForOne) {
            return (amount0, amount1);
        } else {
            return (amount1, amount0);
        }
    }

    function getV2PoolSwapTokenAccumulation(address token0, address token1, bool isZeroForOne)
        internal
        view
        returns (uint256, uint256)
    {
        return getPoolSwapTokenAccumulation(getV2PoolHash(token0, token1), isZeroForOne);
    }

    function getSSPoolHash(address token0, address token1) internal pure returns (bytes32) {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        return keccak256(abi.encode(token0, token1, SWAP_SS));
    }

    function getV2PoolHash(address token0, address token1) internal pure returns (bytes32) {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        return keccak256(abi.encode(token0, token1, SWAP_V2));
    }

    function getV3PoolHash(address token0, address token1, uint24 fee) internal pure returns (bytes32) {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        return keccak256(abi.encode(token0, token1, fee, SWAP_V3));
    }

    function getV4CLPoolHash(PoolKey memory key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, SWAP_V4_CL));
    }

    function getV4BinPoolHash(PoolKey memory key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, SWAP_V4_BIN));
    }
}
