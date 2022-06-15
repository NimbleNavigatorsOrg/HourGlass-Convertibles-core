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

contract Initialize is CBBSetup {
    // initialize()
    function testInitializeOwnerTransfer(uint256 collateralAmount) public {
        address ownerBefore = s_deployedConvertibleBondBox.owner();
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
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            collateralAmount,
            stableAmount,
            address(100)
        );
        address ownerAfter = s_deployedConvertibleBondBox.owner();

        assertEq(false, ownerBefore == ownerAfter);
        assertEq(ownerAfter, address(100));
    }

    function testFailInitializeOwnerTransfer(uint256 collateralAmount) public {
        address ownerBefore = s_deployedConvertibleBondBox.owner();
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
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            collateralAmount,
            stableAmount,
            address(0)
        );
        address ownerAfter = s_deployedConvertibleBondBox.owner();
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
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            collateralAmount,
            stableAmount,
            address(100)
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
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            collateralAmount,
            stableAmount,
            address(100)
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
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_trancheIndex
        );

        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        bytes memory customError = abi.encodeWithSignature(
            "PenaltyTooHigh(uint256,uint256)",
            penalty,
            s_penaltyGranularity
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0,
            address(100)
        );
    }

    function testCannotInitializeBondIsMature() public {
        s_buttonWoodBondController.mature();
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            1001,
            s_trancheIndex
        );

        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        bytes memory customError = abi.encodeWithSignature(
            "BondIsMature(bool,bool)",
            s_buttonWoodBondController.isMature(),
            false
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0,
            address(100)
        );
    }

    function testCannotInitializeTrancheIndexOutOfBounds() public {
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            1001,
            s_buttonWoodBondController.trancheCount() - 1
        );
        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        bytes memory customError = abi.encodeWithSignature(
            "TrancheIndexOutOfBounds(uint256,uint256)",
            s_buttonWoodBondController.trancheCount() - 1,
            s_buttonWoodBondController.trancheCount() - 2
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0,
            address(100)
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
            1001,
            trancheIndex
        );
        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0,
            address(100)
        );
    }

    function testCannotInitializeInitialPriceTooHigh(uint256 price) public {
        vm.assume(price > s_priceGranularity);
        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            price,
            s_trancheIndex
        );

        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);
        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceTooHigh(uint256,uint256)",
            price,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0,
            address(100)
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
            s_price,
            s_trancheIndex
        );

        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        bytes memory customError = abi.encodeWithSignature(
            "OnlyLendOrBorrow(uint256,uint256)",
            collateralAmount,
            stableAmount
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            stableAmount,
            collateralAmount,
            address(100)
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

        uint256 stableAmount = 0;

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
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            collateralAmount,
            0,
            address(100)
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

        uint256 collateralAmount = 0;

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(
            address(this)
        );
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(
            address(this)
        );

        vm.expectEmit(true, true, true, true);
        emit Lend(address(this), address(1), address(2), stableAmount, s_price);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            0,
            stableAmount,
            address(100)
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
