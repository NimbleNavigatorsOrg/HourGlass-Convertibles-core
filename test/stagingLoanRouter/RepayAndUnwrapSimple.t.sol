pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RepayAndUnwrapSimple is RedeemLendSlipsForStablesTestSetup {

    function testRepayAndUnwrapSimpleTransfersStablesFromMsgSenderToCBB(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (uint256 borrowRiskSlipBalanceBeforeRepay, uint256 lendAmount) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        _timeWarp = bound(_timeWarp, block.timestamp, s_deployedConvertibleBondBox.maturityDate());
        vm.warp(_timeWarp);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 borrowerRiskSlipBalanceBefore = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);

        uint256 stableRepayAmount = bound(borrowerStableBalanceBefore, 1, (ISlip(s_deployedSB.safeSlipAddress()).totalSupply() * s_deployedConvertibleBondBox.currentPrice()) / s_deployedConvertibleBondBox.s_priceGranularity());

        (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayAndUnwrapSimple(s_deployedSB, stableRepayAmount);

        vm.assume(stablesOwed > 0);

        uint256 stagingLoanRouterStableBalanceBefore = s_stableToken.balanceOf(address(s_stagingLoanRouter));
        uint256 cbbStableBalanceBefore = s_stableToken.balanceOf(address(s_deployedConvertibleBondBox));

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            borrowerRiskSlipBalanceBefore
            );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceAfter = s_stableToken.balanceOf(address(s_stagingLoanRouter));
        uint256 borrowerRiskSlipBalanceAfter = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);
        uint256 cbbStableBalanceAfter = s_stableToken.balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(borrowerStableBalanceBefore - stablesOwed, borrowerStableBalanceAfter);
        assertEq(stagingLoanRouterStableBalanceBefore, stagingLoanRouterStableBalanceAfter);
        assertEq(cbbStableBalanceBefore + stablesOwed, cbbStableBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowerRiskSlipBalanceBefore == 0);
    }

    function testRepayAndUnwrapSimpleBurnsMsgSenderRiskSlipsAndSendsRemainderBack(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (uint256 borrowRiskSlipBalanceBeforeRepay, uint256 lendAmount) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        _timeWarp = bound(_timeWarp, block.timestamp, s_deployedConvertibleBondBox.maturityDate());
        vm.warp(_timeWarp);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 borrowerRiskSlipBalanceBefore = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);

        uint256 stableRepayAmount = bound(borrowerStableBalanceBefore, 1, (ISlip(s_deployedSB.safeSlipAddress()).totalSupply() * s_deployedConvertibleBondBox.currentPrice()) / s_deployedConvertibleBondBox.s_priceGranularity());

        (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayAndUnwrapSimple(s_deployedSB, stableRepayAmount);

        vm.assume(stablesOwed > 0);

        uint256 stagingLoanRouterStableBalanceBefore = s_stableToken.balanceOf(address(s_stagingLoanRouter));
        uint256 cbbStableBalanceBefore = s_stableToken.balanceOf(address(s_deployedConvertibleBondBox));

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            borrowerRiskSlipBalanceBefore
            );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(s_borrower);
        uint256 stagingLoanRouterStableBalanceAfter = s_stableToken.balanceOf(address(s_stagingLoanRouter));
        uint256 borrowerRiskSlipBalanceAfter = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);
        uint256 cbbStableBalanceAfter = s_stableToken.balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(borrowerRiskSlipBalanceBefore - riskTranchePayout, borrowerRiskSlipBalanceAfter);

        assertFalse(stablesOwed == 0);
        assertFalse(borrowerRiskSlipBalanceBefore == 0);
    }

    function testRepayAndUnwrapSimpleSendsUnderlyingToMsgSender(uint256 _fuzzPrice, uint256 _lendAmount, uint256 _timeWarp) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner, s_deployedCBBAddress);
        (uint256 borrowRiskSlipBalanceBeforeRepay, uint256 lendAmount) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        _timeWarp = bound(_timeWarp, block.timestamp, s_deployedConvertibleBondBox.maturityDate());
        vm.warp(_timeWarp);

        uint256 borrowerStableBalanceBefore = s_stableToken.balanceOf(s_borrower);
        uint256 borrowerRiskSlipBalanceBefore = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);

        uint256 stableRepayAmount = bound(borrowerStableBalanceBefore, 1, (ISlip(s_deployedSB.safeSlipAddress()).totalSupply() * s_deployedConvertibleBondBox.currentPrice()) / s_deployedConvertibleBondBox.s_priceGranularity());

        (uint256 underlyingAmount, uint256 stablesOwed, uint256 stableFees, uint256 riskTranchePayout) = 
        IStagingBoxLens(s_stagingBoxLens).viewRepayAndUnwrapSimple(s_deployedSB, stableRepayAmount);

        vm.assume(stablesOwed > 0);

        address bond = address(s_deployedConvertibleBondBox.bond());

        uint256 borrowerUnderlyingBalanceBefore = s_underlying.balanceOf(s_borrower);
        uint256 bondCollateralBalanceBefore = s_collateralToken.balanceOf(bond);

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).repayAndUnwrapSimple(
            s_deployedSB, 
            stablesOwed,
            borrowerRiskSlipBalanceBefore
            );

        uint256 borrowerUnderlyingBalanceAfter = s_underlying.balanceOf(s_borrower);
        uint256 bondCollateralBalanceAfter = s_collateralToken.balanceOf(bond);

        assertTrue(withinTolerance(bondCollateralBalanceBefore - underlyingAmount, bondCollateralBalanceAfter, 1));
        assertTrue(withinTolerance(borrowerUnderlyingBalanceBefore + underlyingAmount, borrowerUnderlyingBalanceAfter, 1));

        assertFalse(underlyingAmount == 0);
        assertFalse(stablesOwed == 0);
        assertFalse(borrowerRiskSlipBalanceBefore == 0);
    }
}