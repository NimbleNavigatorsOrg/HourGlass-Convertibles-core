pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RepayAndUnwrapMature is RedeemLendSlipsForStablesTestSetup {

    function testRepayAndUnwrapMatureTransfersStablesFromMsgSenderToCBB(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 borrowerRiskSlipBalanceBefore = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);

        uint256 stableRepayAmount = bound(borrowerStableBalanceBefore, 1, (ISlip(s_deployedSB.safeSlipAddress()).totalSupply() * s_deployedConvertibleBondBox.currentPrice()) / s_deployedConvertibleBondBox.s_priceGranularity());

        vm.warp(s_maturityDate + 1);
        s_deployedConvertibleBondBox.bond().mature();

        (, uint256 stablesOwed,, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayAndUnwrapMature(s_deployedSB, stableRepayAmount);

        vm.assume(stablesOwed >= (s_deployedConvertibleBondBox.safeRatio() * s_deployedConvertibleBondBox.currentPrice()) / s_deployedConvertibleBondBox.s_priceGranularity());

        uint256 stagingLoanRouterStableBalanceBefore = s_stableToken.balanceOf(address(s_stagingLoanRouter));
        uint256 cbbStableBalanceBefore = s_stableToken.balanceOf(address(s_deployedConvertibleBondBox));

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayAndUnwrapMature(
            s_deployedSB, 
            stablesOwed,
            riskTranchePayout
            );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceAfter = s_stableToken.balanceOf(address(s_stagingLoanRouter));
        uint256 cbbStableBalanceAfter = s_stableToken.balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(borrowerStableBalanceBefore - stablesOwed, borrowerStableBalanceAfter);
        assertEq(stagingLoanRouterStableBalanceBefore, stagingLoanRouterStableBalanceAfter);
        assertEq(cbbStableBalanceBefore + stablesOwed, cbbStableBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowerRiskSlipBalanceBefore == 0);
    }

    function testRepayAndUnwrapMatureBurnsMsgSenderRiskSlips(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 borrowerRiskSlipBalanceBefore = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);

        uint256 stableRepayAmount = bound(borrowerStableBalanceBefore, 1, (ISlip(s_deployedSB.safeSlipAddress()).totalSupply() * s_deployedConvertibleBondBox.currentPrice()) / s_deployedConvertibleBondBox.s_priceGranularity());

        vm.warp(s_maturityDate + 1);
        s_deployedConvertibleBondBox.bond().mature();

        (, uint256 stablesOwed,, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayAndUnwrapMature(s_deployedSB, stableRepayAmount);

        vm.assume(stablesOwed >= (s_deployedConvertibleBondBox.safeRatio() * s_deployedConvertibleBondBox.currentPrice()) / s_deployedConvertibleBondBox.s_priceGranularity());

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayAndUnwrapMature(
            s_deployedSB, 
            stablesOwed,
            riskTranchePayout
            );

        uint256 borrowerRiskSlipBalanceAfter = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);

        assertEq(borrowerRiskSlipBalanceBefore - riskTranchePayout, borrowerRiskSlipBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowerRiskSlipBalanceBefore == 0);
    }

    function testRepayAndUnwrapMatureSendsUnderlyingToMsgSender(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 borrowerRiskSlipBalanceBefore = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);

        uint256 stableRepayAmount = bound(borrowerStableBalanceBefore, 1, (ISlip(s_deployedSB.safeSlipAddress()).totalSupply() * s_deployedConvertibleBondBox.currentPrice()) / s_deployedConvertibleBondBox.s_priceGranularity());

        vm.warp(s_maturityDate + 1);
        s_deployedConvertibleBondBox.bond().mature();

        (uint256 underlyingAmount, uint256 stablesOwed,, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayAndUnwrapMature(s_deployedSB, stableRepayAmount);

        vm.assume(stablesOwed >= (s_deployedConvertibleBondBox.safeRatio() * s_deployedConvertibleBondBox.currentPrice()) / s_deployedConvertibleBondBox.s_priceGranularity());

        uint256 bondCollateralBalanceBefore = s_collateralToken.balanceOf(address(s_deployedConvertibleBondBox.bond()));
        uint256 borrowerUnderlyingBalanceBefore = s_underlying.balanceOf(s_borrower);

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayAndUnwrapMature(
            s_deployedSB, 
            stablesOwed,
            riskTranchePayout
            );

        uint256 bondCollateralBalanceAfter = s_collateralToken.balanceOf(address(s_deployedConvertibleBondBox.bond()));
        uint256 borrowerUnderlyingBalanceAfter = s_underlying.balanceOf(s_borrower);

        assertEq(bondCollateralBalanceBefore, bondCollateralBalanceAfter);
        assertTrue(withinTolerance(borrowerUnderlyingBalanceBefore + underlyingAmount, borrowerUnderlyingBalanceAfter, 1));

        assertFalse(underlyingAmount == 0);
        assertFalse(stablesOwed == 0);
        assertFalse(borrowerRiskSlipBalanceBefore == 0);
    }
}