// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";
import {IBinQuoter} from "../src/pool-bin/interfaces/IBinQuoter.sol";
import {ICLQuoter} from "../src/pool-cl/interfaces/ICLQuoter.sol";
import {MixedQuoter} from "../src/MixedQuoter.sol";

/**
 * forge script script/07_DeployMixedQuoter.s.sol:DeployMixedQuoterScript -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow \
 *     --verify
 */
contract DeployMixedQuoterScript is BaseScript {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address factoryV3 = getAddressFromConfig("factoryV3");
        emit log_named_address("factoryV3", factoryV3);

        address factoryV2 = getAddressFromConfig("factoryV2");
        emit log_named_address("factoryV2", factoryV2);

        address factoryStable = getAddressFromConfig("factoryStable");
        emit log_named_address("factoryStable", factoryStable);

        address weth = getAddressFromConfig("weth");
        emit log_named_address("WETH", weth);

        address clQuoter = getAddressFromConfig("clQuoter");
        emit log_named_address("clQuoter", clQuoter);

        address binQuoter = getAddressFromConfig("binQuoter");
        emit log_named_address("binQuoter", binQuoter);

        MixedQuoter mixedQuoter =
            new MixedQuoter(factoryV3, factoryV2, factoryStable, weth, ICLQuoter(clQuoter), IBinQuoter(binQuoter));
        emit log_named_address("mixedQuoter", address(mixedQuoter));

        vm.stopBroadcast();
    }
}
