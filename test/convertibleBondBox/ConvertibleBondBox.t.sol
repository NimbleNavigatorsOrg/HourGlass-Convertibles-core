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

contract ConvertibleBondBoxTest is CBBSetup {

    // lend()
    // Need to write a test that calls lend() without calling initialize()

    function testCannotLendConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.lend(
            address(1),
            address(2),
            s_depositLimit
        );
    }

    //borrow()
    // Need to write a test that calls borrow() without calling initialize()

    function testCannotBorrowConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.borrow(
            address(1),
            address(2),
            s_depositLimit
        );
    }

    // currentPrice()

    function testCurrentPrice() public {
        vm.warp(
            (s_deployedConvertibleBondBox.s_startDate() + s_maturityDate) / 2
        );
        uint256 currentPrice = s_deployedConvertibleBondBox.currentPrice();
        uint256 price = s_deployedConvertibleBondBox.initialPrice();
        uint256 priceGranularity = s_priceGranularity;
        assertEq((priceGranularity - price) / 2 + price, currentPrice);
    }

    // repay()
    // Still need to test OverPayment() revert and PayoutExceedsBalance() revert

    function testRepay(uint256 time, uint amount, uint stableAmount) public {
        //More parameters can be added to this test
        address borrowerAddress = address(1);
        time = bound(time, s_maturityDate, s_endOfUnixTime);
        vm.warp(s_maturityDate + time);
        uint minAmount = (s_deployedConvertibleBondBox.safeRatio() * s_deployedConvertibleBondBox.currentPrice()) / s_priceGranularity;
        amount = bound(amount, minAmount, 1e17);
        stableAmount = bound(stableAmount, minAmount, amount);

        vm.prank(address(this));
        s_deployedConvertibleBondBox.initialize(
            borrowerAddress,
            address(2),
            amount, 
            0,
            address(100)
        );

        uint256 userStableBalancedBeforeRepay = s_stableToken.balanceOf(
            borrowerAddress
        );
        uint256 userSafeTrancheBalanceBeforeRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(borrowerAddress);
        uint256 userRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
                .riskTranche()
                .balanceOf(borrowerAddress);
        uint256 userRiskSlipBalancedBeforeRepay = ICBBSlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(borrowerAddress);

        uint256 CBBSafeTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));
        uint256 CBBRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));

        uint256 safeTranchePayout = (stableAmount * s_priceGranularity) /
            s_deployedConvertibleBondBox.currentPrice();

        uint256 zTranchePaidFor = (safeTranchePayout *
            s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        vm.startPrank(borrowerAddress);

        s_deployedConvertibleBondBox.stableToken().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );

        vm.expectEmit(true, true, true, true);
        emit Repay(
            borrowerAddress,
            stableAmount,
            zTranchePaidFor,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.repay(stableAmount);
        vm.stopPrank();

        repayStableBalanceAssertions(
            stableAmount,
            s_stableToken,
            s_deployedConvertibleBondBox,
            userStableBalancedBeforeRepay,
            borrowerAddress
        );

        repaySafeTrancheBalanceAssertions(
            userSafeTrancheBalanceBeforeRepay,
            safeTranchePayout,
            CBBSafeTrancheBalancedBeforeRepay,
            borrowerAddress
        );

        repayRiskTrancheBalanceAssertions(
            userRiskTrancheBalancedBeforeRepay,
            zTranchePaidFor,
            CBBRiskTrancheBalancedBeforeRepay,
            borrowerAddress
        );

        repayRiskSlipAssertions(
            userRiskSlipBalancedBeforeRepay,
            zTranchePaidFor,
            borrowerAddress
        );
    }

    function repayStableBalanceAssertions(
        uint256 stableAmount,
        MockERC20 s_stableToken,
        ConvertibleBondBox s_deployedConvertibleBondBox,
        uint256 userStableBalancedBeforeRepay,
        address borrowerAddress
    ) private {
        uint256 CBBStableBalance = s_stableToken.balanceOf(
            address(s_deployedConvertibleBondBox)
        );
        uint256 userStableBalancedAfterRepay = s_stableToken.balanceOf(
            borrowerAddress
        );

        assertEq(stableAmount, CBBStableBalance);
        assertEq(
            userStableBalancedBeforeRepay - stableAmount,
            userStableBalancedAfterRepay
        );
    }

    function repaySafeTrancheBalanceAssertions(
        uint256 userSafeTrancheBalanceBeforeRepay,
        uint256 safeTranchePayout,
        uint256 CBBSafeTrancheBalancedBeforeRepay,
        address borrowerAddress
    ) private {
        uint256 userSafeTrancheBalancedAfterRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(borrowerAddress);
        uint256 CBBSafeTrancheBalancedAfterRepay = s_deployedConvertibleBondBox
            .safeTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(
            userSafeTrancheBalanceBeforeRepay + safeTranchePayout,
            userSafeTrancheBalancedAfterRepay
        );
        assertEq(
            CBBSafeTrancheBalancedBeforeRepay - safeTranchePayout,
            CBBSafeTrancheBalancedAfterRepay
        );
    }

    function repayRiskTrancheBalanceAssertions(
        uint256 userRiskTrancheBalancedBeforeRepay,
        uint256 zTranchePaidFor,
        uint256 CBBRiskTrancheBalancedBeforeRepay,
        address borrowerAddress
    ) private {
        uint256 userRiskTrancheBalancedAfterRepay = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(borrowerAddress);
        uint256 CBBRiskTrancheBalanceAfterRepay = s_deployedConvertibleBondBox
            .riskTranche()
            .balanceOf(address(s_deployedConvertibleBondBox));
        assertEq(
            userRiskTrancheBalancedBeforeRepay +
                zTranchePaidFor,
            userRiskTrancheBalancedAfterRepay
        );
        assertEq(
            CBBRiskTrancheBalancedBeforeRepay -
                zTranchePaidFor,
            CBBRiskTrancheBalanceAfterRepay
        );
    }

    function repayRiskSlipAssertions(
        uint256 userRiskSlipBalancedBeforeRepay,
        uint256 zTranchePaidFor,
        address borrowerAddress
    ) private {
        uint256 userRiskSlipBalancedAfterRepay = ICBBSlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(borrowerAddress);

        assertEq(
            userRiskSlipBalancedBeforeRepay - zTranchePaidFor,
            userRiskSlipBalancedAfterRepay
        );
    }

    function testCannotRepayConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.repay(100000);
    }

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

    // testFail for redeemStable before any repay function

    // redeemStable()

    function testRedeemStable(uint256 safeSlipAmount) public {
        // initializing the CBB
        vm.prank(address(this));
        emit Initialized(address(1), address(2), 0, s_depositLimit);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0,
            address(100)
        );

        //getting lender + borrower balances after initialization deposit
        uint256 userSafeSlipBalanceBeforeRedeem = ICBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(2));

        uint256 userStableBalanceBeforeRedeem = s_deployedConvertibleBondBox
            .stableToken()
            .balanceOf(address(2));

        uint256 repayAmount = s_deployedConvertibleBondBox
            .stableToken()
            .balanceOf(address(1));

        //borrower repays full amount immediately
        vm.startPrank(address(1));
        s_stableToken.approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        IERC20(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_deployedConvertibleBondBox.repay(repayAmount);
        vm.stopPrank();

        safeSlipAmount = bound(
            safeSlipAmount,
            s_safeRatio,
            IERC20(s_deployedConvertibleBondBox.s_safeSlipTokenAddress())
                .balanceOf(address(2))
        );

        console2.log(
            IERC20(s_deployedConvertibleBondBox.s_safeSlipTokenAddress())
                .balanceOf(address(2)),
            "upperBound"
        );

        console2.log(safeSlipAmount, "afterBound");

        uint256 CBBStableBalanceBeforeRedeem = s_deployedConvertibleBondBox
            .stableToken()
            .balanceOf(address(s_deployedConvertibleBondBox));

        uint256 safeTrancheBalance = IERC20(
            address(s_deployedConvertibleBondBox.safeTranche())
        ).balanceOf(address(s_deployedConvertibleBondBox));

        uint256 safeSlipSupply = IERC20(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).totalSupply();

        uint256 repaidSafeSlips = s_deployedConvertibleBondBox
            .s_repaidSafeSlips();

        uint256 stableTransferAmount = (safeSlipAmount *
            CBBStableBalanceBeforeRedeem) / (repaidSafeSlips);

        // lender redeems stable
        vm.startPrank(address(2));

        IERC20(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );

        vm.expectEmit(true, true, true, true);
        emit RedeemStable(
            address(2),
            safeSlipAmount,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.redeemStable(safeSlipAmount);

        vm.stopPrank();

        uint256 userSafeSlipBalanceAfterRedeem = ICBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(2));
        uint256 userStableBalanceAfterRedeem = s_deployedConvertibleBondBox
            .stableToken()
            .balanceOf(address(2));
        uint256 CBBStableBalanceAfterRedeem = s_deployedConvertibleBondBox
            .stableToken()
            .balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(
            userSafeSlipBalanceBeforeRedeem - safeSlipAmount,
            userSafeSlipBalanceAfterRedeem
        );
        assertEq(
            userStableBalanceBeforeRedeem + stableTransferAmount,
            userStableBalanceAfterRedeem
        );
        assertEq(
            CBBStableBalanceBeforeRedeem - stableTransferAmount,
            CBBStableBalanceAfterRedeem
        );
    }

    function testCannotRedeemStableConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.redeemStable(s_safeSlipAmount);
    }

    function testEndToEnd(
        uint256 collateralAmount,
        uint256 stableAmount,
        uint256 amount,
        uint256 seed
    ) public {
        collateralAmount = bound(collateralAmount, 0, 1e20);
        amount = bound(amount, s_trancheGranularity, 1e20);
        stableAmount = bound(
            stableAmount,
            (amount * s_price) / s_priceGranularity,
            1e20
        );

        seed = bound(seed, 6, 1e20);

        //matcher address between 1 - 5
        uint160 initCaller = uint160((seed % 5) + 1);
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
        //Is this realistic for max approvals?
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

        //Initialize ConvertibleBondBox via initCaller
        vm.startPrank(address(initCaller));
        vm.expectEmit(true, true, true, true);
        emit Initialized(address(borrower), address(lender), 0, amount);
        s_deployedConvertibleBondBox.initialize(
            address(borrower),
            address(lender),
            amount,
            0,
            address(100)
        );
        vm.stopPrank();

        //get slip approvals for all addresses
        for (uint160 i = 1; i < 11; i++) {
            vm.startPrank(address(i));
            ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress())
                .approve(
                    address(s_deployedConvertibleBondBox),
                    type(uint256).max
                );
            ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress())
                .approve(
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
        uint256 riskSlipBalance = ICBBSlip(
            s_deployedConvertibleBondBox.s_riskSlipTokenAddress()
        ).balanceOf(address(borrower)) / 2;

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
        uint256 safeSlipBalance = ICBBSlip(
            s_deployedConvertibleBondBox.s_safeSlipTokenAddress()
        ).balanceOf(address(lender)) / 2;
        vm.expectEmit(true, true, true, true);
        emit RedeemSafeTranche(address(lender), safeSlipBalance);
        s_deployedConvertibleBondBox.redeemSafeTranche(safeSlipBalance);
        vm.stopPrank();

        // Lender redeems half of remaining safeSlips for stables
        vm.startPrank(address(lender));
        safeSlipBalance =
            ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress())
                .balanceOf(address(lender)) /
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
