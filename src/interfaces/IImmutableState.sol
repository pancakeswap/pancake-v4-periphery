// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";

/// @title IImmutableState
/// @notice Interface for the ImmutableState contract
interface IImmutableState {
    /// @notice The Pancakeswap v4 Vault contract
    function vault() external view returns (IVault);
}
