pragma solidity 0.8.13;

import "./IBOLoanRouterSetup.t.sol";

contract RedeemBuySlipsForStables is IBOLoanRouterSetup {
    struct BeforeBalances {
        uint256 lenderBuySlips;
        uint256 lenderStables;
    }

    struct RedeemAmounts {
        uint256 buySlipAmount;
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

        uint256 maxRedeemableBuySlips = (s_bondSlip.balanceOf(
            s_deployedIBOBAddress
        ) *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        vm.startPrank(s_lender);
        s_deployedIBOB.redeemBuySlip(maxRedeemableBuySlips / 2);
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

    function testBuySlipRedeemStables(uint256 buySlipAmount, uint256 data)
        public
    {
        initialSetup(data);

        uint256 minBuySlips = (1e6 *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        uint256 maxRedeemableBuySlips = (s_deployedConvertibleBondBox
            .s_repaidBondSlips() *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        buySlipAmount = bound(
            buySlipAmount,
            Math.max(1, minBuySlips),
            Math.min(maxRedeemableBuySlips, s_buySlip.balanceOf(s_lender))
        );

        (uint256 stableAmount, ) = s_IBOLens.viewRedeemBuySlipsForStables(
            s_deployedIBOB,
            buySlipAmount
        );

        BeforeBalances memory before = BeforeBalances(
            s_buySlip.balanceOf(s_lender),
            s_stableToken.balanceOf(s_lender)
        );

        RedeemAmounts memory adjustments = RedeemAmounts(
            buySlipAmount,
            stableAmount
        );

        vm.startPrank(s_lender);
        s_IBOLoanRouter.redeemBuySlipsForStables(
            s_deployedIBOB,
            buySlipAmount
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RedeemAmounts memory adjustments
    ) internal {
        assertApproxEqRel(
            before.lenderBuySlips - adjustments.buySlipAmount,
            s_buySlip.balanceOf(s_lender),
            1e15
        );

        assertApproxEqRel(
            before.lenderStables + adjustments.stableAmount,
            s_stableToken.balanceOf(s_lender),
            1e15
        );
    }
}
