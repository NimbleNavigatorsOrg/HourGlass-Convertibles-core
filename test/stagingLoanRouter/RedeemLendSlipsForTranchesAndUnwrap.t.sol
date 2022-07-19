pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RedeemLendSlipsForTranchesAndUnwrap is RedeemLendSlipsForStablesTestSetup {

    function testRedeemLendSlipsForTranchesAndUnwrapBurnsMsgSenderLendSlips(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp, uint256 _lendSlipAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (uint256 borrowRiskSlipBalanceBeforeRepay, uint256 lendAmount) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
        uint256 lendSlipAmount = redeemLendSlipsForStablesTestSetup(_timeWarp, borrowRiskSlipBalanceBeforeRepay, _lendSlipAmount, false);
        vm.warp(s_deployedConvertibleBondBox.maturityDate() + 1);

        IButtonWoodBondController(s_deployedConvertibleBondBox.bond()).mature();

        (uint256 underlyingAmount, uint256 buttonAmount) = StagingBoxLens(s_stagingBoxLens).viewRedeemLendSlipsForTranches(s_deployedSB, lendSlipAmount);

        uint256 lenderLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_lender));
        uint256 routerLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_stagingLoanRouter));
        uint256 sbLendSlipBalanceBefore = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_deployedSB));

        vm.prank(s_lender);
        StagingLoanRouter(s_stagingLoanRouter).redeemLendSlipsForTranchesAndUnwrap(s_deployedSB, lendSlipAmount);

        uint256 lenderLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_lender));
        uint256 routerLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_stagingLoanRouter));
        uint256 sbLendSlipBalanceAfter = ISlip(s_deployedSB.lendSlip()).balanceOf(address(s_deployedSB));

        assertEq(lenderLendSlipBalanceBefore - lendSlipAmount, lenderLendSlipBalanceAfter);
        assertEq(routerLendSlipBalanceBefore, routerLendSlipBalanceAfter);
        assertEq(sbLendSlipBalanceBefore, sbLendSlipBalanceAfter);

        assertFalse(lendSlipAmount == 0);
    }
}