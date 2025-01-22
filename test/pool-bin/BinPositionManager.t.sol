// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
// import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";

import {Vault} from "pancake-v4-core/src/Vault.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
// import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
// import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";
// import {BinPoolParametersHelper} from "pancake-v4-core/src/pool-bin/libraries/BinPoolParametersHelper.sol";
// import {SafeCast} from "pancake-v4-core/src/pool-bin/libraries/math/SafeCast.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {IBinPoolManager} from "pancake-v4-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {BinPoolManager} from "pancake-v4-core/src/pool-bin/BinPoolManager.sol";
// import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";

import {IPositionManager} from "../../src/interfaces/IPositionManager.sol";
import {BinPositionManager} from "../../src/pool-bin/BinPositionManager.sol";
// import {IBinFungibleToken} from "../../src/pool-bin/interfaces/IBinFungibleToken.sol";
// import {Planner, Plan} from "../../src/libraries/Planner.sol";
// import {BinTokenLibrary} from "../../src/pool-bin/libraries/BinTokenLibrary.sol";
// import {BinLiquidityHelper} from "./helper/BinLiquidityHelper.sol";
import {IBinPositionManager} from "../../src/pool-bin/interfaces/IBinPositionManager.sol";
// import {Actions} from "../../src/libraries/Actions.sol";
// import {BaseActionsRouter} from "../../src/base/BaseActionsRouter.sol";
import {IWETH9} from "../../src/interfaces/external/IWETH9.sol";
// import {BinPool} from "pancake-v4-core/src/pool-bin/libraries/BinPool.sol";

// test on the native token pair etc..
contract BinPositionManagerTest is Test, GasSnapshot, DeployPermit2 {
    // using Planner for Plan;
    // using BinPoolParametersHelper for bytes32;
    // using SafeCast for uint256;
    // using BinTokenLibrary for PoolId;

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
        // todo: update to vm.snapshotValue when overhaul gas test
        snapSize("BinPositionManager bytecode size", address(binPm));

        // forge coverage will run with '--ir-minimum' which set optimizer run to min
        // thus we do not want to revert for forge coverage case
        if (vm.envExists("FOUNDRY_PROFILE") && address(binPm).code.length > 24576) {
            revert ContractSizeTooLarge(address(binPm).code.length - 24576);
        }
    }
}
