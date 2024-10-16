// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {FixedPoint96} from "pancake-v4-core/src/pool-cl/libraries/FixedPoint96.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {Vault} from "pancake-v4-core/src/Vault.sol";
import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLPoolManager} from "pancake-v4-core/src/pool-cl/CLPoolManager.sol";
import {CLPoolManagerRouter} from "pancake-v4-core/test/pool-cl/helpers/CLPoolManagerRouter.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {TickBitmap} from "pancake-v4-core/src/pool-cl/libraries/TickBitmap.sol";
import {CLPoolParametersHelper} from "pancake-v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {TickMath} from "pancake-v4-core/src/pool-cl/libraries/TickMath.sol";
import {TokenFixture} from "../helpers/TokenFixture.sol";
import {Plan, Planner} from "../../src/libraries/Planner.sol";
import {ITickLens} from "../../src/pool-cl/interfaces/ITickLens.sol";
import {TickLens} from "../../src/pool-cl/lens/TickLens.sol";

contract TickLensTest is TokenFixture, Test {
    using Planner for Plan;
    using PoolIdLibrary for PoolId;
    using CLPoolParametersHelper for bytes32;

    IVault public vault;
    ICLPoolManager public poolManager;
    CLPoolManagerRouter public positionManager;
    TickLens public tickLens;

    PoolKey public poolKey0;
    PoolKey public poolKey1;

    Plan plan;

    function setUp() public {
        plan = Planner.init();
        vault = new Vault();
        poolManager = new CLPoolManager(vault);
        vault.registerApp(address(poolManager));

        initializeTokens();
        vm.label(Currency.unwrap(currency0), "token0");
        vm.label(Currency.unwrap(currency1), "token1");
        vm.label(Currency.unwrap(currency2), "token2");

        // mint more tokens
        MockERC20(Currency.unwrap(currency0)).mint(address(this), 1000000000000000000 ether);
        MockERC20(Currency.unwrap(currency1)).mint(address(this), 1000000000000000000 ether);
        MockERC20(Currency.unwrap(currency2)).mint(address(this), 1000000000000000000 ether);

        positionManager = new CLPoolManagerRouter(vault, poolManager);
        IERC20(Currency.unwrap(currency0)).approve(address(positionManager), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(positionManager), type(uint256).max);
        IERC20(Currency.unwrap(currency2)).approve(address(positionManager), type(uint256).max);

        poolKey0 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: IHooks(address(0)),
            poolManager: poolManager,
            fee: uint24(3000),
            // 0 ~ 15  hookRegistrationMap = nil
            // 16 ~ 24 tickSpacing = 1
            parameters: bytes32(uint256(0x10000))
        });
        // price 100
        uint160 sqrtPriceX96_100 = uint160(10 * FixedPoint96.Q96);
        poolManager.initialize(poolKey0, sqrtPriceX96_100);

        positionManager.modifyPosition(
            poolKey0,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: -300,
                tickUpper: 300,
                liquidityDelta: 10 ether,
                salt: bytes32(0)
            }),
            new bytes(0)
        );

        poolKey1 = PoolKey({
            currency0: currency1,
            currency1: currency2,
            hooks: IHooks(address(0)),
            poolManager: poolManager,
            fee: uint24(3000),
            // 0 ~ 15  hookRegistrationMap = nil
            // 16 ~ 24 tickSpacing = 1
            parameters: bytes32(uint256(0x10000))
        });
        // price 1
        uint160 sqrtPriceX96_1 = uint160(1 * FixedPoint96.Q96);
        poolManager.initialize(poolKey1, sqrtPriceX96_1);

        tickLens = new TickLens(poolManager);
    }

    function test_getPopulatedTicksInWord_with_poolKey() public view {
        (int16 wordPos,) = TickBitmap.position(-300);
        ITickLens.PopulatedTick[] memory populatedTicks = tickLens.getPopulatedTicksInWord(poolKey0, wordPos);
        assertEq(populatedTicks.length, 1);
        assertEq(populatedTicks[0].tick, -300);
        assertEq(populatedTicks[0].liquidityNet, 10 ether);
        assertEq(populatedTicks[0].liquidityGross, 10 ether);
    }

    function test_getPopulatedTicksInWord_with_poolId_and_tickSpacing() public view {
        PoolId id = poolKey0.toId();
        int24 tickSpacing = poolKey0.parameters.getTickSpacing();
        (int16 wordPos,) = TickBitmap.position(-300);
        ITickLens.PopulatedTick[] memory populatedTicks = tickLens.getPopulatedTicksInWord(id, tickSpacing, wordPos);
        assertEq(populatedTicks.length, 1);
        assertEq(populatedTicks[0].tick, -300);
        assertEq(populatedTicks[0].liquidityNet, 10 ether);
        assertEq(populatedTicks[0].liquidityGross, 10 ether);
    }

    function test_getPopulatedTicksInWord_mulitiple_ticks() public {
        // will add more ticks in the same word with tick -300
        // tick should be between -512 and -256
        positionManager.modifyPosition(
            poolKey0,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: -260,
                tickUpper: 260,
                liquidityDelta: 9 ether,
                salt: bytes32(0)
            }),
            new bytes(0)
        );

        positionManager.modifyPosition(
            poolKey0,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: -360,
                tickUpper: 360,
                liquidityDelta: 11 ether,
                salt: bytes32(0)
            }),
            new bytes(0)
        );

        (int16 wordPos,) = TickBitmap.position(-300);
        ITickLens.PopulatedTick[] memory populatedTicks = tickLens.getPopulatedTicksInWord(poolKey0, wordPos);
        assertEq(populatedTicks.length, 3);
        assertEq(populatedTicks[0].tick, -260);
        assertEq(populatedTicks[1].tick, -300);
        assertEq(populatedTicks[2].tick, -360);
        assertEq(populatedTicks[0].liquidityNet, 9 ether);
        assertEq(populatedTicks[1].liquidityNet, 10 ether);
        assertEq(populatedTicks[2].liquidityNet, 11 ether);
        assertEq(populatedTicks[0].liquidityGross, 9 ether);
        assertEq(populatedTicks[1].liquidityGross, 10 ether);
        assertEq(populatedTicks[2].liquidityGross, 11 ether);
    }

    function testFuzz_getPopulatedTicksInWord_single_tick(uint24 tick, bool isNegative) public {
        tick = uint24(bound(tick, 0, uint256(int256(TickMath.MAX_TICK - 256))));
        int24 tickLower = isNegative ? -int24(tick) : int24(tick);
        int24 tickUpper = tickLower + 256;
        //add liquidity
        positionManager.modifyPosition(
            poolKey1,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: 1 ether,
                salt: bytes32(0)
            }),
            new bytes(0)
        );
        (int16 wordPos,) = TickBitmap.position(tickLower);
        ITickLens.PopulatedTick[] memory populatedTicks = tickLens.getPopulatedTicksInWord(poolKey1, wordPos);
        assertEq(populatedTicks.length, 1);
        assertEq(populatedTicks[0].tick, tickLower);
        assertEq(populatedTicks[0].liquidityNet, 1 ether);
        assertEq(populatedTicks[0].liquidityGross, 1 ether);
    }

    function testFuzz_getPopulatedTicksInWord_multiple_ticks(uint24 tick, bool isNegative, uint8 numbers) public {
        vm.assume(numbers > 0);
        tick = uint24(bound(tick, 0, uint256(int256(TickMath.MAX_TICK - 256))));
        int24 tickLower = isNegative ? -int24(tick) : int24(tick);
        (int16 wordPos,) = TickBitmap.position(tickLower);

        int24[] memory tickLowerList = new int24[](numbers);
        uint256 tick_length_in_same_word = isNegative ? (tick % 256) : (256 - tick % 256);
        if (tick % 256 == 0) tick_length_in_same_word = 256;
        tick_length_in_same_word = numbers > tick_length_in_same_word ? tick_length_in_same_word : numbers;
        for (uint8 i = 0; i < numbers; i++) {
            tickLowerList[i] = tickLower;
            int24 tickUpper = tickLower + 256;
            //add liquidity
            positionManager.modifyPosition(
                poolKey1,
                ICLPoolManager.ModifyLiquidityParams({
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: 1 ether,
                    salt: bytes32(0)
                }),
                new bytes(0)
            );
            tickLower += 1;
        }

        ITickLens.PopulatedTick[] memory populatedTicks = tickLens.getPopulatedTicksInWord(poolKey1, wordPos);
        assertEq(populatedTicks.length, tick_length_in_same_word);
        for (uint8 j = 0; j < tick_length_in_same_word; j++) {
            assertEq(populatedTicks[j].tick, tickLowerList[tick_length_in_same_word - j - 1]);
            assertEq(populatedTicks[j].liquidityNet, 1 ether);
            assertEq(populatedTicks[j].liquidityGross, 1 ether);
        }
    }

    function test_getPopulatedTicksInWord_revert_PoolNotInitialized() public {
        poolKey0.poolManager = ICLPoolManager(address(0));
        (int16 wordPos,) = TickBitmap.position(-300);
        vm.expectRevert(ITickLens.PoolNotInitialized.selector);
        tickLens.getPopulatedTicksInWord(poolKey0, wordPos);
    }

    function test_getPopulatedTicksInWord_revert_InvalidTickSpacing() public {
        PoolId id = poolKey0.toId();
        (int16 wordPos,) = TickBitmap.position(-300);
        vm.expectRevert(ITickLens.InvalidTickSpacing.selector);
        tickLens.getPopulatedTicksInWord(id, TickMath.MAX_TICK_SPACING + 1, wordPos);

        vm.expectRevert(ITickLens.InvalidTickSpacing.selector);
        tickLens.getPopulatedTicksInWord(id, TickMath.MIN_TICK_SPACING - 1, wordPos);
    }

    // allow refund of ETH
    receive() external payable {}
}
