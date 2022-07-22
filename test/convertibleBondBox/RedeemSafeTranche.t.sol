// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../src/contracts/Slip.sol";
import "../../src/contracts/SlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
import "./CBBSetup.sol";

contract RedeemSafeTranche is CBBSetup {
    //redeemSafeTranche()

    function testRedeemSafeTranche(uint256 amount, uint256 time) public {
        time = bound(time, s_maturityDate, s_endOfUnixTime);

        amount = bound(
            amount,
            s_safeRatio,
            s_safeTranche.balanceOf(s_cbb_owner)
        );

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(address(1), address(2), amount);

        uint256 safeSlipBalanceBeforeRedeem = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(2));
        uint256 safeTrancheUserBalanceBeforeRedeem = s_deployedConvertibleBondBox
                .safeTranche()
                .balanceOf(address(2));
        uint256 riskTrancheUserBalanceBeforeRedeem = s_deployedConvertibleBondBox
                .riskTranche()
                .balanceOf(address(2));

        uint256 safeTrancheCBBBalanceBeforeRedeem = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));
        uint256 riskTrancheCBBBalanceBeforeRedeem = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));

        uint256 zPenaltyTotal = IERC20(
            address(s_deployedConvertibleBondBox.riskTranche())
        ).balanceOf(address(s_deployedConvertibleBondBox)) -
            s_deployedConvertibleBondBox.riskSlip().totalSupply();

        uint256 safeSlipSupply = s_deployedConvertibleBondBox
            .safeSlip()
            .totalSupply();

        uint256 riskTranchePayout = (amount * zPenaltyTotal) /
            (safeSlipSupply - s_deployedConvertibleBondBox.s_repaidSafeSlips());

        vm.warp(time);
        vm.startPrank(address(2));
        vm.expectEmit(true, true, true, true);
        emit RedeemSafeTranche(address(2), amount);
        s_deployedConvertibleBondBox.redeemSafeTranche(amount);

        redeemSafeTrancheAsserts(
            safeSlipBalanceBeforeRedeem,
            amount,
            safeTrancheUserBalanceBeforeRedeem,
            safeTrancheCBBBalanceBeforeRedeem,
            riskTrancheUserBalanceBeforeRedeem,
            riskTranchePayout,
            riskTrancheCBBBalanceBeforeRedeem
        );
    }

    function redeemSafeTrancheAsserts(
        uint256 safeSlipBalanceBeforeRedeem,
        uint256 amount,
        uint256 safeTrancheUserBalanceBeforeRedeem,
        uint256 safeTrancheCBBBalanceBeforeRedeem,
        uint256 riskTrancheUserBalanceBeforeRedeem,
        uint256 riskTranchePayout,
        uint256 riskTrancheCBBBalanceBeforeRedeem
    ) private {
        uint256 safeSlipBalanceAfterRedeem = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(2));
        uint256 safeTrancheUserBalanceAfterRedeem = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(address(2));
        uint256 riskTrancheUserBalanceAfterRedeem = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(address(2));

        uint256 safeTrancheCBBBalanceAfterRedeem = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));
        uint256 riskTrancheCBBBalanceAfterRedeem = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(
            safeSlipBalanceBeforeRedeem - amount,
            safeSlipBalanceAfterRedeem
        );

        assertEq(
            safeTrancheUserBalanceBeforeRedeem + amount,
            safeTrancheUserBalanceAfterRedeem
        );
        assertEq(
            safeTrancheCBBBalanceBeforeRedeem - amount,
            safeTrancheCBBBalanceAfterRedeem
        );

        assertEq(
            riskTrancheUserBalanceBeforeRedeem + riskTranchePayout,
            riskTrancheUserBalanceAfterRedeem
        );
        assertEq(
            riskTrancheCBBBalanceBeforeRedeem - riskTranchePayout,
            riskTrancheCBBBalanceAfterRedeem
        );
    }

    function testCannotRedeemSafeTrancheBondNotMatureYet(uint256 time) public {
        time = bound(time, 1, s_maturityDate);
        vm.warp(s_maturityDate - time);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        bytes memory customError = abi.encodeWithSignature(
            "BondNotMatureYet(uint256,uint256)",
            s_maturityDate,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemSafeTranche(s_safeSlipAmount);
    }

    function testCannotRedeemSafeTrancheMinimumInput(uint256 safeSlipAmount)
        public
    {
        safeSlipAmount = bound(
            safeSlipAmount,
            0,
            s_deployedConvertibleBondBox.safeRatio() - 1
        );

        vm.warp(s_maturityDate);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            safeSlipAmount,
            s_deployedConvertibleBondBox.safeRatio()
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipAmount);
    }

    function testRedeemSafeTrancheSendsFeeToOwner(
        uint256 depositAmount,
        uint256 safeSlipAmount,
        uint256 fee
    ) public {
        address borrower = address(1);
        address lender = address(2);

        fee = bound(fee, 0, s_maxFeeBPS);
        depositAmount = bound(
            depositAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(s_cbb_owner)
        );

        vm.warp(s_maturityDate);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(borrower, lender, depositAmount);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        safeSlipAmount = bound(
            safeSlipAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_deployedConvertibleBondBox.safeSlip().balanceOf(lender)
        );

        uint256 ownerSafeSlipBalanceBeforeRedeem = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(s_deployedConvertibleBondBox.owner());

        uint256 feeSlipAmount = (safeSlipAmount *
            s_deployedConvertibleBondBox.feeBps()) / s_BPS;

        vm.startPrank(lender);
        s_deployedConvertibleBondBox.safeSlip().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipAmount);
        vm.stopPrank();

        uint256 ownerSafeSlipBalanceAfterRedeem = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(s_deployedConvertibleBondBox.owner());

        assertEq(
            ownerSafeSlipBalanceBeforeRedeem + feeSlipAmount,
            ownerSafeSlipBalanceAfterRedeem
        );
    }

    function testRedeemSafeTrancheBurnsSafeSlipAmountFromMsgSender(
        uint256 depositAmount,
        uint256 safeSlipAmount,
        uint256 fee
    ) public {
        address borrower = address(1);
        address lender = address(2);

        fee = bound(fee, 0, s_maxFeeBPS);
        depositAmount = bound(
            depositAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(s_cbb_owner)
        );

        vm.warp(s_maturityDate);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(borrower, lender, depositAmount);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        safeSlipAmount = bound(
            safeSlipAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_deployedConvertibleBondBox.safeSlip().balanceOf(lender)
        );

        uint256 lenderSafeSlipBalanceBeforeRedeem = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(lender);

        vm.startPrank(lender);
        s_deployedConvertibleBondBox.safeSlip().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipAmount);
        vm.stopPrank();

        uint256 lenderSafeSlipBalanceAfterRedeem = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(lender);

        assertEq(
            lenderSafeSlipBalanceBeforeRedeem - safeSlipAmount,
            lenderSafeSlipBalanceAfterRedeem
        );
    }

    function testRedeemSafeTrancheSendsSafeTrancheToMsgSender(
        uint256 depositAmount,
        uint256 safeSlipAmount,
        uint256 fee
    ) public {
        address borrower = address(1);
        address lender = address(2);

        fee = bound(fee, 0, s_maxFeeBPS);
        depositAmount = bound(
            depositAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(s_cbb_owner)
        );

        vm.warp(s_maturityDate);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(borrower, lender, depositAmount);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        safeSlipAmount = bound(
            safeSlipAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_deployedConvertibleBondBox.safeSlip().balanceOf(lender)
        );

        uint256 lenderSafeTrancheBalanceBeforeRedeem = ITranche(
            s_deployedConvertibleBondBox.safeTranche()
        ).balanceOf(lender);
        uint256 CBBSafeTrancheBalanceBeforeRedeem = ITranche(
            s_deployedConvertibleBondBox.safeTranche()
        ).balanceOf(address(s_deployedConvertibleBondBox));

        uint256 feeSlipAmount = (safeSlipAmount *
            s_deployedConvertibleBondBox.feeBps()) / s_BPS;

        vm.startPrank(lender);
        s_deployedConvertibleBondBox.safeSlip().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipAmount);
        vm.stopPrank();

        uint256 lenderSafeTrancheBalanceAfterRedeem = ITranche(
            s_deployedConvertibleBondBox.safeTranche()
        ).balanceOf(lender);
        uint256 CBBSafeTrancheBalanceAfterRedeem = ITranche(
            s_deployedConvertibleBondBox.safeTranche()
        ).balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(
            lenderSafeTrancheBalanceBeforeRedeem +
                safeSlipAmount -
                feeSlipAmount,
            lenderSafeTrancheBalanceAfterRedeem
        );
        assertEq(
            CBBSafeTrancheBalanceBeforeRedeem - safeSlipAmount + feeSlipAmount,
            CBBSafeTrancheBalanceAfterRedeem
        );
    }

    function testRedeemSafeTrancheSendsRiskTrancheToMsgSender(
        uint256 depositAmount,
        uint256 safeSlipAmount,
        uint256 fee
    ) public {
        address borrower = address(1);
        address lender = address(2);

        fee = bound(fee, 0, s_maxFeeBPS);
        depositAmount = bound(
            depositAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(s_cbb_owner)
        );

        vm.warp(s_maturityDate);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(borrower, lender, depositAmount);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        safeSlipAmount = bound(
            safeSlipAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_deployedConvertibleBondBox.safeSlip().balanceOf(lender)
        );

        uint256 lenderRiskTrancheBalanceBeforeRedeem = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(lender);
        uint256 CBBRiskTrancheBalanceBeforeRedeem = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(address(s_deployedConvertibleBondBox));

        uint256 feeSlipAmount = (safeSlipAmount *
            s_deployedConvertibleBondBox.feeBps()) / s_BPS;

        uint256 safeSlipAmountMinusFee = safeSlipAmount - feeSlipAmount;

        uint256 zPenaltyTotal = IERC20(
            address(s_deployedConvertibleBondBox.riskTranche())
        ).balanceOf(address(s_deployedConvertibleBondBox)) -
            s_deployedConvertibleBondBox.riskSlip().totalSupply();

        uint256 safeSlipSupply = s_deployedConvertibleBondBox
            .safeSlip()
            .totalSupply();

        uint256 riskTrancheTransferAmount = (safeSlipAmountMinusFee *
            zPenaltyTotal) /
            (safeSlipSupply - s_deployedConvertibleBondBox.s_repaidSafeSlips());

        vm.startPrank(lender);
        s_deployedConvertibleBondBox.safeSlip().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipAmount);
        vm.stopPrank();

        uint256 lenderRiskTrancheBalanceAfterRedeem = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(lender);
        uint256 CBBRiskTrancheBalanceAfterRedeem = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(
            lenderRiskTrancheBalanceBeforeRedeem + riskTrancheTransferAmount,
            lenderRiskTrancheBalanceAfterRedeem
        );
        assertEq(
            CBBRiskTrancheBalanceBeforeRedeem - riskTrancheTransferAmount,
            CBBRiskTrancheBalanceAfterRedeem
        );
    }

    function testRedeemSafeTrancheEmitsRedeemSafeTranche(
        uint256 depositAmount,
        uint256 safeSlipAmount,
        uint256 fee
    ) public {
        address borrower = address(1);
        address lender = address(2);

        fee = bound(fee, 0, s_maxFeeBPS);
        depositAmount = bound(
            depositAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(s_cbb_owner)
        );

        vm.warp(s_maturityDate);
        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(borrower, lender, depositAmount);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        safeSlipAmount = bound(
            safeSlipAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_deployedConvertibleBondBox.safeSlip().balanceOf(lender)
        );

        uint256 feeSlipAmount = (safeSlipAmount *
            s_deployedConvertibleBondBox.feeBps()) / s_BPS;
        uint256 safeSlipAmountMinusFee = safeSlipAmount - feeSlipAmount;

        vm.startPrank(lender);
        s_deployedConvertibleBondBox.safeSlip().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        vm.expectEmit(true, true, true, true);
        emit RedeemSafeTranche(lender, safeSlipAmountMinusFee);
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipAmount);
        vm.stopPrank();
    }
}
