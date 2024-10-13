// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.24;

import {Currency} from "pancake-v4-core/src/types/Currency.sol";
import {PathKey} from "../libraries/PathKey.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";

/// @title IQuoter Interface
/// @notice Supports quoting the delta amounts from exact input or exact output swaps.
/// @dev These functions are not marked view because they rely on calling non-view functions and reverting
/// to compute the result. They are also not gas efficient and should not be called on-chain.
interface IQuoter {
    error NotSelf();
    error UnexpectedCallSuccess();

    struct QuoteExactSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 exactAmount;
        bytes hookData;
    }

    struct QuoteExactParams {
        Currency exactCurrency;
        PathKey[] path;
        uint128 exactAmount;
    }
}
