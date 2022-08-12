// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract Repay is CBBSetup {
    struct BeforeBalances {
        uint256 borrowerStables;
        uint256 borrowerSafeTranche;
        uint256 borrowerRiskSlip;
        uint256 borrowerRiskTranche;
        uint256 ownerStables;
        uint256 CBBSafeTranche;
        uint256 CBBRiskTranche;
        uint256 CBBStables;
    }

    struct RepayAmounts {
        uint256 stablesFee;
        uint256 stablesRepaid;
        uint256 riskSlipAmount;
        uint256 safeTranchePayout;
        uint256 riskTranchePayout;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function initialSetup() internal {
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_initialPrice);

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

    function testCannotRepayMinimumInput(uint256 riskSlipAmount) public {
        initialSetup();
        riskSlipAmount = bound(riskSlipAmount, 0, 1e6 - 1);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            riskSlipAmount,
            1e6
        );
        vm.prank(s_borrower);
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.repay(riskSlipAmount);
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
            (s_safeSlip.balanceOf(s_lender) * (10**s_stableDecimals)) /
                (10**s_collateralDecimals)
        );

        time = bound(time, block.timestamp, s_endOfUnixTime);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_safeTranche.balanceOf(s_borrower),
            s_riskSlip.balanceOf(s_borrower),
            s_riskTranche.balanceOf(s_borrower),
            s_stableToken.balanceOf(s_cbb_owner),
            s_safeTranche.balanceOf(s_deployedCBBAddress),
            s_riskTranche.balanceOf(s_deployedCBBAddress),
            s_stableToken.balanceOf(s_deployedCBBAddress)
        );

        uint256 maxStablesOwed = (before.borrowerRiskSlip *
            s_deployedConvertibleBondBox.safeRatio() *
            s_deployedConvertibleBondBox.currentPrice() *
            s_deployedConvertibleBondBox.stableDecimals()) /
            s_deployedConvertibleBondBox.riskRatio() /
            s_deployedConvertibleBondBox.s_priceGranularity() /
            s_deployedConvertibleBondBox.trancheDecimals();

        stableAmount = bound(stableAmount, 1e6, maxStablesOwed);

        uint256 stableFees = (stableAmount * fee) / s_BPS;

        uint256 riskSlipAmount = (stableAmount *
            s_deployedConvertibleBondBox.s_priceGranularity() *
            s_deployedConvertibleBondBox.trancheDecimals() *
            s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.currentPrice() /
            s_deployedConvertibleBondBox.stableDecimals() /
            s_deployedConvertibleBondBox.safeRatio();

        RepayAmounts memory adjustments = RepayAmounts(
            stableFees,
            stableAmount,
            riskSlipAmount,
            (riskSlipAmount * s_safeRatio) / s_riskRatio,
            riskSlipAmount
        );

        vm.startPrank(s_borrower);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit Repay(
            s_borrower,
            stableAmount,
            riskSlipAmount,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.repay(stableAmount);
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function testRepayMax(
        uint256 time,
        uint256 fee,
        uint256 riskSlipAmount
    ) public {
        initialSetup();

        fee = bound(fee, 0, s_maxFeeBPS);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.setFee(fee);

        s_stableToken.mint(
            s_borrower,
            (s_safeSlip.balanceOf(s_lender) * (10**s_stableDecimals)) /
                (10**s_collateralDecimals)
        );

        time = bound(time, block.timestamp, s_endOfUnixTime);

        BeforeBalances memory before = BeforeBalances(
            s_stableToken.balanceOf(s_borrower),
            s_safeTranche.balanceOf(s_borrower),
            s_riskSlip.balanceOf(s_borrower),
            s_riskTranche.balanceOf(s_borrower),
            s_stableToken.balanceOf(s_cbb_owner),
            s_safeTranche.balanceOf(s_deployedCBBAddress),
            s_riskTranche.balanceOf(s_deployedCBBAddress),
            s_stableToken.balanceOf(s_deployedCBBAddress)
        );

        riskSlipAmount = bound(riskSlipAmount, 1e6, before.borrowerRiskSlip);

        uint256 stablesOwed = (riskSlipAmount *
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
            riskSlipAmount,
            (riskSlipAmount * s_safeRatio) / s_riskRatio,
            riskSlipAmount
        );

        vm.startPrank(s_borrower);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit Repay(
            s_borrower,
            stablesOwed,
            riskSlipAmount,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.repayMax(riskSlipAmount);
        vm.stopPrank();

        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RepayAmounts memory adjustments
    ) internal {
        assertEq(
            before.borrowerStables -
                adjustments.stablesRepaid -
                adjustments.stablesFee,
            s_stableToken.balanceOf(s_borrower)
        );

        assertEq(
            before.borrowerSafeTranche + adjustments.safeTranchePayout,
            s_safeTranche.balanceOf(s_borrower)
        );

        assertEq(
            before.borrowerRiskSlip - adjustments.riskSlipAmount,
            s_riskSlip.balanceOf(s_borrower)
        );

        assertEq(
            before.borrowerRiskTranche + adjustments.riskTranchePayout,
            s_riskTranche.balanceOf(s_borrower)
        );

        assertEq(
            before.ownerStables + adjustments.stablesFee,
            s_stableToken.balanceOf(s_cbb_owner)
        );

        assertEq(
            before.CBBSafeTranche - adjustments.safeTranchePayout,
            s_safeTranche.balanceOf(s_deployedCBBAddress)
        );

        assertEq(
            before.CBBRiskTranche - adjustments.riskTranchePayout,
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );

        assertEq(
            before.CBBStables + adjustments.stablesRepaid,
            s_stableToken.balanceOf(s_deployedCBBAddress)
        );
    }
}
