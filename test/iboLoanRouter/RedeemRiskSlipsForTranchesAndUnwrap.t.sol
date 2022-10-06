pragma solidity 0.8.13;

import "./IBOLoanRouterSetup.t.sol";

contract RedeemRiskSlipsForTranchesAndUnwrap is IBOLoanRouterSetup {
    struct BeforeBalances {
        uint256 borrowerRiskSlip;
        uint256 borrowerCollateral;
    }

    struct RedeemAmounts {
        uint256 riskSlipAmount;
        uint256 collateralAmount;
    }

    function initialSetup(uint256 data) internal {
        vm.startPrank(s_borrower);
        s_IBOLoanRouter.simpleWrapTrancheBorrow(
            s_deployedSB,
            s_collateralToken.balanceOf(s_borrower),
            0
        );
        vm.stopPrank();

        vm.startPrank(s_lender);
        s_deployedSB.depositLend(
            s_lender,
            (s_stableToken.balanceOf(s_lender) / 100)
        );
        vm.stopPrank();

        vm.startPrank(s_cbb_owner);
        s_deployedSB.transmitReInit(
            s_SBLens.viewTransmitReInitBool(s_deployedSB)
        );
        vm.stopPrank();

        {
            uint256 maxRedeemableBorrowSlips = Math.min(
                s_deployedSB.s_reinitLendAmount(),
                s_borrowSlip.balanceOf(s_borrower)
            );

            vm.startPrank(s_borrower);
            s_deployedSB.redeemBorrowSlip(maxRedeemableBorrowSlips);
            vm.stopPrank();
        }

        uint256 maxRedeemableLendSlips = (s_safeSlip.balanceOf(
            s_deployedSBAddress
        ) *
            s_deployedSB.initialPrice() *
            s_deployedSB.stableDecimals()) /
            s_deployedSB.priceGranularity() /
            s_deployedSB.trancheDecimals();

        vm.startPrank(s_lender);
        s_deployedSB.redeemLendSlip(maxRedeemableLendSlips / 2);
        vm.stopPrank();

        vm.warp(s_maturityDate + 1);

        data = bound(
            data,
            (s_initMockData * 9) / 10,
            (s_initMockData * 11) / 10
        );

        s_mockOracle.setData(data, true);

        s_buttonWoodBondController.mature();
    }

    function testRiskSlipRedeemTrancheAndUnwrap(
        uint256 riskSlipAmount,
        uint256 data
    ) public {
        initialSetup(data);

        riskSlipAmount = bound(
            riskSlipAmount,
            1e6,
            s_riskSlip.balanceOf(s_borrower)
        );

        (uint256 collateralAmount, , , ) = s_SBLens
            .viewRedeemRiskSlipsForTranches(s_deployedSB, riskSlipAmount);

        BeforeBalances memory before = BeforeBalances(
            s_riskSlip.balanceOf(s_borrower),
            s_collateralToken.balanceOf(s_borrower)
        );

        RedeemAmounts memory adjustments = RedeemAmounts(
            riskSlipAmount,
            collateralAmount
        );

        vm.startPrank(s_borrower);
        s_IBOLoanRouter.redeemRiskSlipsForTranchesAndUnwrap(
            s_deployedSB,
            riskSlipAmount
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RedeemAmounts memory adjustments
    ) internal {
        assertApproxEqRel(
            before.borrowerCollateral + adjustments.collateralAmount,
            s_collateralToken.balanceOf(s_borrower),
            1e15
        );

        assertApproxEqRel(
            before.borrowerRiskSlip - adjustments.riskSlipAmount,
            s_riskSlip.balanceOf(s_borrower),
            1e15
        );
    }
}
