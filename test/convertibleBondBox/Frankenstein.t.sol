// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./CBBSetup.sol";

contract Frankenstein is CBBSetup {
    function testEndToEnd(
        uint256 collateralAmount,
        uint256 stableAmount,
        uint256 amount,
        uint256 seed
    ) public {
        vm.warp(1);
        collateralAmount = bound(collateralAmount, 0, 1e24);
        // used to be 1e20, is this change correct?
        amount = bound(amount, 100e18, s_safeTranche.balanceOf(address(this)));
        stableAmount = bound(stableAmount, 1e18, 1e24);

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
                (amount * s_riskRatio) / s_safeRatio
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

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.activate(s_initialPrice);

        s_deployedConvertibleBondBox.borrow(
            address(borrower),
            address(lender),
            amount
        );

        //get slip approvals for all addresses
        for (uint160 i = 1; i < 11; i++) {
            vm.startPrank(address(i));
            s_safeSlip.approve(
                address(s_deployedConvertibleBondBox),
                type(uint256).max
            );
            s_issuerSlip.approve(
                address(s_deployedConvertibleBondBox),
                type(uint256).max
            );
            vm.stopPrank();
        }

        // Matcher makes a lend @ 1/4 the way to maturity
        vm.warp(s_maturityDate / 4);
        vm.startPrank(address(matcher0));
        uint256 matcherSafeTrancheBalance = ((s_safeTranche.balanceOf(
            address(matcher0)
        ) / 4) * (10**s_stableDecimals)) / (10**s_collateralDecimals);

        s_deployedConvertibleBondBox.lend(
            address(borrower0),
            address(lender0),
            matcherSafeTrancheBalance
        );
        vm.stopPrank();

        // Borrower repays half of issuerSlips halfway to maturity @ currentPrice
        vm.warp(s_maturityDate / 2);
        vm.startPrank(address(borrower));
        uint256 _currentPrice = s_deployedConvertibleBondBox.currentPrice();
        uint256 issuerSlipBalance = s_deployedConvertibleBondBox
            .issuerSlip()
            .balanceOf(address(borrower)) / 2;

        s_deployedConvertibleBondBox.repay(
            (((issuerSlipBalance * s_safeRatio) / s_riskRatio) *
                _currentPrice *
                (10**s_stableDecimals)) /
                s_priceGranularity /
                (10**s_collateralDecimals)
        );
        vm.stopPrank();

        // Matcher makes a borrow 3/4 to maturity
        vm.warp((s_maturityDate * 3) / 4);
        vm.startPrank(address(matcher1));
        matcherSafeTrancheBalance =
            s_safeTranche.balanceOf(address(matcher1)) /
            2;

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
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipBalance);
        vm.stopPrank();

        // Lender redeems half of remaining safeSlips for stables
        vm.startPrank(address(lender));
        safeSlipBalance = s_safeSlip.balanceOf(address(lender)) / 2;
        vm.stopPrank();
    }
}
