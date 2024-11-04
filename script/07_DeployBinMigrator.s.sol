// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {BinMigrator} from "../src/pool-bin/BinMigrator.sol";
import {Create3Factory} from "pancake-create3-factory/src/Create3Factory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Step 1: Deploy
 * forge script script/07_DeployBinMigrator.s.sol:DeployBinMigratorScript -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow
 *
 * Step 2: Verify
 * forge verify-contract <address> BinMigrator --watch \
 *      --chain <chainId> --constructor-args $(cast abi-encode "constructor(address,address,address)" <weth> <binPositionManager> <permit2>)
 */
contract DeployBinMigratorScript is BaseScript {
    function getDeploymentSalt() public pure override returns (bytes32) {
        return keccak256("PANCAKE-V4-PERIPHERY/BinMigrator/0.01");
    }

    function run() public {
        Create3Factory factory = Create3Factory(getAddressFromConfig("create3Factory"));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address weth = getAddressFromConfig("weth");
        emit log_named_address("WETH", weth);

        address binPositionManager = getAddressFromConfig("binPositionManager");
        emit log_named_address("BinPositionManager", binPositionManager);

        address permit2 = getAddressFromConfig("permit2");
        emit log_named_address("Permit2", permit2);

        /// @dev prepare the payload to transfer ownership from deployer to real owner
        bytes memory afterDeploymentExecutionPayload =
            abi.encodeWithSelector(Ownable.transferOwnership.selector, getAddressFromConfig("owner"));

        bytes memory creationCode = abi.encodePacked(
            type(BinMigrator).creationCode, abi.encode(weth, binPositionManager, IAllowanceTransfer(permit2))
        );
        address binMigrator = factory.deploy(
            getDeploymentSalt(), creationCode, keccak256(creationCode), 0, afterDeploymentExecutionPayload, 0
        );

        emit log_named_address("BinMigrator", address(binMigrator));

        vm.stopBroadcast();
    }
}
