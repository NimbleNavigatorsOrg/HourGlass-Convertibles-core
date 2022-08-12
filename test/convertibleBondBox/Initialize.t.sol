// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract Initialize is CBBSetup {
    function testCannotInitializePenaltyTooHigh(uint256 penalty) public {
        vm.assume(penalty > s_penaltyGranularity);
        bytes memory customError = abi.encodeWithSignature(
            "PenaltyTooHigh(uint256,uint256)",
            penalty,
            s_penaltyGranularity
        );
        vm.expectRevert(customError);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            penalty,
            address(s_stableToken),
            s_trancheIndex,
            address(this)
        );

        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);
    }

    function testCannotInitializeBondIsMature() public {
        vm.startPrank(s_cbb_owner);
        vm.warp(s_maturityDate + 1);
        bytes memory customError = abi.encodeWithSignature(
            "BondIsMature(uint256,uint256)",
            block.timestamp,
            s_maturityDate
        );
        vm.expectRevert(customError);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_stableToken),
            s_trancheIndex,
            address(this)
        );
        vm.stopPrank();
    }

    function testCannotInitializeTrancheIndexOutOfBounds() public {
        bytes memory customError = abi.encodeWithSignature(
            "TrancheIndexOutOfBounds(uint256,uint256)",
            s_buttonWoodBondController.trancheCount() - 1,
            s_buttonWoodBondController.trancheCount() - 2
        );
        vm.expectRevert(customError);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_stableToken),
            2,
            address(this)
        );
    }
}
