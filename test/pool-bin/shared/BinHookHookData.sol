// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IBinPoolManager} from "infinity-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "infinity-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "infinity-core/src/types/BeforeSwapDelta.sol";
import {BaseBinTestHook} from "infinity-core/test/pool-bin/helpers/BaseBinTestHook.sol";

/// @notice This contract is NOT a production use contract.
/// It is meant to verify hook data flown to the hook
contract BinHookHookData is BaseBinTestHook {
    bytes public beforeMintHookData;
    bytes public afterMintHookData;
    bytes public beforeBurnHookData;
    bytes public afterBurnHookData;

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeMint: true,
                afterMint: true,
                beforeBurn: true,
                afterBurn: true,
                beforeSwap: false,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnsDelta: false,
                afterSwapReturnsDelta: false,
                afterMintReturnsDelta: false,
                afterBurnReturnsDelta: false
            })
        );
    }

    function beforeMint(address, PoolKey calldata, IBinPoolManager.MintParams calldata, bytes calldata hookData)
        external
        virtual
        override
        returns (bytes4, uint24)
    {
        beforeMintHookData = hookData;
        return (this.beforeMint.selector, 0);
    }

    function afterMint(
        address, /* sender **/
        PoolKey calldata, /* key **/
        IBinPoolManager.MintParams calldata, /* params **/
        BalanceDelta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        afterMintHookData = hookData;
        return (this.afterMint.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function beforeBurn(address, PoolKey calldata, IBinPoolManager.BurnParams calldata, bytes calldata hookData)
        external
        virtual
        override
        returns (bytes4)
    {
        beforeBurnHookData = hookData;
        return this.beforeBurn.selector;
    }

    function afterBurn(
        address, /* sender **/
        PoolKey calldata, /* key **/
        IBinPoolManager.BurnParams calldata, /* params **/
        BalanceDelta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        afterBurnHookData = hookData;
        return (this.afterBurn.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }
}
