// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.24;

import {SafeCallback} from "./SafeCallback.sol";
import {QuoterRevert} from "../libraries/QuoterRevert.sol";
import {IVault} from "infinity-core/src/interfaces/IVault.sol";
import {IQuoter} from "../interfaces/IQuoter.sol";
import {ILockCallback} from "infinity-core/src/interfaces/ILockCallback.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";

abstract contract BaseInfinityQuoter is SafeCallback, IQuoter {
    using QuoterRevert for bytes;

    constructor(address _poolManager) SafeCallback(IPoolManager(_poolManager).vault()) {}

    /// @dev Only this address may call this function. Used to mimic internal functions, using an
    /// external call to catch and parse revert reasons
    modifier selfOnly() {
        if (msg.sender != address(this)) revert NotSelf();
        _;
    }

    function _lockAcquired(bytes calldata data) internal override returns (bytes memory) {
        (bool success, bytes memory returnData) = address(this).call(data);
        // Every quote path gathers a quote, and then reverts either with QuoteSwap(quoteAmount) or alternative error
        if (success) revert UnexpectedCallSuccess();
        // Bubble the revert string, whether a valid quote or an alternative error
        returnData.bubbleReason();
    }
}
