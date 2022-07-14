pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RepayMaxAndUnwrapSimple is RedeemLendSlipsForStablesTestSetup {

    function testRepayMaxAndUnwrapSimpleTransfersStablesFromMsgSender(uint256 _fuzzPrice, uint256 _swtbAmountRaw, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, address(s_deployedSB), s_deployedCBBAddress);
        uint256 borrowRiskSlipBalanceBeforeRepay = repayMaxAndUnwrapSimpleTestSetup(_swtbAmountRaw, _lendAmount);

        (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, borrowRiskSlipBalanceBeforeRepay);

        vm.assume(stablesOwed > 0);

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

    function testRepayMaxAndUnwrapSimpleTransfersRiskSlipsToRouter(uint256 _fuzzPrice, uint256 _swtbAmountRaw, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, address(s_deployedSB), s_deployedCBBAddress);
        uint256 borrowRiskSlipBalanceBeforeRepay = repayMaxAndUnwrapSimpleTestSetup(_swtbAmountRaw, _lendAmount);

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

        console.log(routerRiskSlipBalanceBefore, "routerRiskSlipBalanceBefore");
        console.log(routerRiskSlipBalanceAfter, "routerRiskSlipBalanceAfter");
        console.log(borrowRiskSlipBalanceBeforeRepay, "borrowRiskSlipBalanceBeforeRepay");


        assertEq(borrowerRiskSlipBalanceBefore - borrowRiskSlipBalanceBeforeRepay, borrowerRiskSlipBalanceAfter);
        assertEq(routerRiskSlipBalanceBefore, routerRiskSlipBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);
    }

    function testRepayMaxAndUnwrapSimpleSendsUnderlyingToMsgSender(uint256 _fuzzPrice, uint256 _swtbAmountRaw, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, address(s_deployedSB), s_deployedCBBAddress);
        uint256 borrowRiskSlipBalanceBeforeRepay = repayMaxAndUnwrapSimpleTestSetup(_swtbAmountRaw, _lendAmount);

        (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, borrowRiskSlipBalanceBeforeRepay);

        vm.assume(stablesOwed > 0);

        address bond = address(s_deployedConvertibleBondBox.bond());

        uint256 borrowerUnderlyingBalanceBefore = s_underlying.balanceOf(s_borrower);
        uint256 bondCollateralBalanceBefore = s_collateralToken.balanceOf(bond);

        // multiply stablesOwed by number above one and warp time for final stable test

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            borrowRiskSlipBalanceBeforeRepay
            );

        uint256 borrowerUnderlyingBalanceAfter = s_underlying.balanceOf(s_borrower);
        uint256 bondCollateralBalanceAfter = s_collateralToken.balanceOf(bond);

                console.log(underlyingAmount, "underlyingAmount");
                console.log(bondCollateralBalanceBefore + underlyingAmount, "bondCollateralBalanceBefore");
                console.log(bondCollateralBalanceAfter, "bondCollateralBalanceAfter");

                console.log(borrowerUnderlyingBalanceBefore, "borrowerUnderlyingBalanceBefore");

                console.log(borrowerUnderlyingBalanceBefore +underlyingAmount, "borrowerUnderlyingBalance + underlying ");

                console.log(borrowerUnderlyingBalanceAfter, "borrowerUnderlyingBalanceAfter");


        assertEq(borrowerUnderlyingBalanceBefore + underlyingAmount, borrowerUnderlyingBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);
    }

    function testRepayMaxAndUnwrapSimpleTransfersExtraStablesBackToMsgSender(uint256 _fuzzPrice, uint256 _swtbAmountRaw, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, address(s_deployedSB), s_deployedCBBAddress);
        uint256 borrowRiskSlipBalanceBeforeRepay = repayMaxAndUnwrapSimpleTestSetup(_swtbAmountRaw, _lendAmount);

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