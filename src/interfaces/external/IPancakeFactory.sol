// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// @title IPancakeFactory
/// @notice Interface for the PancakeFactory contract
interface IPancakeFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
