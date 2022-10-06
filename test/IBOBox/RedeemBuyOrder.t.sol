pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract RedeemBuyOrder is iboBoxSetup {
    struct BeforeBalances {
        uint256 lenderBuyOrders;
        uint256 lenderBondSlips;
        uint256 IBOBondSlips;
    }

    struct LendAmounts {
        uint256 buyOrderAmount;
        uint256 bondSlipAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testRedeemBuyOrder(uint256 _fuzzPrice, uint256 _lendAmount)
        public
    {
        setupIBOBox(_fuzzPrice);

        uint256 maxBorrowAmount = (s_safeTranche.balanceOf(address(this)) *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        s_deployedIBOB.depositBorrow(s_borrower, maxBorrowAmount);

        s_deployedIBOB.createBuyOrder(
            s_lender,
            s_stableToken.balanceOf(address(this))
        );

        bool isLend = s_IBOLens.viewTransmitActivateBool(s_deployedIBOB);

        vm.prank(s_cbb_owner);
        s_deployedIBOB.transmitActivate(isLend);

        BeforeBalances memory before = BeforeBalances(
            s_buyOrder.balanceOf(s_lender),
            s_bondSlip.balanceOf(s_lender),
            s_bondSlip.balanceOf(s_deployedIBOBAddress)
        );

        uint256 maxLendAmount = Math.min(
            before.lenderBuyOrders,
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
        emit RedeemBuyOrder(s_lender, _lendAmount);
        s_deployedIBOB.redeemBuyOrder(_lendAmount);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        LendAmounts memory adjustments
    ) internal {
        assertEq(
            before.lenderBuyOrders - adjustments.buyOrderAmount,
            s_buyOrder.balanceOf(s_lender)
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
