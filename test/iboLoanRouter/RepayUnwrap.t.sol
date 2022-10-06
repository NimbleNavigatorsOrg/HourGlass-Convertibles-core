pragma solidity 0.8.13;

import "./IBOLoanRouterSetup.t.sol";

contract RepayUnwrap is IBOLoanRouterSetup {
    struct BeforeBalances {
        uint256 borrowerStables;
        uint256 borrowerDebtSlip;
        uint256 borrowerCollateral;
    }

    struct RepayAmounts {
        uint256 stablesFee;
        uint256 stablesOwed;
        uint256 debtSlipAmount;
        uint256 collateralAmount;
    }

    function initialSetup(
        uint256 data,
        uint256 time,
        bool isMature
    ) internal {
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
            (s_stableToken.balanceOf(s_lender) * 4) / 5
        );
        vm.stopPrank();

        vm.startPrank(s_cbb_owner);
        s_deployedIBOB.transmitActivate(
            s_IBOLens.viewTransmitActivateBool(s_deployedIBOB)
        );
        vm.stopPrank();

        vm.startPrank(s_borrower);
        s_deployedIBOB.redeemIssueOrder(s_issueOrder.balanceOf(s_borrower));
        vm.stopPrank();

        !isMature
            ? time = bound(time, block.timestamp, s_maturityDate)
            : time = bound(time, s_maturityDate + 1, s_endOfUnixTime);
        vm.warp(time);

        data = bound(
            data,
            (s_initMockData * 9) / 10,
            (s_initMockData * 11) / 10
        );

        s_mockOracle.setData(data, true);

        isMature
            ? s_buttonWoodBondController.mature()
            : console2.log("not mature");
    }

    function testRepayMaxUnwrapSimple(
        uint256 debtSlipAmount,
        uint256 data,
        uint256 time
    ) public {
        initialSetup(data, time, false);

        debtSlipAmount = bound(
            debtSlipAmount,
            1e6,
            s_debtSlip.balanceOf(s_borrower)
        );

        (
            uint256 collateralAmount,
            uint256 stablesOwed,
            uint256 stableFees,

        ) = s_IBOLens.viewRepayMaxAndUnwrapSimple(
                s_deployedIBOB,
                debtSlipAmount
            );

        s_stableToken.mint(s_borrower, stablesOwed + stableFees);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_debtSlip.balanceOf(s_borrower),
            s_collateralToken.balanceOf(s_borrower)
        );

        RepayAmounts memory adjustments = RepayAmounts(
            stableFees,
            stablesOwed,
            debtSlipAmount,
            collateralAmount
        );

        vm.startPrank(s_borrower);
        s_IBOLoanRouter.repayMaxAndUnwrapSimple(
            s_deployedIBOB,
            stablesOwed,
            stableFees,
            debtSlipAmount
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function testRepayAndUnwrapSimple(
        uint256 stableAmount,
        uint256 data,
        uint256 time
    ) public {
        initialSetup(data, time, false);

        uint256 minStablesForSafeTranche = (s_deployedIBOB.trancheDecimals() *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        stableAmount = bound(
            stableAmount,
            Math.max(1e6, minStablesForSafeTranche),
            s_stableToken.balanceOf(s_borrower)
        );

        (
            uint256 collateralAmount,
            uint256 stablesOwed,
            uint256 stableFees,
            uint256 riskTranchePayout
        ) = s_IBOLens.viewRepayAndUnwrapSimple(s_deployedIBOB, stableAmount);

        console2.log(riskTranchePayout, "riskTranchePayout");

        s_stableToken.mint(s_borrower, stablesOwed + stableFees);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_debtSlip.balanceOf(s_borrower),
            s_collateralToken.balanceOf(s_borrower)
        );

        RepayAmounts memory adjustments = RepayAmounts(
            stableFees,
            stablesOwed,
            riskTranchePayout,
            collateralAmount
        );

        vm.startPrank(s_borrower);
        s_IBOLoanRouter.repayAndUnwrapSimple(
            s_deployedIBOB,
            stablesOwed,
            stableFees,
            riskTranchePayout
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function testRepayAndUnwrapMature(
        uint256 stableAmount,
        uint256 data,
        uint256 time
    ) public {
        initialSetup(data, time, true);

        stableAmount = bound(
            stableAmount,
            Math.max(1e6, (10**s_stableDecimals)),
            s_stableToken.balanceOf(s_borrower)
        );

        (
            uint256 collateralAmount,
            uint256 stablesOwed,
            uint256 stableFees,
            uint256 riskTranchePayout
        ) = s_IBOLens.viewRepayAndUnwrapMature(s_deployedIBOB, stableAmount);

        s_stableToken.mint(s_borrower, stablesOwed + stableFees);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_debtSlip.balanceOf(s_borrower),
            s_collateralToken.balanceOf(s_borrower)
        );

        RepayAmounts memory adjustments = RepayAmounts(
            stableFees,
            stablesOwed,
            riskTranchePayout,
            collateralAmount
        );

        vm.startPrank(s_borrower);
        s_IBOLoanRouter.repayAndUnwrapMature(
            s_deployedIBOB,
            stablesOwed,
            stableFees,
            riskTranchePayout
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function testRepayMaxAndUnwrapMature(
        uint256 debtSlipAmount,
        uint256 data,
        uint256 time
    ) public {
        initialSetup(data, time, true);

        debtSlipAmount = bound(
            debtSlipAmount,
            Math.max(
                1e6,
                ((10**s_collateralDecimals) * s_riskRatio) / s_safeRatio
            ),
            s_debtSlip.balanceOf(s_borrower)
        );

        (
            uint256 collateralAmount,
            uint256 stablesOwed,
            uint256 stableFees,

        ) = s_IBOLens.viewRepayMaxAndUnwrapMature(
                s_deployedIBOB,
                debtSlipAmount
            );

        s_stableToken.mint(s_borrower, stablesOwed + stableFees);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_debtSlip.balanceOf(s_borrower),
            s_collateralToken.balanceOf(s_borrower)
        );

        RepayAmounts memory adjustments = RepayAmounts(
            stableFees,
            stablesOwed,
            debtSlipAmount,
            collateralAmount
        );

        vm.startPrank(s_borrower);
        s_IBOLoanRouter.repayAndUnwrapMature(
            s_deployedIBOB,
            stablesOwed,
            stableFees,
            debtSlipAmount
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RepayAmounts memory adjustments
    ) internal {
        assertApproxEqRel(
            before.borrowerStables -
                adjustments.stablesFee -
                adjustments.stablesOwed,
            s_stableToken.balanceOf(s_borrower),
            1e15
        );

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
