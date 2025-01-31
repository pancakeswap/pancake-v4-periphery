// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {Currency} from "infinity-core/src/types/Currency.sol";
import {PathKey} from "../libraries/PathKey.sol";
import {ICLRouterBase} from "../pool-cl/interfaces/ICLRouterBase.sol";
import {IBinRouterBase} from "../pool-bin/interfaces/IBinRouterBase.sol";

/// @title IInfinityRouter
/// @notice Interface containing all the structs and errors for different infinity swap types
interface IInfinityRouter is ICLRouterBase, IBinRouterBase {
    /// @notice Emitted when an exactInput swap does not receive its minAmountOut
    error TooLittleReceived(uint256 minAmountOutReceived, uint256 amountReceived);
    /// @notice Emitted when an exactOutput is asked for more than its maxAmountIn
    error TooMuchRequested(uint256 maxAmountInRequested, uint256 amountRequested);
}
