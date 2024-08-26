// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IStableSwapFactory {
    struct StableSwapPairInfo {
        address swapContract;
        address token0;
        address token1;
        address LPContract;
    }

    struct StableSwapThreePoolPairInfo {
        address swapContract;
        address token0;
        address token1;
        address token2;
        address LPContract;
    }

    // solium-disable-next-line mixedcase
    function pairLength() external view returns (uint256);

    function getPairInfo(address _tokenA, address _tokenB) external view returns (StableSwapPairInfo memory info);

    function getThreePoolPairInfo(address _tokenA, address _tokenB)
        external
        view
        returns (StableSwapThreePoolPairInfo memory info);

    function createSwapPair(address _tokenA, address _tokenB, uint256 _A, uint256 _fee, uint256 _admin_fee) external;
}
