// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

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

contract Initialize is CBBSetup {
    // initialize()
    function testFailInitializeNotOwner(uint256 collateralAmount)
        public
    {
        collateralAmount = bound(
            collateralAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(address(this))
        );

        uint256 stableAmount = 0;

        vm.prank(address(1));
        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            collateralAmount,
            stableAmount,
            s_price
        );
    }

    function testInitializeAndBorrowEmitsInitialized(uint256 collateralAmount)
        public
    {
        collateralAmount = bound(
            collateralAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(address(this))
        );

        uint256 stableAmount = 0;

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            address(this)
        );
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            address(this)
        );

        vm.prank(address(this));
        vm.expectEmit(true, true, true, true);
        emit Initialized(address(1), address(2), 0, collateralAmount);
        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            collateralAmount,
            stableAmount,
            s_price
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(
            address(this)
        );
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(
            address(this)
        );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(
            address(1)
        );
        uint256 borrowerRiskSlipsAfter = ICBBSlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = ICBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(2));

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

    function testInitializeAndLendEmitsInitialized(uint256 stableAmount)
        public
    {
        stableAmount = bound(
            stableAmount,
            (s_safeRatio * s_price) / s_priceGranularity,
            (s_safeTranche.balanceOf(address(this)) * s_price) /
                s_priceGranularity
        );

        uint256 collateralAmount = 0;

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            address(this)
        );
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            address(this)
        );

        vm.prank(address(this));
        vm.expectEmit(true, true, true, true);
        emit Initialized(address(1), address(2), stableAmount, 0);
        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            collateralAmount,
            stableAmount,
            s_price
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(
            address(this)
        );
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(
            address(this)
        );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(
            address(1)
        );
        uint256 borrowerRiskSlipsAfter = ICBBSlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = ICBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(2));

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

    function testCannotInitializePenaltyTooHigh(uint256 penalty) public {
        vm.assume(penalty > s_penaltyGranularity);
        bytes memory customError = abi.encodeWithSignature(
            "PenaltyTooHigh(uint256,uint256)",
            penalty,
            s_penaltyGranularity
        );
        vm.expectRevert(customError);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_trancheIndex,
            address(this)
        );

        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);
    }

    function testCannotInitializeBondIsMature() public {
        s_buttonWoodBondController.mature();
        bytes memory customError = abi.encodeWithSignature(
            "BondIsMature(bool,bool)",
            s_buttonWoodBondController.isMature(),
            false
        );
        vm.expectRevert(customError);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_trancheIndex,
            address(this)
        );
    }

    function testCannotInitializeTrancheIndexOutOfBounds() public {
        bytes memory customError = abi.encodeWithSignature(
            "TrancheIndexOutOfBounds(uint256,uint256)",
            s_buttonWoodBondController.trancheCount() - 1,
            s_buttonWoodBondController.trancheCount() - 2
        );
        vm.expectRevert(customError);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            2,
            address(this)
        );
    }

    function testFailInitializeTrancheBW(uint256 trancheIndex) public {
        vm.assume(trancheIndex > s_buttonWoodBondController.trancheCount() - 1);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            trancheIndex,
            address(this)
        );
        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            s_depositLimit,
            0,
            s_price
        );
    }

    function testCannotReInitializeInitialPriceTooHigh(uint256 price) public {
        vm.assume(price > s_priceGranularity);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_trancheIndex,
            address(this)
        );
        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceTooHigh(uint256,uint256)",
            price,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            0,
            0,
            price
        );
    }

    function testCannotInitializeOnlyLendOrBorrow(
        uint256 collateralAmount,
        uint256 stableAmount
    ) public {
        stableAmount = bound(stableAmount, 0, 10e12);
        collateralAmount = bound(collateralAmount, 0, 10e12);
        vm.assume(stableAmount * collateralAmount != 0);

        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_trancheIndex,
            address(this)
        );

        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        bytes memory customError = abi.encodeWithSignature(
            "OnlyLendOrBorrow(uint256,uint256)",
            collateralAmount,
            stableAmount
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            stableAmount,
            collateralAmount,
            s_price
        );
    }

    function testInitializeAndBorrowEmitsBorrow(uint256 collateralAmount)
        public
    {
        collateralAmount = bound(
            collateralAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(address(this))
        );

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            address(this)
        );
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            address(this)
        );

        vm.expectEmit(true, true, true, true);
        emit Borrow(
            address(this),
            address(1),
            address(2),
            collateralAmount,
            s_price
        );
        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            collateralAmount,
            0,
            s_price
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(
            address(this)
        );
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(
            address(this)
        );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(
            address(1)
        );
        uint256 borrowerRiskSlipsAfter = ICBBSlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = ICBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(2));

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

    function testInitializeAndLendEmitsLend(uint256 stableAmount) public {
        stableAmount = bound(
            stableAmount,
            (s_safeRatio * s_price) / s_priceGranularity,
            (s_safeTranche.balanceOf(address(this)) * s_price) /
                s_priceGranularity
        );

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            address(this)
        );
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            address(this)
        );

        vm.expectEmit(true, true, true, true);
        emit Lend(address(this), address(1), address(2), stableAmount, s_price);
        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            0,
            stableAmount,
            s_price
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(
            address(this)
        );
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(
            address(this)
        );

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(
            address(1)
        );
        uint256 borrowerRiskSlipsAfter = ICBBSlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = ICBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(2));

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
