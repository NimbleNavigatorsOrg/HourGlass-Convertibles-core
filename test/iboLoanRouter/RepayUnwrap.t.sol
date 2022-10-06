pragma solidity 0.8.13;

import "./IBOLoanRouterSetup.t.sol";

contract RepayUnwrap is IBOLoanRouterSetup {
    struct BeforeBalances {
        uint256 borrowerStables;
        uint256 borrowerRiskSlip;
        uint256 borrowerCollateral;
    }

    struct RepayAmounts {
        uint256 stablesFee;
        uint256 stablesOwed;
        uint256 riskSlipAmount;
        uint256 collateralAmount;
    }

    function initialSetup(
        uint256 data,
        uint256 time,
        bool isMature
    ) internal {
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
            (s_stableToken.balanceOf(s_lender) * 4) / 5
        );
        vm.stopPrank();

        vm.startPrank(s_cbb_owner);
        s_deployedSB.transmitReInit(
            s_SBLens.viewTransmitReInitBool(s_deployedSB)
        );
        vm.stopPrank();

        vm.startPrank(s_borrower);
        s_deployedSB.redeemBorrowSlip(s_borrowSlip.balanceOf(s_borrower));
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
        uint256 riskSlipAmount,
        uint256 data,
        uint256 time
    ) public {
        initialSetup(data, time, false);

        riskSlipAmount = bound(
            riskSlipAmount,
            1e6,
            s_riskSlip.balanceOf(s_borrower)
        );

        (
            uint256 collateralAmount,
            uint256 stablesOwed,
            uint256 stableFees,

        ) = s_SBLens.viewRepayMaxAndUnwrapSimple(s_deployedSB, riskSlipAmount);

        s_stableToken.mint(s_borrower, stablesOwed + stableFees);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_riskSlip.balanceOf(s_borrower),
            s_collateralToken.balanceOf(s_borrower)
        );

        RepayAmounts memory adjustments = RepayAmounts(
            stableFees,
            stablesOwed,
            riskSlipAmount,
            collateralAmount
        );

        vm.startPrank(s_borrower);
        s_IBOLoanRouter.repayMaxAndUnwrapSimple(
            s_deployedSB,
            stablesOwed,
            stableFees,
            riskSlipAmount
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

        uint256 minStablesForSafeTranche = (s_deployedSB.trancheDecimals() *
            s_deployedSB.initialPrice() *
            s_deployedSB.stableDecimals()) /
            s_deployedSB.priceGranularity() /
            s_deployedSB.trancheDecimals();

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
        ) = s_SBLens.viewRepayAndUnwrapSimple(s_deployedSB, stableAmount);

        console2.log(riskTranchePayout, "riskTranchePayout");

        s_stableToken.mint(s_borrower, stablesOwed + stableFees);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_riskSlip.balanceOf(s_borrower),
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
            s_deployedSB,
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
        ) = s_SBLens.viewRepayAndUnwrapMature(s_deployedSB, stableAmount);

        s_stableToken.mint(s_borrower, stablesOwed + stableFees);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_riskSlip.balanceOf(s_borrower),
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
            s_deployedSB,
            stablesOwed,
            stableFees,
            riskTranchePayout
        );
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function testRepayMaxAndUnwrapMature(
        uint256 riskSlipAmount,
        uint256 data,
        uint256 time
    ) public {
        initialSetup(data, time, true);

        riskSlipAmount = bound(
            riskSlipAmount,
            Math.max(
                1e6,
                ((10**s_collateralDecimals) * s_riskRatio) / s_safeRatio
            ),
            s_riskSlip.balanceOf(s_borrower)
        );

        (
            uint256 collateralAmount,
            uint256 stablesOwed,
            uint256 stableFees,

        ) = s_SBLens.viewRepayMaxAndUnwrapMature(s_deployedSB, riskSlipAmount);

        s_stableToken.mint(s_borrower, stablesOwed + stableFees);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_riskSlip.balanceOf(s_borrower),
            s_collateralToken.balanceOf(s_borrower)
        );

        RepayAmounts memory adjustments = RepayAmounts(
            stableFees,
            stablesOwed,
            riskSlipAmount,
            collateralAmount
        );

        vm.startPrank(s_borrower);
        s_IBOLoanRouter.repayAndUnwrapMature(
            s_deployedSB,
            stablesOwed,
            stableFees,
            riskSlipAmount
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
            before.borrowerRiskSlip - adjustments.riskSlipAmount,
            s_riskSlip.balanceOf(s_borrower),
            1e15
        );
    }
}
