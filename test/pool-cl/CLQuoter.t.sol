// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IQuoter} from "../../src/interfaces/IQuoter.sol";
import {ICLQuoter} from "../../src/pool-cl/interfaces/ICLQuoter.sol";
import {CLQuoter} from "../../src/pool-cl/lens/CLQuoter.sol";
import {LiquidityAmounts} from "../../src/pool-cl/libraries/LiquidityAmounts.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {BalanceDelta} from "pancake-v4-core/src/types/BalanceDelta.sol";
import {SafeCast} from "pancake-v4-core/src/libraries/SafeCast.sol";
import {Deployers} from "pancake-v4-core/test/pool-cl/helpers/Deployers.sol";
import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";
import {PoolModifyPositionTest} from "./shared/PoolModifyPositionTest.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {CLPoolManager} from "pancake-v4-core/src/pool-cl/CLPoolManager.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLPoolManagerRouter} from "pancake-v4-core/test/pool-cl/helpers/CLPoolManagerRouter.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {TickMath} from "pancake-v4-core/src/pool-cl/libraries/TickMath.sol";
import {PathKey} from "../../src/libraries/PathKey.sol";

contract CLQuoterTest is Test, Deployers {
    using SafeCast for *;
    using PoolIdLibrary for PoolKey;

    // Min tick for full range with tick spacing of 60
    int24 internal constant MIN_TICK = -887220;
    // Max tick for full range with tick spacing of 60
    int24 internal constant MAX_TICK = -MIN_TICK;

    uint160 internal constant SQRT_RATIO_100_102 = 78447570448055484695608110440;
    uint160 internal constant SQRT_RATIO_102_100 = 80016521857016594389520272648;

    uint256 internal constant CONTROLLER_GAS_LIMIT = 500000;

    IVault public vault;
    CLPoolManager public manager;

    CLQuoter quoter;

    PoolModifyPositionTest positionManager;

    MockERC20 token0;
    MockERC20 token1;
    MockERC20 token2;

    PoolKey key01;
    PoolKey key02;
    PoolKey key12;

    MockERC20[] tokenPath;

    function setUp() public {
        (vault, manager) = createFreshManager();
        quoter = new CLQuoter(address(manager));
        positionManager = new PoolModifyPositionTest(vault, manager);

        // salts are chosen so that address(token0) < address(token1) && address(token1) < address(token2)
        token0 = new MockERC20("Test0", "0", 18);
        vm.etch(address(0x1111), address(token0).code);
        token0 = MockERC20(address(0x1111));
        token0.mint(address(this), 2 ** 128);

        vm.etch(address(0x2222), address(token0).code);
        token1 = MockERC20(address(0x2222));
        token1.mint(address(this), 2 ** 128);

        vm.etch(address(0x3333), address(token0).code);
        token2 = MockERC20(address(0x3333));
        token2.mint(address(this), 2 ** 128);

        key01 = createPoolKey(token0, token1, address(0));
        key02 = createPoolKey(token0, token2, address(0));
        key12 = createPoolKey(token1, token2, address(0));
        setupPool(key01);
        setupPool(key12);
        setupPoolMultiplePositions(key02);
    }

    function testCLQuoter_quoteExactInputSingle_ZeroForOne_MultiplePositions() public {
        uint256 amountIn = 10000;
        uint256 expectedAmountOut = 9871;
        uint160 expectedSqrtPriceX96After = 78461846509168490764501028180;

        (int128[] memory deltaAmounts, uint160 sqrtPriceX96After, uint32 initializedTicksLoaded) = quoter
            .quoteExactInputSingle(
            ICLQuoter.QuoteExactSingleParams({
                poolKey: key02,
                zeroForOne: true,
                exactAmount: uint128(amountIn),
                sqrtPriceLimitX96: 0,
                hookData: ZERO_BYTES
            })
        );

        assertEq(uint128(deltaAmounts[1]), expectedAmountOut);
        assertEq(sqrtPriceX96After, expectedSqrtPriceX96After);
        assertEq(initializedTicksLoaded, 2);
    }

    function testCLQuoter_quoteExactInputSingle_OneForZero_MultiplePositions() public {
        uint256 amountIn = 10000;
        uint256 expectedAmountOut = 9871;
        uint160 expectedSqrtPriceX96After = 80001962924147897865541384515;

        (int128[] memory deltaAmounts, uint160 sqrtPriceX96After, uint32 initializedTicksLoaded) = quoter
            .quoteExactInputSingle(
            ICLQuoter.QuoteExactSingleParams({
                poolKey: key02,
                zeroForOne: false,
                exactAmount: uint128(amountIn),
                sqrtPriceLimitX96: 0,
                hookData: ZERO_BYTES
            })
        );

        assertEq(uint128(deltaAmounts[0]), expectedAmountOut);
        assertEq(sqrtPriceX96After, expectedSqrtPriceX96After);
        assertEq(initializedTicksLoaded, 2);
    }

    // nested self-call into lockAcquired reverts
    function testCLQuoter_callLockAcquired_reverts() public {
        vm.expectRevert(IQuoter.LockFailure.selector);
        vm.prank(address(vault));
        quoter.lockAcquired(abi.encodeWithSelector(quoter.lockAcquired.selector, address(this), "0x"));
    }

    function testCLQuoter_quoteExactInput_0to2_2TicksLoaded() public {
        tokenPath.push(token0);
        tokenPath.push(token2);
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 10000);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);

        assertEq(uint128(deltaAmounts[1]), 9871);
        assertEq(sqrtPriceX96AfterList[0], 78461846509168490764501028180);
        assertEq(initializedTicksLoadedList[0], 2);
    }

    function testCLQuoter_quoteExactInput_0to2_2TicksLoaded_initialiedAfter() public {
        tokenPath.push(token0);
        tokenPath.push(token2);

        // The swap amount is set such that the active tick after the swap is -120.
        // -120 is an initialized tick for this pool. We check that we don't count it.
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 6200);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);

        assertEq(uint128(deltaAmounts[1]), 6143);
        assertEq(sqrtPriceX96AfterList[0], 78757224507315167622282810783);
        assertEq(initializedTicksLoadedList[0], 1);
    }

    function testCLQuoter_quoteExactInput_0to2_1TickLoaded() public {
        tokenPath.push(token0);
        tokenPath.push(token2);

        // The swap amount is set such that the active tick after the swap is -60.
        // -60 is an initialized tick for this pool. We check that we don't count it.
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 4000);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);

        assertEq(uint128(deltaAmounts[1]), 3971);
        assertEq(sqrtPriceX96AfterList[0], 78926452400586371254602774705);
        assertEq(initializedTicksLoadedList[0], 1);
    }

    function testCLQuoter_quoteExactInput_0to2_0TickLoaded_startingNotInitialized() public {
        tokenPath.push(token0);
        tokenPath.push(token2);
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 10);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);

        assertEq(uint128(deltaAmounts[1]), 8);
        assertEq(sqrtPriceX96AfterList[0], 79227483487511329217250071027);
        assertEq(initializedTicksLoadedList[0], 0);
    }

    function testCLQuoter_quoteExactInput_0to2_0TickLoaded_startingInitialized() public {
        setupPoolWithZeroTickInitialized(key02);
        tokenPath.push(token0);
        tokenPath.push(token2);
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 10);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);

        assertEq(uint128(deltaAmounts[1]), 8);
        assertEq(sqrtPriceX96AfterList[0], 79227817515327498931091950511);
        assertEq(initializedTicksLoadedList[0], 1);
    }

    function testCLQuoter_quoteExactInput_2to0_2TicksLoaded() public {
        tokenPath.push(token2);
        tokenPath.push(token0);
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 10000);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);

        assertEq(deltaAmounts[1], 9871);
        assertEq(sqrtPriceX96AfterList[0], 80001962924147897865541384515);
        assertEq(initializedTicksLoadedList[0], 2);
    }

    function testCLQuoter_quoteExactInput_2to0_2TicksLoaded_initialiedAfter() public {
        tokenPath.push(token2);
        tokenPath.push(token0);

        // The swap amount is set such that the active tick after the swap is 120.
        // 120 is an initialized tick for this pool. We check that we don't count it.
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 6250);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);

        assertEq(deltaAmounts[1], 6190);
        assertEq(sqrtPriceX96AfterList[0], 79705728824507063507279123685);
        assertEq(initializedTicksLoadedList[0], 2);
    }

    function testCLQuoter_quoteExactInput_2to0_0TickLoaded_startingInitialized() public {
        setupPoolWithZeroTickInitialized(key02);
        tokenPath.push(token2);
        tokenPath.push(token0);
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 200);

        // Tick 0 initialized. Tick after = 1
        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);

        assertEq(deltaAmounts[1], 198);
        assertEq(sqrtPriceX96AfterList[0], 79235729830182478001034429156);
        assertEq(initializedTicksLoadedList[0], 0);
    }

    // 2->0 starting not initialized
    function testCLQuoter_quoteExactInput_2to0_0TickLoaded_startingNotInitialized() public {
        tokenPath.push(token2);
        tokenPath.push(token0);
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 103);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);

        assertEq(deltaAmounts[1], 101);
        assertEq(sqrtPriceX96AfterList[0], 79235858216754624215638319723);
        assertEq(initializedTicksLoadedList[0], 0);
    }

    function testCLQuoter_quoteExactInput_2to1() public {
        tokenPath.push(token2);
        tokenPath.push(token1);
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 10000);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);
        assertEq(deltaAmounts[1], 9871);
        assertEq(sqrtPriceX96AfterList[0], 80018067294531553039351583520);
        assertEq(initializedTicksLoadedList[0], 0);
    }

    function testCLQuoter_quoteExactInput_0to2to1() public {
        tokenPath.push(token0);
        tokenPath.push(token2);
        tokenPath.push(token1);
        ICLQuoter.QuoteExactParams memory params = getExactInputParams(tokenPath, 10000);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactInput(params);

        assertEq(deltaAmounts[2], 9745);
        assertEq(sqrtPriceX96AfterList[0], 78461846509168490764501028180);
        assertEq(sqrtPriceX96AfterList[1], 80007846861567212939802016351);
        assertEq(initializedTicksLoadedList[0], 2);
        assertEq(initializedTicksLoadedList[1], 0);
    }

    function testCLQuoter_quoteExactOutputSingle_0to1() public {
        (int128[] memory deltaAmounts, uint160 sqrtPriceX96After, uint32 initializedTicksLoaded) = quoter
            .quoteExactOutputSingle(
            ICLQuoter.QuoteExactSingleParams({
                poolKey: key01,
                zeroForOne: true,
                exactAmount: type(uint128).max,
                sqrtPriceLimitX96: SQRT_RATIO_100_102,
                hookData: ZERO_BYTES
            })
        );

        assertEq(-deltaAmounts[0], 9981);
        assertEq(sqrtPriceX96After, SQRT_RATIO_100_102);
        assertEq(initializedTicksLoaded, 0);
    }

    function testCLQuoter_quoteExactOutputSingle_1to0() public {
        (int128[] memory deltaAmounts, uint160 sqrtPriceX96After, uint32 initializedTicksLoaded) = quoter
            .quoteExactOutputSingle(
            ICLQuoter.QuoteExactSingleParams({
                poolKey: key01,
                zeroForOne: false,
                exactAmount: type(uint128).max,
                sqrtPriceLimitX96: SQRT_RATIO_102_100,
                hookData: ZERO_BYTES
            })
        );

        assertEq(-deltaAmounts[1], 9981);
        assertEq(sqrtPriceX96After, SQRT_RATIO_102_100);
        assertEq(initializedTicksLoaded, 0);
    }

    function testCLQuoter_quoteExactOutput_0to2_2TicksLoaded() public {
        tokenPath.push(token0);
        tokenPath.push(token2);
        ICLQuoter.QuoteExactParams memory params = getExactOutputParams(tokenPath, 15000);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactOutput(params);

        assertEq(-deltaAmounts[0], 15273);
        assertEq(sqrtPriceX96AfterList[0], 78055527257643669242286029831);
        assertEq(initializedTicksLoadedList[0], 2);
    }

    function testCLQuoter_quoteExactOutput_0to2_1TickLoaded_initialiedAfter() public {
        tokenPath.push(token0);
        tokenPath.push(token2);

        ICLQuoter.QuoteExactParams memory params = getExactOutputParams(tokenPath, 6143);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactOutput(params);

        assertEq(-deltaAmounts[0], 6200);
        assertEq(sqrtPriceX96AfterList[0], 78757225449310403327341205211);
        assertEq(initializedTicksLoadedList[0], 1);
    }

    function testCLQuoter_quoteExactOutput_0to2_1TickLoaded() public {
        tokenPath.push(token0);
        tokenPath.push(token2);

        ICLQuoter.QuoteExactParams memory params = getExactOutputParams(tokenPath, 4000);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactOutput(params);

        assertEq(-deltaAmounts[0], 4029);
        assertEq(sqrtPriceX96AfterList[0], 78924219757724709840818372098);
        assertEq(initializedTicksLoadedList[0], 1);
    }

    function testCLQuoter_quoteExactOutput_0to2_0TickLoaded_startingInitialized() public {
        setupPoolWithZeroTickInitialized(key02);
        tokenPath.push(token0);
        tokenPath.push(token2);

        ICLQuoter.QuoteExactParams memory params = getExactOutputParams(tokenPath, 100);

        // Tick 0 initialized. Tick after = 1
        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactOutput(params);

        assertEq(-deltaAmounts[0], 102);
        assertEq(sqrtPriceX96AfterList[0], 79224329176051641448521403903);
        assertEq(initializedTicksLoadedList[0], 1);
    }

    function testCLQuoter_quoteExactOutput_0to2_0TickLoaded_startingNotInitialized() public {
        tokenPath.push(token0);
        tokenPath.push(token2);

        ICLQuoter.QuoteExactParams memory params = getExactOutputParams(tokenPath, 10);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactOutput(params);

        assertEq(-deltaAmounts[0], 12);
        assertEq(sqrtPriceX96AfterList[0], 79227408033628034983534698435);
        assertEq(initializedTicksLoadedList[0], 0);
    }

    function testCLQuoter_quoteExactOutput_2to0_2TicksLoaded() public {
        tokenPath.push(token2);
        tokenPath.push(token0);
        ICLQuoter.QuoteExactParams memory params = getExactOutputParams(tokenPath, 15000);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactOutput(params);

        assertEq(-deltaAmounts[0], 15273);
        assertEq(sqrtPriceX96AfterList[0], 80418414376567919517220409857);
        assertEq(initializedTicksLoadedList.length, 1);
        assertEq(initializedTicksLoadedList[0], 2);
    }

    function testCLQuoter_quoteExactOutput_2to0_2TicksLoaded_initialiedAfter() public {
        tokenPath.push(token2);
        tokenPath.push(token0);

        ICLQuoter.QuoteExactParams memory params = getExactOutputParams(tokenPath, 6223);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactOutput(params);

        assertEq(-deltaAmounts[0], 6283);
        assertEq(sqrtPriceX96AfterList[0], 79708304437530892332449657932);
        assertEq(initializedTicksLoadedList.length, 1);
        assertEq(initializedTicksLoadedList[0], 2);
    }

    function testCLQuoter_quoteExactOutput_2to0_1TickLoaded() public {
        tokenPath.push(token2);
        tokenPath.push(token0);

        ICLQuoter.QuoteExactParams memory params = getExactOutputParams(tokenPath, 6000);
        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactOutput(params);

        assertEq(-deltaAmounts[0], 6055);
        assertEq(sqrtPriceX96AfterList[0], 79690640184021170956740081887);
        assertEq(initializedTicksLoadedList.length, 1);
        assertEq(initializedTicksLoadedList[0], 1);
    }

    function testCLQuoter_quoteExactOutput_2to1() public {
        tokenPath.push(token2);
        tokenPath.push(token1);

        ICLQuoter.QuoteExactParams memory params = getExactOutputParams(tokenPath, 9871);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactOutput(params);

        assertEq(-deltaAmounts[0], 10000);
        assertEq(sqrtPriceX96AfterList[0], 80018020393569259756601362385);
        assertEq(initializedTicksLoadedList.length, 1);
        assertEq(initializedTicksLoadedList[0], 0);
    }

    function testCLQuoter_quoteExactOutput_0to2to1() public {
        tokenPath.push(token0);
        tokenPath.push(token2);
        tokenPath.push(token1);

        ICLQuoter.QuoteExactParams memory params = getExactOutputParams(tokenPath, 9745);

        (
            int128[] memory deltaAmounts,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksLoadedList
        ) = quoter.quoteExactOutput(params);

        assertEq(-deltaAmounts[0], 10000);
        assertEq(deltaAmounts[1], 0);
        assertEq(-deltaAmounts[2], -9745);
        assertEq(sqrtPriceX96AfterList[0], 78461888503179331029803316753);
        assertEq(sqrtPriceX96AfterList[1], 80007838904387594703933785072);
        assertEq(initializedTicksLoadedList.length, 2);
        assertEq(initializedTicksLoadedList[0], 2);
        assertEq(initializedTicksLoadedList[1], 0);
    }

    function createPoolKey(MockERC20 tokenA, MockERC20 tokenB, address hookAddr)
        internal
        view
        returns (PoolKey memory)
    {
        if (address(tokenA) > address(tokenB)) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({
            currency0: Currency.wrap(address(tokenA)),
            currency1: Currency.wrap(address(tokenB)),
            hooks: IHooks(hookAddr),
            poolManager: manager,
            fee: uint24(3000),
            parameters: bytes32(uint256(0x3c0000))
        });
    }

    function setupPool(PoolKey memory poolKey) internal {
        manager.initialize(poolKey, SQRT_RATIO_1_1, ZERO_BYTES);
        MockERC20(Currency.unwrap(poolKey.currency0)).approve(address(positionManager), type(uint256).max);
        MockERC20(Currency.unwrap(poolKey.currency1)).approve(address(positionManager), type(uint256).max);
        positionManager.modifyPosition(
            poolKey,
            ICLPoolManager.ModifyLiquidityParams(
                MIN_TICK,
                MAX_TICK,
                calculateLiquidityFromAmounts(SQRT_RATIO_1_1, MIN_TICK, MAX_TICK, 1000000, 1000000).toInt256(),
                bytes32(0)
            ),
            ZERO_BYTES
        );
    }

    function setupPoolMultiplePositions(PoolKey memory poolKey) internal {
        manager.initialize(poolKey, SQRT_RATIO_1_1, ZERO_BYTES);
        MockERC20(Currency.unwrap(poolKey.currency0)).approve(address(positionManager), type(uint256).max);
        MockERC20(Currency.unwrap(poolKey.currency1)).approve(address(positionManager), type(uint256).max);
        positionManager.modifyPosition(
            poolKey,
            ICLPoolManager.ModifyLiquidityParams(
                MIN_TICK,
                MAX_TICK,
                calculateLiquidityFromAmounts(SQRT_RATIO_1_1, MIN_TICK, MAX_TICK, 1000000, 1000000).toInt256(),
                bytes32(0)
            ),
            ZERO_BYTES
        );
        positionManager.modifyPosition(
            poolKey,
            ICLPoolManager.ModifyLiquidityParams(
                -60, 60, calculateLiquidityFromAmounts(SQRT_RATIO_1_1, -60, 60, 100, 100).toInt256(), bytes32(0)
            ),
            ZERO_BYTES
        );
        positionManager.modifyPosition(
            poolKey,
            ICLPoolManager.ModifyLiquidityParams(
                -120, 120, calculateLiquidityFromAmounts(SQRT_RATIO_1_1, -120, 120, 100, 100).toInt256(), bytes32(0)
            ),
            ZERO_BYTES
        );
    }

    function setupPoolWithZeroTickInitialized(PoolKey memory poolKey) internal {
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96,,,) = manager.getSlot0(poolId);
        if (sqrtPriceX96 == 0) {
            manager.initialize(poolKey, SQRT_RATIO_1_1, ZERO_BYTES);
        }

        MockERC20(Currency.unwrap(poolKey.currency0)).approve(address(positionManager), type(uint256).max);
        MockERC20(Currency.unwrap(poolKey.currency1)).approve(address(positionManager), type(uint256).max);
        positionManager.modifyPosition(
            poolKey,
            ICLPoolManager.ModifyLiquidityParams({
                tickLower: MIN_TICK,
                tickUpper: MAX_TICK,
                liquidityDelta: calculateLiquidityFromAmounts(SQRT_RATIO_1_1, MIN_TICK, MAX_TICK, 1000000, 1000000).toInt256(
                ),
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
        positionManager.modifyPosition(
            poolKey,
            ICLPoolManager.ModifyLiquidityParams(
                0, 60, calculateLiquidityFromAmounts(SQRT_RATIO_1_1, 0, 60, 100, 100).toInt256(), bytes32(0)
            ),
            ZERO_BYTES
        );
        positionManager.modifyPosition(
            poolKey,
            ICLPoolManager.ModifyLiquidityParams(
                -120, 0, calculateLiquidityFromAmounts(SQRT_RATIO_1_1, -120, 0, 100, 100).toInt256(), bytes32(0)
            ),
            ZERO_BYTES
        );
    }

    function calculateLiquidityFromAmounts(
        uint160 sqrtRatioX96,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        liquidity =
            LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1);
    }

    function getExactInputParams(MockERC20[] memory _tokenPath, uint256 amountIn)
        internal
        view
        returns (ICLQuoter.QuoteExactParams memory params)
    {
        PathKey[] memory path = new PathKey[](_tokenPath.length - 1);
        for (uint256 i = 0; i < _tokenPath.length - 1; i++) {
            path[i] = PathKey(
                Currency.wrap(address(_tokenPath[i + 1])),
                3000,
                IHooks(address(0)),
                ICLPoolManager(manager),
                bytes(""),
                bytes32(uint256(0x3c0000))
            );
        }

        params.exactCurrency = Currency.wrap(address(_tokenPath[0]));
        params.path = path;
        params.exactAmount = uint128(amountIn);
    }

    function getExactOutputParams(MockERC20[] memory _tokenPath, uint256 amountOut)
        internal
        view
        returns (ICLQuoter.QuoteExactParams memory params)
    {
        PathKey[] memory path = new PathKey[](_tokenPath.length - 1);
        for (uint256 i = _tokenPath.length - 1; i > 0; i--) {
            path[i - 1] = PathKey(
                Currency.wrap(address(_tokenPath[i - 1])),
                3000,
                IHooks(address(0)),
                ICLPoolManager(manager),
                bytes(""),
                bytes32(uint256(0x3c0000))
            );
        }

        params.exactCurrency = Currency.wrap(address(_tokenPath[_tokenPath.length - 1]));
        params.path = path;
        params.exactAmount = uint128(amountOut);
    }
}
