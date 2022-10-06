pragma solidity 0.8.13;

import "./IBOLoanRouterSetup.t.sol";

contract RedeemBondSlipsForTranchesAndUnwrap is IBOLoanRouterSetup {
    struct BeforeBalances {
        uint256 lenderBondSlips;
        uint256 lenderCollateral;
    }

    struct RedeemAmounts {
        uint256 bondSlipAmount;
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

    function testBondSlipRedeemTrancheAndUnwrap(
        uint256 bondSlipAmount,
        uint256 data
    ) public {
        initialSetup(data);

        bondSlipAmount = bound(
            bondSlipAmount,
            1e6,
            s_bondSlip.balanceOf(s_lender)
        );

        (uint256 collateralAmount, , , ) = s_IBOLens
            .viewRedeemBondSlipsForTranches(s_deployedIBOB, bondSlipAmount);

        BeforeBalances memory before = BeforeBalances(
            s_bondSlip.balanceOf(s_lender),
            s_collateralToken.balanceOf(s_lender)
        );

        RedeemAmounts memory adjustments = RedeemAmounts(
            bondSlipAmount,
            collateralAmount
        );

        vm.startPrank(s_lender);
        s_IBOLoanRouter.redeemBondSlipsForTranchesAndUnwrap(
            s_deployedIBOB,
            bondSlipAmount
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RedeemAmounts memory adjustments
    ) internal {
        assertApproxEqRel(
            before.lenderBondSlips - adjustments.bondSlipAmount,
            s_bondSlip.balanceOf(s_lender),
            1e15
        );

        assertApproxEqRel(
            before.lenderCollateral + adjustments.collateralAmount,
            s_collateralToken.balanceOf(s_lender),
            1e15
        );
    }
}
