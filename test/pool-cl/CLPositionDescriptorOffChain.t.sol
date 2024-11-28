// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {CLPositionDescriptorOffChain} from "../../src/pool-cl/CLPositionDescriptorOffChain.sol";
import {ICLPositionManager} from "../../src/pool-cl/interfaces/ICLPositionManager.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICLPositionDescriptor} from "../../src/pool-cl/interfaces/ICLPositionDescriptor.sol";

contract FakeTokenURIContract is ICLPositionDescriptor {
    function tokenURI(ICLPositionManager positionManager, uint256 tokenId)
        external
        pure
        override
        returns (string memory)
    {
        return string.concat(Strings.toString(uint160(address(positionManager))), "/", Strings.toString(tokenId));
    }
}

contract CLPositionDescriptorOffChainTest is Test, GasSnapshot {
    CLPositionDescriptorOffChain clPositionDescriptorOffChain;

    error ContractSizeTooLarge(uint256 diff);

    function setUp() public {
        clPositionDescriptorOffChain =
            new CLPositionDescriptorOffChain("https://pancakeswap.finance/v4/pool-cl/positions/");
    }

    function test_bytecodeSize() public {
        snapSize("CLPositionDescriptorOffChainSize", address(clPositionDescriptorOffChain));

        // forge coverage will run with '--ir-minimum' which set optimizer run to min
        // thus we do not want to revert for forge coverage case
        if (vm.envExists("FOUNDRY_PROFILE") && address(clPositionDescriptorOffChain).code.length > 24576) {
            revert ContractSizeTooLarge(address(clPositionDescriptorOffChain).code.length - 24576);
        }
    }

    function testTokenURI() public view {
        // tokenId=1
        string memory tokenURI = clPositionDescriptorOffChain.tokenURI(ICLPositionManager(address(0)), 1);
        assertEq(tokenURI, "https://pancakeswap.finance/v4/pool-cl/positions/1");

        // tokenId=uint.max
        tokenURI = clPositionDescriptorOffChain.tokenURI(ICLPositionManager(address(0)), type(uint256).max);
        assertEq(
            tokenURI,
            "https://pancakeswap.finance/v4/pool-cl/positions/115792089237316195423570985008687907853269984665640564039457584007913129639935"
        );

        // positionManager is not used
        tokenURI = clPositionDescriptorOffChain.tokenURI(ICLPositionManager(address(0x01)), 1);
        assertEq(tokenURI, "https://pancakeswap.finance/v4/pool-cl/positions/1");
    }

    function testTokenURI_generateByTokenURIContract() public {
        clPositionDescriptorOffChain.setTokenURIContract(new FakeTokenURIContract());

        // tokenId=1
        string memory tokenURI = clPositionDescriptorOffChain.tokenURI(ICLPositionManager(address(0x1234)), 1);
        assertEq(tokenURI, "4660/1");
    }

    function testTokenURIFuzz(uint256 tokenId) public view {
        string memory tokenURI = clPositionDescriptorOffChain.tokenURI(ICLPositionManager(address(0)), tokenId);
        assertEq(
            tokenURI, string.concat("https://pancakeswap.finance/v4/pool-cl/positions/", Strings.toString(tokenId))
        );
    }

    function testSetBaseTokenURI() public {
        clPositionDescriptorOffChain.setBaseTokenURI("https://pancakeswap.finance/swap/v4/pool-cl/positions/");
        string memory tokenURI = clPositionDescriptorOffChain.tokenURI(ICLPositionManager(address(0)), 1);
        assertEq(tokenURI, "https://pancakeswap.finance/swap/v4/pool-cl/positions/1");

        clPositionDescriptorOffChain.setBaseTokenURI("https://pancakeswap.finance/");
        tokenURI = clPositionDescriptorOffChain.tokenURI(ICLPositionManager(address(0)), 2);
        assertEq(tokenURI, "https://pancakeswap.finance/2");

        clPositionDescriptorOffChain.setBaseTokenURI("");
        tokenURI = clPositionDescriptorOffChain.tokenURI(ICLPositionManager(address(0)), 3);
        assertEq(tokenURI, "");
    }

    function testSetBaseTokenURI_NotOwner(address msgSender) public {
        vm.assume(msgSender != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, msgSender));
        vm.prank(msgSender);
        clPositionDescriptorOffChain.setBaseTokenURI("whatever");
    }

    function testSetTokenURIContract_NotOwner(address msgSender) public {
        vm.assume(msgSender != address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, msgSender));
        vm.prank(msgSender);
        clPositionDescriptorOffChain.setTokenURIContract(ICLPositionDescriptor(address(0x01)));
    }
}
