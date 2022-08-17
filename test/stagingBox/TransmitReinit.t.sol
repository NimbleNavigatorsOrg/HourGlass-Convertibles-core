pragma solidity 0.8.13;

import "./integration/SBIntegrationSetup.t.sol";

contract TransmitReinit is SBIntegrationSetup {
    struct BeforeBalances {
        uint256 SBSafeTranche;
        uint256 SBRiskTranche;
        uint256 SBStableTokens;
        uint256 SBSafeSlip;
        uint256 SBRiskSlip;
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
        setupStagingBox(_fuzzPrice);

        uint256 maxBorrowAmount = (s_safeTranche.balanceOf(address(this)) *
            s_deployedSB.initialPrice() *
            s_deployedSB.stableDecimals()) /
            s_deployedSB.priceGranularity() /
            s_deployedSB.trancheDecimals();

        uint256 minBorrowAmount = (1e6 *
            s_deployedSB.initialPrice() *
            s_deployedSB.stableDecimals()) /
            s_deployedSB.priceGranularity() /
            s_deployedSB.trancheDecimals();

        _borrowAmount = bound(
            _borrowAmount,
            Math.max(minBorrowAmount, 1),
            maxBorrowAmount
        );

        s_deployedSB.depositBorrow(s_borrower, _borrowAmount);

        _lendAmount = bound(
            _lendAmount,
            1e6,
            s_stableToken.balanceOf(address(this))
        );

        s_deployedSB.depositLend(s_lender, _lendAmount);

        BeforeBalances memory before = BeforeBalances(
            s_safeTranche.balanceOf(s_deployedSBAddress),
            s_riskTranche.balanceOf(s_deployedSBAddress),
            s_stableToken.balanceOf(s_deployedSBAddress),
            s_safeSlip.balanceOf(s_deployedSBAddress),
            s_riskSlip.balanceOf(s_deployedSBAddress),
            s_safeTranche.balanceOf(s_deployedCBBAddress),
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );

        bool isLend = s_SBLens.viewTransmitReInitBool(s_deployedSB);

        uint256 reinitLendAmount;
        uint256 safeTrancheAmount;

        if (isLend) {
            reinitLendAmount = before.SBStableTokens;
            safeTrancheAmount =
                (reinitLendAmount *
                    s_deployedSB.priceGranularity() *
                    s_deployedSB.trancheDecimals()) /
                s_deployedSB.initialPrice() /
                s_deployedSB.stableDecimals();
        } else {
            reinitLendAmount =
                (before.SBSafeTranche *
                    s_deployedSB.initialPrice() *
                    s_deployedSB.stableDecimals()) /
                s_deployedSB.priceGranularity() /
                s_deployedSB.trancheDecimals();
            safeTrancheAmount = before.SBSafeTranche;
        }

        ReinitAmounts memory adjustments = ReinitAmounts(
            safeTrancheAmount,
            (safeTrancheAmount * s_riskRatio) / s_safeRatio,
            reinitLendAmount
        );

        vm.startPrank(s_cbb_owner);
        s_deployedSB.transmitReInit(isLend);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        ReinitAmounts memory adjustments
    ) internal {
        assertEq(
            before.SBSafeTranche - adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(s_deployedSBAddress)
        );
        assertEq(
            before.SBRiskTranche - adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(s_deployedSBAddress)
        );
        assertEq(
            before.SBStableTokens,
            s_stableToken.balanceOf(s_deployedSBAddress)
        );
        assertEq(
            before.SBSafeSlip + adjustments.safeTrancheAmount,
            s_safeSlip.balanceOf(s_deployedSBAddress)
        );
        assertEq(
            before.SBRiskSlip + adjustments.riskTrancheAmount,
            s_riskSlip.balanceOf(s_deployedSBAddress)
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
            s_deployedSB.s_reinitLendAmount()
        );
        assertEq(s_deployedConvertibleBondBox.owner(), s_cbb_owner);
    }
}
