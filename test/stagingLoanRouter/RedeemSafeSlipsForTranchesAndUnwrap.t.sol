pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RedeemSafeSlipsForTranchesAndUnwrap is RedeemLendSlipsForStablesTestSetup {

    function testRedeemSafeSlipsForTranchesAndUnwrapBurnsMsgSenderLendSlips(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        (uint256 borrowRiskSlipBalanceBeforeRepay,) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
        uint256 lendSlipAmount = redeemLendSlipsForStablesTestSetup(_timeWarp, borrowRiskSlipBalanceBeforeRepay, _lendSlipAmount, false);
        vm.warp(s_deployedConvertibleBondBox.maturityDate() + 1);

        IButtonWoodBondController(s_deployedConvertibleBondBox.bond()).mature();

        uint256 lenderLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_lender));
        uint256 routerLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_stagingLoanRouter));
        uint256 sbLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_deployedSB));

        vm.prank(s_lender);
        s_deployedSB.redeemLendSlip(lendSlipAmount);

        uint256 safeSlipAmount = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(s_lender);

        vm.assume(safeSlipAmount > 400);

        vm.startPrank(s_lender);
        ISlip(s_deployedSB.safeSlipAddress()).approve(address(s_stagingLoanRouter), type(uint256).max);
        vm.stopPrank();

        vm.prank(s_lender);
        StagingLoanRouter(s_stagingLoanRouter).redeemSafeSlipsForTranchesAndUnwrap(s_deployedSB, safeSlipAmount);

        uint256 lenderLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_lender));
        uint256 routerLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_stagingLoanRouter));
        uint256 sbLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_deployedSB));

        assertEq(lenderLendSlipBalanceBefore - lendSlipAmount, lenderLendSlipBalanceAfter);
        assertEq(routerLendSlipBalanceBefore, routerLendSlipBalanceAfter);
        assertEq(sbLendSlipBalanceBefore, sbLendSlipBalanceAfter);

        assertFalse(lendSlipAmount == 0);
    }

    function testRedeemSafeSlipsForTranchesBurnsSafeSlipsFromMsgSender(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        (uint256 borrowRiskSlipBalanceBeforeRepay,) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
        uint256 lendSlipAmount = redeemLendSlipsForStablesTestSetup(_timeWarp, borrowRiskSlipBalanceBeforeRepay, _lendSlipAmount, false);
        vm.warp(s_deployedConvertibleBondBox.maturityDate() + 1);

        IButtonWoodBondController(s_deployedConvertibleBondBox.bond()).mature();

        uint256 sbSafeSlipBalanceBefore = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_deployedSB));
        uint256 routerSafeSlipBalanceBefore = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_stagingLoanRouter));
        uint256 cbbSafeSlipBalanceBefore = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_deployedConvertibleBondBox));

        vm.prank(s_lender);
        s_deployedSB.redeemLendSlip(lendSlipAmount);

        uint256 lenderSafeSlipBalanceBefore = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_lender));

        uint256 safeSlipAmount = IERC20(s_deployedSB.safeSlipAddress()).balanceOf(s_lender);

        vm.assume(safeSlipAmount > 400);

        (, uint256 buttonAmount) = StagingBoxLens(s_stagingBoxLens).viewRedeemLendSlipsForTranches(s_deployedSB, lendSlipAmount);

        vm.startPrank(s_lender);
        ISlip(s_deployedSB.safeSlipAddress()).approve(address(s_stagingLoanRouter), type(uint256).max);
        vm.stopPrank();

        vm.prank(s_lender);
        StagingLoanRouter(s_stagingLoanRouter).redeemSafeSlipsForTranchesAndUnwrap(s_deployedSB, safeSlipAmount);

        uint256 sbSafeSlipBalanceAfter = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_deployedSB));
        uint256 routerSafeSlipBalanceAfter = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_stagingLoanRouter));
        uint256 cbbSafeSlipBalanceAfter = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_deployedConvertibleBondBox));
        uint256 lenderSafeSlipBalanceAfter = ISlip(s_deployedSB.safeSlipAddress()).balanceOf(address(s_lender));

        assertEq(sbSafeSlipBalanceBefore - buttonAmount, sbSafeSlipBalanceAfter);
        assertEq(routerSafeSlipBalanceBefore, routerSafeSlipBalanceAfter);
        assertEq(cbbSafeSlipBalanceBefore, cbbSafeSlipBalanceAfter);
        assertEq(lenderSafeSlipBalanceBefore - buttonAmount, lenderSafeSlipBalanceAfter);

        assertFalse(lendSlipAmount == 0);
        assertFalse(buttonAmount == 0);
    }

    function testRedeemSafeSlipsForTranchesReturnsUnderlyingToMsgSender(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        (uint256 borrowRiskSlipBalanceBeforeRepay,) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
        uint256 lendSlipAmount = redeemLendSlipsForStablesTestSetup(_timeWarp, borrowRiskSlipBalanceBeforeRepay, _lendSlipAmount, false);
        vm.warp(s_deployedConvertibleBondBox.maturityDate() + 1);

        IButtonWoodBondController(s_deployedConvertibleBondBox.bond()).mature();

        uint256 lenderUnderlyingBalanceBefore = IERC20(IButtonToken(IButtonWoodBondController(s_deployedConvertibleBondBox.bond()).collateralToken()).underlying()).balanceOf(s_lender);

        vm.prank(s_lender);
        s_deployedSB.redeemLendSlip(lendSlipAmount);

        uint256 safeSlipAmount = IERC20(s_deployedSB.safeSlipAddress()).balanceOf(s_lender);

        vm.assume(safeSlipAmount > 400);

        (uint256 underlyingAmount,) = StagingBoxLens(s_stagingBoxLens).viewRedeemLendSlipsForTranches(s_deployedSB, lendSlipAmount);

        vm.startPrank(s_lender);
        ISlip(s_deployedSB.safeSlipAddress()).approve(address(s_stagingLoanRouter), type(uint256).max);
        vm.stopPrank();

        vm.prank(s_lender);
        StagingLoanRouter(s_stagingLoanRouter).redeemSafeSlipsForTranchesAndUnwrap(s_deployedSB, safeSlipAmount);

        uint256 lenderUnderlyingBalanceAfter = IERC20(IButtonToken(IButtonWoodBondController(s_deployedConvertibleBondBox.bond()).collateralToken()).underlying()).balanceOf(s_lender);

        assertEq(lenderUnderlyingBalanceBefore + underlyingAmount, lenderUnderlyingBalanceAfter);

        assertFalse(underlyingAmount == 0);
    }
}