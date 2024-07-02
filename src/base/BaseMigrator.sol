// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.19;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {PeripheryImmutableState} from "./PeripheryImmutableState.sol";

contract BaseMigrator is PeripheryImmutableState, Multicall, SelfPermit {
    constructor(address _WETH9) PeripheryImmutableState(_WETH9) {}

    function withdrawLiquidityFromV2(address pair, uint256 amount)
        internal
        returns (uint256 amount0Received, uint256 amount1Received)
    {
        // burn v2 liquidity to this address
        IUniswapV2Pair(pair).transferFrom(msg.sender, pair, amount);
        return IUniswapV2Pair(pair).burn(address(this));
    }

    function withdrawLiquidityFromV3(
        address nfp,
        INonfungiblePositionManager.DecreaseLiquidityParams decreaseLiquidityParams,
        bool collectFee
    ) internal returns (uint256 amount0Received, uint256 amount1Received) {
        // TODO: consider batching decreaseLiquidity and collect

        /// @notice decrease liquidity from v3#nfp, more sure migrator has been approved
        (amount0Received, amount1Received) = INonfungiblePositionManager(nfp).decreaseLiquidity(decreaseLiquidityParams);

        INonfungiblePositionManager.CollectParams collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: decreaseLiquidityParams.tokenId,
            recipient: address(this),
            amount0Max: collectFee ? type(uint128).max : amount0Received,
            amount1Max: collectFee ? type(uint128).max : amount1Received
        });

        return INonfungiblePositionManager(nfp).collect(collectParams);
    }

    function refund(address token, address to, uint256 amount) internal {
        if (token == WETH9) {
            IWETH9(WETH9).withdraw(amount);
            TransferHelper.safeTransferETH(to, amount);
        } else {
            TransferHelper.safeTransfer(token, to, amount);
        }
    }

    receive() external payable {
        require(msg.sender == WETH9, "Not WETH9");
    }
}
