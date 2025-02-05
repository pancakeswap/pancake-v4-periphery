// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {Currency} from "infinity-core/src/types/Currency.sol";
import {PathKey} from "../../libraries/PathKey.sol";
import {IImmutableState} from "../../interfaces/IImmutableState.sol";

interface IBinRouterBase is IImmutableState {
    struct BinSwapExactInputSingleParams {
        PoolKey poolKey;
        bool swapForY;
        uint128 amountIn;
        uint128 amountOutMinimum;
        bytes hookData;
    }

    struct BinSwapExactInputParams {
        Currency currencyIn;
        PathKey[] path;
        uint128 amountIn;
        uint128 amountOutMinimum;
    }

    struct BinSwapExactOutputSingleParams {
        PoolKey poolKey;
        bool swapForY;
        uint128 amountOut;
        uint128 amountInMaximum;
        bytes hookData;
    }

    struct BinSwapExactOutputParams {
        Currency currencyOut;
        PathKey[] path;
        uint128 amountOut;
        uint128 amountInMaximum;
    }
}
