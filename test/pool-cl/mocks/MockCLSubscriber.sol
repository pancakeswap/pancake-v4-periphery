// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ICLSubscriber} from "../../../src/pool-cl/interfaces/ICLSubscriber.sol";
import {CLPositionManager} from "../../../src/pool-cl/CLPositionManager.sol";
import {BalanceDelta} from "infinity-core/src/types/BalanceDelta.sol";
import {CLPositionInfo} from "../../../src/pool-cl/libraries/CLPositionInfoLibrary.sol";

/// @notice A subscriber contract that ingests updates from the v4 position manager
contract MockCLSubscriber is ICLSubscriber {
    CLPositionManager posm;

    uint256 public notifySubscribeCount;
    uint256 public notifyUnsubscribeCount;
    uint256 public notifyModifyLiquidityCount;
    uint256 public notifyBurnCount;
    int256 public liquidityChange;
    uint256 public liquidity;
    BalanceDelta public feesAccrued;

    bytes public subscribeData;

    error NotAuthorizedNotifer(address sender);

    error NotImplemented();

    constructor(CLPositionManager _posm) {
        posm = _posm;
    }

    modifier onlyByPosm() {
        if (msg.sender != address(posm)) revert NotAuthorizedNotifer(msg.sender);
        _;
    }

    function notifySubscribe(uint256, bytes memory data) external onlyByPosm {
        notifySubscribeCount++;
        subscribeData = data;
    }

    function notifyUnsubscribe(uint256) external onlyByPosm {
        notifyUnsubscribeCount++;
    }

    function notifyModifyLiquidity(uint256, int256 _liquidityChange, BalanceDelta _feesAccrued) external onlyByPosm {
        notifyModifyLiquidityCount++;
        liquidityChange = _liquidityChange;
        feesAccrued = _feesAccrued;
    }

    function notifyBurn(uint256, address, CLPositionInfo, uint256 _liquidity, BalanceDelta _feesAccrued)
        external
        onlyByPosm
    {
        liquidity = _liquidity;
        feesAccrued = _feesAccrued;
        notifyBurnCount++;
    }
}
