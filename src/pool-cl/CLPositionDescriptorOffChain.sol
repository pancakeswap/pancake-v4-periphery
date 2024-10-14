// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.24;

import {ICLPositionDescriptor} from "./interfaces/ICLPositionDescriptor.sol";
import {ICLPositionManager} from "./interfaces/ICLPositionManager.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Describes NFT token positions
contract CLPositionDescriptorOffChain is ICLPositionDescriptor, Ownable {
    using Strings for uint256;

    string private _baseTokenURI;

    constructor(string memory baseTokenURI) Ownable(msg.sender) {
        _baseTokenURI = baseTokenURI;
    }

    function setBaseTokenURI(string memory baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    /// @inheritdoc ICLPositionDescriptor
    function tokenURI(ICLPositionManager, uint256 tokenId) external view override returns (string memory) {
        return bytes(_baseTokenURI).length > 0 ? string(abi.encodePacked(_baseTokenURI, tokenId.toString())) : "";
    }
}
