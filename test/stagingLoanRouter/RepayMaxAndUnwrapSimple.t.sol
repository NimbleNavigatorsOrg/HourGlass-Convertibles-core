pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RepayMaxAndUnwrapSimple is RedeemLendSlipsForStablesTestSetup {

    function testRepayMaxAndUnwrapSimpleTransfersStablesFromMsgSender(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (uint256 borrowRiskSlipBalanceBeforeRepay, uint256 lendAmount) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        borrowRiskSlipBalanceBeforeRepay = bound(borrowRiskSlipBalanceBeforeRepay, s_deployedConvertibleBondBox.riskRatio(), borrowRiskSlipBalanceBeforeRepay);
        (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, borrowRiskSlipBalanceBeforeRepay);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceBefore = s_stableToken.balanceOf(address(s_stagingLoanRouter));

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            borrowRiskSlipBalanceBeforeRepay
            );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceAfter = s_stableToken.balanceOf(address(s_stagingLoanRouter));

        assertEq(borrowerStableBalanceBefore - stablesOwed, borrowerStableBalanceAfter);
        assertEq(stagingLoanRouterStableBalanceBefore, stagingLoanRouterStableBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);
    }

    function testRepayMaxAndUnwrapSimpleTransfersRiskSlipsToRouter(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (uint256 borrowRiskSlipBalanceBeforeRepay, uint256 lendAmount) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, borrowRiskSlipBalanceBeforeRepay);

        vm.assume(stablesOwed > 0);

        uint256 borrowerRiskSlipBalanceBefore = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);
        uint256 routerRiskSlipBalanceBefore = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(address(s_stagingLoanRouter));

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            borrowRiskSlipBalanceBeforeRepay
            );

        uint256 borrowerRiskSlipBalanceAfter = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);
        uint256 routerRiskSlipBalanceAfter = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(address(s_stagingLoanRouter));

        assertEq(borrowerRiskSlipBalanceBefore - borrowRiskSlipBalanceBeforeRepay, borrowerRiskSlipBalanceAfter);
        assertEq(routerRiskSlipBalanceBefore, routerRiskSlipBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);
    }

    function testRepayMaxAndUnwrapSimpleSendsUnderlyingToMsgSender(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (uint256 borrowRiskSlipBalanceBeforeRepay, uint256 lendAmount) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, borrowRiskSlipBalanceBeforeRepay);

        vm.assume(stablesOwed > 0);

        address bond = address(s_deployedConvertibleBondBox.bond());

        uint256 borrowerUnderlyingBalanceBefore = s_underlying.balanceOf(s_borrower);
        uint256 bondCollateralBalanceBefore = s_collateralToken.balanceOf(bond);

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            borrowRiskSlipBalanceBeforeRepay
            );

        uint256 borrowerUnderlyingBalanceAfter = s_underlying.balanceOf(s_borrower);
        uint256 bondCollateralBalanceAfter = s_collateralToken.balanceOf(bond);

        assertTrue(borrowerUnderlyingBalanceBefore + underlyingAmount <= borrowerUnderlyingBalanceAfter);

        assertTrue(withinTolerance(borrowerUnderlyingBalanceBefore + underlyingAmount, borrowerUnderlyingBalanceAfter, 200000));
        assertFalse(stablesOwed == 0);
        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);
    }

    function testRepayMaxAndUnwrapSimpleTransfersExtraStablesBackToMsgSender(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (uint256 borrowRiskSlipBalanceBeforeRepay, uint256 lendAmount) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, borrowRiskSlipBalanceBeforeRepay);

        uint256 extraStables = 15500;

        vm.assume(stablesOwed > 0);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceBefore = s_stableToken.balanceOf(address(s_stagingLoanRouter));

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed + extraStables,
            borrowRiskSlipBalanceBeforeRepay
            );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceAfter = s_stableToken.balanceOf(address(s_stagingLoanRouter));

        assertEq(borrowerStableBalanceBefore - stablesOwed, borrowerStableBalanceAfter);
        assertEq(stagingLoanRouterStableBalanceBefore, stagingLoanRouterStableBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);
    }
}