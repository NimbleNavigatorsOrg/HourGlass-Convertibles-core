// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract RedeemSafeTranche is CBBSetup {
    struct BeforeBalances {
        uint256 lenderBondSlip;
        uint256 lenderSafeTranche;
        uint256 lenderRiskTranche;
        uint256 ownerBondSlip;
        uint256 CBBSafeTranche;
        uint256 CBBRiskTranche;
    }

    struct RedeemAmounts {
        uint256 feeSlip;
        uint256 bondSlipAmount;
        uint256 penaltyTrancheAmount;
    }

    address s_borrower = address(1);
    address s_lender = address(2);

    function testCannotRedeemSafeTrancheBondNotMatureYet(uint256 time) public {
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        time = bound(
            time,
            s_deployedConvertibleBondBox.s_startDate(),
            s_maturityDate
        );
        vm.warp(time);

        bytes memory customError = abi.encodeWithSignature(
            "BondNotMatureYet(uint256,uint256)",
            s_maturityDate,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemSafeTranche(1e6);
    }

    function testCannotRedeemSafeTrancheMinimumInput(uint256 bondSlipAmount)
        public
    {
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        vm.warp(s_maturityDate);
        bondSlipAmount = bound(bondSlipAmount, 0, 1e6 - 1);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            bondSlipAmount,
            1e6
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemSafeTranche(bondSlipAmount);
    }

    function testRedeemSafeTranche(
        uint256 bondSlipRedeemAmount,
        uint256 debtSlipRedeemAmount,
        uint256 time,
        uint256 fee
    ) public {
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        //set fee
        fee = bound(fee, 0, s_maxFeeBPS);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.setFee(fee);

        //do a borrow
        time = bound(
            time,
            s_deployedConvertibleBondBox.s_startDate(),
            s_maturityDate
        );
        vm.warp(time);

        {
            uint256 stablesToTranches = (s_stableToken.balanceOf(
                address(this)
            ) *
                s_deployedConvertibleBondBox.s_priceGranularity() *
                s_deployedConvertibleBondBox.trancheDecimals()) /
                s_deployedConvertibleBondBox.currentPrice() /
                s_deployedConvertibleBondBox.stableDecimals();

            s_deployedConvertibleBondBox.borrow(
                s_borrower,
                s_lender,
                Math.min(
                    s_safeTranche.balanceOf(address(this)),
                    stablesToTranches
                )
            );
        }

        //fast forward to maturity
        vm.warp(s_maturityDate + 1);

        // do a riskTrancheRedeem
        {
            debtSlipRedeemAmount = bound(
                debtSlipRedeemAmount,
                1e6,
                s_debtSlip.balanceOf(address(s_borrower))
            );
            vm.startPrank(s_borrower);
            s_debtSlip.approve(s_deployedCBBAddress, type(uint256).max);
            s_deployedConvertibleBondBox.redeemRiskTranche(
                debtSlipRedeemAmount
            );
            vm.stopPrank();
        }

        // check balances
        BeforeBalances memory before = BeforeBalances(
            s_bondSlip.balanceOf(s_lender),
            s_safeTranche.balanceOf(s_lender),
            s_riskTranche.balanceOf(s_lender),
            s_bondSlip.balanceOf(s_cbb_owner),
            s_safeTranche.balanceOf(s_deployedCBBAddress),
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );

        // calculate amounts

        bondSlipRedeemAmount = bound(
            bondSlipRedeemAmount,
            1e6,
            before.lenderBondSlip
        );

        uint256 feeSlip = (bondSlipRedeemAmount * fee) / s_BPS;
        uint256 zTranchePayout = ((bondSlipRedeemAmount - feeSlip) *
            (before.CBBRiskTranche - s_debtSlip.totalSupply())) /
            (s_bondSlip.totalSupply() -
                s_deployedConvertibleBondBox.s_repaidBondSlips());

        RedeemAmounts memory adjustments = RedeemAmounts(
            feeSlip,
            bondSlipRedeemAmount,
            zTranchePayout
        );

        // do the safeTrancheRedeem
        vm.startPrank(s_lender);
        s_bondSlip.approve(s_deployedCBBAddress, type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit RedeemSafeTranche(address(2), bondSlipRedeemAmount - feeSlip);
        s_deployedConvertibleBondBox.redeemSafeTranche(bondSlipRedeemAmount);
        vm.stopPrank();

        // check assertions
        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RedeemAmounts memory adjustments
    ) internal {
        assertEq(
            before.lenderBondSlip - adjustments.bondSlipAmount,
            s_bondSlip.balanceOf(s_lender)
        );

        assertEq(
            before.lenderSafeTranche +
                adjustments.bondSlipAmount -
                adjustments.feeSlip,
            s_safeTranche.balanceOf(s_lender)
        );

        assertEq(
            before.lenderRiskTranche + adjustments.penaltyTrancheAmount,
            s_riskTranche.balanceOf(s_lender)
        );

        assertEq(
            before.ownerBondSlip + adjustments.feeSlip,
            s_bondSlip.balanceOf(s_cbb_owner)
        );

        assertEq(
            before.CBBSafeTranche -
                adjustments.bondSlipAmount +
                adjustments.feeSlip,
            s_safeTranche.balanceOf(s_deployedCBBAddress)
        );

        assertEq(
            before.CBBRiskTranche - adjustments.penaltyTrancheAmount,
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );
    }
}
