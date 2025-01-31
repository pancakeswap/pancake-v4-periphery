// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {BalanceDelta} from "infinity-core/src/types/BalanceDelta.sol";
import {ICLPoolManager} from "infinity-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {IPositionManager} from "../../interfaces/IPositionManager.sol";
import {CLPositionInfo} from "../libraries/CLPositionInfoLibrary.sol";
import {ICLSubscriber} from "./ICLSubscriber.sol";

interface ICLPositionManager is IPositionManager {
    /// @notice Thrown when the caller is not approved to modify a position
    error NotApproved(address caller);

    /// @notice Emitted when a new liquidity position is minted
    event MintPosition(uint256 indexed tokenId);

    /// @notice Emitted when liquidity is modified
    /// @param tokenId the tokenId of the position that was modified
    /// @param liquidityChange the change in liquidity of the position
    /// @param feesAccrued the fees collected from the liquidity change
    event ModifyLiquidity(uint256 indexed tokenId, int256 liquidityChange, BalanceDelta feesAccrued);

    /// @notice Get the clPoolManager
    function clPoolManager() external view returns (ICLPoolManager);

    /// @notice Initialize an infinity cl pool
    /// @dev If the pool is already initialized, this function will not revert and just return type(int24).max
    /// @param key the PoolKey of the pool to initialize
    /// @param sqrtPriceX96 the initial sqrtPriceX96 of the pool
    /// @return tick The current tick of the pool
    function initializePool(PoolKey calldata key, uint160 sqrtPriceX96) external payable returns (int24);

    /// @notice Used to get the ID that will be used for the next minted liquidity position
    /// @return uint256 The next token ID
    function nextTokenId() external view returns (uint256);

    /// @param tokenId the ERC721 tokenId
    /// @return liquidity the position's liquidity, as a liquidityAmount
    /// @dev this value can be processed as an amount0 and amount1 by using the LiquidityAmounts library
    function getPositionLiquidity(uint256 tokenId) external view returns (uint128 liquidity);

    /// @notice Get the detailed information for a specified position
    /// @param tokenId the ERC721 tokenId
    /// @return poolKey the pool key of the position
    /// @return tickLower the lower tick of the position
    /// @return tickUpper the upper tick of the position
    /// @return liquidity the liquidity of the position
    /// @return feeGrowthInside0LastX128 the fee growth count of token0 since last time updated
    /// @return feeGrowthInside1LastX128 the fee growth count of token1 since last time updated
    /// @return _subscriber the address of the subscriber, if not set, it returns address(0)
    function positions(uint256 tokenId)
        external
        view
        returns (
            PoolKey memory poolKey,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            ICLSubscriber _subscriber
        );

    /// @param tokenId the ERC721 tokenId
    /// @return poolKey the pool key of the position
    /// @return CLPositionInfo a uint256 packed value holding information about the position including the range (tickLower, tickUpper)
    function getPoolAndPositionInfo(uint256 tokenId) external view returns (PoolKey memory, CLPositionInfo);
}
