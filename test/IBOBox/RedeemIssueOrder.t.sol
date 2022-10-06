pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract RedeemIssueOrder is iboBoxSetup {
    struct BeforeBalances {
        uint256 borrowerIssueOrders;
        uint256 borrowerDebtSlips;
        uint256 borrowerStableTokens;
        uint256 IBODebtSlips;
        uint256 IBOStableTokens;
        uint256 activateLendAmount;
    }

    struct BorrowAmounts {
        uint256 debtSlipAmount;
        uint256 issueOrderAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testRedeemIssueOrder(uint256 _fuzzPrice, uint256 _borrowAmount)
        public
    {
        setupIBOBox(_fuzzPrice);

        uint256 maxBorrowAmount = (s_safeTranche.balanceOf(address(this)) *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        s_deployedIBOB.createIssueOrder(s_borrower, maxBorrowAmount);

        s_deployedIBOB.createBuyOrder(
            s_lender,
            s_stableToken.balanceOf(address(this))
        );

        bool isLend = s_IBOLens.viewTransmitActivateBool(s_deployedIBOB);

        vm.prank(s_cbb_owner);
        s_deployedIBOB.transmitActivate(isLend);

        BeforeBalances memory before = BeforeBalances(
            s_issueOrder.balanceOf(s_borrower),
            s_debtSlip.balanceOf(s_borrower),
            s_stableToken.balanceOf(s_borrower),
            s_debtSlip.balanceOf(s_deployedIBOBAddress),
            s_stableToken.balanceOf(s_deployedIBOBAddress),
            s_deployedIBOB.s_activateLendAmount()
        );

        _borrowAmount = bound(_borrowAmount, 1, before.borrowerIssueOrders);

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
        emit RedeemIssueOrder(s_borrower, _borrowAmount);
        s_deployedIBOB.redeemIssueOrder(_borrowAmount);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        BorrowAmounts memory adjustments
    ) internal {
        assertEq(
            before.borrowerIssueOrders - adjustments.issueOrderAmount,
            s_issueOrder.balanceOf(s_borrower)
        );

        assertEq(
            before.borrowerDebtSlips + adjustments.debtSlipAmount,
            s_debtSlip.balanceOf(s_borrower)
        );

        assertEq(
            before.borrowerStableTokens + adjustments.issueOrderAmount,
            s_stableToken.balanceOf(s_borrower)
        );

        assertEq(
            before.IBODebtSlips - adjustments.debtSlipAmount,
            s_debtSlip.balanceOf(s_deployedIBOBAddress)
        );

        assertEq(
            before.IBOStableTokens - adjustments.issueOrderAmount,
            s_stableToken.balanceOf(s_deployedIBOBAddress)
        );

        assertEq(
            before.activateLendAmount - adjustments.issueOrderAmount,
            s_deployedIBOB.s_activateLendAmount()
        );
    }
}
