pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";

contract TransmitReinit is SBSetup {

    function testTransmitReInitIsLendTrue(uint256 price) public {
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
        assertEq(s_cbb_owner, s_deployedSB.owner());
    }

    function testTransmitReInitIsLendFalse(uint256 price) public {
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

        uint256 safeTrancheBalance = s_deployedSB.safeTranche().balanceOf(address(s_deployedSB));
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
        assertEq(s_cbb_owner, s_deployedSB.owner());
    }
}