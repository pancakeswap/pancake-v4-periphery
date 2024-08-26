// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {OldVersionHelper} from "./helpers/OldVersionHelper.sol";
import {IPancakePair} from "../src/interfaces/external/IPancakePair.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CLPositionManager} from "../src/pool-cl/CLPositionManager.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {Vault} from "pancake-v4-core/src/Vault.sol";
import {CLPoolManager} from "pancake-v4-core/src/pool-cl/CLPoolManager.sol";
import {BinPoolManager} from "pancake-v4-core/src/pool-bin/BinPoolManager.sol";
import {IBinPoolManager} from "pancake-v4-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {CLPoolParametersHelper} from "pancake-v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {IPoolManager} from "pancake-v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {PosmTestSetup} from "./pool-cl/shared/PosmTestSetup.sol";
import {PositionConfig} from "../src/pool-cl/libraries/PositionConfig.sol";
import {Permit2ApproveHelper} from "./helpers/Permit2ApproveHelper.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {Permit2Forwarder} from "../src/base/Permit2Forwarder.sol";
import {IV3NonfungiblePositionManager} from "../src/interfaces/external/IV3NonfungiblePositionManager.sol";
import {IMixedQuoter} from "../src/interfaces/IMixedQuoter.sol";
import {MixedQuoter} from "../src/MixedQuoter.sol";
import {ICLQuoter} from "../src/pool-cl/interfaces/ICLQuoter.sol";
import {IBinQuoter} from "../src/pool-bin/interfaces/IBinQuoter.sol";
import {MixedQuoterActions} from "../src/libraries/MixedQuoterActions.sol";
import {IPancakeFactory} from "../src/interfaces/external/IPancakeFactory.sol";
import {IPancakeV3Factory} from "../src/interfaces/external/IPancakeV3Factory.sol";
import {ICLQuoter} from "../src/pool-cl/interfaces/ICLQuoter.sol";
import {CLQuoter} from "../src/pool-cl/lens/CLQuoter.sol";
import {BinPositionManager} from "../src/pool-bin/BinPositionManager.sol";
import {IBinPositionManager} from "../src/pool-bin/interfaces/IBinPositionManager.sol";
import {IBinQuoter, BinQuoter} from "../src/pool-bin/lens/BinQuoter.sol";
import {BinPoolParametersHelper} from "pancake-v4-core/src/pool-bin/libraries/BinPoolParametersHelper.sol";
import {BinLiquidityHelper} from "./pool-bin/helper/BinLiquidityHelper.sol";
import {Plan, Planner} from "../src/libraries/Planner.sol";
import {Actions} from "../src/libraries/Actions.sol";
import {DeployStableSwapHelper} from "./helpers/DeployStableSwapHelper.sol";
import {IStableSwapFactory} from "../src/interfaces/external/IStableSwapFactory.sol";
import {IStableSwap} from "../src/interfaces/external/IStableSwap.sol";

contract MixedQuoterTest is
    Test,
    OldVersionHelper,
    PosmTestSetup,
    Permit2ApproveHelper,
    BinLiquidityHelper,
    DeployStableSwapHelper,
    GasSnapshot
{
    using SafeCast for *;
    using CLPoolParametersHelper for bytes32;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using BinPoolParametersHelper for bytes32;
    using Planner for Plan;

    uint160 public constant INIT_SQRT_PRICE = 79228162514264337593543950336;
    uint24 activeId = 2 ** 23; // where token0 and token1 price is the same

    WETH weth;
    MockERC20 token0;
    MockERC20 token1;
    MockERC20 token2;
    MockERC20 token3;
    MockERC20 token4;
    MockERC20 token5;

    IVault vault;
    ICLPoolManager clPoolManager;

    IPancakeFactory v2Factory;
    IPancakePair v2Pair;
    IPancakePair v2PairWithoutNativeToken;

    address v3Deployer;
    IPancakeV3Factory v3Factory;
    IV3NonfungiblePositionManager v3Nfpm;

    IStableSwapFactory stableSwapFactory;
    IStableSwap stableSwapPair;

    IBinPoolManager binPoolManager;
    BinPositionManager binPm;
    ICLQuoter clQuoter;
    IBinQuoter binQuoter;
    MixedQuoter mixedQuoter;

    PoolId poolId;
    PoolKey poolKey;
    PoolKey poolKeyWithNativeToken;
    PoolKey poolKeyWithWETH;

    bytes32 binPoolParam;

    PoolKey binPoolKey;

    PositionConfig positionConfig;

    function setUp() public {
        weth = new WETH();
        token2 = new MockERC20("Token0", "TKN2", 18);
        token3 = new MockERC20("Token1", "TKN3", 18);
        token4 = new MockERC20("Token2", "TKN4", 18);
        token5 = new MockERC20("Token3", "TKN5", 18);
        (token2, token3) = token2 < token3 ? (token2, token3) : (token3, token2);
        (token3, token4) = token3 < token4 ? (token3, token4) : (token4, token3);
        deployPosmHookSavesDelta();
        (vault, clPoolManager, poolKey, poolId) =
            createFreshPool(IHooks(address(hook)), 3000, SQRT_RATIO_1_1, ZERO_BYTES);

        binPoolManager = new BinPoolManager(vault, 500000);
        vault.registerApp(address(binPoolManager));

        currency0 = poolKey.currency0;
        currency1 = poolKey.currency1;
        token0 = MockERC20(Currency.unwrap(currency0));
        token1 = MockERC20(Currency.unwrap(currency1));
        deployAndApprovePosm(vault, clPoolManager);

        binPm = new BinPositionManager(vault, binPoolManager, permit2);

        clQuoter = new CLQuoter(address(clPoolManager));
        binQuoter = new BinQuoter(address(binPoolManager));

        binPoolKey = PoolKey({
            currency0: Currency.wrap(address(token3)),
            currency1: Currency.wrap(address(token4)),
            hooks: IHooks(address(0)),
            poolManager: binPoolManager,
            fee: uint24(3000), // 3000 = 0.3%
            parameters: binPoolParam.setBinStep(10) // binStep
        });

        poolKeyWithNativeToken = poolKey;
        poolKeyWithNativeToken.currency0 = Currency.wrap(address(0));
        poolKeyWithNativeToken.currency1 = Currency.wrap(address(token1));
        clPoolManager.initialize(poolKeyWithNativeToken, SQRT_RATIO_1_1, ZERO_BYTES);

        //set pool with WETH
        poolKeyWithWETH = poolKey;
        if (address(weth) < address(token2)) {
            poolKeyWithWETH.currency0 = Currency.wrap(address(weth));
            poolKeyWithWETH.currency1 = Currency.wrap(address(token2));
        } else {
            poolKeyWithWETH.currency0 = Currency.wrap(address(token2));
            poolKeyWithWETH.currency1 = Currency.wrap(address(weth));
        }
        clPoolManager.initialize(poolKeyWithWETH, SQRT_RATIO_1_1, ZERO_BYTES);

        // make sure the contract has enough balance
        deal(address(this), 100000 ether);
        weth.deposit{value: 10000 ether}();
        token2.mint(address(this), 10000 ether);
        token3.mint(address(this), 10000 ether);
        token4.mint(address(this), 10000 ether);
        token5.mint(address(this), 10000 ether);

        v2Factory = IPancakeFactory(createContractThroughBytecode(_getBytecodePath()));
        v2Pair = IPancakePair(v2Factory.createPair(address(weth), address(token2)));
        v2PairWithoutNativeToken = IPancakePair(v2Factory.createPair(address(token2), address(token3)));

        // pcs v3
        if (bytes(_getDeployerBytecodePath()).length != 0) {
            v3Deployer = createContractThroughBytecode(_getDeployerBytecodePath());
            v3Factory = IPancakeV3Factory(
                createContractThroughBytecode(_getFactoryBytecodePath(), toBytes32(address(v3Deployer)))
            );
            (bool success,) = v3Deployer.call(abi.encodeWithSignature("setFactoryAddress(address)", address(v3Factory)));
            require(success, "setFactoryAddress failed");
            v3Nfpm = IV3NonfungiblePositionManager(
                createContractThroughBytecode(
                    _getNfpmBytecodePath(),
                    toBytes32(v3Deployer),
                    toBytes32(address(v3Factory)),
                    toBytes32(address(weth)),
                    0
                )
            );
        } else {
            v3Factory = IPancakeV3Factory(createContractThroughBytecode(_getFactoryBytecodePath()));

            v3Nfpm = IV3NonfungiblePositionManager(
                createContractThroughBytecode(
                    _getNfpmBytecodePath(), toBytes32(address(v3Factory)), toBytes32(address(weth)), 0
                )
            );
        }

        // make sure v3Nfpm has allowance
        weth.approve(address(v3Nfpm), type(uint256).max);
        token2.approve(address(v3Nfpm), type(uint256).max);
        token3.approve(address(v3Nfpm), type(uint256).max);

        // 1. mint some liquidity to the v3 pool
        _mintV3Liquidity(address(weth), address(token2));

        // 1. mint some liquidity to the v2 pair
        _mintV2Liquidity(v2Pair);
        _mintV2Liquidity(v2PairWithoutNativeToken);

        // set stable swap
        stableSwapFactory = IStableSwapFactory(deployStableSwap(address(this)));
        stableSwapFactory.createSwapPair(address(token1), address(token2), 1000, 4000000, 5000000000);
        IStableSwapFactory.StableSwapPairInfo memory ssPairInfo =
            stableSwapFactory.getPairInfo(address(token1), address(token2));
        stableSwapPair = IStableSwap(ssPairInfo.swapContract);
        token1.approve(address(stableSwapPair), type(uint256).max);
        token2.approve(address(stableSwapPair), type(uint256).max);
        uint256[2] memory liquidityAmounts;
        liquidityAmounts[0] = 10 ether;
        liquidityAmounts[1] = 10 ether;
        stableSwapPair.add_liquidity(liquidityAmounts, 0);

        positionConfig = PositionConfig({poolKey: poolKey, tickLower: -300, tickUpper: 300});

        // deploy mixed quoter
        mixedQuoter = new MixedQuoter(
            // v3Deployer,
            address(v3Factory),
            address(v2Factory),
            address(stableSwapFactory),
            address(weth),
            clQuoter,
            binQuoter
        );

        seedBalance(address(this));
        approvePosmFor(address(this));
        mint(positionConfig, 3000 ether, address(this), ZERO_BYTES);

        permit2Approve(address(this), permit2, address(weth), address(lpm));
        permit2Approve(address(this), permit2, address(token1), address(lpm));
        permit2Approve(address(this), permit2, address(token2), address(lpm));

        PositionConfig memory nativePairConfig =
            PositionConfig({poolKey: poolKeyWithNativeToken, tickLower: -300, tickUpper: 300});
        mintWithNative(0, nativePairConfig, 1000 ether, address(this), ZERO_BYTES);

        PositionConfig memory wethPairConfig =
            PositionConfig({poolKey: poolKeyWithWETH, tickLower: -300, tickUpper: 300});
        mint(wethPairConfig, 1000 ether, address(this), ZERO_BYTES);

        // mint some liquidity to the bin pool
        binPoolManager.initialize(binPoolKey, activeId, ZERO_BYTES);
        permit2Approve(address(this), permit2, address(token3), address(binPm));
        permit2Approve(address(this), permit2, address(token4), address(binPm));

        uint24[] memory binIds = getBinIds(activeId, 3);
        IBinPositionManager.BinAddLiquidityParams memory addParams;
        addParams = _getAddParams(binPoolKey, binIds, 10 ether, 10 ether, activeId, address(this));
        Plan memory planner = Planner.init().add(Actions.BIN_ADD_LIQUIDITY, abi.encode(addParams));
        bytes memory payload = planner.finalizeModifyLiquidityWithClose(binPoolKey);
        binPm.modifyLiquidities(payload, block.timestamp + 1);
    }

    function testQuoteExactInputSingleStable() public {
        address[] memory paths = new address[](2);
        paths[0] = address(token1);
        paths[1] = address(token2);

        bytes memory actions = new bytes(1);
        actions[0] = bytes1(uint8(MixedQuoterActions.SS_2_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](1);

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 999499143496490285);
    }

    function testQuoteExactInputSingleV2() public {
        address[] memory paths = new address[](2);
        paths[0] = address(weth);
        paths[1] = address(token2);

        bytes memory actions = new bytes(1);
        actions[0] = bytes1(uint8(MixedQuoterActions.V2_EXACT_INPUT_SINGLE));
        bytes[] memory params = new bytes[](1);

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 907024323709934075);
    }

    function testQuoteExactInputSingleV3() public {
        address[] memory paths = new address[](2);
        paths[0] = address(weth);
        paths[1] = address(token2);

        bytes memory actions = new bytes(1);
        actions[0] = bytes1(uint8(MixedQuoterActions.V3_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 500;
        params[0] = abi.encode(fee);

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 999002019627632472);
    }

    function testV4CLquoteExactInputSingle_ZeroForOne() public {
        address[] memory paths = new address[](2);
        paths[0] = address(Currency.unwrap(poolKey.currency0));
        paths[1] = address(Currency.unwrap(poolKey.currency1));

        bytes memory actions = new bytes(1);
        actions[0] = bytes1(uint8(MixedQuoterActions.V4_CL_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](1);
        params[0] =
            abi.encode(IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: poolKey, hookData: ZERO_BYTES}));

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 996668773744192346);

        (int128[] memory deltaAmounts,,) = clQuoter.quoteExactInputSingle(
            ICLQuoter.QuoteExactSingleParams({
                poolKey: poolKey,
                zeroForOne: true,
                exactAmount: 1 ether,
                sqrtPriceLimitX96: 0,
                hookData: ZERO_BYTES
            })
        );
        assertEq(-deltaAmounts[0], 1 ether);
        assertEq(uint128(deltaAmounts[1]), amountOut);
    }

    function testV4CLquoteExactInputSingle_OneForZero() public {
        address[] memory paths = new address[](2);
        paths[0] = address(Currency.unwrap(poolKey.currency1));
        paths[1] = address(Currency.unwrap(poolKey.currency0));

        bytes memory actions = new bytes(1);
        actions[0] = bytes1(uint8(MixedQuoterActions.V4_CL_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](1);
        params[0] =
            abi.encode(IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: poolKey, hookData: ZERO_BYTES}));

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 996668773744192346);

        (int128[] memory deltaAmounts,,) = clQuoter.quoteExactInputSingle(
            ICLQuoter.QuoteExactSingleParams({
                poolKey: poolKey,
                zeroForOne: false,
                exactAmount: 1 ether,
                sqrtPriceLimitX96: 0,
                hookData: ZERO_BYTES
            })
        );
        assertEq(-deltaAmounts[1], 1 ether);
        assertEq(uint128(deltaAmounts[0]), amountOut);
    }

    function testV4CLquoteExactInputSingle_ZeroForOne_WETHPair() public {
        address[] memory paths = new address[](2);
        if (address(weth) < address(token2)) {
            paths[0] = address(weth);
            paths[1] = address(token2);
        } else {
            paths[0] = address(token2);
            paths[1] = address(weth);
        }

        bytes memory actions = new bytes(1);
        actions[0] = bytes1(uint8(MixedQuoterActions.V4_CL_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](1);
        params[0] = abi.encode(
            IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: poolKeyWithWETH, hookData: ZERO_BYTES})
        );

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 996006981039903216);

        (int128[] memory deltaAmounts,,) = clQuoter.quoteExactInputSingle(
            ICLQuoter.QuoteExactSingleParams({
                poolKey: poolKeyWithWETH,
                zeroForOne: true,
                exactAmount: 1 ether,
                sqrtPriceLimitX96: 0,
                hookData: ZERO_BYTES
            })
        );
        assertEq(-deltaAmounts[0], 1 ether);
        assertEq(uint128(deltaAmounts[1]), amountOut);
    }

    function testBinQuoteExactInputSingle_ZeroForOne() public {
        address[] memory paths = new address[](2);
        paths[0] = address(token3);
        paths[1] = address(token4);

        bytes memory actions = new bytes(1);
        actions[0] = bytes1(uint8(MixedQuoterActions.V4_BIN_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](1);
        params[0] =
            abi.encode(IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: binPoolKey, hookData: ZERO_BYTES}));

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 997000000000000000);

        (int128[] memory deltaAmounts,) = binQuoter.quoteExactInputSingle(
            IBinQuoter.QuoteExactSingleParams({
                poolKey: binPoolKey,
                zeroForOne: true,
                exactAmount: 1 ether,
                hookData: ZERO_BYTES
            })
        );
        assertEq(-deltaAmounts[0], 1 ether);
        assertEq(uint128(deltaAmounts[1]), amountOut);
    }

    function testBinQuoteExactInputSingle_OneForZero() public {
        address[] memory paths = new address[](2);
        paths[0] = address(token4);
        paths[1] = address(token3);

        bytes memory actions = new bytes(1);
        actions[0] = bytes1(uint8(MixedQuoterActions.V4_BIN_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](1);
        params[0] =
            abi.encode(IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: binPoolKey, hookData: ZERO_BYTES}));

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 997000000000000000);

        (int128[] memory deltaAmounts,) = binQuoter.quoteExactInputSingle(
            IBinQuoter.QuoteExactSingleParams({
                poolKey: binPoolKey,
                zeroForOne: false,
                exactAmount: 1 ether,
                hookData: ZERO_BYTES
            })
        );
        assertEq(-deltaAmounts[1], 1 ether);
        assertEq(uint128(deltaAmounts[0]), amountOut);
    }

    // token0 -> token1 -> token2
    // V4 CL Pool -> SS Pool
    function testQuoteMixedTwoHops_V4Cl_SS() public {
        address[] memory paths = new address[](3);
        paths[0] = address(token0);
        paths[1] = address(token1);
        paths[2] = address(token2);

        bytes memory actions = new bytes(2);
        actions[0] = bytes1(uint8(MixedQuoterActions.V4_CL_EXACT_INPUT_SINGLE));
        actions[1] = bytes1(uint8(MixedQuoterActions.SS_2_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](2);
        params[0] =
            abi.encode(IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: poolKey, hookData: ZERO_BYTES}));
        params[1] = new bytes(0);

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 996169927245114903);
    }

    // token0 -> token1 -> token2 -> WETH
    // V4 CL Pool -> SS Pool -> V3 Pool
    function testQuoteMixedThreeHops_V4Cl_SS_V3() public {
        address[] memory paths = new address[](4);
        paths[0] = address(token0);
        paths[1] = address(token1);
        paths[2] = address(token2);
        paths[3] = address(weth);

        bytes memory actions = new bytes(3);
        actions[0] = bytes1(uint8(MixedQuoterActions.V4_CL_EXACT_INPUT_SINGLE));
        actions[1] = bytes1(uint8(MixedQuoterActions.SS_2_EXACT_INPUT_SINGLE));
        actions[2] = bytes1(uint8(MixedQuoterActions.V3_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](3);
        params[0] =
            abi.encode(IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: poolKey, hookData: ZERO_BYTES}));
        params[1] = new bytes(0);
        uint24 fee = 500;
        params[2] = abi.encode(fee);

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 995177668263126217);
    }

    // token0 -> token1 -> token2 -> token3 -> token4
    // V4 CL Pool -> SS Pool -> V2 Pool -> V4 Bin Pool
    function testQuoteMixedFourHops_V4Cl_SS_V2_V4Bin() public {
        address[] memory paths = new address[](5);
        paths[0] = address(token0);
        paths[1] = address(token1);
        paths[2] = address(token2);
        paths[3] = address(token3);
        paths[4] = address(token4);

        bytes memory actions = new bytes(4);
        actions[0] = bytes1(uint8(MixedQuoterActions.V4_CL_EXACT_INPUT_SINGLE));
        actions[1] = bytes1(uint8(MixedQuoterActions.SS_2_EXACT_INPUT_SINGLE));
        actions[2] = bytes1(uint8(MixedQuoterActions.V2_EXACT_INPUT_SINGLE));
        actions[3] = bytes1(uint8(MixedQuoterActions.V4_BIN_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](4);
        params[0] =
            abi.encode(IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: poolKey, hookData: ZERO_BYTES}));
        params[1] = new bytes(0);
        params[2] = new bytes(0);
        params[3] =
            abi.encode(IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: binPoolKey, hookData: ZERO_BYTES}));

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 901152761185198407);
    }

    // token2 -> WETH -> token1
    // V3 WETH Pool -> V4 Native Pool
    function testQuoteMixed_ConvertWETHToNative_V3WETHPair_V4CLNativePair() public {
        address[] memory paths = new address[](3);
        paths[0] = address(token2);
        paths[1] = address(weth);
        paths[2] = address(token1);

        bytes memory actions = new bytes(2);
        actions[0] = bytes1(uint8(MixedQuoterActions.V3_EXACT_INPUT_SINGLE));
        actions[1] = bytes1(uint8(MixedQuoterActions.V4_CL_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](2);
        uint24 fee = 500;
        params[0] = abi.encode(fee);
        params[1] = abi.encode(
            IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: poolKeyWithNativeToken, hookData: ZERO_BYTES})
        );

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 995013974661415835);
    }

    // token1 -> address(0) -> token2
    // V4 CL Native Pool -> V3 WETH Pool
    function testQuoteMixed_ConvertNativeToWETH_V4CLNativePair_V3WETHPair() public {
        address[] memory paths = new address[](3);
        paths[0] = address(token1);
        paths[1] = address(0);
        paths[2] = address(token2);

        bytes memory actions = new bytes(2);
        actions[0] = bytes1(uint8(MixedQuoterActions.V4_CL_EXACT_INPUT_SINGLE));
        actions[1] = bytes1(uint8(MixedQuoterActions.V3_EXACT_INPUT_SINGLE));

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            IMixedQuoter.QuoteMixedV4ExactInputSingleParams({poolKey: poolKeyWithNativeToken, hookData: ZERO_BYTES})
        );
        uint24 fee = 500;
        params[1] = abi.encode(fee);

        uint256 amountOut = mixedQuoter.quoteMixedExactInput(paths, actions, params, 1 ether);

        assertEq(amountOut, 995014965144446181);
    }

    function _mintV3Liquidity(address _token0, address _token1) internal {
        (_token0, _token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);
        v3Nfpm.createAndInitializePoolIfNecessary(_token0, _token1, 500, INIT_SQRT_PRICE);
        IV3NonfungiblePositionManager.MintParams memory mintParams = IV3NonfungiblePositionManager.MintParams({
            token0: _token0,
            token1: _token1,
            fee: 500,
            tickLower: -100,
            tickUpper: 100,
            amount0Desired: 10 ether,
            amount1Desired: 10 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp + 100
        });

        v3Nfpm.mint(mintParams);
    }

    function _mintV3Liquidity(address _token0, address _token1, uint256 amount0, uint256 amount1) internal {
        int24 tickLower;
        int24 tickUpper;
        if (_token0 < _token1) {
            tickLower = -100;
            tickUpper = 200;
        } else {
            (_token0, _token1) = (_token1, _token0);
            (amount0, amount1) = (amount1, amount0);
            tickLower = -200;
            tickUpper = 100;
        }
        v3Nfpm.createAndInitializePoolIfNecessary(_token0, _token1, 500, INIT_SQRT_PRICE);

        IV3NonfungiblePositionManager.MintParams memory mintParams = IV3NonfungiblePositionManager.MintParams({
            token0: _token0,
            token1: _token1,
            fee: 500,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: amount0 - 0.1 ether,
            amount1Min: amount1 - 0.1 ether,
            recipient: address(this),
            deadline: block.timestamp + 100
        });

        v3Nfpm.mint(mintParams);
    }

    function _mintV2Liquidity(IPancakePair pair) public {
        IERC20(pair.token0()).transfer(address(pair), 10 ether);
        IERC20(pair.token1()).transfer(address(pair), 10 ether);

        pair.mint(address(this));
    }

    function _mintV2Liquidity(IPancakePair pair, uint256 amount0, uint256 amount1) public {
        IERC20(pair.token0()).transfer(address(pair), amount0);
        IERC20(pair.token1()).transfer(address(pair), amount1);

        pair.mint(address(this));
    }

    function _getBytecodePath() internal pure returns (string memory) {
        // Create a Pancakeswap V2 pair
        // relative to the root of the project
        // https://etherscan.io/address/0x1097053Fd2ea711dad45caCcc45EfF7548fCB362#code
        return "./test/bin/pcsV2Factory.bytecode";
    }

    function _getDeployerBytecodePath() internal pure returns (string memory) {
        // https://etherscan.io/address/0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9#code
        return "./test/bin/pcsV3Deployer.bytecode";
    }

    function _getFactoryBytecodePath() internal pure returns (string memory) {
        // https://etherscan.io/address/0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865#code
        return "./test/bin/pcsV3Factory.bytecode";
    }

    function _getNfpmBytecodePath() internal pure returns (string memory) {
        // https://etherscan.io/address/0x46A15B0b27311cedF172AB29E4f4766fbE7F4364#code
        return "./test/bin/pcsV3Nfpm.bytecode";
    }

    receive() external payable {}
}
