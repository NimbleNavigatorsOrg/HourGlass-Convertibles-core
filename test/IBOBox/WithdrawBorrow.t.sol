pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract WithdrawBorrow is iboBoxSetup {
    struct BeforeBalances {
        uint256 borrowerBorrowSlips;
        uint256 borrowerSafeTranche;
        uint256 borrowerRiskTranche;
        uint256 IBOSafeTranche;
        uint256 IBORiskTranche;
    }

    struct BorrowAmounts {
        uint256 borrowSlipAmount;
        uint256 safeTrancheAmount;
        uint256 riskTrancheAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testWithdrawBorrow(uint256 _fuzzPrice, uint256 _borrowAmount)
        public
    {
        setupIBOBox(_fuzzPrice);

        uint256 maxBorrowAmount = (s_safeTranche.balanceOf(address(this)) *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        s_deployedIBOB.depositBorrow(s_borrower, maxBorrowAmount);

        BeforeBalances memory before = BeforeBalances(
            s_borrowSlip.balanceOf(s_borrower),
            s_safeTranche.balanceOf(s_borrower),
            s_riskTranche.balanceOf(s_borrower),
            s_safeTranche.balanceOf(s_deployedIBOBAddress),
            s_riskTranche.balanceOf(s_deployedIBOBAddress)
        );

        _borrowAmount = bound(_borrowAmount, 1, before.borrowerBorrowSlips);

        uint256 safeTrancheAmount = (_borrowAmount *
            s_deployedIBOB.priceGranularity() *
            s_deployedIBOB.trancheDecimals()) /
            s_deployedIBOB.initialPrice() /
            s_deployedIBOB.stableDecimals();

        BorrowAmounts memory adjustments = BorrowAmounts(
            _borrowAmount,
            safeTrancheAmount,
            (safeTrancheAmount * s_riskRatio) / s_safeRatio
        );

        vm.startPrank(s_borrower);
        s_borrowSlip.approve(s_deployedIBOBAddress, type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit BorrowWithdrawal(s_borrower, _borrowAmount);
        s_deployedIBOB.withdrawBorrow(_borrowAmount);
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        BorrowAmounts memory adjustments
    ) internal {
        assertEq(
            before.borrowerBorrowSlips - adjustments.borrowSlipAmount,
            s_borrowSlip.balanceOf(s_borrower)
        );

        assertEq(
            before.borrowerSafeTranche + adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(s_borrower)
        );

        assertEq(
            before.borrowerRiskTranche + adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(s_borrower)
        );

        assertEq(
            before.IBOSafeTranche - adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(s_deployedIBOBAddress)
        );

        assertEq(
            before.IBORiskTranche - adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(s_deployedIBOBAddress)
        );
    }
}
