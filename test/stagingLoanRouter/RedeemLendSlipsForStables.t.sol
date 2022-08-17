pragma solidity 0.8.13;

import "./StagingLoanRouterSetup.t.sol";

contract RedeemLendSlipsForStables is StagingLoanRouterSetup {
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
        s_stagingLoanRouter.simpleWrapTrancheBorrow(
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
            s_deployedSB.initialPrice() *
            s_deployedSB.stableDecimals()) /
            s_deployedSB.priceGranularity() /
            s_deployedSB.trancheDecimals();

        uint256 maxRedeemableLendSlips = (s_deployedConvertibleBondBox
            .s_repaidSafeSlips() *
            s_deployedSB.initialPrice() *
            s_deployedSB.stableDecimals()) /
            s_deployedSB.priceGranularity() /
            s_deployedSB.trancheDecimals();

        lendSlipAmount = bound(
            lendSlipAmount,
            Math.max(1, minLendSlips),
            Math.min(maxRedeemableLendSlips, s_lendSlip.balanceOf(s_lender))
        );

        uint256 stableAmount = s_SBLens.viewRedeemLendSlipsForStables(
            s_deployedSB,
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
        s_stagingLoanRouter.redeemLendSlipsForStables(
            s_deployedSB,
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
