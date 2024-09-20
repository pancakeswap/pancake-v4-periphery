// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ERC721Enumerable, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721PermitHash} from "../libraries/ERC721PermitHash.sol";
import {SignatureVerification} from "permit2/src/libraries/SignatureVerification.sol";

import {EIP712_v4} from "./EIP712_v4.sol";
import {IERC721Permit_v4} from "../interfaces/IERC721Permit_v4.sol";
import {UnorderedNonce} from "./UnorderedNonce.sol";

/// @title ERC721 with permit
/// @notice Nonfungible tokens that support an approve via signature, i.e. permit
abstract contract ERC721Permit_v4 is ERC721Enumerable, IERC721Permit_v4, EIP712_v4, UnorderedNonce {
    using SignatureVerification for bytes;

    /// @notice Computes the nameHash and versionHash
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) EIP712_v4(name_) {}

    /// @notice Checks if the block's timestamp is before a signature's deadline
    modifier checkSignatureDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert SignatureDeadlineExpired();
        _;
    }

    /// @inheritdoc IERC721Permit_v4
    function permit(address spender, uint256 tokenId, uint256 deadline, uint256 nonce, bytes calldata signature)
        external
        payable
        checkSignatureDeadline(deadline)
    {
        // the .verify function checks the owner is non-0
        address owner = ownerOf(tokenId);

        bytes32 digest = ERC721PermitHash.hashPermit(spender, tokenId, nonce, deadline);
        signature.verify(_hashTypedData(digest), owner);

        _useUnorderedNonce(owner, nonce);
        _approve(spender, tokenId, address(0));
    }

    /// @inheritdoc IERC721Permit_v4
    function permitForAll(
        address owner,
        address operator,
        bool approved,
        uint256 deadline,
        uint256 nonce,
        bytes calldata signature
    ) external payable checkSignatureDeadline(deadline) {
        bytes32 digest = ERC721PermitHash.hashPermitForAll(operator, approved, nonce, deadline);
        signature.verify(_hashTypedData(digest), owner);

        _useUnorderedNonce(owner, nonce);
        _setApprovalForAll(owner, operator, approved);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        return spender == ownerOf(tokenId) || getApproved(tokenId) == spender
            || isApprovedForAll(ownerOf(tokenId), spender);
    }

    // TODO: to be implemented after audits
    function tokenURI(uint256) public pure override returns (string memory) {
        return "https://example.com";
    }
}
