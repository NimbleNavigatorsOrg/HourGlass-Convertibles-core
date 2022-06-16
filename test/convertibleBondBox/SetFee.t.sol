// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../src/contracts/CBBSlip.sol";
import "../../src/contracts/CBBSlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
import "./CBBSetup.sol";

contract SetFee is CBBSetup {

    function testSetFee(uint256 newFee) public {
        console2.log(s_ratios[0], "s_ratios");
        console.log(newFee, "newFee");
        newFee = bound(newFee, 0, s_maxFeeBPS);
        console.log(s_deployedConvertibleBondBox.owner(), "s_deployedConvertibleBondBox.owner()");
        vm.prank(s_deployedConvertibleBondBox.owner());
        vm.expectEmit(true, true, true, true);
        emit FeeUpdate(newFee);
        s_deployedConvertibleBondBox.setFee(newFee);
        assertEq(s_deployedConvertibleBondBox.feeBps(), newFee);
    }

    function testFailSetFeeCalledByNonOwner(uint256 newFee) public {
        newFee = bound(newFee, 0, s_BPS);
        vm.prank(address(1));
        s_deployedConvertibleBondBox.setFee(newFee);
    }

    function testCannotSetFeeBondIsMature(uint256 newFee) public {
        s_buttonWoodBondController.mature();
        newFee = bound(newFee, 0, s_BPS);
        vm.prank(s_deployedConvertibleBondBox.owner());
        bytes memory customError = abi.encodeWithSignature(
            "BondIsMature(bool,bool)",
            true,
            false
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.setFee(newFee);
    }

    function testCannotSetFeeFeeTooLarge(uint256 newFee) public {
        newFee = bound(newFee, s_BPS, type(uint256).max);
        vm.prank(s_deployedConvertibleBondBox.owner());
        bytes memory customError = abi.encodeWithSignature(
            "FeeTooLarge(uint256,uint256)",
            newFee,
            s_maxFeeBPS
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.setFee(newFee);
    }
}