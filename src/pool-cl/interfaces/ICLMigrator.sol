// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {IBaseMigrator} from "../../interfaces/IBaseMigrator.sol";
import {IV3NonfungiblePositionManager} from "../../interfaces/external/IV3NonfungiblePositionManager.sol";

interface ICLMigrator is IBaseMigrator {
    error INSUFFICIENT_LIQUIDITY();

    /// @notice same fields as INonfungiblePositionManager.MintParams
    /// except amount0Desired/amount1Desired which will be calculated by migrator
    struct InfiCLPoolParams {
        PoolKey poolKey;
        int24 tickLower;
        int24 tickUpper;
        uint256 liquidityMin;
        address recipient;
        uint256 deadline;
        // hookData will flow to hook's beforeAddLiquidity/ afterAddLiquidity
        bytes hookData;
    }

    struct MintParams {
        PoolKey poolKey;
        int24 tickLower;
        int24 tickUpper;
        uint128 amount0In;
        uint128 amount1In;
        uint256 liquidityMin;
        address recipient;
        bytes hookData;
    }

    /// @notice Migrate liquidity from v2 to infinity
    /// @param v2PoolParams ncessary info for removing liqudity the source v2 pool
    /// @param infiPoolParams necessary info for adding liquidity the target infinity cl-pool
    /// @param extraAmount0 the extra amount of token0 that user wants to add (optional, usually 0)
    /// if pool token0 is ETH and msg.value == 0, WETH will be taken from sender.
    /// Otherwise if pool token0 is ETH and msg.value !=0, method will assume user have sent extraAmount0 in msg.value
    /// @param extraAmount1 the extra amount of token1 that user wants to add (optional, usually 0)
    function migrateFromV2(
        V2PoolParams calldata v2PoolParams,
        InfiCLPoolParams calldata infiPoolParams,
        // extra funds to be added
        uint256 extraAmount0,
        uint256 extraAmount1
    ) external payable;

    /// @notice Migrate liquidity from v3 to infinity
    /// @param v3PoolParams ncessary info for removing liqudity the source v3 pool
    /// @param infiPoolParams necessary info for adding liquidity the target infinity cl-pool
    /// @param extraAmount0 the extra amount of token0 that user wants to add (optional, usually 0)
    /// if pool token0 is ETH and msg.value == 0, WETH will be taken from sender.
    /// Otherwise if pool token0 is ETH and msg.value !=0, method will assume user have sent extraAmount0 in msg.value
    /// @param extraAmount1 the extra amount of token1 that user wants to add (optional, usually 0)
    function migrateFromV3(
        V3PoolParams calldata v3PoolParams,
        InfiCLPoolParams calldata infiPoolParams,
        // extra funds to be added
        uint256 extraAmount0,
        uint256 extraAmount1
    ) external payable;

    /// @notice Initialize a pool for a given pool key, the function will forwards the call to the CLPoolManager
    /// @dev Call this when the pool does not exist and is not initialized.
    /// @param poolKey The pool key
    /// @param sqrtPriceX96 The initial sqrt price of the pool
    /// @return tick Pool tick
    function initializePool(PoolKey memory poolKey, uint160 sqrtPriceX96) external payable returns (int24 tick);
}
