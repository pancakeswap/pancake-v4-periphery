// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";

import {Vault} from "pancake-v4-core/src/Vault.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {IBinPoolManager} from "pancake-v4-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {BinPoolManager} from "pancake-v4-core/src/pool-bin/BinPoolManager.sol";
import {IPositionManager} from "../../src/interfaces/IPositionManager.sol";
import {BinPositionManager} from "../../src/pool-bin/BinPositionManager.sol";
import {IBinPositionManager} from "../../src/pool-bin/interfaces/IBinPositionManager.sol";
import {IWETH9} from "../../src/interfaces/external/IWETH9.sol";

contract BinPositionManagerTest is Test, DeployPermit2 {
    error ContractSizeTooLarge(uint256 diff);

    Vault vault;
    BinPoolManager poolManager;
    BinPositionManager binPm;
    IAllowanceTransfer permit2;

    function setUp() public {
        vault = new Vault();
        poolManager = new BinPoolManager(IVault(address(vault)));
        vault.registerApp(address(poolManager));
        permit2 = IAllowanceTransfer(deployPermit2());

        binPm = new BinPositionManager(
            IVault(address(vault)), IBinPoolManager(address(poolManager)), permit2, IWETH9(address(0))
        );
    }

    function test_bytecodeSize() public {
        vm.snapshotValue("BinPositionManagerBytecode size", address(binPm).code.length);

        if (address(binPm).code.length > 24576) {
            revert ContractSizeTooLarge(address(binPm).code.length - 24576);
        }
    }
}
