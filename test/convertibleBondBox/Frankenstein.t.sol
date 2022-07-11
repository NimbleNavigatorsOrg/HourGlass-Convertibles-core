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

contract Frankenstein is CBBSetup {
    function testEndToEnd(
        uint256 collateralAmount,
        uint256 stableAmount,
        uint256 amount,
        uint256 seed
    ) public {
        vm.warp(1);
        collateralAmount = bound(collateralAmount, 0, 1e20);
        // used to be 1e20, is this change correct?
        amount = bound(
            amount,
            s_trancheGranularity,
            s_safeTranche.balanceOf(s_cbb_owner)
        );
        stableAmount = bound(
            stableAmount,
            (amount * s_price) / s_priceGranularity,
            1e20
        );

        seed = bound(seed, 6, 1e20);

        //matcher address between 1 - 5
        uint160 matcher0 = uint160(((seed + 1) % 5) + 1);
        uint160 matcher1 = uint160(((seed + 2) % 5) + 1);

        //borrower and lender between 6 & 10
        uint160 lender = uint160(((seed - 1) % 5) + 6);
        uint160 borrower = uint160(((seed - 2) % 5) + 6);

        uint160 lender0 = uint160(((seed - 3) % 5) + 6);
        uint160 borrower0 = uint160(((seed - 4) % 5) + 6);

        //Mint tranches & stables to matcher addresses
        vm.startPrank(address(s_buttonWoodBondController));
        for (uint160 i = 1; i < 11; i++) {
            s_safeTranche.mint(address(i), amount);
            s_riskTranche.mint(
                address(i),
                (amount * s_ratios[2]) / s_ratios[0]
            );
            s_stableToken.mint(address(i), stableAmount);
        }
        vm.stopPrank();

        //Get approvals for all addresses
        for (uint160 i = 1; i < 11; i++) {
            vm.startPrank(address(i));
            s_safeTranche.approve(
                address(s_deployedConvertibleBondBox),
                type(uint256).max
            );
            s_riskTranche.approve(
                address(s_deployedConvertibleBondBox),
                type(uint256).max
            );
            s_stableToken.approve(
                address(s_deployedConvertibleBondBox),
                type(uint256).max
            );
            vm.stopPrank();
        }

        vm.startPrank(s_deployedConvertibleBondBox.owner());
        vm.expectEmit(true, true, true, true);
        emit Initialized(address(borrower), address(lender), 0, amount);
        s_deployedConvertibleBondBox.reinitialize(
            address(borrower),
            address(lender),
            amount,
            0,
            s_price
        );
        vm.stopPrank();

        vm.prank(s_deployedConvertibleBondBox.owner());
        s_deployedConvertibleBondBox.borrow(
            address(borrower),
            address(lender),
            amount
        );

        //get slip approvals for all addresses
        for (uint160 i = 1; i < 11; i++) {
            vm.startPrank(address(i));
            s_deployedConvertibleBondBox.riskSlip().approve(
                address(s_deployedConvertibleBondBox),
                type(uint256).max
            );
            s_deployedConvertibleBondBox.riskSlip().approve(
                address(s_deployedConvertibleBondBox),
                type(uint256).max
            );
            vm.stopPrank();
        }

        // Matcher makes a lend @ 1/4 the way to maturity
        vm.warp(s_maturityDate / 4);
        vm.startPrank(address(matcher0));
        uint256 matcherSafeTrancheBalance = s_safeTranche.balanceOf(
            address(matcher0)
        ) / 2;
        vm.expectEmit(true, true, true, true);
        emit Lend(
            address(matcher0),
            address(borrower0),
            address(lender0),
            matcherSafeTrancheBalance,
            s_deployedConvertibleBondBox.currentPrice()
        );

        s_deployedConvertibleBondBox.lend(
            address(borrower0),
            address(lender0),
            matcherSafeTrancheBalance
        );
        vm.stopPrank();

        // Borrower repays half of riskSlips halfway to maturity @ currentPrice
        vm.warp(s_maturityDate / 2);
        vm.startPrank(address(borrower));
        uint256 _currentPrice = s_deployedConvertibleBondBox.currentPrice();
        uint256 riskSlipBalance = s_deployedConvertibleBondBox
            .riskSlip()
            .balanceOf(address(borrower)) / 2;

        uint256 _stableAmount = (((riskSlipBalance * s_ratios[0]) /
            s_ratios[2]) * _currentPrice) / s_priceGranularity;

        uint256 safeTranchePayout = (_stableAmount * s_priceGranularity) /
            _currentPrice;

        uint256 zTranchePaidFor = (safeTranchePayout *
            s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        vm.expectEmit(true, true, true, true);
        emit Repay(
            address(borrower),
            _stableAmount,
            zTranchePaidFor,
            _currentPrice
        );

        s_deployedConvertibleBondBox.repay(
            (((riskSlipBalance * s_ratios[0]) / s_ratios[2]) * _currentPrice) /
                s_priceGranularity
        );
        vm.stopPrank();

        // Matcher makes a borrow 3/4 to maturity
        vm.warp((s_maturityDate * 3) / 4);
        vm.startPrank(address(matcher1));
        matcherSafeTrancheBalance =
            s_safeTranche.balanceOf(address(matcher1)) /
            2;

        vm.expectEmit(true, true, true, true);
        emit Borrow(
            address(matcher1),
            address(borrower0),
            address(lender0),
            matcherSafeTrancheBalance,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.borrow(
            address(borrower0),
            address(lender0),
            matcherSafeTrancheBalance
        );
        vm.stopPrank();

        // Lender redeems half of safeSlips for tranches @ maturity
        vm.warp(s_maturityDate);

        vm.startPrank(address(lender));
        uint256 safeSlipBalance = s_deployedConvertibleBondBox
            .safeSlip()
            .balanceOf(address(lender)) / 2;
        vm.expectEmit(true, true, true, true);
        emit RedeemSafeTranche(address(lender), safeSlipBalance);
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipBalance);
        vm.stopPrank();

        // Lender redeems half of remaining safeSlips for stables
        vm.startPrank(address(lender));
        safeSlipBalance =
            s_deployedConvertibleBondBox.safeSlip().balanceOf(address(lender)) /
            2;
        vm.expectEmit(true, true, true, true);
        emit RedeemStable(
            address(lender),
            safeSlipBalance,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.redeemStable(safeSlipBalance);
        vm.stopPrank();
    }
}
