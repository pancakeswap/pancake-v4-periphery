// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {BaseBinTestHook} from "pancake-v4-core/test/pool-bin/helpers/BaseBinTestHook.sol";
import {IBinPoolManager} from "pancake-v4-core/src/pool-bin/interfaces/IBinPoolManager.sol";

/// @notice store hookData
contract MockBinMigratorHook is BaseBinTestHook {
    bytes public hookData;

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeMint: true,
                afterMint: false,
                beforeBurn: false,
                afterBurn: false,
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

    function beforeMint(address, PoolKey calldata, IBinPoolManager.MintParams calldata, bytes calldata _hookData)
        external
        override
        returns (bytes4, uint24)
    {
        hookData = _hookData;

        return (this.beforeMint.selector, 0);
    }
}
