pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract TransmitActivate is iboBoxSetup {
    struct BeforeBalances {
        uint256 IBOSafeTranche;
        uint256 IBORiskTranche;
        uint256 IBOStableTokens;
        uint256 IBOBondSlip;
        uint256 IBODebtSlip;
        uint256 CBBSafeTranche;
        uint256 CBBRiskTranche;
    }

    struct ActivateAmounts {
        uint256 safeTrancheAmount;
        uint256 riskTrancheAmount;
        uint256 activateLendAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testTransmitActivate(
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

        s_deployedIBOB.createIssueOrder(s_borrower, _borrowAmount);

        _lendAmount = bound(
            _lendAmount,
            1e6,
            s_stableToken.balanceOf(address(this))
        );

        s_deployedIBOB.createBuyOrder(s_lender, _lendAmount);

        BeforeBalances memory before = BeforeBalances(
            s_safeTranche.balanceOf(s_deployedIBOBAddress),
            s_riskTranche.balanceOf(s_deployedIBOBAddress),
            s_stableToken.balanceOf(s_deployedIBOBAddress),
            s_bondSlip.balanceOf(s_deployedIBOBAddress),
            s_debtSlip.balanceOf(s_deployedIBOBAddress),
            s_safeTranche.balanceOf(s_deployedCBBAddress),
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );

        bool isLend = s_IBOLens.viewTransmitActivateBool(s_deployedIBOB);

        uint256 activateLendAmount;
        uint256 safeTrancheAmount;

        if (isLend) {
            activateLendAmount = before.IBOStableTokens;
            safeTrancheAmount =
                (activateLendAmount *
                    s_deployedIBOB.priceGranularity() *
                    s_deployedIBOB.trancheDecimals()) /
                s_deployedIBOB.initialPrice() /
                s_deployedIBOB.stableDecimals();
        } else {
            activateLendAmount =
                (before.IBOSafeTranche *
                    s_deployedIBOB.initialPrice() *
                    s_deployedIBOB.stableDecimals()) /
                s_deployedIBOB.priceGranularity() /
                s_deployedIBOB.trancheDecimals();
            safeTrancheAmount = before.IBOSafeTranche;
        }

        ActivateAmounts memory adjustments = ActivateAmounts(
            safeTrancheAmount,
            (safeTrancheAmount * s_riskRatio) / s_safeRatio,
            activateLendAmount
        );

        vm.startPrank(s_cbb_owner);
        s_deployedIBOB.transmitActivate(isLend);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        ActivateAmounts memory adjustments
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
            before.IBOBondSlip + adjustments.safeTrancheAmount,
            s_bondSlip.balanceOf(s_deployedIBOBAddress)
        );
        assertEq(
            before.IBODebtSlip + adjustments.riskTrancheAmount,
            s_debtSlip.balanceOf(s_deployedIBOBAddress)
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
            adjustments.activateLendAmount,
            s_deployedIBOB.s_activateLendAmount()
        );
        assertEq(s_deployedConvertibleBondBox.owner(), s_cbb_owner);
    }
}
