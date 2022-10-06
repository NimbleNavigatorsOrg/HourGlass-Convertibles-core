pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract RedeemBuySlip is iboBoxSetup {
    struct BeforeBalances {
        uint256 lenderBuySlips;
        uint256 lenderBondSlips;
        uint256 IBOBondSlips;
    }

    struct LendAmounts {
        uint256 buySlipAmount;
        uint256 bondSlipAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testRedeemBuySlip(uint256 _fuzzPrice, uint256 _lendAmount)
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
            s_buySlip.balanceOf(s_lender),
            s_bondSlip.balanceOf(s_lender),
            s_bondSlip.balanceOf(s_deployedIBOBAddress)
        );

        uint256 maxLendAmount = Math.min(
            before.lenderBuySlips,
            (before.IBOBondSlips *
                s_deployedIBOB.initialPrice() *
                s_deployedIBOB.stableDecimals()) /
                s_deployedIBOB.priceGranularity() /
                s_deployedIBOB.trancheDecimals()
        );

        _lendAmount = bound(_lendAmount, 1, maxLendAmount);

        LendAmounts memory adjustments = LendAmounts(
            _lendAmount,
            (_lendAmount *
                s_deployedIBOB.priceGranularity() *
                s_deployedIBOB.trancheDecimals()) /
                s_deployedIBOB.initialPrice() /
                s_deployedIBOB.stableDecimals()
        );

        vm.prank(s_lender);
        vm.expectEmit(true, true, true, true);
        emit RedeemBuySlip(s_lender, _lendAmount);
        s_deployedIBOB.redeemBuySlip(_lendAmount);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        LendAmounts memory adjustments
    ) internal {
        assertEq(
            before.lenderBuySlips - adjustments.buySlipAmount,
            s_buySlip.balanceOf(s_lender)
        );

        assertEq(
            before.lenderBondSlips + adjustments.bondSlipAmount,
            s_bondSlip.balanceOf(s_lender)
        );

        assertEq(
            before.IBOBondSlips - adjustments.bondSlipAmount,
            s_bondSlip.balanceOf(s_deployedIBOBAddress)
        );
    }
}
