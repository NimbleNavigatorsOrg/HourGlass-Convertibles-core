pragma solidity 0.8.13;

import "./StagingLoanRouterSetup.t.sol";

contract RedeemLendSlipsForTranchesAndUnwrap is StagingLoanRouterSetup {
    // function testRedeemLendSlipsForTranchesAndUnwrapBurnsMsgSenderLendSlips(
    //     uint256 _fuzzPrice,
    //     uint256 _lendAmount,
    //     uint256 _timeWarp,
    //     uint256 _lendSlipAmount
    // ) public {
    //     setupStagingBox(_fuzzPrice);
    //     setupTranches(false, s_owner);
    //     (
    //         uint256 borrowRiskSlipBalanceBeforeRepay,
    //     ) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
    //     uint256 lendSlipAmount = redeemLendSlipsForStablesTestSetup(
    //         _timeWarp,
    //         borrowRiskSlipBalanceBeforeRepay,
    //         _lendSlipAmount,
    //         false
    //     );
    //     vm.warp(s_deployedConvertibleBondBox.maturityDate() + 1);
    //     (s_deployedConvertibleBondBox.bond()).mature();
    //     uint256 lenderLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip())
    //         .balanceOf(address(s_lender));
    //     uint256 routerLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip())
    //         .balanceOf(address(s_stagingLoanRouter));
    //     uint256 sbLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip())
    //         .balanceOf(address(s_deployedSB));
    //     vm.prank(s_lender);
    //     StagingLoanRouter(s_stagingLoanRouter)
    //         .redeemLendSlipsForTranchesAndUnwrap(s_deployedSB, lendSlipAmount);
    //     uint256 lenderLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip())
    //         .balanceOf(address(s_lender));
    //     uint256 routerLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip())
    //         .balanceOf(address(s_stagingLoanRouter));
    //     uint256 sbLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip())
    //         .balanceOf(address(s_deployedSB));
    //     assertEq(
    //         lenderLendSlipBalanceBefore - lendSlipAmount,
    //         lenderLendSlipBalanceAfter
    //     );
    //     assertEq(routerLendSlipBalanceBefore, routerLendSlipBalanceAfter);
    //     assertEq(sbLendSlipBalanceBefore, sbLendSlipBalanceAfter);
    //     assertFalse(lendSlipAmount == 0);
    // }
    // function testRedeemLendSlipsForTranchesBurnsSafeSlipsFromStagingBox(
    //     uint256 _fuzzPrice,
    //     uint256 _lendAmount,
    //     uint256 _timeWarp,
    //     uint256 _lendSlipAmount
    // ) public {
    //     setupStagingBox(_fuzzPrice);
    //     setupTranches(false, s_owner);
    //     (
    //         uint256 borrowRiskSlipBalanceBeforeRepay,
    //     ) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
    //     uint256 lendSlipAmount = redeemLendSlipsForStablesTestSetup(
    //         _timeWarp,
    //         borrowRiskSlipBalanceBeforeRepay,
    //         _lendSlipAmount,
    //         false
    //     );
    //     vm.warp(s_deployedConvertibleBondBox.maturityDate() + 1);
    //     (s_deployedConvertibleBondBox.bond()).mature();
    //     (, uint256 buttonAmount) = StagingBoxLens(s_stagingBoxLens)
    //         .viewRedeemLendSlipsForTranches(s_deployedSB, lendSlipAmount);
    //     uint256 sbSafeSlipBalanceBefore = ISlip(s_deployedSB.safeSlipAddress())
    //         .balanceOf(address(s_deployedSB));
    //     uint256 routerSafeSlipBalanceBefore = ISlip(
    //         s_deployedSB.safeSlipAddress()
    //     ).balanceOf(address(s_stagingLoanRouter));
    //     uint256 cbbSafeSlipBalanceBefore = ISlip(s_deployedSB.safeSlipAddress())
    //         .balanceOf(address(s_deployedConvertibleBondBox));
    //     vm.prank(s_lender);
    //     StagingLoanRouter(s_stagingLoanRouter)
    //         .redeemLendSlipsForTranchesAndUnwrap(s_deployedSB, lendSlipAmount);
    //     uint256 sbSafeSlipBalanceAfter = ISlip(s_deployedSB.safeSlipAddress())
    //         .balanceOf(address(s_deployedSB));
    //     uint256 routerSafeSlipBalanceAfter = ISlip(
    //         s_deployedSB.safeSlipAddress()
    //     ).balanceOf(address(s_stagingLoanRouter));
    //     uint256 cbbSafeSlipBalanceAfter = ISlip(s_deployedSB.safeSlipAddress())
    //         .balanceOf(address(s_deployedConvertibleBondBox));
    //     assertEq(
    //         sbSafeSlipBalanceBefore - buttonAmount,
    //         sbSafeSlipBalanceAfter
    //     );
    //     assertEq(routerSafeSlipBalanceBefore, routerSafeSlipBalanceAfter);
    //     assertEq(cbbSafeSlipBalanceBefore, cbbSafeSlipBalanceAfter);
    //     assertFalse(lendSlipAmount == 0);
    //     assertFalse(buttonAmount == 0);
    // }
    // function testRedeemLendSlipsForTranchesReturnsUnderlyingToMsgSender(
    //     uint256 _fuzzPrice,
    //     uint256 _lendAmount,
    //     uint256 _timeWarp,
    //     uint256 _lendSlipAmount
    // ) public {
    //     setupStagingBox(_fuzzPrice);
    //     setupTranches(false, s_owner);
    //     (
    //         uint256 borrowRiskSlipBalanceBeforeRepay,
    //     ) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
    //     uint256 lendSlipAmount = redeemLendSlipsForStablesTestSetup(
    //         _timeWarp,
    //         borrowRiskSlipBalanceBeforeRepay,
    //         _lendSlipAmount,
    //         false
    //     );
    //     vm.warp(s_deployedConvertibleBondBox.maturityDate() + 1);
    //     s_deployedConvertibleBondBox.bond().mature();
    //     uint256 lenderUnderlyingBalanceBefore = IERC20(
    //         IButtonToken(s_deployedConvertibleBondBox.bond().collateralToken())
    //             .underlying()
    //     ).balanceOf(s_lender);
    //     (uint256 underlyingAmount, ) = StagingBoxLens(s_stagingBoxLens)
    //         .viewRedeemLendSlipsForTranches(s_deployedSB, lendSlipAmount);
    //     vm.prank(s_lender);
    //     StagingLoanRouter(s_stagingLoanRouter)
    //         .redeemLendSlipsForTranchesAndUnwrap(s_deployedSB, lendSlipAmount);
    //     uint256 lenderUnderlyingBalanceAfter = IERC20(
    //         IButtonToken(
    //             (s_deployedConvertibleBondBox.bond()).collateralToken()
    //         ).underlying()
    //     ).balanceOf(s_lender);
    //     assertEq(
    //         lenderUnderlyingBalanceBefore + underlyingAmount,
    //         lenderUnderlyingBalanceAfter
    //     );
    //     assertFalse(underlyingAmount == 0);
    // }
}
