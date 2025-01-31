// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.0;

/// @notice Library to define different mixed quoter actions.
library MixedQuoterActions {
    // ExactInput actions
    // SS means stable swap
    uint256 constant SS_2_EXACT_INPUT_SINGLE = 0x00;
    uint256 constant SS_3_EXACT_INPUT_SINGLE = 0x01;
    uint256 constant V2_EXACT_INPUT_SINGLE = 0x02;
    uint256 constant V3_EXACT_INPUT_SINGLE = 0x03;

    // INFI means infinity
    uint256 constant INFI_CL_EXACT_INPUT_SINGLE = 0x04;
    uint256 constant INFI_BIN_EXACT_INPUT_SINGLE = 0x05;
}
