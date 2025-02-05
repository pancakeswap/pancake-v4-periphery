// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";

import {Vault} from "infinity-core/src/Vault.sol";
import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {Currency} from "infinity-core/src/types/Currency.sol";
import {IHooks} from "infinity-core/src/interfaces/IHooks.sol";
import {BinPoolParametersHelper} from "infinity-core/src/pool-bin/libraries/BinPoolParametersHelper.sol";
import {SafeCast} from "infinity-core/src/pool-bin/libraries/math/SafeCast.sol";
import {IVault} from "infinity-core/src/interfaces/IVault.sol";
import {IBinPoolManager} from "infinity-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {BinPoolManager} from "infinity-core/src/pool-bin/BinPoolManager.sol";
import {PoolId, PoolIdLibrary} from "infinity-core/src/types/PoolId.sol";
import {PackedUint128Math} from "infinity-core/src/pool-bin/libraries/math/PackedUint128Math.sol";
import {TokenFixture} from "infinity-core/test/helpers/TokenFixture.sol";

import {IPositionManager} from "../../src/interfaces/IPositionManager.sol";
import {IBinPositionManager} from "../../src/pool-bin/interfaces/IBinPositionManager.sol";
import {BinPositionManager} from "../../src/pool-bin/BinPositionManager.sol";
import {IBinFungibleToken} from "../../src/pool-bin/interfaces/IBinFungibleToken.sol";
import {Planner, Plan} from "../../src/libraries/Planner.sol";
import {BinTokenLibrary} from "../../src/pool-bin/libraries/BinTokenLibrary.sol";
import {BinLiquidityHelper} from "./helper/BinLiquidityHelper.sol";
import {Actions} from "../../src/libraries/Actions.sol";
import {ActionConstants} from "../../src/libraries/ActionConstants.sol";
import {BaseActionsRouter} from "../../src/base/BaseActionsRouter.sol";
import {IWETH9} from "../../src/interfaces/external/IWETH9.sol";
import {BinPool} from "infinity-core/src/pool-bin/libraries/BinPool.sol";

// test on the various way to perform delta resolver
contract BinPositionManager_DeltaTest is BinLiquidityHelper, TokenFixture, DeployPermit2 {
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
    MockERC20 token0;
    MockERC20 token1;

    bytes32 poolParam;
    address alice = makeAddr("alice");
    uint24 activeId = 2 ** 23; // where token0 and token1 price is the same

    function setUp() public {
        vault = new Vault();
        poolManager = new BinPoolManager(IVault(address(vault)));
        vault.registerApp(address(poolManager));
        permit2 = IAllowanceTransfer(deployPermit2());
        initializeTokens();
        (token0, token1) = (MockERC20(Currency.unwrap(currency0)), MockERC20(Currency.unwrap(currency1)));

        binPm = new BinPositionManager(
            IVault(address(vault)), IBinPoolManager(address(poolManager)), permit2, IWETH9(address(0))
        );
        key1 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: IHooks(address(0)),
            poolManager: IBinPoolManager(address(poolManager)),
            fee: uint24(3000), // 3000 = 0.3%
            parameters: poolParam.setBinStep(10) // binStep
        });
        binPm.initializePool(key1, activeId);

        // approval
        approveBinPm(address(this), key1, address(binPm), permit2);
        approveBinPm(alice, key1, address(binPm), permit2);
    }

    function test_settlePair() public {
        uint24[] memory binIds = getBinIds(activeId, 3);
        IBinPositionManager.BinAddLiquidityParams memory param =
            _getAddParams(key1, binIds, 1 ether, 1 ether, activeId, alice);
        Plan memory planner = Planner.init();
        planner.add(Actions.BIN_ADD_LIQUIDITY, abi.encode(param));
        planner.add(Actions.SETTLE_PAIR, abi.encode(currency0, currency1));

        binPm.modifyLiquidities(planner.encode(), _deadline);
    }

    function test_settle() public {
        // add liquidity then try settle for each token
        uint24[] memory binIds = getBinIds(activeId, 3);
        IBinPositionManager.BinAddLiquidityParams memory param =
            _getAddParams(key1, binIds, 1 ether, 1 ether, activeId, alice);
        Plan memory planner = Planner.init();
        planner.add(Actions.BIN_ADD_LIQUIDITY, abi.encode(param));
        planner.add(Actions.SETTLE, abi.encode(currency0, ActionConstants.OPEN_DELTA, true));
        planner.add(Actions.SETTLE, abi.encode(currency1, ActionConstants.OPEN_DELTA, false));

        // as Action.Settle for currency1's payerIsUser==false, transfer token to contract manually
        token1.mint(address(binPm), 1 ether);

        binPm.modifyLiquidities(planner.encode(), _deadline);
    }

    function test_takePair_AddressThis() public {
        // pre-req add liquidity
        uint24[] memory binIds = getBinIds(activeId, 3);
        (, uint256[] memory liquidityMinted) = _addLiquidity(binPm, key1, binIds, activeId);

        // remove liquidity, then try take pair
        IBinPositionManager.BinRemoveLiquidityParams memory param =
            _getRemoveParams(key1, binIds, liquidityMinted, address(this));
        Plan memory planner = Planner.init();
        planner.add(Actions.BIN_REMOVE_LIQUIDITY, abi.encode(param));
        planner.add(Actions.TAKE_PAIR, abi.encode(currency0, currency1, address(this)));

        binPm.modifyLiquidities(planner.encode(), _deadline);
    }

    function test_takePair_AddressAlice() public {
        // pre-req add liquidity
        uint24[] memory binIds = getBinIds(activeId, 3);
        (, uint256[] memory liquidityMinted) = _addLiquidity(binPm, key1, binIds, activeId);

        // before
        assertEq(token0.balanceOf(alice), 0);
        assertEq(token1.balanceOf(alice), 0);

        // remove liquidity, then try take pair
        IBinPositionManager.BinRemoveLiquidityParams memory param =
            _getRemoveParams(key1, binIds, liquidityMinted, address(this));
        Plan memory planner = Planner.init();
        planner.add(Actions.BIN_REMOVE_LIQUIDITY, abi.encode(param));
        planner.add(Actions.TAKE_PAIR, abi.encode(currency0, currency1, address(alice)));
        binPm.modifyLiquidities(planner.encode(), _deadline);

        // after remove liqudiity, there will be some dust locked in the contract to prevent inflation attack
        // 3 bins, left with (0, 1) (1, 1) (1, 0)
        assertEq(token0.balanceOf(alice), 1 ether - 2);
        assertEq(token1.balanceOf(alice), 1 ether - 2);

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

    function test_take() public {
        // pre-req add liquidity
        uint24[] memory binIds = getBinIds(activeId, 3);
        (, uint256[] memory liquidityMinted) = _addLiquidity(binPm, key1, binIds, activeId);

        // before
        assertEq(token0.balanceOf(address(this)), 999 ether);
        assertEq(token1.balanceOf(address(binPm)), 0);

        // remove liquidity, then try take
        IBinPositionManager.BinRemoveLiquidityParams memory param =
            _getRemoveParams(key1, binIds, liquidityMinted, address(this));
        Plan memory planner = Planner.init();
        planner.add(Actions.BIN_REMOVE_LIQUIDITY, abi.encode(param));
        planner.add(Actions.TAKE, abi.encode(currency0, ActionConstants.MSG_SENDER, ActionConstants.OPEN_DELTA));
        planner.add(Actions.TAKE, abi.encode(currency1, ActionConstants.ADDRESS_THIS, ActionConstants.OPEN_DELTA));
        binPm.modifyLiquidities(planner.encode(), _deadline);

        // after remove liqudiity, there will be some dust locked in the contract to prevent inflation attack
        // 3 bins, left with (0, 1) (1, 1) (1, 0)
        assertEq(token0.balanceOf(address(this)), 1000 ether - 2);
        assertEq(token1.balanceOf(address(binPm)), 1 ether - 2);

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

    function test_take_toAlice() public {
        // pre-req add liquidity
        uint24[] memory binIds = getBinIds(activeId, 3);
        (, uint256[] memory liquidityMinted) = _addLiquidity(binPm, key1, binIds, activeId);

        // before
        assertEq(token0.balanceOf(address(alice)), 0);
        assertEq(token1.balanceOf(address(alice)), 0);

        // remove liquidity, then try take
        IBinPositionManager.BinRemoveLiquidityParams memory param =
            _getRemoveParams(key1, binIds, liquidityMinted, address(this));
        Plan memory planner = Planner.init();
        planner.add(Actions.BIN_REMOVE_LIQUIDITY, abi.encode(param));
        planner.add(Actions.TAKE, abi.encode(currency0, alice, ActionConstants.OPEN_DELTA));
        planner.add(Actions.TAKE, abi.encode(currency1, alice, ActionConstants.OPEN_DELTA));
        binPm.modifyLiquidities(planner.encode(), _deadline);

        // after remove liqudiity, there will be some dust locked in the contract to prevent inflation attack
        // 3 bins, left with (0, 1) (1, 1) (1, 0)
        assertEq(token0.balanceOf(address(alice)), 1 ether - 2);
        assertEq(token1.balanceOf(address(alice)), 1 ether - 2);

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

    function test_clearOrTake() public {
        // pre-req add liquidity
        uint24[] memory binIds = getBinIds(activeId, 3);
        (, uint256[] memory liquidityMinted) = _addLiquidity(binPm, key1, binIds, activeId);

        // before
        assertEq(token0.balanceOf(address(this)), 999 ether);
        assertEq(token1.balanceOf(address(this)), 999 ether);

        // remove liquidity, then try take
        IBinPositionManager.BinRemoveLiquidityParams memory param =
            _getRemoveParams(key1, binIds, liquidityMinted, address(this));
        Plan memory planner = Planner.init();
        planner.add(Actions.BIN_REMOVE_LIQUIDITY, abi.encode(param));
        planner.add(Actions.CLEAR_OR_TAKE, abi.encode(currency0, 2 ether));
        // it must be "1 ether - 3" to avoid clear since the debt for token0 is 1 ether - 2
        // i.e. there will be 2 dust locked
        planner.add(Actions.CLEAR_OR_TAKE, abi.encode(currency1, 1 ether - 3));
        binPm.modifyLiquidities(planner.encode(), _deadline);

        // after, as currency1 min amount is 2 ether, clear the debt instead
        assertEq(token0.balanceOf(address(this)), 999 ether);
        assertEq(token1.balanceOf(address(this)), 1000 ether - 2);
    }
}
