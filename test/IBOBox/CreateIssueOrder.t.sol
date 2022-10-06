pragma solidity 0.8.13;

import "./iboBoxSetup.t.sol";

contract CreateIssueOrder is iboBoxSetup {
    struct BeforeBalances {
        uint256 borrowerIssueOrders;
        uint256 routerSafeTranche;
        uint256 routerRiskTranche;
        uint256 IBOSafeTranche;
        uint256 IBORiskTranche;
    }

    struct BorrowAmounts {
        uint256 safeTrancheAmount;
        uint256 riskTrancheAmount;
        uint256 issueOrderAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testCannotCreateIssueOrderCBBNotActivated() public {
        setupIBOBox(0);

        vm.prank(s_deployedIBOBAddress);
        s_deployedConvertibleBondBox.activate(5);

        bytes memory customError = abi.encodeWithSignature(
            "CBBActivated(bool,bool)",
            true,
            false
        );
        vm.expectRevert(customError);
        s_deployedIBOB.createIssueOrder(s_borrower, 1);
    }

    function testCreateIssueOrder(uint256 _fuzzPrice, uint256 _borrowAmount)
        public
    {
        setupIBOBox(_fuzzPrice);

        BeforeBalances memory before = BeforeBalances(
            s_issueOrder.balanceOf(s_borrower),
            s_safeTranche.balanceOf(address(this)),
            s_riskTranche.balanceOf(address(this)),
            s_safeTranche.balanceOf(s_deployedIBOBAddress),
            s_riskTranche.balanceOf(s_deployedIBOBAddress)
        );

        uint256 maxBorrowAmount = (before.routerSafeTranche *
            s_deployedIBOB.initialPrice() *
            s_deployedIBOB.stableDecimals()) /
            s_deployedIBOB.priceGranularity() /
            s_deployedIBOB.trancheDecimals();

        _borrowAmount = bound(_borrowAmount, 1, maxBorrowAmount);

        uint256 safeTrancheAmount = (_borrowAmount *
            s_deployedIBOB.priceGranularity() *
            s_deployedIBOB.trancheDecimals()) /
            s_deployedIBOB.initialPrice() /
            s_deployedIBOB.stableDecimals();

        BorrowAmounts memory adjustments = BorrowAmounts(
            safeTrancheAmount,
            (safeTrancheAmount * s_riskRatio) / s_safeRatio,
            _borrowAmount
        );

        vm.expectEmit(true, true, true, true);
        emit IssueOrderCreated(s_borrower, _borrowAmount);
        s_deployedIBOB.createIssueOrder(s_borrower, _borrowAmount);

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        BorrowAmounts memory adjustments
    ) internal {
        assertEq(
            before.routerSafeTranche - adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(address(this))
        );

        assertEq(
            before.routerRiskTranche - adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(address(this))
        );

        assertEq(
            before.IBOSafeTranche + adjustments.safeTrancheAmount,
            s_safeTranche.balanceOf(s_deployedIBOBAddress)
        );

        assertEq(
            before.IBORiskTranche + adjustments.riskTrancheAmount,
            s_riskTranche.balanceOf(s_deployedIBOBAddress)
        );

        assertEq(
            before.borrowerIssueOrders + adjustments.issueOrderAmount,
            s_issueOrder.balanceOf(s_borrower)
        );
    }
}
