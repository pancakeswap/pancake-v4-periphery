// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice This interface is used for an EIP712 implementation
interface IEIP712 {
    /// @notice Returns the domain separator for the current chain.
    /// @dev Uses cached version if chainid is unchanged from construction.
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
