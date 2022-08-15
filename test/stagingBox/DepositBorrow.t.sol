pragma solidity 0.8.13;

import "./integration/SBIntegrationSetup.t.sol";

contract DepositBorrow is SBIntegrationSetup {
    struct BeforeBalances {
        uint256 borrowerBorrowSlips;
        uint256 routerSafeTranche;
        uint256 routerRiskTranche;
        uint256 SBSafeTranche;
        uint256 SBRiskTranche;
    }

    struct BorrowAmounts {
        uint256 safeTrancheAmount;
        uint256 riskTrancheAmount;
        uint256 borrowSlipAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testCannotDepositBorrowCBBNotReinitialized() public {
        setupStagingBox(0);

        vm.prank(s_deployedSBAddress);
        s_deployedConvertibleBondBox.reinitialize(5);

        bytes memory customError = abi.encodeWithSignature(
            "CBBReinitialized(bool,bool)",
            true,
            false
        );
        vm.expectRevert(customError);
        s_deployedSB.depositBorrow(s_borrower, 1);
    }

    function testDepositBorrow(uint256 _fuzzPrice, uint256 _borrowAmount)
        public
    {
        setupStagingBox(_fuzzPrice);

        BeforeBalances memory before = BeforeBalances(
            s_borrowSlip.balanceOf(s_borrower),
            s_safeTranche.balanceOf(address(this)),
            s_riskTranche.balanceOf(address(this)),
            s_safeTranche.balanceOf(s_deployedSBAddress),
            s_riskTranche.balanceOf(s_deployedSBAddress)
        );

        uint256 maxBorrowAmount = (before.routerSafeTranche *
            s_deployedSB.initialPrice() *
            s_deployedSB.stableDecimals()) /
            s_deployedSB.priceGranularity() /
            s_deployedSB.trancheDecimals();

        _borrowAmount = bound(_borrowAmount, 1, maxBorrowAmount);

        uint256 safeTrancheAmount = (_borrowAmount *
            s_deployedSB.priceGranularity() *
            s_deployedSB.trancheDecimals()) /
            s_deployedSB.initialPrice() /
            s_deployedSB.stableDecimals();

        BorrowAmounts memory adjustments = BorrowAmounts(
            safeTrancheAmount,
            (safeTrancheAmount * s_riskRatio) / s_safeRatio,
            _borrowAmount
        );

        vm.expectEmit(true, true, true, true);
        emit BorrowDeposit(s_borrower, _borrowAmount);
        s_deployedSB.depositBorrow(s_borrower, _borrowAmount);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        BorrowAmounts memory adjustments
    ) internal {
        assertEq(
            before.routerSafeTranche - adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(address(this))
        );

        assertEq(
            before.routerRiskTranche - adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(address(this))
        );

        assertEq(
            before.SBSafeTranche + adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(s_deployedSBAddress)
        );

        assertEq(
            before.SBRiskTranche + adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(s_deployedSBAddress)
        );

        assertEq(
            before.borrowerBorrowSlips + adjustments.borrowSlipAmount,
            s_borrowSlip.balanceOf(s_borrower)
        );
    }
}
