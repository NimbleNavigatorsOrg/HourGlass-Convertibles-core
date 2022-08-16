// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract SetFee is CBBSetup {
    function testSetFee(uint256 newFee) public {
        newFee = bound(newFee, 0, s_maxFeeBPS);
        vm.prank(s_cbb_owner);
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
        newFee = bound(newFee, 0, s_BPS);

        vm.startPrank(s_cbb_owner);
        vm.warp(s_maturityDate);
        bytes memory customError = abi.encodeWithSignature(
            "BondIsMature(uint256,uint256)",
            block.timestamp,
            s_maturityDate
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.setFee(newFee);
        vm.stopPrank();
    }

    function testCannotSetFeeFeeTooLarge(uint256 newFee) public {
        newFee = bound(newFee, s_BPS, type(uint256).max);
        vm.prank(s_cbb_owner);
        bytes memory customError = abi.encodeWithSignature(
            "FeeTooLarge(uint256,uint256)",
            newFee,
            s_maxFeeBPS
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.setFee(newFee);
        vm.stopPrank();
    }
}
