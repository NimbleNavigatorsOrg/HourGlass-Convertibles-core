pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract TransmitReinit is iboBoxSetup {
    struct BeforeBalances {
        uint256 IBOSafeTranche;
        uint256 IBORiskTranche;
        uint256 IBOStableTokens;
        uint256 IBOSafeSlip;
        uint256 IBORiskSlip;
        uint256 CBBSafeTranche;
        uint256 CBBRiskTranche;
    }

    struct ReinitAmounts {
        uint256 safeTrancheAmount;
        uint256 riskTrancheAmount;
        uint256 reinitLendAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testTransmitReinit(
        uint256 _fuzzPrice,
        uint256 _borrowAmount,
        uint256 _lendAmount
    ) public {
        setupIBOBox(_fuzzPrice);

        uint256 maxBorrowAmount = (s_safeTranche.balanceOf(address(this)) *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        uint256 minBorrowAmount = (1e6 *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        _borrowAmount = bound(
            _borrowAmount,
            Math.max(minBorrowAmount, 1),
            maxBorrowAmount
        );

        s_deployedIBOB.depositBorrow(s_borrower, _borrowAmount);

        _lendAmount = bound(
            _lendAmount,
            1e6,
            s_stableToken.balanceOf(address(this))
        );

        s_deployedIBOB.depositLend(s_lender, _lendAmount);

        BeforeBalances memory before = BeforeBalances(
            s_safeTranche.balanceOf(s_deployedIBOBAddress),
            s_riskTranche.balanceOf(s_deployedIBOBAddress),
            s_stableToken.balanceOf(s_deployedIBOBAddress),
            s_safeSlip.balanceOf(s_deployedIBOBAddress),
            s_riskSlip.balanceOf(s_deployedIBOBAddress),
            s_safeTranche.balanceOf(s_deployedCBBAddress),
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );

        bool isLend = s_IBOLens.viewTransmitReInitBool(s_deployedIBOB);

        uint256 reinitLendAmount;
        uint256 safeTrancheAmount;

        if (isLend) {
            reinitLendAmount = before.IBOStableTokens;
            safeTrancheAmount =
                (reinitLendAmount *
                    s_deployedIBOB.priceGranularity() *
                    s_deployedIBOB.trancheDecimals()) /
                s_deployedIBOB.initialPrice() /
                s_deployedIBOB.stableDecimals();
        } else {
            reinitLendAmount =
                (before.IBOSafeTranche *
                    s_deployedIBOB.initialPrice() *
                    s_deployedIBOB.stableDecimals()) /
                s_deployedIBOB.priceGranularity() /
                s_deployedIBOB.trancheDecimals();
            safeTrancheAmount = before.IBOSafeTranche;
        }

        ReinitAmounts memory adjustments = ReinitAmounts(
            safeTrancheAmount,
            (safeTrancheAmount * s_riskRatio) / s_safeRatio,
            reinitLendAmount
        );

        vm.startPrank(s_cbb_owner);
        s_deployedIBOB.transmitReInit(isLend);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        ReinitAmounts memory adjustments
    ) internal {
        assertEq(
            before.IBOSafeTranche - adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(s_deployedIBOBAddress)
        );
        assertEq(
            before.IBORiskTranche - adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(s_deployedIBOBAddress)
        );
        assertEq(
            before.IBOStableTokens,
            s_stableToken.balanceOf(s_deployedIBOBAddress)
        );
        assertEq(
            before.IBOSafeSlip + adjustments.safeTrancheAmount,
            s_safeSlip.balanceOf(s_deployedIBOBAddress)
        );
        assertEq(
            before.IBORiskSlip + adjustments.riskTrancheAmount,
            s_riskSlip.balanceOf(s_deployedIBOBAddress)
        );
        assertEq(
            before.CBBSafeTranche + adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(s_deployedCBBAddress)
        );
        assertEq(
            before.CBBRiskTranche + adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );
        assertEq(
            adjustments.reinitLendAmount,
            s_deployedIBOB.s_reinitLendAmount()
        );
        assertEq(s_deployedConvertibleBondBox.owner(), s_cbb_owner);
    }
}
