// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {CLPositionManager} from "../src/pool-cl/CLPositionManager.sol";
import {ICLPositionDescriptor} from "../src/pool-cl/interfaces/ICLPositionDescriptor.sol";
import {IWETH9} from "../../src/interfaces/external/IWETH9.sol";

/**
 * forge script --sig 'run(uint256)' script/02_DeployCLPositionManager.s.sol:DeployCLPositionManagerScript <unsubscribeGasLimit> -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow \
 *     --verify
 */
contract DeployCLPositionManagerScript is BaseScript {
    function run(uint256 unsubscribeGasLimit) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address vault = getAddressFromConfig("vault");
        emit log_named_address("Vault", vault);

        address clPoolManager = getAddressFromConfig("clPoolManager");
        emit log_named_address("CLPoolManager", clPoolManager);

        address permit2 = getAddressFromConfig("permit2");
        emit log_named_address("Permit2", permit2);

        address clPositionDescriptor = getAddressFromConfig("clPositionDescriptor");
        emit log_named_address("CLPositionDescriptor", clPositionDescriptor);

        address weth = getAddressFromConfig("weth");
        emit log_named_address("WETH", weth);

        CLPositionManager clPositionManager = new CLPositionManager(
            IVault(vault),
            ICLPoolManager(clPoolManager),
            IAllowanceTransfer(permit2),
            unsubscribeGasLimit,
            ICLPositionDescriptor(clPositionDescriptor),
            IWETH9(weth)
        );
        emit log_named_address("CLPositionManager", address(clPositionManager));

        vm.stopBroadcast();
    }
}
