// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.19;

import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";

interface ICLMigrator {
    struct MigrateFromV2Params {
        // source v2 pool params
        address pair; // the PancakeSwap v2-compatible pair
        uint256 liquidityToMigrate; // the amount of liquidity to migrate
        // target v4 pool params
        PoolKey poolKey;
        int24 tickLower;
        int24 tickUpper;
        bytes32 salt;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
        bool refundAsETH;
    }

    struct MigrateFromV3Params {
        // source v3 pool params
        address nfp; // the PancakeSwap v3-compatible NFP
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0MinForV3;
        uint256 amount1MinForV3;
        bool collectFee;
        // target v4 pool params
        PoolKey poolKey; // the target v4 pool
        int24 tickLower;
        int24 tickUpper;
        bytes32 salt;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min; // must be discounted by percentageToMigrate
        uint256 amount1Min; // must be discounted by percentageToMigrate
        address recipient;
        uint256 deadline;
        bool refundAsETH;
    }

    function migrateFromV2(MigrateFromV2Params calldata params) external;

    function migrateFromV3(MigrateFromV3Params calldata params) external;
}
