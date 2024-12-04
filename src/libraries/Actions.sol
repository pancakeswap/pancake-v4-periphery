// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.0;

/// @notice Library to define different pool actions.
/// @dev These are suggested common commands, however additional commands should be defined as required
library Actions {
    // cl-pool actions
    // liquidity actions
    uint256 constant CL_INCREASE_LIQUIDITY = 0x00;
    uint256 constant CL_DECREASE_LIQUIDITY = 0x01;
    uint256 constant CL_MINT_POSITION = 0x02;
    uint256 constant CL_BURN_POSITION = 0x03;
    uint256 constant CL_INCREASE_LIQUIDITY_FROM_DELTAS = 0x04;
    uint256 constant CL_MINT_POSITION_FROM_DELTAS = 0x05;

    // swapping
    uint256 constant CL_SWAP_EXACT_IN_SINGLE = 0x06;
    uint256 constant CL_SWAP_EXACT_IN = 0x07;
    uint256 constant CL_SWAP_EXACT_OUT_SINGLE = 0x08;
    uint256 constant CL_SWAP_EXACT_OUT = 0x09;
    // donate
    uint256 constant CL_DONATE = 0x0a;

    // closing deltas on the pool manager
    // settling
    uint256 constant SETTLE = 0x0b;
    uint256 constant SETTLE_ALL = 0x0c;
    uint256 constant SETTLE_PAIR = 0x0d;
    // taking
    uint256 constant TAKE = 0x0e;
    uint256 constant TAKE_ALL = 0x0f;
    uint256 constant TAKE_PORTION = 0x10;
    uint256 constant TAKE_PAIR = 0x11;

    uint256 constant CLOSE_CURRENCY = 0x12;
    uint256 constant CLEAR_OR_TAKE = 0x13;
    uint256 constant SWEEP = 0x14;
    uint256 constant WRAP = 0x15;
    uint256 constant UNWRAP = 0x16;

    // minting/burning 6909s to close deltas
    uint256 constant MINT_6909 = 0x17;
    uint256 constant BURN_6909 = 0x18;

    // bin-pool actions
    // liquidity actions
    uint256 constant BIN_ADD_LIQUIDITY = 0x19;
    uint256 constant BIN_REMOVE_LIQUIDITY = 0x1a;
    uint256 constant BIN_ADD_LIQUIDITY_FROM_DELTAS = 0x1b;
    // swapping
    uint256 constant BIN_SWAP_EXACT_IN_SINGLE = 0x1c;
    uint256 constant BIN_SWAP_EXACT_IN = 0x1d;
    uint256 constant BIN_SWAP_EXACT_OUT_SINGLE = 0x1e;
    uint256 constant BIN_SWAP_EXACT_OUT = 0x1f;
    // donate
    uint256 constant BIN_DONATE = 0x20;
}
