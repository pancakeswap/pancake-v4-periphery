// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.0;

/// @notice Library to define different pool actions.
/// @dev These are suggested common commands, however additional commands should be defined as required
/// Some of these actions are not supported in the Router contracts or Position Manager contracts, but are left as they may be helpful commands for other peripheral contracts.
library Actions {
    // cl-pool actions
    // liquidity actions
    uint256 internal constant CL_INCREASE_LIQUIDITY = 0x00;
    uint256 internal constant CL_DECREASE_LIQUIDITY = 0x01;
    uint256 internal constant CL_MINT_POSITION = 0x02;
    uint256 internal constant CL_BURN_POSITION = 0x03;
    uint256 internal constant CL_INCREASE_LIQUIDITY_FROM_DELTAS = 0x04;
    uint256 internal constant CL_MINT_POSITION_FROM_DELTAS = 0x05;

    // swapping
    uint256 internal constant CL_SWAP_EXACT_IN_SINGLE = 0x06;
    uint256 internal constant CL_SWAP_EXACT_IN = 0x07;
    uint256 internal constant CL_SWAP_EXACT_OUT_SINGLE = 0x08;
    uint256 internal constant CL_SWAP_EXACT_OUT = 0x09;

    // donate
    /// @dev this is not supported in the position manager or router
    uint256 internal constant CL_DONATE = 0x0a;

    // closing deltas on the pool manager
    // settling
    uint256 internal constant SETTLE = 0x0b;
    uint256 internal constant SETTLE_ALL = 0x0c;
    uint256 internal constant SETTLE_PAIR = 0x0d;
    // taking
    uint256 internal constant TAKE = 0x0e;
    uint256 internal constant TAKE_ALL = 0x0f;
    uint256 internal constant TAKE_PORTION = 0x10;
    uint256 internal constant TAKE_PAIR = 0x11;

    uint256 internal constant CLOSE_CURRENCY = 0x12;
    uint256 internal constant CLEAR_OR_TAKE = 0x13;
    uint256 internal constant SWEEP = 0x14;
    uint256 internal constant WRAP = 0x15;
    uint256 internal constant UNWRAP = 0x16;

    // minting/burning 6909s to close deltas
    /// @dev this is not supported in the position manager or router
    uint256 internal constant MINT_6909 = 0x17;
    uint256 internal constant BURN_6909 = 0x18;

    // bin-pool actions
    // liquidity actions
    uint256 internal constant BIN_ADD_LIQUIDITY = 0x19;
    uint256 internal constant BIN_REMOVE_LIQUIDITY = 0x1a;
    uint256 internal constant BIN_ADD_LIQUIDITY_FROM_DELTAS = 0x1b;
    // swapping
    uint256 internal constant BIN_SWAP_EXACT_IN_SINGLE = 0x1c;
    uint256 internal constant BIN_SWAP_EXACT_IN = 0x1d;
    uint256 internal constant BIN_SWAP_EXACT_OUT_SINGLE = 0x1e;
    uint256 internal constant BIN_SWAP_EXACT_OUT = 0x1f;
    // donate
    uint256 internal constant BIN_DONATE = 0x20;
}
