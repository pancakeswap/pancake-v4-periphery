// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "pancake-v4-core/src/types/BalanceDelta.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";

import {PositionConfig} from "../libraries/PositionConfig.sol";
import {IPositionManager} from "../../interfaces/IPositionManager.sol";

interface ICLPositionManager is IPositionManager {
    /// @notice Thrown when the caller is not approved to modify a position
    error NotApproved(address caller);

    /// @notice Thrown when the caller provides the incorrect PositionConfig for a corresponding tokenId when modifying liquidity
    error IncorrectPositionConfigForTokenId(uint256 tokenId);

    /// @notice Emitted when a new liquidity position is minted
    event MintPosition(uint256 indexed tokenId, PositionConfig config);

    /// @notice Emitted when liquidity is modified
    /// @param tokenId the tokenId of the position that was modified
    /// @param liquidityChange the change in liquidity of the position
    /// @param feesAccrued the fees collected from the liquidity change
    event ModifyLiquidity(uint256 indexed tokenId, int256 liquidityChange, BalanceDelta feesAccrued);

    function clPoolManager() external view returns (ICLPoolManager);

    /// @notice Get the detailed information for a specified position
    function positions(uint256 tokenId)
        external
        view
        returns (
            PoolKey memory poolKey,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128
        );

    /// @notice Initialize a v4 PCS cl pool
    /// @param key the PoolKey of the pool to initialize
    /// @param sqrtPriceX96 the initial sqrtPriceX96 of the pool
    /// @param hookData the optional data passed to the hook's initialize functions
    function initializePool(PoolKey calldata key, uint160 sqrtPriceX96, bytes calldata hookData)
        external
        payable
        returns (int24);

    /// @notice Used to get the ID that will be used for the next minted liquidity position
    /// @return uint256 The next token ID
    function nextTokenId() external view returns (uint256);

    /// @param tokenId the ERC721 tokenId
    /// @return bytes32 a truncated hash of the position's poolkey, tickLower, and tickUpper
    /// @dev truncates the least significant bit of the hash
    function getPositionConfigId(uint256 tokenId) external view returns (bytes32);

    /// @param tokenId the ERC721 tokenId
    /// @param config the corresponding PositionConfig for the tokenId
    /// @return liquidity the position's liquidity, as a liquidityAmount
    /// @dev this value can be processed as an amount0 and amount1 by using the LiquidityAmounts library
    function getPositionLiquidity(uint256 tokenId, PositionConfig calldata config)
        external
        view
        returns (uint128 liquidity);
}
