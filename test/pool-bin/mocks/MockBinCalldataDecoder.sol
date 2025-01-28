// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BinCalldataDecoder} from "../../../src/pool-bin/libraries/BinCalldataDecoder.sol";
import {IInfinityRouter} from "../../../src/interfaces/IInfinityRouter.sol";
import {IBinPositionManager} from "../../../src/pool-bin/interfaces/IBinPositionManager.sol";
import {Currency} from "infinity-core/src/types/Currency.sol";

// we need to use a mock contract to make the calls happen in calldata not memory
contract MockBinCalldataDecoder {
    using BinCalldataDecoder for bytes;

    function decodeBinAddLiquidityParams(bytes calldata params)
        external
        pure
        returns (IBinPositionManager.BinAddLiquidityParams calldata addLiquidityParams)
    {
        return params.decodeBinAddLiquidityParams();
    }

    function decodeBinRemoveLiquidityParams(bytes calldata params)
        external
        pure
        returns (IBinPositionManager.BinRemoveLiquidityParams calldata removeLiquidityParams)
    {
        return params.decodeBinRemoveLiquidityParams();
    }

    function decodeBinAddLiquidityFromDeltasParams(bytes calldata params)
        external
        pure
        returns (IBinPositionManager.BinAddLiquidityFromDeltasParams calldata addLiquidityParams)
    {
        return params.decodeBinAddLiquidityFromDeltasParams();
    }

    function decodeBinSwapExactInParams(bytes calldata params)
        external
        pure
        returns (IInfinityRouter.BinSwapExactInputParams calldata swapParams)
    {
        return params.decodeBinSwapExactInParams();
    }

    function decodeBinSwapExactInSingleParams(bytes calldata params)
        external
        pure
        returns (IInfinityRouter.BinSwapExactInputSingleParams calldata swapParams)
    {
        return params.decodeBinSwapExactInSingleParams();
    }

    function decodeBinSwapExactOutParams(bytes calldata params)
        external
        pure
        returns (IInfinityRouter.BinSwapExactOutputParams calldata swapParams)
    {
        return params.decodeBinSwapExactOutParams();
    }

    function decodeBinSwapExactOutSingleParams(bytes calldata params)
        external
        pure
        returns (IInfinityRouter.BinSwapExactOutputSingleParams calldata swapParams)
    {
        return params.decodeBinSwapExactOutSingleParams();
    }
}
