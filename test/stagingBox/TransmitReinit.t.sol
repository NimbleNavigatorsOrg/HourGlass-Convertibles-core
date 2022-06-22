pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";

contract TransmitReinit is SBSetup {

    function testTransmitReInitIsLendTrueSetsHasReinitializedToTrueAndSetsReInitLendAmount(uint256 price) public {
        bool _isLend = true;
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_cbb_owner
        ));

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.cbbTransferOwnership(address(s_deployedSB));

        // Isn't this being called with address(this) now??? 
        // Shouldn't it be called with address(s_cbb_owner)??? 
        // Address(this) and address(s_cbb_owner) are the same thing???
        // This is bad. We should have them be two seperate address maybe or rename the variable for readability.
        uint256 stableAmount = s_deployedSB.stableToken().balanceOf(address(s_deployedSB));

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.reinitialize.selector),
            abi.encode(true)
        );

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.cbbTransferOwnership.selector),
            abi.encode(true)
        );

        vm.startPrank(s_cbb_owner);
        s_deployedSB.transmitReInit(_isLend);
        vm.stopPrank();

        assertEq(true, s_deployedSB.s_hasReinitialized());
        assertEq(stableAmount, s_deployedSB.s_reinitLendAmount());
    }

    function testTransmitReInitIsLendFalseSetsHasReinitializedToTrueAndSetsReInitLendAmount(uint256 price) public {
        bool _isLend = false;
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_cbb_owner
        ));

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.cbbTransferOwnership(address(s_deployedSB));

        // Isn't this being called with address(this) now??? 
        // Shouldn't it be called with address(s_cbb_owner)??? 
        // Address(this) and address(s_cbb_owner) are the same thing???
        // This is bad. We should have them be two seperate address maybe or rename the variable for readability.
        uint256 safeTrancheBalance = s_deployedSB.safeTranche().balanceOf(address(this));

        uint256 expectedReinitLendAmount = (safeTrancheBalance * s_deployedSB.initialPrice()) / s_deployedSB.priceGranularity();

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.reinitialize.selector),
            abi.encode(true)
        );

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.cbbTransferOwnership.selector),
            abi.encode(true)
        );

        vm.startPrank(s_cbb_owner);
        s_deployedSB.transmitReInit(_isLend);
        vm.stopPrank();

        assertEq(true, s_deployedSB.s_hasReinitialized());
        assertEq(expectedReinitLendAmount, s_deployedSB.s_reinitLendAmount());
    }
}