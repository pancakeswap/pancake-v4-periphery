// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";
import {BinQuoter} from "../src/pool-bin/lens/BinQuoter.sol";
import {Create3Factory} from "pancake-create3-factory/src/Create3Factory.sol";

/**
 * Step 1: Deploy
 * forge script script/05_DeployBinQuoter.s.sol:DeployBinQuoterScript -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow
 *
 * Step 2: Verify
 * forge verify-contract <address> BinQuoter --watch \
 *      --chain <chainId> --constructor-args $(cast abi-encode "constructor(address)" <binPoolManager>)
 */
contract DeployBinQuoterScript is BaseScript {
    function getDeploymentSalt() public pure override returns (bytes32) {
        return keccak256("INFINITY-PERIPHERY/BinQuoter/0.92");
    }

    function run() public {
        Create3Factory factory = Create3Factory(getAddressFromConfig("create3Factory"));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address binPoolManager = getAddressFromConfig("binPoolManager");
        emit log_named_address("BinPoolManager", binPoolManager);

        bytes memory creationCodeData = abi.encode(binPoolManager);
        bytes memory creationCode = abi.encodePacked(type(BinQuoter).creationCode, creationCodeData);
        address binQuoter =
            factory.deploy(getDeploymentSalt(), creationCode, keccak256(creationCode), 0, new bytes(0), 0);
        emit log_named_address("BinQuoter", binQuoter);

        vm.stopBroadcast();
    }
}
