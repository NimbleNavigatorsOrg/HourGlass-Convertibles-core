pragma solidity 0.8.13;

import "./integration/SBIntegrationSetup.t.sol";

contract WithdrawBorrow is SBIntegrationSetup {
    struct BeforeBalances {
        uint256 borrowerBorrowSlips;
        uint256 borrowerSafeTranche;
        uint256 borrowerRiskTranche;
        uint256 SBSafeTranche;
        uint256 SBRiskTranche;
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
        setupStagingBox(_fuzzPrice);

        uint256 maxBorrowAmount = (s_safeTranche.balanceOf(address(this)) *
            s_deployedSB.initialPrice() *
            s_deployedSB.stableDecimals()) /
            s_deployedSB.priceGranularity() /
            s_deployedSB.trancheDecimals();

        s_deployedSB.depositBorrow(s_borrower, maxBorrowAmount);

        BeforeBalances memory before = BeforeBalances(
            s_borrowSlip.balanceOf(s_borrower),
            s_safeTranche.balanceOf(s_borrower),
            s_riskTranche.balanceOf(s_borrower),
            s_safeTranche.balanceOf(s_deployedSBAddress),
            s_riskTranche.balanceOf(s_deployedSBAddress)
        );

        _borrowAmount = bound(_borrowAmount, 1, before.borrowerBorrowSlips);

        uint256 safeTrancheAmount = (_borrowAmount *
            s_deployedSB.priceGranularity() *
            s_deployedSB.trancheDecimals()) /
            s_deployedSB.initialPrice() /
            s_deployedSB.stableDecimals();

        BorrowAmounts memory adjustments = BorrowAmounts(
            _borrowAmount,
            safeTrancheAmount,
            (safeTrancheAmount * s_riskRatio) / s_safeRatio
        );

        vm.startPrank(s_borrower);
        s_borrowSlip.approve(s_deployedSBAddress, type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit BorrowWithdrawal(s_borrower, _borrowAmount);
        s_deployedSB.withdrawBorrow(_borrowAmount);
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
            before.SBSafeTranche - adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(s_deployedSBAddress)
        );

        assertEq(
            before.SBRiskTranche - adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(s_deployedSBAddress)
        );
    }
}
