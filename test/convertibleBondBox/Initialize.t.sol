// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../src/contracts/Slip.sol";
import "../../src/contracts/SlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
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
        s_buttonWoodBondController.mature();
        bytes memory customError = abi.encodeWithSignature(
            "BondIsMature(bool,bool)",
            s_buttonWoodBondController.isMature(),
            false
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
