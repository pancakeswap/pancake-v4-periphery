// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ICLSubscriber} from "../interfaces/ICLSubscriber.sol";
import {PositionConfig} from "../libraries/PositionConfig.sol";
import {PositionConfigId, PositionConfigIdLibrary} from "../libraries/PositionConfigId.sol";
import {BipsLibrary} from "../../libraries/BipsLibrary.sol";
import {ICLNotifier} from "../interfaces/ICLNotifier.sol";
import {CustomRevert} from "pancake-v4-core/src/libraries/CustomRevert.sol";
import {BalanceDelta} from "pancake-v4-core/src/types/BalanceDelta.sol";

/// @notice Notifier is used to opt in to sending updates to external contracts about position modifications or transfers
abstract contract CLNotifier is ICLNotifier {
    using BipsLibrary for uint256;
    using CustomRevert for bytes4;
    using PositionConfigIdLibrary for PositionConfigId;

    error AlreadySubscribed(address subscriber);

    event Subscribed(uint256 tokenId, address subscriber);
    event Unsubscribed(uint256 tokenId, address subscriber);

    ICLSubscriber private constant NO_SUBSCRIBER = ICLSubscriber(address(0));

    // a percentage of the block.gaslimit denoted in BPS, used as the gas limit for subscriber calls
    // 100 bps is 1%
    // at 30M gas, the limit is 300K
    uint256 private constant BLOCK_LIMIT_BPS = 100;

    mapping(uint256 tokenId => ICLSubscriber subscriber) public subscriber;

    modifier onlyIfApproved(address caller, uint256 tokenId) virtual;
    modifier onlyValidConfig(uint256 tokenId, PositionConfig calldata config) virtual;

    function _positionConfigs(uint256 tokenId) internal view virtual returns (PositionConfigId storage);

    /// @inheritdoc ICLNotifier
    function subscribe(uint256 tokenId, PositionConfig calldata config, address newSubscriber, bytes calldata data)
        external
        payable
        onlyIfApproved(msg.sender, tokenId)
        onlyValidConfig(tokenId, config)
    {
        // will revert below if the user already has a subcriber
        _positionConfigs(tokenId).setSubscribe();
        ICLSubscriber _subscriber = subscriber[tokenId];

        if (_subscriber != NO_SUBSCRIBER) revert AlreadySubscribed(address(_subscriber));
        subscriber[tokenId] = ICLSubscriber(newSubscriber);

        bool success = _call(
            address(newSubscriber),
            abi.encodeWithSelector(ICLSubscriber.notifySubscribe.selector, tokenId, config, data)
        );

        if (!success) {
            Wrap__SubsciptionReverted.selector.bubbleUpAndRevertWith(address(newSubscriber));
        }

        emit Subscribed(tokenId, address(newSubscriber));
    }

    /// @inheritdoc ICLNotifier
    function unsubscribe(uint256 tokenId, PositionConfig calldata config, bytes calldata data)
        external
        payable
        onlyIfApproved(msg.sender, tokenId)
        onlyValidConfig(tokenId, config)
    {
        _positionConfigs(tokenId).setUnsubscribe();
        ICLSubscriber _subscriber = subscriber[tokenId];
        delete subscriber[tokenId];

        uint256 subscriberGasLimit = block.gaslimit.calculatePortion(BLOCK_LIMIT_BPS);
        try _subscriber.notifyUnsubscribe{gas: subscriberGasLimit}(tokenId, config, data) {} catch {}

        emit Unsubscribed(tokenId, address(_subscriber));
    }

    function _notifyModifyLiquidity(
        uint256 tokenId,
        PositionConfig memory config,
        int256 liquidityChange,
        BalanceDelta feesAccrued
    ) internal {
        ICLSubscriber _subscriber = subscriber[tokenId];

        bool success = _call(
            address(_subscriber),
            abi.encodeWithSelector(
                ICLSubscriber.notifyModifyLiquidity.selector, tokenId, config, liquidityChange, feesAccrued
            )
        );

        if (!success) {
            Wrap__ModifyLiquidityNotificationReverted.selector.bubbleUpAndRevertWith(address(_subscriber));
        }
    }

    function _notifyTransfer(uint256 tokenId, address previousOwner, address newOwner) internal {
        ICLSubscriber _subscriber = subscriber[tokenId];

        bool success = _call(
            address(_subscriber),
            abi.encodeWithSelector(ICLSubscriber.notifyTransfer.selector, tokenId, previousOwner, newOwner)
        );

        if (!success) {
            Wrap__TransferNotificationReverted.selector.bubbleUpAndRevertWith(address(_subscriber));
        }
    }

    function _call(address target, bytes memory encodedCall) internal returns (bool success) {
        assembly ("memory-safe") {
            success := call(gas(), target, 0, add(encodedCall, 0x20), mload(encodedCall), 0, 0)
        }
    }

    /// @inheritdoc ICLNotifier
    function hasSubscriber(uint256 tokenId) external view returns (bool) {
        return _positionConfigs(tokenId).hasSubscriber();
    }
}
