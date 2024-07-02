// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.19;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {BaseMigrator} from "../base/BaseMigrator.sol";
import {ICLMigrator} from "./interfaces/ICLMigrator.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";

contract CLMigrator is ICLMigrator, BaseMigrator {
    using LowGasSafeMath for uint256;

    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    constructor(address _WETH9, address _nonfungiblePositionManager) BaseMigrator(_WETH9) {
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

    function migrateFromV2(MigrateFromV2Params calldata params) external override {
        // 1. burn v2 liquidity to this address
        (uint256 amount0Received, uint256 amount1Received) =
            withdrawLiquidityFromV2(params.pair, params.liquidityToMigrate);

        // TODO: check amount0Received and amount1Received are within acceptable bounds

        // 2. mint v4 position token, token sent to recipient

        // TO BE CONFIRMED:
        // Consider the case from a WETH pool to a ETH pool (v3 not support ETH pool):
        // in that case we might need to unwrap WETH to ETH and send to the nfp contract
        // but how many token should be sent to the nfp contract ?
        // i don't see nfp have refund logic, what if the token consumed is less than the token sent ?

        SafeTransferLib.safeApprove(params.poolKey.currency0, address(nonfungiblePositionManager), amount0Desired);
        SafeTransferLib.safeApprove(params.poolKey.currency1, address(nonfungiblePositionManager), amount1Desired);

        (uint256 tokenId, uint128 liquidity, uint256 amount0Consumed, uint256 amount1Consumed) =
        nonfungiblePositionManager.mint(
            MintParams({
                PoolKey: params.poolKey,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                salt: params.salt,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: params.recipient,
                deadline: params.deadline
            })
        );

        // TODO: any other check here?

        // 3. clear allowance and refund if necessary
        if (params.amount0Desired > amount0Consumed) {
            SafeTransferLib.safeApprove(params.poolKey.currency0, address(nonfungiblePositionManager), 0);
        }
        if (params.amount1Desired > amount1Consumed) {
            SafeTransferLib.safeApprove(params.poolKey.currency1, address(nonfungiblePositionManager), 0);
        }

        if (amount0Received > amount0Consumed) {
            refund(params.poolKey.currency0, params.recipient, amount0Received - amount0Consumed);
        }

        if (amount1Received > amount1Consumed) {
            refund(params.poolKey.currency1, params.recipient, amount1Received - amount1Consumed);
        }

        // TODO: check whether we need any events here
    }

    function migrateFromV3(MigrateFromV3Params calldata params) external override {}
}
