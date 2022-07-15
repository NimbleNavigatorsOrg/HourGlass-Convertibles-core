pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RedeemLendSlipsForStables is RedeemLendSlipsForStablesTestSetup {

    function testRedeemLendSlipsForStablesTransfersUnderlyingFromMsgSender(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (uint256 borrowRiskSlipBalanceBeforeRepay, uint256 lendAmount) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, borrowRiskSlipBalanceBeforeRepay);

        vm.assume(stablesOwed > 0);

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            borrowRiskSlipBalanceBeforeRepay
            );

        assertFalse(stablesOwed == 0);
        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);

        vm.warp(s_maturityDate);

        uint256 lendSlipBalance = ISlip(s_deployedSB.lendSlip()).balanceOf(s_lender);

        vm.startPrank(s_lender);
        ISlip(s_deployedSB.lendSlip()).approve(address(s_stagingLoanRouter), type(uint256).max);
        vm.stopPrank();

        uint256 stableAmount = s_stagingBoxLens.viewRedeemLendSlipsForStables(s_deployedSB, lendSlipBalance);

        uint256 lenderStableBalanceBefore = s_stableToken.balanceOf(s_lender);
        uint256 lenderLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip()).balanceOf(s_lender);

        uint256 cbbStableBalance = s_stableToken.balanceOf(address(s_deployedConvertibleBondBox));

        if(cbbStableBalance >= stableAmount) {
            vm.prank(s_lender);
            StagingLoanRouter(s_stagingLoanRouter).redeemLendSlipsForStables(s_deployedSB, lendSlipBalance);
        } else {
            uint256 maxRedeemableLendSlips = squareRootOf(cbbStableBalance * s_deployedConvertibleBondBox.s_repaidSafeSlips());
            vm.startPrank(s_lender);
            s_stagingLoanRouter.redeemLendSlipsForStables(s_deployedSB, s_deployedConvertibleBondBox.s_repaidSafeSlips());
            vm.stopPrank();
        }

        uint256 lenderStableBalanceAfter = s_stableToken.balanceOf(s_lender);
        uint256 lenderLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip()).balanceOf(s_lender);
    }
}