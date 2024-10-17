// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {TickLens} from "../src/pool-cl/lens/TickLens.sol";

/**
 * forge script script/09_DeployCLTickLens.s.sol:DeployCLTickLensScript -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow \
 *     --verify
 */
contract DeployCLTickLensScript is BaseScript {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address clPoolManager = getAddressFromConfig("clPoolManager");
        emit log_named_address("CLPoolManager", clPoolManager);

        TickLens tickLens = new TickLens(ICLPoolManager(clPoolManager));
        emit log_named_address("TickLens", address(tickLens));

        vm.stopBroadcast();
    }
}
