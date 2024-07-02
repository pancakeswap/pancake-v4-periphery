// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {IAllowanceTransfer} from "../permit2/src/interfaces/IAllowanceTransfer.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";

struct RouterParameters {
    address permit2;
    address weth9;
    address seaportV1_5;
    address seaportV1_4;
    address openseaConduit;
    address x2y2;
    address looksRareV2;
    address routerRewardsDistributor;
    address looksRareRewardsDistributor;
    address looksRareToken;
    address v2Factory;
    address v3Factory;
    address v3Deployer;
    bytes32 v2InitCodeHash;
    bytes32 v3InitCodeHash;
    address stableFactory;
    address stableInfo;
    address binPoolManager;
    address clPoolManager;
    address vault;
    address pancakeNFTMarket;
}

/// @title Router Immutable Storage contract
/// @notice Used along with the `RouterParameters` struct for ease of cross-chain deployment
contract RouterImmutables {
    /// @dev WETH9 address
    IWETH9 internal immutable WETH9;

    /// @dev Permit2 address
    IAllowanceTransfer internal immutable PERMIT2;

    /// @dev Seaport 1.5 address
    address internal immutable SEAPORT_V1_5;

    /// @dev Seaport 1.4 address
    address internal immutable SEAPORT_V1_4;

    /// @dev The address of OpenSea's conduit used in both Seaport 1.4 and Seaport 1.5
    address internal immutable OPENSEA_CONDUIT;

    /// @dev The address of X2Y2
    address internal immutable X2Y2;

    /// @dev The address of LooksRareV2
    address internal immutable LOOKS_RARE_V2;

    /// @dev The address of LooksRare token
    ERC20 internal immutable LOOKS_RARE_TOKEN;

    /// @dev The address of LooksRare rewards distributor
    address internal immutable LOOKS_RARE_REWARDS_DISTRIBUTOR;

    /// @dev The address of router rewards distributor
    address internal immutable ROUTER_REWARDS_DISTRIBUTOR;

    /// @dev The address of PancakeSwapV2Factory
    address internal immutable PANCAKESWAP_V2_FACTORY;

    /// @dev The PancakeSwapV2Pair initcodehash
    bytes32 internal immutable PANCAKESWAP_V2_PAIR_INIT_CODE_HASH;

    /// @dev The address of PancakeSwapV3Factory
    address internal immutable PANCAKESWAP_V3_FACTORY;

    /// @dev The PancakeSwapV3Pool initcodehash
    bytes32 internal immutable PANCAKESWAP_V3_POOL_INIT_CODE_HASH;

    /// @dev The address of PancakeSwap V3 Deployer
    address internal immutable PANCAKESWAP_V3_DEPLOYER;

    /// @dev The address of PancakeSwap NFT Market
    address internal immutable PANCAKESWAP_NFT_MARKET;

    enum Spenders {
        OSConduit
    }

    constructor(RouterParameters memory params) {
        PERMIT2 = IAllowanceTransfer(params.permit2);
        WETH9 = IWETH9(params.weth9);
        SEAPORT_V1_5 = params.seaportV1_5;
        SEAPORT_V1_4 = params.seaportV1_4;
        OPENSEA_CONDUIT = params.openseaConduit;
        X2Y2 = params.x2y2;
        LOOKS_RARE_V2 = params.looksRareV2;
        LOOKS_RARE_TOKEN = ERC20(params.looksRareToken);
        LOOKS_RARE_REWARDS_DISTRIBUTOR = params.looksRareRewardsDistributor;
        ROUTER_REWARDS_DISTRIBUTOR = params.routerRewardsDistributor;
        PANCAKESWAP_V2_FACTORY = params.v2Factory;
        PANCAKESWAP_V2_PAIR_INIT_CODE_HASH = params.v2InitCodeHash;
        PANCAKESWAP_V3_FACTORY = params.v3Factory;
        PANCAKESWAP_V3_POOL_INIT_CODE_HASH = params.v3InitCodeHash;
        PANCAKESWAP_V3_DEPLOYER = params.v3Deployer;
        PANCAKESWAP_NFT_MARKET = params.pancakeNFTMarket;
    }
}
