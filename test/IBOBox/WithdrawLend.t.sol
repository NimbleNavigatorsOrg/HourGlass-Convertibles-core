pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract WithdrawLend is iboBoxSetup {
    struct BeforeBalances {
        uint256 lenderLendSlips;
        uint256 lenderStableTokens;
        uint256 IBOStableTokens;
    }

    struct LendAmounts {
        uint256 stableAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testCannotWithdrawLendWithdrawAmountTooHigh(
        uint256 _fuzzPrice,
        uint256 _lendAmount
    ) public {
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

        bool isLend = s_IBOLens.viewTransmitReInitBool(s_deployedIBOB);

        vm.prank(s_cbb_owner);
        s_deployedIBOB.transmitReInit(isLend);

        uint256 maxWithdrawAmount = s_stableToken.balanceOf(
            s_deployedIBOBAddress
        ) - s_deployedIBOB.s_reinitLendAmount();

        _lendAmount = bound(
            _lendAmount,
            maxWithdrawAmount + 1,
            Math.max(maxWithdrawAmount + 1, s_lendSlip.balanceOf(s_lender))
        );

        bytes memory customError = abi.encodeWithSignature(
            "WithdrawAmountTooHigh(uint256,uint256)",
            _lendAmount,
            maxWithdrawAmount
        );

        vm.prank(s_lender);
        vm.expectRevert(customError);
        s_deployedIBOB.withdrawLend(_lendAmount);
    }

    function testWithdrawLend(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupIBOBox(_fuzzPrice);

        s_deployedIBOB.depositLend(
            s_lender,
            s_stableToken.balanceOf(address(this))
        );

        BeforeBalances memory before = BeforeBalances(
            s_lendSlip.balanceOf(s_lender),
            s_stableToken.balanceOf(s_lender),
            s_stableToken.balanceOf(s_deployedIBOBAddress)
        );

        _lendAmount = bound(_lendAmount, 1, before.lenderLendSlips);

        LendAmounts memory adjustments = LendAmounts(_lendAmount);

        vm.startPrank(s_lender);
        vm.expectEmit(true, true, true, true);
        emit LendWithdrawal(s_lender, _lendAmount);
        s_deployedIBOB.withdrawLend(_lendAmount);
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        LendAmounts memory adjustments
    ) internal {
        assertEq(
            before.lenderLendSlips - adjustments.stableAmount,
            s_lendSlip.balanceOf(s_lender)
        );

        assertEq(
            before.lenderStableTokens + adjustments.stableAmount,
            s_stableToken.balanceOf(s_lender)
        );

        assertEq(
            before.IBOStableTokens - adjustments.stableAmount,
            s_stableToken.balanceOf(s_deployedIBOBAddress)
        );
    }
}
