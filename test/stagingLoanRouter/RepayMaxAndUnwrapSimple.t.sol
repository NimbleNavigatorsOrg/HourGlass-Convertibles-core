pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RepayMaxAndUnwrapSimple is RedeemLendSlipsForStablesTestSetup {

    function testRepayMaxAndUnwrapSimpleTransfersStablesFromMsgSender(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp, uint256 _borrowSlipsToRedeem) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        (uint256 borrowRiskSlipBalanceBeforeRepay,) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        _borrowSlipsToRedeem = bound(_borrowSlipsToRedeem, s_deployedConvertibleBondBox.riskRatio(), borrowRiskSlipBalanceBeforeRepay);

        _timeWarp = bound(_timeWarp, block.timestamp, s_deployedConvertibleBondBox.maturityDate());
        vm.warp(_timeWarp);

        (, uint256 stablesOwed,,) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, _borrowSlipsToRedeem);

        vm.assume(stablesOwed > 0);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceBefore = s_stableToken.balanceOf(address(s_stagingLoanRouter));
        uint256 cbbStableBalanceBefore = s_stableToken.balanceOf(address(s_deployedConvertibleBondBox));

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            _borrowSlipsToRedeem
            );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceAfter = s_stableToken.balanceOf(address(s_stagingLoanRouter));
        uint256 cbbStableBalanceAfter = s_stableToken.balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(borrowerStableBalanceBefore - stablesOwed, borrowerStableBalanceAfter);
        assertEq(stagingLoanRouterStableBalanceBefore, stagingLoanRouterStableBalanceAfter);
        assertEq(cbbStableBalanceBefore + stablesOwed, cbbStableBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(_borrowSlipsToRedeem == 0);
    }

    function testRepayMaxAndUnwrapSimpleBurnsMsgSenderRiskSlips(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp, uint256 _borrowSlipsToRedeem) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        (uint256 borrowRiskSlipBalanceBeforeRepay,) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
        borrowRiskSlipBalanceBeforeRepay = bound(borrowRiskSlipBalanceBeforeRepay, s_deployedConvertibleBondBox.riskRatio(), borrowRiskSlipBalanceBeforeRepay);

        _borrowSlipsToRedeem = bound(_borrowSlipsToRedeem, s_deployedConvertibleBondBox.riskRatio(), borrowRiskSlipBalanceBeforeRepay);

        _timeWarp = bound(_timeWarp, block.timestamp, s_deployedConvertibleBondBox.maturityDate());
        vm.warp(_timeWarp);

        (, uint256 stablesOwed,,) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, _borrowSlipsToRedeem);
        vm.assume(stablesOwed > 0);

        uint256 borrowerRiskSlipBalanceBefore = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);
        uint256 routerRiskSlipBalanceBefore = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(address(s_stagingLoanRouter));

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            _borrowSlipsToRedeem
            );

        uint256 borrowerRiskSlipBalanceAfter = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);
        uint256 routerRiskSlipBalanceAfter = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(address(s_stagingLoanRouter));

        assertEq(borrowerRiskSlipBalanceBefore - _borrowSlipsToRedeem, borrowerRiskSlipBalanceAfter);
        assertEq(routerRiskSlipBalanceBefore, routerRiskSlipBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);
    }

    function testRepayMaxAndUnwrapSimpleSendsUnderlyingToMsgSender(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        (uint256 borrowRiskSlipBalanceBeforeRepay,) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
        borrowRiskSlipBalanceBeforeRepay = bound(borrowRiskSlipBalanceBeforeRepay, s_deployedConvertibleBondBox.riskRatio() * 1000, borrowRiskSlipBalanceBeforeRepay);

        borrowRiskSlipBalanceBeforeRepay = bound(borrowRiskSlipBalanceBeforeRepay, s_deployedConvertibleBondBox.riskRatio() * 1000, borrowRiskSlipBalanceBeforeRepay);

        _timeWarp = bound(_timeWarp, block.timestamp, s_deployedConvertibleBondBox.maturityDate() - 1);
        
        vm.warp(_timeWarp);

        (uint256 underlyingAmount, uint256 stablesOwed,,) = 
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

        assertTrue(withinTolerance(bondCollateralBalanceBefore - underlyingAmount, bondCollateralBalanceAfter, 1));
        assertTrue(withinTolerance(borrowerUnderlyingBalanceBefore + underlyingAmount, borrowerUnderlyingBalanceAfter, 1));

        assertFalse(underlyingAmount == 0);
        assertFalse(stablesOwed == 0);
        assertFalse(borrowRiskSlipBalanceBeforeRepay == 0);
    }

    function testRepayMaxAndUnwrapSimpleTransfersExtraStablesBackToMsgSender(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp, uint256 _borrowSlipsToRedeem) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        (uint256 borrowRiskSlipBalanceBeforeRepay,) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);
        borrowRiskSlipBalanceBeforeRepay = bound(borrowRiskSlipBalanceBeforeRepay, s_deployedConvertibleBondBox.riskRatio(), borrowRiskSlipBalanceBeforeRepay);

        _borrowSlipsToRedeem = bound(_borrowSlipsToRedeem, s_deployedConvertibleBondBox.riskRatio(), borrowRiskSlipBalanceBeforeRepay);

        _timeWarp = bound(_timeWarp, block.timestamp, s_deployedConvertibleBondBox.maturityDate());
        vm.warp(_timeWarp);

        (, uint256 stablesOwed,,) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayMaxAndUnwrapSimple(s_deployedSB, _borrowSlipsToRedeem);

        uint256 extraStables = 15500;

        vm.assume(stablesOwed > 0);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceBefore = s_stableToken.balanceOf(address(s_stagingLoanRouter));

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed + extraStables,
            _borrowSlipsToRedeem
            );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceAfter = s_stableToken.balanceOf(address(s_stagingLoanRouter));

        assertEq(borrowerStableBalanceBefore - stablesOwed, borrowerStableBalanceAfter);
        assertEq(stagingLoanRouterStableBalanceBefore, stagingLoanRouterStableBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(_borrowSlipsToRedeem == 0);
    }
}