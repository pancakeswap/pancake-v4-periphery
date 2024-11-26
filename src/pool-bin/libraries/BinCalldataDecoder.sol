// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IBinPositionManager} from "../interfaces/IBinPositionManager.sol";
import {IV4Router} from "../../interfaces/IV4Router.sol";

/// @title Library for abi decoding in bin pool calldata
library BinCalldataDecoder {
    /// @notice equivalent to SliceOutOfBounds.selector, stored in least-significant bits
    uint256 constant SLICE_ERROR_SELECTOR = 0x3b99b53d;

    /// todo: <wip> see if tweaking to calldataload saves gas
    /// @dev equivalent to: abi.decode(params, (IBinPositionManager.BinAddLiquidityParams))
    function decodeBinAddLiquidityParams(bytes calldata params)
        internal
        pure
        returns (IBinPositionManager.BinAddLiquidityParams calldata addLiquidityParams)
    {
        assembly ("memory-safe") {
            addLiquidityParams := add(params.offset, calldataload(params.offset))
        }
    }

    /// todo: <wip> see if tweaking to calldataload saves gas
    /// @dev equivalent to: abi.decode(params, (IBinPositionManager.BinRemoveLiquidityParams))
    function decodeBinRemoveLiquidityParams(bytes calldata params)
        internal
        pure
        returns (IBinPositionManager.BinRemoveLiquidityParams calldata removeLiquidityParams)
    {
        assembly ("memory-safe") {
            removeLiquidityParams := add(params.offset, calldataload(params.offset))
        }
    }

    /// @dev equivalent to: abi.decode(params, (IV4Router.BinExactInputParams))
    function decodeBinSwapExactInParams(bytes calldata params)
        internal
        pure
        returns (IV4Router.BinSwapExactInputParams calldata swapParams)
    {
        // BinExactInputParams is a variable length struct so we just have to look up its location
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

    /// @dev equivalent to: abi.decode(params, (IV4Router.BinExactInputSingleParams))
    function decodeBinSwapExactInSingleParams(bytes calldata params)
        internal
        pure
        returns (IV4Router.BinSwapExactInputSingleParams calldata swapParams)
    {
        // BinExactInputSingleParams is a variable length struct so we just have to look up its location
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

    /// @dev equivalent to: abi.decode(params, (IV4Router.BinExactOutputParams))
    function decodeBinSwapExactOutParams(bytes calldata params)
        internal
        pure
        returns (IV4Router.BinSwapExactOutputParams calldata swapParams)
    {
        // BinExactOutputParams is a variable length struct so we just have to look up its location
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

    /// @dev equivalent to: abi.decode(params, (IV4Router.BinExactOutputSingleParams))
    function decodeBinSwapExactOutSingleParams(bytes calldata params)
        internal
        pure
        returns (IV4Router.BinSwapExactOutputSingleParams calldata swapParams)
    {
        // BinExactOutputSingleParams is a variable length struct so we just have to look up its location
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
}
