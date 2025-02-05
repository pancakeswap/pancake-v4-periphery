// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ICLPoolManager} from "infinity-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {BaseCLTestHook} from "infinity-core/test/pool-cl/helpers/BaseCLTestHook.sol";
import {CLPositionManager} from "../../../src/pool-cl/CLPositionManager.sol";

contract MockCLReenterHook is BaseCLTestHook {
    CLPositionManager posm;

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        Permissions memory permissions;
        permissions.beforeAddLiquidity = true;
        return _hooksRegistrationBitmapFrom(permissions);
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata,
        ICLPoolManager.ModifyLiquidityParams calldata,
        bytes calldata functionSelector
    ) external override returns (bytes4) {
        if (functionSelector.length == 0) {
            return this.beforeAddLiquidity.selector;
        }
        (bytes4 selector, address owner, uint256 tokenId) = abi.decode(functionSelector, (bytes4, address, uint256));

        if (selector == posm.transferFrom.selector) {
            posm.transferFrom(owner, address(this), tokenId);
        } else if (selector == posm.subscribe.selector) {
            posm.subscribe(tokenId, address(this), "");
        } else if (selector == posm.unsubscribe.selector) {
            posm.unsubscribe(tokenId);
        }
        return this.beforeAddLiquidity.selector;
    }

    function setPosm(CLPositionManager _posm) external {
        posm = _posm;
    }
}
