// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CLCalldataDecoder} from "../../../src/pool-cl/libraries/CLCalldataDecoder.sol";
import {IV4Router} from "../../../src/interfaces/IV4Router.sol";
import {Currency} from "pancake-v4-core/src/types/Currency.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";

// we need to use a mock contract to make the calls happen in calldata not memory
contract MockCLCalldataDecoder {
    using CLCalldataDecoder for bytes;

    struct CLMintFromDeltasParams {
        PoolKey poolKey;
        int24 tickLower;
        int24 tickUpper;
        uint128 amount0Max;
        uint128 amount1Max;
        address owner;
        bytes hookData;
    }

    function decodeCLModifyLiquidityParams(bytes calldata params)
        external
        pure
        returns (uint256 tokenId, uint256 liquidity, uint128 amount0, uint128 amount1, bytes calldata hookData)
    {
        return params.decodeCLModifyLiquidityParams();
    }

    function decodeCLBurnParams(bytes calldata params)
        external
        pure
        returns (uint256 tokenId, uint128 amount0Min, uint128 amount1Min, bytes calldata hookData)
    {
        return params.decodeCLBurnParams();
    }

    function decodeCLSwapExactInParams(bytes calldata params)
        external
        pure
        returns (IV4Router.CLSwapExactInputParams calldata swapParams)
    {
        return params.decodeCLSwapExactInParams();
    }

    function decodeCLSwapExactInSingleParams(bytes calldata params)
        external
        pure
        returns (IV4Router.CLSwapExactInputSingleParams calldata swapParams)
    {
        return params.decodeCLSwapExactInSingleParams();
    }

    function decodeCLSwapExactOutParams(bytes calldata params)
        external
        pure
        returns (IV4Router.CLSwapExactOutputParams calldata swapParams)
    {
        return params.decodeCLSwapExactOutParams();
    }

    function decodeCLSwapExactOutSingleParams(bytes calldata params)
        external
        pure
        returns (IV4Router.CLSwapExactOutputSingleParams calldata swapParams)
    {
        return params.decodeCLSwapExactOutSingleParams();
    }

    function decodeCLMintParams(bytes calldata params)
        external
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
        return params.decodeCLMintParams();
    }

    function decodeIncreaseLiquidityFromDeltasParams(bytes calldata params)
        external
        pure
        returns (uint256 tokenId, uint128 amount0Max, uint128 amount1Max, bytes calldata hookData)
    {
        return params.decodeCLIncreaseLiquidityFromDeltasParams();
    }

    function decodeCLMintFromDeltasParams(bytes calldata params)
        external
        pure
        returns (CLMintFromDeltasParams memory mintParams)
    {
        (
            PoolKey memory poolKey,
            int24 tickLower,
            int24 tickUpper,
            uint128 amount0Max,
            uint128 amount1Max,
            address owner,
            bytes memory hookData
        ) = params.decodeCLMintFromDeltasParams();
        return CLMintFromDeltasParams({
            poolKey: poolKey,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Max: amount0Max,
            amount1Max: amount1Max,
            owner: owner,
            hookData: hookData
        });
    }
}
