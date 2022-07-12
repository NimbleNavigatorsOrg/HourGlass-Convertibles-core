// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../src/contracts/Slip.sol";
import "../../src/contracts/SlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
import "./CBBSetup.sol";
import "../../src/interfaces/ISlip.sol";

contract RedeemRiskTranche is CBBSetup {
    function testCannotRedeemRiskTrancheBondNotMatureYet(
        uint256 time,
        uint256 riskSlipAmount
    ) public {
        time = bound(time, 0, s_maturityDate - 1);

        vm.warp(time);
        bytes memory customError = abi.encodeWithSignature(
            "BondNotMatureYet(uint256,uint256)",
            s_maturityDate,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemRiskTranche(riskSlipAmount);
    }

    function testCannotRedeemRiskTrancheMinimumInput(
        uint256 time,
        uint256 riskSlipAmount
    ) public {
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        riskSlipAmount = bound(
            riskSlipAmount,
            0,
            s_deployedConvertibleBondBox.riskRatio() - 1
        );
        vm.warp(time);

        bytes memory customError = abi.encodeWithSignature(
            "MinimumInput(uint256,uint256)",
            riskSlipAmount,
            s_deployedConvertibleBondBox.riskRatio()
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemRiskTranche(riskSlipAmount);
    }

    function testRedeemRiskTrancheSendsRiskSlipTokenFeeToOwner(
        uint256 time,
        uint256 depositAmount,
        uint256 riskSlipAmountToRedeem,
        uint256 fee
    ) public {
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        depositAmount = bound(
            depositAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_safeTranche.balanceOf(s_deployedConvertibleBondBox.owner())
        );
        fee = bound(fee, 0, s_maxFeeBPS);

        vm.warp(time);

        address borrowerAddress = address(1);
        address lenderAddress = address(2);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.borrow(
            borrowerAddress,
            lenderAddress,
            depositAmount
        );

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        riskSlipAmountToRedeem = bound(
            riskSlipAmountToRedeem,
            s_deployedConvertibleBondBox.riskRatio(),
            s_deployedConvertibleBondBox.riskSlip().balanceOf(borrowerAddress)
        );
        uint256 ownerRiskSlipBalanceBeforeRedeem = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(s_deployedConvertibleBondBox.owner());
        uint256 feeSlip = (riskSlipAmountToRedeem *
            s_deployedConvertibleBondBox.feeBps()) / s_BPS;

        vm.startPrank(borrowerAddress);
        s_deployedConvertibleBondBox.riskSlip().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );

        s_deployedConvertibleBondBox.redeemRiskTranche(riskSlipAmountToRedeem);
        vm.stopPrank();

        uint256 ownerRiskSlipBalanceAfterRedeem = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(s_deployedConvertibleBondBox.owner());

        assertEq(
            ownerRiskSlipBalanceAfterRedeem,
            ownerRiskSlipBalanceBeforeRedeem + feeSlip
        );
    }

    function testRedeemRiskTrancheSendsRiskTrancheFromCBBToMsgSender(
        uint256 time,
        uint256 depositAmount,
        uint256 riskSlipAmountToRedeem,
        uint256 fee
    ) public {
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        depositAmount = bound(
            depositAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_safeTranche.balanceOf(s_cbb_owner)
        );
        fee = bound(fee, 0, s_maxFeeBPS);

        vm.warp(time);

        address borrowerAddress = address(1);
        address lenderAddress = address(2);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.borrow(
            borrowerAddress,
            lenderAddress,
            depositAmount
        );

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        riskSlipAmountToRedeem = bound(
            riskSlipAmountToRedeem,
            s_deployedConvertibleBondBox.riskRatio(),
            s_deployedConvertibleBondBox.riskSlip().balanceOf(borrowerAddress)
        );
        uint256 CBBRiskTrancheBalanceBeforeRedeem = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(address(s_deployedConvertibleBondBox));
        uint256 BorrowerRiskTrancheBalanceBeforeRedeem = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(address(borrowerAddress));

        uint256 feeSlip = (riskSlipAmountToRedeem *
            s_deployedConvertibleBondBox.feeBps()) / s_BPS;

        uint256 riskSlipAmountAfterFee = riskSlipAmountToRedeem - feeSlip;

        uint256 zTranchePayout = (riskSlipAmountAfterFee *
            (s_penaltyGranularity - s_deployedConvertibleBondBox.penalty())) /
            (s_penaltyGranularity);

        vm.startPrank(borrowerAddress);
        s_deployedConvertibleBondBox.riskSlip().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );

        s_deployedConvertibleBondBox.redeemRiskTranche(riskSlipAmountToRedeem);
        vm.stopPrank();

        uint256 CBBRiskTrancheBalanceAfterRedeem = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(address(s_deployedConvertibleBondBox));
        uint256 BorrowerRiskTrancheBalanceAfterRedeem = ITranche(
            s_deployedConvertibleBondBox.riskTranche()
        ).balanceOf(address(borrowerAddress));

        assertEq(
            CBBRiskTrancheBalanceBeforeRedeem - zTranchePayout,
            CBBRiskTrancheBalanceAfterRedeem
        );
        assertEq(
            BorrowerRiskTrancheBalanceBeforeRedeem + zTranchePayout,
            BorrowerRiskTrancheBalanceAfterRedeem
        );
    }

    function testRedeemRiskTrancheBurnsRiskTrancheFromMsgSender(
        uint256 time,
        uint256 depositAmount,
        uint256 riskSlipAmountToRedeem,
        uint256 fee
    ) public {
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        depositAmount = bound(
            depositAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_safeTranche.balanceOf(s_deployedConvertibleBondBox.owner())
        );
        fee = bound(fee, 0, s_maxFeeBPS);

        vm.warp(time);

        address borrowerAddress = address(1);
        address lenderAddress = address(2);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.borrow(
            borrowerAddress,
            lenderAddress,
            depositAmount
        );

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        riskSlipAmountToRedeem = bound(
            riskSlipAmountToRedeem,
            s_deployedConvertibleBondBox.riskRatio(),
            s_deployedConvertibleBondBox.riskSlip().balanceOf(borrowerAddress)
        );
        uint256 BorrowerRiskSlipBalanceBeforeRedeem = s_deployedConvertibleBondBox
                .riskSlip()
                .balanceOf(address(borrowerAddress));

        vm.startPrank(borrowerAddress);
        s_deployedConvertibleBondBox.riskSlip().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );

        s_deployedConvertibleBondBox.redeemRiskTranche(riskSlipAmountToRedeem);
        vm.stopPrank();

        uint256 BorrowerRiskSlipBalanceAfterRedeem = s_deployedConvertibleBondBox
                .riskSlip()
                .balanceOf(address(borrowerAddress));

        assertEq(
            BorrowerRiskSlipBalanceBeforeRedeem - riskSlipAmountToRedeem,
            BorrowerRiskSlipBalanceAfterRedeem
        );
    }

    function testRedeemRiskTrancheEmitsRedeemRiskTranche(
        uint256 time,
        uint256 depositAmount,
        uint256 riskSlipAmountToRedeem,
        uint256 fee
    ) public {
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        depositAmount = bound(
            depositAmount,
            s_deployedConvertibleBondBox.safeRatio(),
            s_safeTranche.balanceOf(s_deployedConvertibleBondBox.owner())
        );
        fee = bound(fee, 0, s_maxFeeBPS);

        vm.warp(time);

        address borrowerAddress = address(1);
        address lenderAddress = address(2);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.borrow(
            borrowerAddress,
            lenderAddress,
            depositAmount
        );

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.setFee(fee);

        riskSlipAmountToRedeem = bound(
            riskSlipAmountToRedeem,
            s_deployedConvertibleBondBox.riskRatio(),
            s_deployedConvertibleBondBox.riskSlip().balanceOf(borrowerAddress)
        );

        uint256 feeSlip = (riskSlipAmountToRedeem *
            s_deployedConvertibleBondBox.feeBps()) / s_BPS;

        uint256 riskSlipAmountAfterFee = riskSlipAmountToRedeem - feeSlip;

        vm.startPrank(borrowerAddress);
        s_deployedConvertibleBondBox.riskSlip().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );

        vm.expectEmit(true, true, true, true);
        emit RedeemRiskTranche(borrowerAddress, riskSlipAmountAfterFee);
        s_deployedConvertibleBondBox.redeemRiskTranche(riskSlipAmountToRedeem);
        vm.stopPrank();
    }
}
