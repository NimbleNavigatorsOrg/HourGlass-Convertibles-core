pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../stagingBox/integration/SBIntegrationSetup.t.sol";
import "./RedeemLendSlipsForStablesTestSetup.t.sol";

import "forge-std/console2.sol";

contract RedeemRiskSlipsForTranchesAndUnwrap is RedeemLendSlipsForStablesTestSetup {

    function testRedeemRiskSlipsForTranchesAndUnwrapBurnsMsgSenderRiskSlips(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        (uint256 borrowerRiskSlipBalanceBefore,) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        vm.warp(s_deployedConvertibleBondBox.maturityDate() + 1);

        s_deployedConvertibleBondBox.bond().mature();

        uint256 riskSlipRedeemAmount = bound(borrowerRiskSlipBalanceBefore, s_deployedConvertibleBondBox.riskRatio(), borrowerRiskSlipBalanceBefore);

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).redeemRiskSlipsForTranchesAndUnwrap(
            s_deployedSB, 
            riskSlipRedeemAmount
            );

        uint256 borrowerRiskSlipBalanceAfter = ISlip(s_deployedSB.riskSlipAddress()).balanceOf(s_borrower);

        assertEq(borrowerRiskSlipBalanceBefore - riskSlipRedeemAmount, borrowerRiskSlipBalanceAfter);
    }

    function testRedeemRiskSlipsForTranchesAndUnwrapSendsUnderlyingToMsgSender(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        (uint256 borrowerRiskSlipBalanceBefore,) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        vm.warp(s_deployedConvertibleBondBox.maturityDate() + 1);

        s_deployedConvertibleBondBox.bond().mature();

        uint256 borrowerUnderlyingBalanceBefore = s_underlying.balanceOf(s_borrower);

        uint256 riskSlipRedeemAmount = bound(borrowerRiskSlipBalanceBefore, s_deployedConvertibleBondBox.riskRatio(), borrowerRiskSlipBalanceBefore);

        (uint256 underlyingAmount,) = 
        IStagingBoxLens(s_stagingBoxLens).viewRedeemRiskSlipsForTranches(s_deployedSB, riskSlipRedeemAmount);

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).redeemRiskSlipsForTranchesAndUnwrap(
            s_deployedSB, 
            riskSlipRedeemAmount
            );

        uint256 borrowerUnderlyingBalanceAfter = s_underlying.balanceOf(s_borrower);

        assertTrue(withinTolerance(borrowerUnderlyingBalanceBefore + underlyingAmount, borrowerUnderlyingBalanceAfter, 1));
        assertFalse(underlyingAmount == 0);
    }

    function testRedeemRiskSlipsForTranchesAndUnwrapWithdrawsCollateralFromBond(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);
        setupTranches(false, s_owner);
        (uint256 borrowerRiskSlipBalanceBefore,) = repayMaxAndUnwrapSimpleTestSetup(_lendAmount);

        vm.warp(s_deployedConvertibleBondBox.maturityDate() + 1);

        s_deployedConvertibleBondBox.bond().mature();

        uint256 riskTrancheCollateralBalanceBefore = s_collateralToken.balanceOf(address(s_deployedConvertibleBondBox.riskTranche()));

        uint256 riskSlipRedeemAmount = bound(borrowerRiskSlipBalanceBefore, s_deployedConvertibleBondBox.riskRatio(), borrowerRiskSlipBalanceBefore);

        (, uint256 buttonAmount) = 
        IStagingBoxLens(s_stagingBoxLens).viewRedeemRiskSlipsForTranches(s_deployedSB, riskSlipRedeemAmount);

        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).redeemRiskSlipsForTranchesAndUnwrap(
            s_deployedSB, 
            riskSlipRedeemAmount
            );

        uint256 riskTrancheCollateralBalanceAfter = s_collateralToken.balanceOf(address(s_deployedConvertibleBondBox.riskTranche()));

        assertTrue(withinTolerance(riskTrancheCollateralBalanceBefore - buttonAmount, riskTrancheCollateralBalanceAfter, 1));
        assertFalse(buttonAmount == 0);
    }
}