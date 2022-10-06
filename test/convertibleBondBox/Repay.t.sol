// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract Repay is CBBSetup {
    struct BeforeBalances {
        uint256 borrowerStables;
        uint256 borrowerSafeTranche;
        uint256 borrowerIssuerSlip;
        uint256 borrowerRiskTranche;
        uint256 ownerStables;
        uint256 CBBSafeTranche;
        uint256 CBBRiskTranche;
        uint256 CBBStables;
        uint256 repaidBondSlips;
    }

    struct RepayAmounts {
        uint256 stablesFee;
        uint256 stablesRepaid;
        uint256 issuerSlipAmount;
        uint256 safeTranchePayout;
        uint256 riskTranchePayout;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function initialSetup() internal {
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        uint256 stablesToTranches = (s_stableToken.balanceOf(address(this)) *
            s_deployedConvertibleBondBox.s_priceGranularity() *
            s_deployedConvertibleBondBox.trancheDecimals()) /
            s_deployedConvertibleBondBox.currentPrice() /
            s_deployedConvertibleBondBox.stableDecimals();

        s_deployedConvertibleBondBox.borrow(
            s_borrower,
            s_lender,
            Math.min(s_safeTranche.balanceOf(address(this)), stablesToTranches)
        );
    }

    function testCannotRepayConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.prank(s_borrower);
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.repay(1e6);
    }

    function testCannotRepayMaxConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );

        uint256 issuerSlipAmount = s_issuerSlip.balanceOf(s_borrower);

        vm.prank(s_borrower);
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.repayMax(issuerSlipAmount);
    }

    function testCannotRepayMinimumInput(uint256 issuerSlipAmount) public {
        initialSetup();
        issuerSlipAmount = bound(issuerSlipAmount, 0, 1e6 - 1);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            issuerSlipAmount,
            1e6
        );
        vm.prank(s_borrower);
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.repay(issuerSlipAmount);
    }

    function testRepay(
        uint256 time,
        uint256 fee,
        uint256 stableAmount
    ) public {
        initialSetup();

        fee = bound(fee, 0, s_maxFeeBPS);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.setFee(fee);

        s_stableToken.mint(
            s_borrower,
            (s_bondSlip.balanceOf(s_lender) * (10**s_stableDecimals)) /
                (10**s_collateralDecimals)
        );

        time = bound(time, block.timestamp, s_endOfUnixTime);

        vm.warp(time);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_safeTranche.balanceOf(s_borrower),
            s_issuerSlip.balanceOf(s_borrower),
            s_riskTranche.balanceOf(s_borrower),
            s_stableToken.balanceOf(s_cbb_owner),
            s_safeTranche.balanceOf(s_deployedCBBAddress),
            s_riskTranche.balanceOf(s_deployedCBBAddress),
            s_stableToken.balanceOf(s_deployedCBBAddress),
            s_deployedConvertibleBondBox.s_repaidBondSlips()
        );

        uint256 maxStablesOwed = (before.borrowerIssuerSlip *
            s_deployedConvertibleBondBox.safeRatio() *
            s_deployedConvertibleBondBox.currentPrice() *
            s_deployedConvertibleBondBox.stableDecimals()) /
            s_deployedConvertibleBondBox.riskRatio() /
            s_deployedConvertibleBondBox.s_priceGranularity() /
            s_deployedConvertibleBondBox.trancheDecimals();

        stableAmount = bound(stableAmount, 1e6, maxStablesOwed);

        uint256 stableFees = (stableAmount * fee) / s_BPS;

        uint256 safeTranchePayout = (stableAmount *
            s_deployedConvertibleBondBox.s_priceGranularity() *
            s_deployedConvertibleBondBox.trancheDecimals()) /
            s_deployedConvertibleBondBox.currentPrice() /
            s_deployedConvertibleBondBox.stableDecimals();

        RepayAmounts memory adjustments = RepayAmounts(
            stableFees,
            stableAmount,
            (safeTranchePayout * s_riskRatio) / s_safeRatio,
            safeTranchePayout,
            (safeTranchePayout * s_riskRatio) / s_safeRatio
        );

        vm.startPrank(s_borrower);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit Repay(
            s_borrower,
            stableAmount,
            (safeTranchePayout * s_riskRatio) / s_safeRatio,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.repay(stableAmount);
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function testRepayMax(
        uint256 time,
        uint256 fee,
        uint256 issuerSlipAmount
    ) public {
        initialSetup();

        fee = bound(fee, 0, s_maxFeeBPS);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.setFee(fee);

        s_stableToken.mint(
            s_borrower,
            (s_bondSlip.balanceOf(s_lender) * (10**s_stableDecimals)) /
                (10**s_collateralDecimals)
        );

        time = bound(time, block.timestamp, s_endOfUnixTime);

        vm.warp(time);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_safeTranche.balanceOf(s_borrower),
            s_issuerSlip.balanceOf(s_borrower),
            s_riskTranche.balanceOf(s_borrower),
            s_stableToken.balanceOf(s_cbb_owner),
            s_safeTranche.balanceOf(s_deployedCBBAddress),
            s_riskTranche.balanceOf(s_deployedCBBAddress),
            s_stableToken.balanceOf(s_deployedCBBAddress),
            s_deployedConvertibleBondBox.s_repaidBondSlips()
        );

        issuerSlipAmount = bound(
            issuerSlipAmount,
            1e6,
            before.borrowerIssuerSlip
        );

        uint256 stablesOwed = (issuerSlipAmount *
            s_deployedConvertibleBondBox.safeRatio() *
            s_deployedConvertibleBondBox.currentPrice() *
            s_deployedConvertibleBondBox.stableDecimals()) /
            s_deployedConvertibleBondBox.riskRatio() /
            s_deployedConvertibleBondBox.s_priceGranularity() /
            s_deployedConvertibleBondBox.trancheDecimals();

        uint256 stableFees = (stablesOwed * fee) / s_BPS;

        RepayAmounts memory adjustments = RepayAmounts(
            stableFees,
            stablesOwed,
            issuerSlipAmount,
            (issuerSlipAmount * s_safeRatio) / s_riskRatio,
            issuerSlipAmount
        );

        vm.startPrank(s_borrower);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);
        vm.expectEmit(true, true, true, false);
        emit Repay(
            s_borrower,
            stablesOwed,
            issuerSlipAmount,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.repayMax(issuerSlipAmount);
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RepayAmounts memory adjustments
    ) internal {
        assertApproxEqRel(
            before.borrowerStables -
                adjustments.stablesRepaid -
                adjustments.stablesFee,
            s_stableToken.balanceOf(s_borrower),
            1e15
        );

        assertApproxEqRel(
            before.borrowerSafeTranche + adjustments.safeTranchePayout,
            s_safeTranche.balanceOf(s_borrower),
            1e15
        );

        assertApproxEqRel(
            before.borrowerIssuerSlip - adjustments.issuerSlipAmount,
            s_issuerSlip.balanceOf(s_borrower),
            1e15
        );

        assertApproxEqRel(
            before.borrowerRiskTranche + adjustments.riskTranchePayout,
            s_riskTranche.balanceOf(s_borrower),
            1e15
        );

        assertApproxEqRel(
            before.ownerStables + adjustments.stablesFee,
            s_stableToken.balanceOf(s_cbb_owner),
            1e15
        );

        assertApproxEqRel(
            before.CBBSafeTranche - adjustments.safeTranchePayout,
            s_safeTranche.balanceOf(s_deployedCBBAddress),
            1e15
        );

        assertApproxEqRel(
            before.CBBRiskTranche - adjustments.riskTranchePayout,
            s_riskTranche.balanceOf(s_deployedCBBAddress),
            1e15
        );

        assertApproxEqRel(
            before.CBBStables + adjustments.stablesRepaid,
            s_stableToken.balanceOf(s_deployedCBBAddress),
            1e15
        );

        assertApproxEqRel(
            before.repaidBondSlips + adjustments.safeTranchePayout,
            s_deployedConvertibleBondBox.s_repaidBondSlips(),
            1e15
        );
    }
}
