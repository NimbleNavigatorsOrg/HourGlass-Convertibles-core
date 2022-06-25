pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";

import "./integration/SBIntegrationSetup.t.sol";

contract TransmitReinit is SBIntegrationSetup {

    function testTransmitReInitLendSetsStorageVariables(uint256 fuzzPrice) public {
        transmitReinitIntegrationSetup(fuzzPrice, true);

        uint256 stableAmount = s_deployedSB.stableToken().balanceOf(address(s_deployedSB));

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.reinitialize.selector),
            abi.encode(true)
        );

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.lend.selector),
            abi.encode(true)
        );

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.cbbTransferOwnership.selector),
            abi.encode(true)
        );

        vm.startPrank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);
        vm.stopPrank();

        assertEq(true, s_deployedSB.s_hasReinitialized());
        assertEq(stableAmount, s_deployedSB.s_reinitLendAmount());
        assertEq(s_cbb_owner, s_deployedSB.owner());
    }

    function testTransmitReInitBorrowSetsStorageVariables(uint256 fuzzPrice) public {
        transmitReinitIntegrationSetup(fuzzPrice, false);

        uint256 safeTrancheBalance = s_deployedSB.safeTranche().balanceOf(address(s_deployedSB));
        uint256 expectedReinitLendAmount = (safeTrancheBalance * s_deployedSB.initialPrice()) / s_deployedSB.priceGranularity();

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.reinitialize.selector),
            abi.encode(true)
        );

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.borrow.selector),
            abi.encode(true)
        );

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.cbbTransferOwnership.selector),
            abi.encode(true)
        );

        vm.startPrank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);
        vm.stopPrank();

        assertEq(true, s_deployedSB.s_hasReinitialized());
        assertEq(expectedReinitLendAmount, s_deployedSB.s_reinitLendAmount());
        assertEq(s_cbb_owner, s_deployedSB.owner());
    }
}