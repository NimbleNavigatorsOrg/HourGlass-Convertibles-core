pragma solidity 0.8.13;

import "./IBOLoanRouterSetup.t.sol";

contract RedeemLendSlipsForStables is IBOLoanRouterSetup {
    struct BeforeBalances {
        uint256 lenderLendSlips;
        uint256 lenderStables;
    }

    struct RedeemAmounts {
        uint256 lendSlipAmount;
        uint256 stableAmount;
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

        vm.startPrank(s_borrower);

        s_deployedConvertibleBondBox.repay(
            s_stableToken.balanceOf(s_borrower) / 2
        );
        vm.stopPrank();

        data = bound(
            data,
            (s_initMockData * 9) / 10,
            (s_initMockData * 11) / 10
        );

        s_mockOracle.setData(data, true);

        s_buttonWoodBondController.mature();
    }

    function testLendSlipRedeemStables(uint256 lendSlipAmount, uint256 data)
        public
    {
        initialSetup(data);

        uint256 minLendSlips = (1e6 *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        uint256 maxRedeemableLendSlips = (s_deployedConvertibleBondBox
            .s_repaidSafeSlips() *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        lendSlipAmount = bound(
            lendSlipAmount,
            Math.max(1, minLendSlips),
            Math.min(maxRedeemableLendSlips, s_lendSlip.balanceOf(s_lender))
        );

        (uint256 stableAmount, ) = s_IBOLens.viewRedeemLendSlipsForStables(
            s_deployedIBOB,
            lendSlipAmount
        );

        BeforeBalances memory before = BeforeBalances(
            s_lendSlip.balanceOf(s_lender),
            s_stableToken.balanceOf(s_lender)
        );

        RedeemAmounts memory adjustments = RedeemAmounts(
            lendSlipAmount,
            stableAmount
        );

        vm.startPrank(s_lender);
        s_IBOLoanRouter.redeemLendSlipsForStables(
            s_deployedIBOB,
            lendSlipAmount
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RedeemAmounts memory adjustments
    ) internal {
        assertApproxEqRel(
            before.lenderLendSlips - adjustments.lendSlipAmount,
            s_lendSlip.balanceOf(s_lender),
            1e15
        );

        assertApproxEqRel(
            before.lenderStables + adjustments.stableAmount,
            s_stableToken.balanceOf(s_lender),
            1e15
        );
    }
}
