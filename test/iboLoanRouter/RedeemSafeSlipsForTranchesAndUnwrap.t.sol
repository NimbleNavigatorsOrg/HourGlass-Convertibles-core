pragma solidity 0.8.13;

import "./IBOLoanRouterSetup.t.sol";

contract RedeemSafeSlipsForTranchesAndUnwrap is IBOLoanRouterSetup {
    struct BeforeBalances {
        uint256 lenderSafeSlips;
        uint256 lenderCollateral;
    }

    struct RedeemAmounts {
        uint256 safeSlipAmount;
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
        s_deployedIBOB.transmitReInit(
            s_IBOLens.viewTransmitReInitBool(s_deployedIBOB)
        );
        vm.stopPrank();

        {
            uint256 maxRedeemableBorrowSlips = Math.min(
                s_deployedIBOB.s_reinitLendAmount(),
                s_borrowSlip.balanceOf(s_borrower)
            );

            vm.startPrank(s_borrower);
            s_deployedIBOB.redeemBorrowSlip(maxRedeemableBorrowSlips);
            vm.stopPrank();
        }

        uint256 maxRedeemableLendSlips = (s_safeSlip.balanceOf(
            s_deployedIBOBAddress
        ) *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        vm.startPrank(s_lender);
        s_deployedIBOB.redeemLendSlip(maxRedeemableLendSlips / 2);
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

    function testSafeSlipRedeemTrancheAndUnwrap(
        uint256 safeSlipAmount,
        uint256 data
    ) public {
        initialSetup(data);

        safeSlipAmount = bound(
            safeSlipAmount,
            1e6,
            s_safeSlip.balanceOf(s_lender)
        );

        (uint256 collateralAmount, , , ) = s_IBOLens
            .viewRedeemSafeSlipsForTranches(s_deployedIBOB, safeSlipAmount);

        BeforeBalances memory before = BeforeBalances(
            s_safeSlip.balanceOf(s_lender),
            s_collateralToken.balanceOf(s_lender)
        );

        RedeemAmounts memory adjustments = RedeemAmounts(
            safeSlipAmount,
            collateralAmount
        );

        vm.startPrank(s_lender);
        s_IBOLoanRouter.redeemSafeSlipsForTranchesAndUnwrap(
            s_deployedIBOB,
            safeSlipAmount
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RedeemAmounts memory adjustments
    ) internal {
        assertApproxEqRel(
            before.lenderSafeSlips - adjustments.safeSlipAmount,
            s_safeSlip.balanceOf(s_lender),
            1e15
        );

        assertApproxEqRel(
            before.lenderCollateral + adjustments.collateralAmount,
            s_collateralToken.balanceOf(s_lender),
            1e15
        );
    }
}
