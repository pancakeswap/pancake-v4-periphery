// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";
import {CLPositionDescriptorOffChain} from "../src/pool-cl/CLPositionDescriptorOffChain.sol";
import {Create3Factory} from "pancake-create3-factory/src/Create3Factory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Step 1: Deploy
 * forge script script/01_DeployCLPositionDescriptorOffchain.s.sol:DeployCLPositionDescriptorOffChainScript -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow
 *
 * Step 2: Verify
 * forge verify-contract <address> CLPositionDescriptorOffChain --watch \
 *      --chain <chain_id> --constructor-args $(cast abi-encode "constructor(string)" "<baseTokenURI>")
 */
contract DeployCLPositionDescriptorOffChainScript is BaseScript {
    function getDeploymentSalt() public pure override returns (bytes32) {
        return keccak256("PANCAKE-V4-PERIPHERY/CLPositionDescriptorOffChain/0.01");
    }

    function run() public {
        Create3Factory factory = Create3Factory(getAddressFromConfig("create3Factory"));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        /// @dev prepare the payload to transfer ownership from deployer to real owner
        bytes memory afterDeploymentExecutionPayload =
            abi.encodeWithSelector(Ownable.transferOwnership.selector, getAddressFromConfig("owner"));

        string memory baseTokenURI = getStringFromConfig("clPositionDescriptorTokenUri");
        bytes memory creationCode =
            abi.encodePacked(type(CLPositionDescriptorOffChain).creationCode, abi.encode(baseTokenURI));
        address clPositionDescriptor = factory.deploy(
            getDeploymentSalt(), creationCode, keccak256(creationCode), 0, afterDeploymentExecutionPayload, 0
        );

        emit log_named_address("CLPositionDescriptorOffChain", address(clPositionDescriptor));
        vm.stopBroadcast();
    }
}
