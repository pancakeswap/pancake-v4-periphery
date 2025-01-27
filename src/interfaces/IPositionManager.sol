// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IImmutableState} from "./IImmutableState.sol";

/// @title IPositionManager
/// @notice Interface for the PositionManager contract
interface IPositionManager is IImmutableState {
    /// @notice Thrown when the block.timestamp exceeds the user-provided deadline
    error DeadlinePassed(uint256 deadline);

    /// @notice Thrown when calling transfer, subscribe, or unsubscribe on CLPositionManager
    /// or batchTransferFrom on BinPositionManager when the vault is locked.
    /// @dev This is to prevent hooks from being able to trigger actions or notifications at the same time the position is being modified.
    error VaultMustBeUnlocked();

    /// @notice Thrown when the token ID is bind to an unexisting pool
    error InvalidTokenID();

    /// @notice Unlocks Vault and batches actions for modifying liquidity
    /// @dev This is the standard entrypoint for the PositionManager
    /// @param payload is an encoding of actions, and parameters for those actions
    /// @param deadline is the deadline for the batched actions to be executed
    function modifyLiquidities(bytes calldata payload, uint256 deadline) external payable;

    /// @notice Batches actions for modifying liquidity without getting a lock from vault
    /// @dev This must be called by a contract that has already locked the vault
    /// @param actions the actions to perform
    /// @param params the parameters to provide for the actions
    function modifyLiquiditiesWithoutLock(bytes calldata actions, bytes[] calldata params) external payable;
}
