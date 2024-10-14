// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";
import {CLPositionDescriptorOffChain} from "../src/pool-cl/CLPositionDescriptorOffChain.sol";

/**
 * forge script --sig 'run(string)' script/01_DeployCLPositionDescriptorOffchain.s.sol:DeployCLPositionDescriptorOffChainScript <baseTokenURI> -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow \
 *     --verify
 */
contract DeployCLPositionDescriptorOffChainScript is BaseScript {
    function run(string memory baseTokenURI) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CLPositionDescriptorOffChain clPositionDescriptor = new CLPositionDescriptorOffChain(baseTokenURI);
        emit log_named_address("CLPositionDescriptorOffChain", address(clPositionDescriptor));

        vm.stopBroadcast();
    }
}
