pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract RedeemBorrowSlip is iboBoxSetup {
    struct BeforeBalances {
        uint256 borrowerBorrowSlips;
        uint256 borrowerRiskSlips;
        uint256 borrowerStableTokens;
        uint256 IBORiskSlips;
        uint256 IBOStableTokens;
        uint256 activateLendAmount;
    }

    struct BorrowAmounts {
        uint256 riskSlipAmount;
        uint256 borrowSlipAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testRedeemBorrowSlip(uint256 _fuzzPrice, uint256 _borrowAmount)
        public
    {
        setupIBOBox(_fuzzPrice);

        uint256 maxBorrowAmount = (s_safeTranche.balanceOf(address(this)) *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        s_deployedIBOB.depositBorrow(s_borrower, maxBorrowAmount);

        s_deployedIBOB.depositLend(
            s_lender,
            s_stableToken.balanceOf(address(this))
        );

        bool isLend = s_IBOLens.viewTransmitActivateBool(s_deployedIBOB);

        vm.prank(s_cbb_owner);
        s_deployedIBOB.transmitActivate(isLend);

        BeforeBalances memory before = BeforeBalances(
            s_borrowSlip.balanceOf(s_borrower),
            s_riskSlip.balanceOf(s_borrower),
            s_stableToken.balanceOf(s_borrower),
            s_riskSlip.balanceOf(s_deployedIBOBAddress),
            s_stableToken.balanceOf(s_deployedIBOBAddress),
            s_deployedIBOB.s_activateLendAmount()
        );

        _borrowAmount = bound(_borrowAmount, 1, before.borrowerBorrowSlips);

        BorrowAmounts memory adjustments = BorrowAmounts(
            (_borrowAmount *
                s_deployedIBOB.priceGranularity() *
                s_deployedIBOB.riskRatio() *
                s_deployedIBOB.trancheDecimals()) /
                s_deployedIBOB.initialPrice() /
                s_deployedIBOB.safeRatio() /
                s_deployedIBOB.stableDecimals(),
            _borrowAmount
        );

        vm.prank(s_borrower);
        vm.expectEmit(true, true, true, true);
        emit RedeemBorrowSlip(s_borrower, _borrowAmount);
        s_deployedIBOB.redeemBorrowSlip(_borrowAmount);

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
            before.borrowerRiskSlips + adjustments.riskSlipAmount,
            s_riskSlip.balanceOf(s_borrower)
        );

        assertEq(
            before.borrowerStableTokens + adjustments.borrowSlipAmount,
            s_stableToken.balanceOf(s_borrower)
        );

        assertEq(
            before.IBORiskSlips - adjustments.riskSlipAmount,
            s_riskSlip.balanceOf(s_deployedIBOBAddress)
        );

        assertEq(
            before.IBOStableTokens - adjustments.borrowSlipAmount,
            s_stableToken.balanceOf(s_deployedIBOBAddress)
        );

        assertEq(
            before.activateLendAmount - adjustments.borrowSlipAmount,
            s_deployedIBOB.s_activateLendAmount()
        );
    }
}
