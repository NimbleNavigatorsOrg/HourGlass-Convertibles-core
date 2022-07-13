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

contract Reinitialize is CBBSetup {
    function testFailReinitializeNotOwner(uint256 collateralAmount) public {
        collateralAmount = bound(
            collateralAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(address(this))
        );

        uint256 stableAmount = 0;

        vm.prank(address(1));
        s_deployedConvertibleBondBox.reinitialize(s_price);
    }

    function testReinitializeAndBorrowEmitsInitialized(uint256 collateralAmount)
        public
    {
        collateralAmount = bound(
            collateralAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(s_cbb_owner)
        );

        uint256 stableAmount = 0;

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            s_cbb_owner
        );
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            s_cbb_owner
        );

        vm.prank(s_cbb_owner);
        vm.expectEmit(true, true, true, true);
        emit ReInitialized(s_price, block.timestamp);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.borrow(
            address(1),
            address(2),
            collateralAmount
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(
            s_cbb_owner
        );
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(
            s_cbb_owner
        );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(
            address(1)
        );
        uint256 borrowerRiskSlipsAfter = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(2));

        uint256 expectedZ = (collateralAmount * s_ratios[2]) / s_ratios[0];

        uint256 expectedStables = (collateralAmount *
            s_deployedConvertibleBondBox.currentPrice()) / s_priceGranularity;

        assertEq(
            matcherSafeTrancheBalanceAfter,
            matcherSafeTrancheBalanceBefore - collateralAmount
        );
        assertEq(
            matcherRiskTrancheBalanceAfter,
            matcherRiskTrancheBalanceBefore - expectedZ
        );

        assertEq(borrowerStableBalanceAfter, expectedStables);
        assertEq(borrowerRiskSlipsAfter, expectedZ);

        assertEq(lenderSafeSlipsAfter, collateralAmount);
    }

    function testReinitializeAndLendEmitsInitialized(uint256 stableAmount)
        public
    {
        stableAmount = bound(
            stableAmount,
            (s_safeRatio * s_price) / s_priceGranularity,
            (s_safeTranche.balanceOf(s_cbb_owner) * s_price) /
                s_priceGranularity
        );

        uint256 collateralAmount = 0;

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            s_cbb_owner
        );
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            s_cbb_owner
        );

        vm.prank(s_cbb_owner);
        vm.expectEmit(true, true, true, true);
        emit ReInitialized(s_price, block.timestamp);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.lend(address(1), address(2), stableAmount);

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(
            s_cbb_owner
        );
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(
            s_cbb_owner
        );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(
            address(1)
        );
        uint256 borrowerRiskSlipsAfter = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(2));

        uint256 mintAmount = (stableAmount * s_priceGranularity) /
            s_deployedConvertibleBondBox.currentPrice();
        uint256 expectedZ = (mintAmount * s_ratios[2]) / s_ratios[0];

        assertEq(
            matcherSafeTrancheBalanceAfter,
            matcherSafeTrancheBalanceBefore - mintAmount
        );
        assertEq(
            matcherRiskTrancheBalanceAfter,
            matcherRiskTrancheBalanceBefore - expectedZ
        );

        assertEq(borrowerStableBalanceAfter, stableAmount);
        assertEq(borrowerRiskSlipsAfter, expectedZ);

        assertEq(lenderSafeSlipsAfter, mintAmount);
    }

    function testFailReinitializeTrancheBW(uint256 trancheIndex) public {
        vm.assume(trancheIndex > s_buttonWoodBondController.trancheCount() - 1);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_stableToken),
            trancheIndex,
            address(this)
        );
        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        s_deployedConvertibleBondBox.reinitialize(s_price);
    }

    function testCannotReinitializeInitialPriceTooHigh(uint256 price) public {
        price = bound(price, s_priceGranularity + 1, type(uint256).max);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_stableToken),
            s_trancheIndex,
            s_cbb_owner
        );

        vm.prank(s_cbb_owner);
        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceTooHigh(uint256,uint256)",
            price,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.reinitialize(price);
    }

    function testCannotReinitializeInitialPriceIsZero() public {
        uint256 price = 0;
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_stableToken),
            s_trancheIndex,
            s_cbb_owner
        );

        vm.prank(s_cbb_owner);
        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceIsZero(uint256,uint256)",
            price,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.reinitialize(price);
    }

    function testReinitializeAndBorrowEmitsBorrow(uint256 collateralAmount)
        public
    {
        collateralAmount = bound(
            collateralAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(s_cbb_owner)
        );

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            s_cbb_owner
        );
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            s_cbb_owner
        );

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        vm.expectEmit(true, true, true, true);
        emit Borrow(
            s_cbb_owner,
            address(1),
            address(2),
            collateralAmount,
            s_price
        );
        s_deployedConvertibleBondBox.borrow(
            address(1),
            address(2),
            collateralAmount
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(
            s_cbb_owner
        );
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(
            s_cbb_owner
        );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(
            address(1)
        );
        uint256 borrowerRiskSlipsAfter = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(2));

        uint256 expectedZ = (collateralAmount * s_ratios[2]) / s_ratios[0];

        uint256 expectedStables = (collateralAmount *
            s_deployedConvertibleBondBox.currentPrice()) / s_priceGranularity;

        assertEq(
            matcherSafeTrancheBalanceAfter,
            matcherSafeTrancheBalanceBefore - collateralAmount
        );
        assertEq(
            matcherRiskTrancheBalanceAfter,
            matcherRiskTrancheBalanceBefore - expectedZ
        );

        assertEq(borrowerStableBalanceAfter, expectedStables);
        assertEq(borrowerRiskSlipsAfter, expectedZ);

        assertEq(lenderSafeSlipsAfter, collateralAmount);
    }

    function testReinitializeAndLendEmitsLend(uint256 stableAmount) public {
        stableAmount = bound(
            stableAmount,
            (s_safeRatio * s_price) / s_priceGranularity,
            (s_safeTranche.balanceOf(s_cbb_owner) * s_price) /
                s_priceGranularity
        );

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            s_cbb_owner
        );
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            s_cbb_owner
        );
        vm.prank(s_cbb_owner);
        vm.expectEmit(true, true, true, true);
        emit ReInitialized(s_price, block.timestamp);

        s_deployedConvertibleBondBox.reinitialize(s_price);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.lend(address(1), address(2), stableAmount);

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(
            s_cbb_owner
        );
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(
            s_cbb_owner
        );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(
            address(1)
        );
        uint256 borrowerRiskSlipsAfter = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(2));

        uint256 mintAmount = (stableAmount * s_priceGranularity) /
            s_deployedConvertibleBondBox.currentPrice();
        uint256 expectedZ = (mintAmount * s_ratios[2]) / s_ratios[0];

        assertEq(
            matcherSafeTrancheBalanceAfter,
            matcherSafeTrancheBalanceBefore - mintAmount
        );
        assertEq(
            matcherRiskTrancheBalanceAfter,
            matcherRiskTrancheBalanceBefore - expectedZ
        );

        assertEq(borrowerStableBalanceAfter, stableAmount);
        assertEq(borrowerRiskSlipsAfter, expectedZ);

        assertEq(lenderSafeSlipsAfter, mintAmount);
    }
}
