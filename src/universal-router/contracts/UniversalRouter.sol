// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

// Command implementations
import {Dispatcher} from "./base/Dispatcher.sol";
import {RewardsCollector} from "./base/RewardsCollector.sol";
import {RouterParameters, RouterImmutables} from "./base/RouterImmutables.sol";
import {Commands} from "./libraries/Commands.sol";
import {Constants} from "./libraries/Constants.sol";
import {IUniversalRouter} from "./interfaces/IUniversalRouter.sol";
import {StableSwapRouter} from "./modules/pancakeswap/StableSwapRouter.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {SwapRouterBase} from "../../SwapRouterBase.sol";
import {BinSwapRouterBase} from "../../pool-bin/BinSwapRouterBase.sol";
import {CLSwapRouterBase} from "../../pool-cl/CLSwapRouterBase.sol";
import {IBinPoolManager} from "pancake-v4-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {IVault} from "pancake-v4-core/src/interfaces/IVault.sol";
import {BytesLib} from "./libraries/BytesLib.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract UniversalRouter is RouterImmutables, IUniversalRouter, Dispatcher, RewardsCollector, Pausable {
    using BytesLib for bytes;
    using CurrencyLibrary for Currency;
    using SafeTransferLib for ERC20;

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert TransactionDeadlinePassed();
        _;
    }

    constructor(RouterParameters memory params)
        RouterImmutables(params)
        StableSwapRouter(params.stableFactory, params.stableInfo)
        BinSwapRouterBase(IBinPoolManager(params.binPoolManager))
        CLSwapRouterBase(ICLPoolManager(params.clPoolManager))
        SwapRouterBase(IVault(params.vault))
    {}

    /// @inheritdoc IUniversalRouter
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline, bool vaultLock)
        external
        payable
        checkDeadline(deadline)
    {
        if (vaultLock) vault.lock(abi.encode(commands, inputs));
        else execute(commands, inputs);
    }

    /// @inheritdoc Dispatcher
    function execute(bytes calldata commands, bytes[] calldata inputs)
        public
        payable
        override
        isNotLocked
        whenNotPaused
    {
        bool success;
        bytes memory output;
        uint256 numCommands = commands.length;
        if (inputs.length != numCommands) revert LengthMismatch();

        // loop through all given commands, execute them and pass along outputs as defined
        for (uint256 commandIndex = 0; commandIndex < numCommands;) {
            bytes1 command = commands[commandIndex];

            bytes calldata input = inputs[commandIndex];

            (success, output) = dispatch(command, input);

            if (!success && successRequired(command)) {
                revert ExecutionFailed({commandIndex: commandIndex, message: output});
            }

            unchecked {
                commandIndex++;
            }
        }

        uint256 balance = address(this).balance;
        if ((balance > 0) && (msg.sender != address(this))) sweep(Constants.ETH, msg.sender, balance);
    }

    function lockAcquired(bytes calldata vaultLockData) external {
        bytes calldata commands = vaultLockData.toBytes(0);
        bytes[] calldata inputs = vaultLockData.toBytesArray(1);
        execute(commands, inputs);
    }

    function successRequired(bytes1 command) internal pure returns (bool) {
        return command & Commands.FLAG_ALLOW_REVERT == 0;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    /// @notice To receive ETH from WETH and NFT protocols
    receive() external payable {}

    function _pay(Currency currency, address payer, address recipient, uint256 amount) internal virtual override {
        if (payer == address(this) || currency.isNative()) {
            // currency is native, assume contract owns the ETH currently
            currency.transfer(recipient, amount);
        } else {
            // pull payment
            ERC20(Currency.unwrap(currency)).safeTransferFrom(payer, recipient, amount);
        }
    }
}
