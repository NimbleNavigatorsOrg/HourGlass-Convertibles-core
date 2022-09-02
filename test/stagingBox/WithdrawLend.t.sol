pragma solidity 0.8.13;

import "./integration/SBIntegrationSetup.t.sol";

contract WithdrawLend is SBIntegrationSetup {
    struct BeforeBalances {
        uint256 lenderLendSlips;
        uint256 lenderStableTokens;
        uint256 SBStableTokens;
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

        uint256 maxWithdrawAmount = s_stableToken.balanceOf(
            s_deployedSBAddress
        ) - s_deployedSB.s_reinitLendAmount();

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
        s_deployedSB.withdrawLend(_lendAmount);
    }

    function testWithdrawLend(uint256 _fuzzPrice, uint256 _lendAmount) public {
        setupStagingBox(_fuzzPrice);

        s_deployedSB.depositLend(
            s_lender,
            s_stableToken.balanceOf(address(this))
        );

        BeforeBalances memory before = BeforeBalances(
            s_lendSlip.balanceOf(s_lender),
            s_stableToken.balanceOf(s_lender),
            s_stableToken.balanceOf(s_deployedSBAddress)
        );

        _lendAmount = bound(_lendAmount, 1, before.lenderLendSlips);

        LendAmounts memory adjustments = LendAmounts(_lendAmount);

        vm.startPrank(s_lender);
        vm.expectEmit(true, true, true, true);
        emit LendWithdrawal(s_lender, _lendAmount);
        s_deployedSB.withdrawLend(_lendAmount);
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
            before.SBStableTokens - adjustments.stableAmount,
            s_stableToken.balanceOf(s_deployedSBAddress)
        );
    }
}
