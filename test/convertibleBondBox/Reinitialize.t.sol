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

contract Reinitialize is CBBSetup {

    function testFailReinitializeNotOwner(uint256 collateralAmount) public {
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

    function testReinitializeAndBorrowEmitsInitialized(uint256 collateralAmount) public {
        collateralAmount = bound(
            collateralAmount,
            s_safeRatio,
            s_safeTranche.balanceOf(s_cbb_owner)
        );

        uint256 stableAmount = 0;

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(s_cbb_owner);
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(s_cbb_owner);

        vm.prank(s_cbb_owner);
        vm.expectEmit(true, true, true, true);
        emit Initialized(address(1), address(2), 0, collateralAmount);
        s_deployedConvertibleBondBox.reinitialize(
            address(1),
            address(2),
            collateralAmount,
            stableAmount,
            s_price
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(s_cbb_owner);
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(s_cbb_owner);

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
}