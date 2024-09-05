// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ILockCallback} from "pancake-v4-core/src/interfaces/ILockCallback.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {ImmutableState} from "./ImmutableState.sol";

/// @title Safe Callback
/// @notice A contract that only allows the Pancake v4 Vault to call the lockAcquired function
abstract contract SafeCallback is ImmutableState, ILockCallback {
    /// @notice Thrown when calling lockAcquired where the caller is not the Vault
    error NotVault();

    constructor(IVault _vault) ImmutableState(_vault) {}

    /// @notice Only allow calls from the Vault contract
    modifier onlyByVault() {
        if (msg.sender != address(vault)) revert NotVault();
        _;
    }

    /// @inheritdoc ILockCallback
    /// @dev We force the onlyByVault modifier by exposing a virtual function after the onlyByVault check.
    function lockAcquired(bytes calldata data) external onlyByVault returns (bytes memory) {
        return _lockAcquired(data);
    }

    /// @dev to be implemented by the child contract, to safely guarantee the logic is only executed by the Vault
    function _lockAcquired(bytes calldata data) internal virtual returns (bytes memory);
}
