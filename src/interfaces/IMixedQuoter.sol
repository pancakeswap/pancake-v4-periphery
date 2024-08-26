// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";

/// @title MixedQuoter Interface
/// @notice Supports quoting the calculated amounts for exact input swaps. Is specialized for routes containing a mix of Stable, V2, V3 liquidity, v4 liquidity.
/// @notice For each pool also tells you the number of initialized ticks crossed and the sqrt price of the pool after the swap.
/// @dev These functions are not marked view because they rely on calling non-view functions and reverting
/// to compute the result. They are also not gas efficient and should not be called on-chain.
interface IMixedQuoter {
    error INVALID_ADDRESS();
    error InputLengthMismatch();
    error InvalidPath();
    error InvalidPoolKeyCurrency();
    error NoActions();
    error UnsupportedAction(uint256 action);

    struct QuoteMixedV4ExactInputSingleParams {
        PoolKey poolKey;
        bytes hookData;
    }

    struct QuoteExactInputSingleV3Params {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    struct QuoteExactInputSingleV2Params {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
    }

    struct QuoteExactInputSingleStableParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 flag;
    }

    /// @notice Returns the amount out received for a given exact input swap without executing the swap
    /// @param paths The path of the swap, i.e. each token pair in the path
    /// @param actions The actions to take for each pair in the path
    /// @param params The params for each action in the path
    /// SS_2_EXACT_INPUT_SINGLE params are zero bytes
    /// SS_3_EXACT_INPUT_SINGLE params are zero bytes
    /// V2_EXACT_INPUT_SINGLE params are zero bytes
    /// V3_EXACT_INPUT_SINGLE params are encoded as `uint24 fee`
    /// V4_CL_EXACT_INPUT_SINGLE params are encoded as `QuoteMixedV4ExactInputSingleParams`
    /// V4_EXACT_INPUT_SINGLE params are encoded as `QuoteMixedV4ExactInputSingleParams`
    /// @param amountIn The amount of the first token to swap
    /// @return amountOut The amount of the last token that would be received
    function quoteMixedExactInput(
        address[] calldata paths,
        bytes calldata actions,
        bytes[] calldata params,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    /// @notice Returns the amount out received for a given exact input but for a swap of a single pool
    /// @param params The params for the quote, encoded as `QuoteExactInputSingleParams`
    /// tokenIn The token being swapped in
    /// tokenOut The token being swapped out
    /// fee The fee of the token pool to consider for the pair
    /// amountIn The desired input amount
    /// sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountOut The amount of `tokenOut` that would be received
    /// @return sqrtPriceX96After The sqrt price of the pool after the swap
    /// @return initializedTicksCrossed The number of initialized ticks that the swap crossed
    /// @return gasEstimate The estimate of the gas that the swap consumes
    function quoteExactInputSingleV3(QuoteExactInputSingleV3Params memory params)
        external
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);

    /// @notice Returns the amount out received for a given exact input but for a swap of a single V2 pool
    /// @param params The params for the quote, encoded as `QuoteExactInputSingleV2Params`
    /// tokenIn The token being swapped in
    /// tokenOut The token being swapped out
    /// amountIn The desired input amount
    /// @return amountOut The amount of `tokenOut` that would be received
    function quoteExactInputSingleV2(QuoteExactInputSingleV2Params memory params)
        external
        returns (uint256 amountOut);

    /// @notice Returns the amount out received for a given exact input but for a swap of a single Stable pool
    /// @param params The params for the quote, encoded as `QuoteExactInputSingleStableParams`
    /// tokenIn The token being swapped in
    /// tokenOut The token being swapped out
    /// amountIn The desired input amount
    /// flag The token amount in a single Stable pool. 2 for 2pool, 3 for 3pool
    /// @return amountOut The amount of `tokenOut` that would be received
    function quoteExactInputSingleStable(QuoteExactInputSingleStableParams memory params)
        external
        returns (uint256 amountOut);

    /// @dev ExactOutput swaps are not supported by this new Quoter which is specialized for supporting routes
    ///      crossing Stable, V2 liquidity pairs and V3 pools.
    /// @deprecated quoteExactOutputSingle and exactOutput. Use QuoterV2 instead.
}
