// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract RedeemSafeTranche is CBBSetup {
    struct BeforeBalances {
        uint256 lenderSafeSlip;
        uint256 lenderSafeTranche;
        uint256 lenderRiskTranche;
        uint256 ownerSafeSlip;
        uint256 CBBSafeTranche;
        uint256 CBBRiskTranche;
    }

    struct RedeemAmounts {
        uint256 feeSlip;
        uint256 safeSlipAmount;
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

    function testCannotRedeemSafeTrancheMinimumInput(uint256 safeSlipAmount)
        public
    {
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        vm.warp(s_maturityDate);
        safeSlipAmount = bound(safeSlipAmount, 0, 1e6 - 1);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            safeSlipAmount,
            1e6
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipAmount);
    }

    function testRedeemSafeTranche(
        uint256 safeSlipRedeemAmount,
        uint256 issuerSlipRedeemAmount,
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
            issuerSlipRedeemAmount = bound(
                issuerSlipRedeemAmount,
                1e6,
                s_issuerSlip.balanceOf(address(s_borrower))
            );
            vm.startPrank(s_borrower);
            s_issuerSlip.approve(s_deployedCBBAddress, type(uint256).max);
            s_deployedConvertibleBondBox.redeemRiskTranche(
                issuerSlipRedeemAmount
            );
            vm.stopPrank();
        }

        // check balances
        BeforeBalances memory before = BeforeBalances(
            s_safeSlip.balanceOf(s_lender),
            s_safeTranche.balanceOf(s_lender),
            s_riskTranche.balanceOf(s_lender),
            s_safeSlip.balanceOf(s_cbb_owner),
            s_safeTranche.balanceOf(s_deployedCBBAddress),
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );

        // calculate amounts

        safeSlipRedeemAmount = bound(
            safeSlipRedeemAmount,
            1e6,
            before.lenderSafeSlip
        );

        uint256 feeSlip = (safeSlipRedeemAmount * fee) / s_BPS;
        uint256 zTranchePayout = ((safeSlipRedeemAmount - feeSlip) *
            (before.CBBRiskTranche - s_issuerSlip.totalSupply())) /
            (s_safeSlip.totalSupply() -
                s_deployedConvertibleBondBox.s_repaidSafeSlips());

        RedeemAmounts memory adjustments = RedeemAmounts(
            feeSlip,
            safeSlipRedeemAmount,
            zTranchePayout
        );

        // do the safeTrancheRedeem
        vm.startPrank(s_lender);
        s_safeSlip.approve(s_deployedCBBAddress, type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit RedeemSafeTranche(address(2), safeSlipRedeemAmount - feeSlip);
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipRedeemAmount);
        vm.stopPrank();

        // check assertions
        assertions(before, adjustments);
    }

    function assertions(
        BeforeBalances memory before,
        RedeemAmounts memory adjustments
    ) internal {
        assertEq(
            before.lenderSafeSlip - adjustments.safeSlipAmount,
            s_safeSlip.balanceOf(s_lender)
        );

        assertEq(
            before.lenderSafeTranche +
                adjustments.safeSlipAmount -
                adjustments.feeSlip,
            s_safeTranche.balanceOf(s_lender)
        );

        assertEq(
            before.lenderRiskTranche + adjustments.penaltyTrancheAmount,
            s_riskTranche.balanceOf(s_lender)
        );

        assertEq(
            before.ownerSafeSlip + adjustments.feeSlip,
            s_safeSlip.balanceOf(s_cbb_owner)
        );

        assertEq(
            before.CBBSafeTranche -
                adjustments.safeSlipAmount +
                adjustments.feeSlip,
            s_safeTranche.balanceOf(s_deployedCBBAddress)
        );

        assertEq(
            before.CBBRiskTranche - adjustments.penaltyTrancheAmount,
            s_riskTranche.balanceOf(s_deployedCBBAddress)
        );
    }
}
