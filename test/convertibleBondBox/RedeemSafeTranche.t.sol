// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../src/contracts/CBBSlip.sol";
import "../../src/contracts/CBBSlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
import "./CBBSetup.sol";

contract RedeemSafeTranche is CBBSetup {
    //redeemSafeTranche()

    function testRedeemSafeTranche(
        uint256 amount,
        uint256 time,
        uint256 collateralAmount
    ) public {
        (ITranche safeTranche, uint256 ratio) = s_buttonWoodBondController
            .tranches(0);
        // If the below line is commented out, we get an arithmatic underflow/overflow error. Why?
        time = bound(time, 0, s_endOfUnixTime - s_maturityDate);

        //TODO see if there is a way to increase s_depositLimit to 1e18 or close in this test.
        amount = bound(
            amount,
            s_safeRatio,
            s_safeTranche.balanceOf(address(this))
        );

        vm.warp(s_maturityDate + time);

        vm.prank(address(this));
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            amount, 
            0,
            address(100)
        );

        uint256 safeSlipBalanceBeforeRedeem = CBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(2));
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

        uint256 safeTrancheBalance = IERC20(
            address(s_deployedConvertibleBondBox.safeTranche())
        ).balanceOf(address(2));

        uint256 zPenaltyTotal = IERC20(
            address(s_deployedConvertibleBondBox.riskTranche())
        ).balanceOf(address(s_deployedConvertibleBondBox)) -
            IERC20(s_deployedConvertibleBondBox.s_riskSlipTokenAddress())
                .totalSupply();

        uint256 safeSlipSupply = ICBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).totalSupply();

        uint256 riskTranchePayout = (amount * zPenaltyTotal) /
            (safeSlipSupply - s_deployedConvertibleBondBox.s_repaidSafeSlips());
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
        uint256 safeSlipBalanceAfterRedeem = CBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(2));
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
        vm.assume(time <= s_maturityDate && time != 0);
        vm.warp(s_maturityDate - time);
        vm.prank(address(this));
        emit Initialized(address(1), address(2), 0, s_depositLimit);

        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0,
            address(100)
        );
        vm.startPrank(s_deployedCBBAddress);
        CBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).mint(
            address(this),
            1e18
        );
        vm.stopPrank();
        bytes memory customError = abi.encodeWithSignature(
            "BondNotMatureYet(uint256,uint256)",
            s_maturityDate,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemSafeTranche(s_safeSlipAmount);
    }
}