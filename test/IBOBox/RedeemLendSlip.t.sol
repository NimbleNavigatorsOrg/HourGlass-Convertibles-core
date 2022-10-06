pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract RedeemLendSlip is iboBoxSetup {
    struct BeforeBalances {
        uint256 lenderLendSlips;
        uint256 lenderSafeSlips;
        uint256 SBSafeSlips;
    }

    struct LendAmounts {
        uint256 lendSlipAmount;
        uint256 safeSlipAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testRedeemLendSlip(uint256 _fuzzPrice, uint256 _lendAmount)
        public
    {
        setupIBOBox(_fuzzPrice);

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
            s_lendSlip.balanceOf(s_lender),
            s_safeSlip.balanceOf(s_lender),
            s_safeSlip.balanceOf(s_deployedSBAddress)
        );

        uint256 maxLendAmount = Math.min(
            before.lenderLendSlips,
            (before.SBSafeSlips *
                s_deployedSB.initialPrice() *
                s_deployedSB.stableDecimals()) /
                s_deployedSB.priceGranularity() /
                s_deployedSB.trancheDecimals()
        );

        _lendAmount = bound(_lendAmount, 1, maxLendAmount);

        LendAmounts memory adjustments = LendAmounts(
            _lendAmount,
            (_lendAmount *
                s_deployedSB.priceGranularity() *
                s_deployedSB.trancheDecimals()) /
                s_deployedSB.initialPrice() /
                s_deployedSB.stableDecimals()
        );

        vm.prank(s_lender);
        vm.expectEmit(true, true, true, true);
        emit RedeemLendSlip(s_lender, _lendAmount);
        s_deployedSB.redeemLendSlip(_lendAmount);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        LendAmounts memory adjustments
    ) internal {
        assertEq(
            before.lenderLendSlips - adjustments.lendSlipAmount,
            s_lendSlip.balanceOf(s_lender)
        );

        assertEq(
            before.lenderSafeSlips + adjustments.safeSlipAmount,
            s_safeSlip.balanceOf(s_lender)
        );

        assertEq(
            before.SBSafeSlips - adjustments.safeSlipAmount,
            s_safeSlip.balanceOf(s_deployedSBAddress)
        );
    }
}
