// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

/// @title IPositionManagerPermit2
/// @notice Interface for the IPositionManagerPermit2 contract
interface IPositionManagerPermit2 {
    function permit2() external view returns (IAllowanceTransfer);
}
