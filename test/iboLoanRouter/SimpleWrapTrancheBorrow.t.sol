pragma solidity 0.8.13;

import "./IBOLoanRouterSetup.t.sol";

contract SimpleWrapTrancheBorrow is IBOLoanRouterSetup {
    struct BeforeBalances {
        uint256 borrowerCollateral;
        uint256 borrowerBorrowSlip;
        uint256 SBSafeTranche;
        uint256 SBRiskTranche;
    }

    struct BorrowAmounts {
        uint256 safeTrancheAmount;
        uint256 riskTrancheAmount;
        uint256 stableAmount;
        uint256 collateralAmount;
    }

    function testSimpleWrapTrancheBorrow(uint256 collateralAmount, uint256 data)
        public
    {
        collateralAmount = bound(
            collateralAmount,
            Math.max(1e6, 10**s_collateralDecimals),
            s_collateralToken.balanceOf(s_borrower)
        );

        data = bound(
            data,
            (s_initMockData * 9) / 10,
            (s_initMockData * 11) / 10
        );

        s_mockOracle.setData(data, true);

        (uint256 loanAmount, uint256 safeTrancheAmount) = s_SBLens
            .viewSimpleWrapTrancheBorrow(s_deployedSB, collateralAmount);

        BeforeBalances memory before = BeforeBalances(
            s_collateralToken.balanceOf(s_borrower),
            s_borrowSlip.balanceOf(s_borrower),
            s_safeTranche.balanceOf(s_deployedSBAddress),
            s_riskTranche.balanceOf(s_deployedSBAddress)
        );

        BorrowAmounts memory adjustments = BorrowAmounts(
            safeTrancheAmount,
            (safeTrancheAmount * s_riskRatio) / s_safeRatio,
            loanAmount,
            collateralAmount
        );

        vm.prank(s_borrower);
        s_IBOLoanRouter.simpleWrapTrancheBorrow(
            s_deployedSB,
            collateralAmount,
            (loanAmount * 95) / 100
        );

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        BorrowAmounts memory adjustments
    ) internal {
        assertApproxEqRel(
            before.borrowerCollateral - adjustments.collateralAmount,
            s_collateralToken.balanceOf(s_borrower),
            1e15
        );

        assertApproxEqRel(
            before.borrowerBorrowSlip + adjustments.stableAmount,
            s_borrowSlip.balanceOf(s_borrower),
            1e15
        );

        assertApproxEqRel(
            before.SBSafeTranche + adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(s_deployedSBAddress),
            1e15
        );

        assertApproxEqRel(
            before.SBRiskTranche + adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(s_deployedSBAddress),
            1e15
        );
    }
}
