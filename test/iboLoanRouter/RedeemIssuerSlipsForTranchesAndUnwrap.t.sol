pragma solidity 0.8.13;

import "./IBOLoanRouterSetup.t.sol";

contract RedeemDebtSlipsForTranchesAndUnwrap is IBOLoanRouterSetup {
    struct BeforeBalances {
        uint256 borrowerDebtSlip;
        uint256 borrowerCollateral;
    }

    struct RedeemAmounts {
        uint256 debtSlipAmount;
        uint256 collateralAmount;
    }

    function initialSetup(uint256 data) internal {
        vm.startPrank(s_borrower);
        s_IBOLoanRouter.simpleWrapTrancheBorrow(
            s_deployedIBOB,
            s_collateralToken.balanceOf(s_borrower),
            0
        );
        vm.stopPrank();

        vm.startPrank(s_lender);
        s_deployedIBOB.depositLend(
            s_lender,
            (s_stableToken.balanceOf(s_lender) / 100)
        );
        vm.stopPrank();

        vm.startPrank(s_cbb_owner);
        s_deployedIBOB.transmitActivate(
            s_IBOLens.viewTransmitActivateBool(s_deployedIBOB)
        );
        vm.stopPrank();

        {
            uint256 maxRedeemableBorrowSlips = Math.min(
                s_deployedIBOB.s_activateLendAmount(),
                s_borrowSlip.balanceOf(s_borrower)
            );

            vm.startPrank(s_borrower);
            s_deployedIBOB.redeemBorrowSlip(maxRedeemableBorrowSlips);
            vm.stopPrank();
        }

        uint256 maxRedeemableBuyOrders = (s_bondSlip.balanceOf(
            s_deployedIBOBAddress
        ) *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        vm.startPrank(s_lender);
        s_deployedIBOB.redeemBuyOrder(maxRedeemableBuyOrders / 2);
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

    function testDebtSlipRedeemTrancheAndUnwrap(
        uint256 debtSlipAmount,
        uint256 data
    ) public {
        initialSetup(data);

        debtSlipAmount = bound(
            debtSlipAmount,
            1e6,
            s_debtSlip.balanceOf(s_borrower)
        );

        (uint256 collateralAmount, , , ) = s_IBOLens
            .viewRedeemDebtSlipsForTranches(s_deployedIBOB, debtSlipAmount);

        BeforeBalances memory before = BeforeBalances(
            s_debtSlip.balanceOf(s_borrower),
            s_collateralToken.balanceOf(s_borrower)
        );

        RedeemAmounts memory adjustments = RedeemAmounts(
            debtSlipAmount,
            collateralAmount
        );

        vm.startPrank(s_borrower);
        s_IBOLoanRouter.redeemDebtSlipsForTranchesAndUnwrap(
            s_deployedIBOB,
            debtSlipAmount
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
            before.borrowerDebtSlip - adjustments.debtSlipAmount,
            s_debtSlip.balanceOf(s_borrower),
            1e15
        );
    }
}
