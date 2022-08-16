pragma solidity 0.8.13;

import "./integration/SBIntegrationSetup.t.sol";

contract RedeemBorrowSlip is SBIntegrationSetup {
    struct BeforeBalances {
        uint256 borrowerBorrowSlips;
        uint256 borrowerRiskSlips;
        uint256 borrowerStableTokens;
        uint256 SBRiskSlips;
        uint256 SBStableTokens;
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
        setupStagingBox(_fuzzPrice);

        uint256 maxBorrowAmount = (s_safeTranche.balanceOf(address(this)) *
            s_deployedSB.initialPrice() *
            s_deployedSB.stableDecimals()) /
            s_deployedSB.priceGranularity() /
            s_deployedSB.trancheDecimals();

        s_deployedSB.depositBorrow(s_borrower, maxBorrowAmount);

        s_deployedSB.depositLend(
            s_lender,
            s_stableToken.balanceOf(address(this))
        );

        bool isLend = s_SBLens.viewTransmitReInitBool(s_deployedSB);

        vm.prank(s_cbb_owner);
        s_deployedSB.transmitReInit(isLend);

        BeforeBalances memory before = BeforeBalances(
            s_borrowSlip.balanceOf(s_borrower),
            s_riskSlip.balanceOf(s_borrower),
            s_stableToken.balanceOf(s_borrower),
            s_riskSlip.balanceOf(s_deployedSBAddress),
            s_stableToken.balanceOf(s_deployedSBAddress)
        );

        _borrowAmount = bound(_borrowAmount, 1, before.borrowerBorrowSlips);

        BorrowAmounts memory adjustments = BorrowAmounts(
            (_borrowAmount *
                s_deployedSB.priceGranularity() *
                s_deployedSB.riskRatio() *
                s_deployedSB.trancheDecimals()) /
                s_deployedSB.initialPrice() /
                s_deployedSB.safeRatio() /
                s_deployedSB.stableDecimals(),
            _borrowAmount
        );

        vm.prank(s_borrower);
        vm.expectEmit(true, true, true, true);
        emit RedeemBorrowSlip(s_borrower, _borrowAmount);
        s_deployedSB.redeemBorrowSlip(_borrowAmount);

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
            before.SBRiskSlips - adjustments.riskSlipAmount,
            s_riskSlip.balanceOf(s_deployedSBAddress)
        );

        assertEq(
            before.SBStableTokens - adjustments.borrowSlipAmount,
            s_stableToken.balanceOf(s_deployedSBAddress)
        );
    }
}
