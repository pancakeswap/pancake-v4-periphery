// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";

import {Vault} from "infinity-core/src/Vault.sol";
import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "infinity-core/src/types/Currency.sol";
import {IHooks} from "infinity-core/src/interfaces/IHooks.sol";
import {BinPoolParametersHelper} from "infinity-core/src/pool-bin/libraries/BinPoolParametersHelper.sol";
import {SafeCast} from "infinity-core/src/pool-bin/libraries/math/SafeCast.sol";
import {IVault} from "infinity-core/src/interfaces/IVault.sol";
import {IBinPoolManager} from "infinity-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {BinPoolManager} from "infinity-core/src/pool-bin/BinPoolManager.sol";
import {PoolId, PoolIdLibrary} from "infinity-core/src/types/PoolId.sol";

import {IPositionManager} from "../../src/interfaces/IPositionManager.sol";
import {BinPositionManager} from "../../src/pool-bin/BinPositionManager.sol";
import {IBinFungibleToken} from "../../src/pool-bin/interfaces/IBinFungibleToken.sol";
import {Planner, Plan} from "../../src/libraries/Planner.sol";
import {BinTokenLibrary} from "../../src/pool-bin/libraries/BinTokenLibrary.sol";
import {BinLiquidityHelper} from "./helper/BinLiquidityHelper.sol";
import {IBinPositionManager} from "../../src/pool-bin/interfaces/IBinPositionManager.sol";
import {Actions} from "../../src/libraries/Actions.sol";
import {BaseActionsRouter} from "../../src/base/BaseActionsRouter.sol";
import {IWETH9} from "../../src/interfaces/external/IWETH9.sol";
import {BinPool} from "infinity-core/src/pool-bin/libraries/BinPool.sol";

// test on the native token pair etc..
contract BinPositionManager_NativeTokenTest is BinLiquidityHelper, DeployPermit2 {
    using BinPoolParametersHelper for bytes32;
    using SafeCast for uint256;
    using BinTokenLibrary for PoolId;

    bytes constant ZERO_BYTES = new bytes(0);
    uint256 _deadline = block.timestamp + 1;

    PoolKey key1;
    Vault vault;
    BinPoolManager poolManager;
    BinPositionManager binPm;
    IAllowanceTransfer permit2;
    MockERC20 token1;

    bytes32 poolParam;
    uint24 activeId = 2 ** 23; // where token0 and token1 price is the same

    function setUp() public {
        vault = new Vault();
        poolManager = new BinPoolManager(IVault(address(vault)));
        vault.registerApp(address(poolManager));
        permit2 = IAllowanceTransfer(deployPermit2());

        binPm = new BinPositionManager(
            IVault(address(vault)), IBinPoolManager(address(poolManager)), permit2, IWETH9(address(0))
        );

        token1 = new MockERC20("TestA", "A", 18);
        key1 = PoolKey({
            currency0: CurrencyLibrary.NATIVE,
            currency1: Currency.wrap(address(token1)),
            hooks: IHooks(address(0)),
            poolManager: IBinPoolManager(address(poolManager)),
            fee: uint24(3000), // 3000 = 0.3%
            parameters: poolParam.setBinStep(10) // binStep
        });
        binPm.initializePool(key1, activeId);

        // approval - only currency1 required
        IERC20(Currency.unwrap(key1.currency1)).approve(address(permit2), type(uint256).max);
        permit2.approve(Currency.unwrap(key1.currency1), address(binPm), type(uint160).max, type(uint48).max);
    }

    function test_addLiquidity() public {
        vm.deal(address(this), 1 ether);
        token1.mint(address(this), 1 ether);

        // before
        assertEq(address(this).balance, 1 ether);
        assertEq(token1.balanceOf(address(this)), 1 ether);

        uint24[] memory binIds = getBinIds(activeId, 3);
        IBinPositionManager.BinAddLiquidityParams memory param =
            _getAddParams(key1, binIds, 1 ether, 1 ether, activeId, address(this));
        Plan memory planner = Planner.init().add(Actions.BIN_ADD_LIQUIDITY, abi.encode(param));
        bytes memory payload = planner.finalizeModifyLiquidityWithClose(key1);

        binPm.modifyLiquidities{value: 1 ether}(payload, _deadline);
        vm.snapshotGasLastCall("test_addLiquidity");

        // after
        assertEq(address(this).balance, 0 ether);
        assertEq(token1.balanceOf(address(this)), 0 ether);
    }

    function test_addLiquidity_excessEth() public {
        vm.deal(address(this), 2 ether);
        token1.mint(address(this), 1 ether);

        // before
        assertEq(address(this).balance, 2 ether);
        assertEq(token1.balanceOf(address(this)), 1 ether);

        uint24[] memory binIds = getBinIds(activeId, 3);
        IBinPositionManager.BinAddLiquidityParams memory param =
            _getAddParams(key1, binIds, 1 ether, 1 ether, activeId, address(this));
        Plan memory planner = Planner.init();
        planner.add(Actions.BIN_ADD_LIQUIDITY, abi.encode(param));
        planner.add(Actions.CLOSE_CURRENCY, abi.encode(key1.currency0));
        planner.add(Actions.CLOSE_CURRENCY, abi.encode(key1.currency1));
        planner.add(Actions.SWEEP, abi.encode(key1.currency0, address(this)));

        binPm.modifyLiquidities{value: 1 ether}(planner.encode(), _deadline);
        vm.snapshotGasLastCall("test_addLiquidity_excessEth");

        // after, should have 1 ether remaining
        assertEq(address(this).balance, 1 ether);
        assertEq(token1.balanceOf(address(this)), 0 ether);
    }

    function test_decreaseLiquidity() public {
        vm.deal(address(this), 1 ether);
        token1.mint(address(this), 1 ether);

        // add liquidity
        uint24[] memory binIds = getBinIds(activeId, 3);
        IBinPositionManager.BinAddLiquidityParams memory param =
            _getAddParams(key1, binIds, 1 ether, 1 ether, activeId, address(this));
        Plan memory planner = Planner.init().add(Actions.BIN_ADD_LIQUIDITY, abi.encode(param));
        bytes memory payload = planner.finalizeModifyLiquidityWithClose(key1);
        binPm.modifyLiquidities{value: 1 ether}(payload, _deadline);

        uint256[] memory tokenIds = new uint256[](binIds.length);
        uint256[] memory liquidityMinted = new uint256[](binIds.length);
        for (uint256 i; i < binIds.length; i++) {
            tokenIds[i] = calculateTokenId(key1.toId(), binIds[i]);
            liquidityMinted[i] = binPm.balanceOf(address(this), tokenIds[i]);
        }

        // before remove liqudiity
        assertEq(address(this).balance, 0 ether);
        assertEq(token1.balanceOf(address(this)), 0 ether);

        // remove liquidity
        IBinPositionManager.BinRemoveLiquidityParams memory removeParam =
            _getRemoveParams(key1, binIds, liquidityMinted, address(this));
        planner = Planner.init().add(Actions.BIN_REMOVE_LIQUIDITY, abi.encode(removeParam));
        payload = planner.finalizeModifyLiquidityWithClose(key1);
        binPm.modifyLiquidities(payload, _deadline);
        vm.snapshotGasLastCall("test_decreaseLiquidity");

        // after remove liqudiity, there will be some dust locked in the contract to prevent inflation attack
        // 3 bins, left with (0, 1) (1, 1) (1, 0)
        assertEq(address(this).balance, 1 ether - 2);
        assertEq(token1.balanceOf(address(this)), 1 ether - 2);

        // check reserve of each bin
        (uint128 binReserveX, uint128 binReserveY, uint256 binLiquidity, uint256 totalShares) =
            poolManager.getBin(key1.toId(), binIds[0]);
        assertEq(binReserveX, 0);
        assertEq(binReserveY, 1);
        assertGt(binLiquidity, 0);
        assertEq(totalShares, BinPool.MINIMUM_SHARE);

        (binReserveX, binReserveY, binLiquidity, totalShares) = poolManager.getBin(key1.toId(), binIds[1]);
        assertEq(binReserveX, 1);
        assertEq(binReserveY, 1);
        assertGt(binLiquidity, 0);
        assertEq(totalShares, BinPool.MINIMUM_SHARE);

        (binReserveX, binReserveY, binLiquidity, totalShares) = poolManager.getBin(key1.toId(), binIds[2]);
        assertEq(binReserveX, 1);
        assertEq(binReserveY, 0);
        assertGt(binLiquidity, 0);
        assertEq(totalShares, BinPool.MINIMUM_SHARE);
    }

    // allow contract to receive native token when removing liquidity
    receive() external payable {}
}
