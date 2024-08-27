// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

interface IPositionManagerPermit2 {
    function permit2() external view returns (IAllowanceTransfer);
}
