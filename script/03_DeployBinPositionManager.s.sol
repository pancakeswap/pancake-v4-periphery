// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {IBinPoolManager} from "pancake-v4-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {BinPositionManager} from "../src/pool-bin/BinPositionManager.sol";
import {IWETH9} from "../../src/interfaces/external/IWETH9.sol";

/**
 * forge script script/03_DeployBinPositionManager.s.sol:DeployBinPositionManagerScript -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow \
 *     --verify
 */
contract DeployBinPositionManagerScript is BaseScript {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address vault = getAddressFromConfig("vault");
        emit log_named_address("Vault", vault);

        address binPoolManager = getAddressFromConfig("binPoolManager");
        emit log_named_address("BinPoolManager", binPoolManager);

        address permit2 = getAddressFromConfig("permit2");
        emit log_named_address("Permit2", permit2);

        address weth = getAddressFromConfig("weth");
        emit log_named_address("WETH", weth);

        BinPositionManager binPositionManager = new BinPositionManager(
            IVault(vault), IBinPoolManager(binPoolManager), IAllowanceTransfer(permit2), IWETH9(weth)
        );
        emit log_named_address("BinPositionManager", address(binPositionManager));

        vm.stopBroadcast();
    }
}
