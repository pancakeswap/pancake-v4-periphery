// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ERC721Permit_infi} from "../../../src/pool-cl/base/ERC721Permit_infi.sol";

contract MockERC721Permit is ERC721Permit_infi {
    uint256 public lastTokenId;

    constructor(string memory name, string memory symbol) ERC721Permit_infi(name, symbol) {}

    function mint() external returns (uint256 tokenId) {
        tokenId = ++lastTokenId;
        _mint(msg.sender, tokenId);
    }

    function tokenURI(uint256 tokenId) public pure override returns (string memory) {
        return string(abi.encodePacked("https://example.com/token/", tokenId));
    }
}
