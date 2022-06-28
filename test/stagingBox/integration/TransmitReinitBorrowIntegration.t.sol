pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../../src/contracts/StagingBox.sol";
import "../../../src/contracts/StagingBoxFactory.sol";
import "../../../src/contracts/CBBFactory.sol";
import "../../../src/contracts/ConvertibleBondBox.sol";
import "./SBIntegrationSetup.t.sol";

contract TransmitReinitBorrowIntegration is SBIntegrationSetup {

    function testTransmitReInitIntegrationBorrow(uint256 fuzzPrice) public {
        setupStagingBox(fuzzPrice);
        setupTranches(false, address(s_deployedSB));

        uint256 safeTrancheBalance = s_deployedSB.safeTranche().balanceOf(address(s_deployedSB));
        uint256 expectedReinitLendAmount = (safeTrancheBalance * s_deployedSB.initialPrice()) / s_deployedSB.priceGranularity();

        vm.startPrank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);
        vm.stopPrank();

        assertEq(true, s_deployedSB.s_hasReinitialized());
        assertEq(expectedReinitLendAmount, s_deployedSB.s_reinitLendAmount());
        assertEq(s_cbb_owner, s_deployedSB.owner());
    }

    function testTransmitReinitIntegrationBorrowEmitsBorrow(uint256 fuzzPrice) public {
        setupStagingBox(fuzzPrice);
        setupTranches(false, address(s_deployedSB));

        uint256 sbSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(s_deployedSB));

        uint256 sbStableBalanceBefore = s_stableToken.balanceOf(address(s_deployedSB));

        uint256 sbRiskSlipBalanceBefore = ISlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(address(s_deployedSB));

        vm.prank(s_cbb_owner);
        vm.expectEmit(true, true, true, true);
        emit Borrow(
            address(s_deployedSB), 
            address(s_deployedSB), 
            address(s_deployedSB),
            sbSafeTrancheBalanceBefore,
            s_price
        );
        s_deployedSB.transmitReInit(s_isLend);

        uint256 sbStableBalanceAfter = s_stableToken.balanceOf(address(s_deployedSB));
        uint256 sbRiskSlipBalanceAfter = ISlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(address(s_deployedSB));

        uint256 expectedZ = (sbSafeTrancheBalanceBefore * s_ratios[2]) / s_ratios[0];

        assertEq(sbRiskSlipBalanceBefore + expectedZ, sbRiskSlipBalanceAfter);

        assertEq(sbStableBalanceBefore, sbStableBalanceAfter);
    }

    function testTransmitReinitIntegrationBorrowTransfersSafeTrancheFromSBToCBB(uint256 fuzzPrice) public {
        setupStagingBox(fuzzPrice);
        setupTranches(false, address(s_deployedSB));

        uint256 sbSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(s_deployedSB));
        uint256 cbbSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(s_deployedConvertibleBondBox));

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);

        uint256 sbSafeTrancheBalanceAfter = s_safeTranche.balanceOf(address(s_deployedSB));
        uint256 cbbSafeTrancheBalanceAfter = s_safeTranche.balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(0, sbSafeTrancheBalanceAfter);
        assertEq(cbbSafeTrancheBalanceBefore + sbSafeTrancheBalanceBefore, cbbSafeTrancheBalanceAfter);
    }

    function testTransmitReinitIntegrationBorrowTransfersRiskTrancheFromSBToCBB(uint256 fuzzPrice) public {
        setupStagingBox(fuzzPrice);
        setupTranches(false, address(s_deployedSB));

        uint256 sbSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(s_deployedSB));

        uint256 sbRiskTrancheBalanceBefore = s_riskTranche.balanceOf(address(s_deployedSB));
        uint256 cbbRiskTrancheBalanceBefore = s_riskTranche.balanceOf(address(s_deployedConvertibleBondBox));

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);

        uint256 sbRiskTrancheBalanceAfter = s_riskTranche.balanceOf(address(s_deployedSB));
        uint256 cbbRiskTrancheBalanceAfter = s_riskTranche.balanceOf(address(s_deployedConvertibleBondBox));

        uint256 expectedZ = (sbSafeTrancheBalanceBefore * s_ratios[2]) / s_ratios[0];

        assertEq(sbRiskTrancheBalanceBefore - expectedZ, sbRiskTrancheBalanceAfter);
        assertEq(cbbRiskTrancheBalanceBefore + expectedZ, cbbRiskTrancheBalanceAfter);
    }

    function testTransmitReinitIntegrationBorrowMintsSafeSlipsToSB(uint256 fuzzPrice) public {
        setupStagingBox(fuzzPrice);
        setupTranches(false, address(s_deployedSB));

        uint256 sbSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(s_deployedSB));
        uint256 sbSafeSlipBalanceBefore = ISlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(s_deployedSB));

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);

        uint256 sbSafeSlipBalanceAfter = ISlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(s_deployedSB));

        assertEq(sbSafeSlipBalanceBefore + sbSafeTrancheBalanceBefore, sbSafeSlipBalanceAfter);
    }

    function testTransmitReinitIntegrationBorrowMintsRiskSlipsToSB(uint256 fuzzPrice) public {
        setupStagingBox(fuzzPrice);
        setupTranches(false, address(s_deployedSB));

        uint256 sbSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(s_deployedSB));
        uint256 sbRiskSlipBalanceBefore = ISlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(address(s_deployedSB));

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);

        uint256 sbRiskSlipBalanceAfter = ISlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(address(s_deployedSB));
        uint256 expectedZ = (sbSafeTrancheBalanceBefore * s_ratios[2]) / s_ratios[0];

        assertEq(sbRiskSlipBalanceBefore + expectedZ, sbRiskSlipBalanceAfter);
    }

    function testTransmitReinitIntegrationBorrowDoesNotChangeSBStableBalance(uint256 fuzzPrice) public {
        setupStagingBox(fuzzPrice);
        setupTranches(false, address(s_deployedSB));
        
        uint256 sbStableBalanceBefore = s_stableToken.balanceOf(address(s_deployedSB));

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(s_isLend);

        uint256 sbStableBalanceAfter = s_stableToken.balanceOf(address(s_deployedSB));

        assertEq(sbStableBalanceBefore, sbStableBalanceAfter);
    }
}