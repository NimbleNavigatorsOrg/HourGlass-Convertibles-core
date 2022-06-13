// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/ConvertibleBondBox.sol";
import "../src/contracts/CBBFactory.sol";
import "../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../src/contracts/CBBSlip.sol";
import "../src/contracts/CBBSlipFactory.sol";
import "forge-std/console2.sol";
import "../test/mocks/MockERC20.sol";

contract ConvertibleBondBoxTest is Test {
    ButtonWoodBondController s_buttonWoodBondController;
    ConvertibleBondBox s_convertibleBondBox;
    ConvertibleBondBox s_deployedConvertibleBondBox;
    CBBFactory s_CBBFactory;

    MockERC20 s_collateralToken;

    MockERC20 s_stableToken;
    TrancheFactory s_trancheFactory;
    Tranche s_tranche;
    CBBSlip s_slip;
    CBBSlipFactory s_slipFactory;
    ITranche s_safeTranche;
    ITranche s_riskTranche;
    uint256[] s_ratios;
    uint256 s_depositLimit;
    uint256 constant s_penalty = 500;
    uint256 constant s_price = 5e8;
    uint256 constant s_trancheIndex = 0;
    uint256 constant s_maturityDate = 1656717949;
    uint256 constant s_safeSlipAmount = 10;
    uint256 constant s_endOfUnixTime = 2147483647;
    uint256 constant s_trancheGranularity = 1000;
    uint256 constant s_penaltyGranularity = 1000;
    uint256 constant s_priceGranularity = 1000000000;
    address s_deployedCBBAddress;

    event ConvertibleBondBoxCreated(
        address s_collateralToken,
        address s_stableToken,
        uint256 trancheIndex,
        uint256 penalty,
        address creator
    );

    event Lend(address, address, address, uint256, uint256);
    event Borrow(address, address, address, uint256, uint256);
    event RedeemStable(address, uint256, uint256);
    event RedeemTranche(address, uint256);
    event Repay(address, uint256, uint256, uint256, uint256);
    event Initialized(address, address, uint256, uint256);

    function setUp() public {
        //push numbers into array
        s_ratios.push(200);
        s_ratios.push(300);
        s_ratios.push(500);

        // create buttonwood bond collateral token
        s_collateralToken = new MockERC20("CollateralToken", "CT");
        s_collateralToken.mint(address(this), 1e18);

        // // create stable token
        s_stableToken = new MockERC20("StableToken", "ST");
        s_stableToken.mint(address(this), 10e18);
        // // create tranche
        s_tranche = new Tranche();

        // // create buttonwood tranche factory
        s_trancheFactory = new TrancheFactory(address(s_tranche));

        // // create s_slip
        s_slip = new CBBSlip();

        // // create s_slip factory
        s_slipFactory = new CBBSlipFactory(address(s_slip));

        s_buttonWoodBondController = new ButtonWoodBondController();
        s_convertibleBondBox = new ConvertibleBondBox();
        s_CBBFactory = new CBBFactory(address(s_convertibleBondBox));

        s_buttonWoodBondController.init(
            address(s_trancheFactory),
            address(s_collateralToken),
            address(this),
            s_ratios,
            s_maturityDate,
            s_depositLimit
        );

        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_trancheIndex
        );

        s_collateralToken.approve(
            address(s_buttonWoodBondController),
            type(uint256).max
        );

        s_buttonWoodBondController.deposit(1e18);

        (s_safeTranche, ) = s_buttonWoodBondController.tranches(s_trancheIndex);
        (s_riskTranche, ) = s_buttonWoodBondController.tranches(
            s_buttonWoodBondController.trancheCount() - 1
        );

        s_safeTranche.approve(s_deployedCBBAddress, type(uint256).max);
        s_riskTranche.approve(s_deployedCBBAddress, type(uint256).max);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);

        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        s_depositLimit =
            (s_safeTranche.balanceOf(address(this)) * s_price) /
            s_priceGranularity;
    }

    // initialize()

    function testInitializeAndBorrowEmitsInitialized(uint256 collateralAmount)
        public
    {
        vm.assume(collateralAmount <= s_safeTranche.balanceOf(address(this)));
        vm.assume(collateralAmount != 0);

        uint256 stableAmount = 0;

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(this));
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(address(this));

        vm.prank(address(this));
        vm.expectEmit(true, true, true, true);
        emit Initialized(address(1), address(2), 0, collateralAmount);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            collateralAmount,
            stableAmount
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(address(this));
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(address(this));

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(address(1));
        uint256 borrowerRiskSlipsAfter = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(2));

        uint256 expectedZ = (collateralAmount * s_ratios[2]) /
            s_ratios[0];

        uint256 expectedStables = (collateralAmount * s_deployedConvertibleBondBox.currentPrice()) /
            s_priceGranularity;
 
        assertEq(matcherSafeTrancheBalanceAfter, matcherSafeTrancheBalanceBefore - collateralAmount);
        assertEq(matcherRiskTrancheBalanceAfter, matcherRiskTrancheBalanceBefore - expectedZ);

        assertEq(borrowerStableBalanceAfter, expectedStables);
        assertEq(borrowerRiskSlipsAfter, expectedZ);

        assertEq(lenderSafeSlipsAfter, collateralAmount);
    }

    // are these assumes right? possible lend overflow error?
    function testInitializeAndLendEmitsInitialized(uint256 stableAmount)
        public
    {
        vm.assume(stableAmount < 1e18);
        vm.assume((stableAmount * s_priceGranularity) / s_deployedConvertibleBondBox.currentPrice() < s_safeTranche.balanceOf(address(this)));
        vm.assume(stableAmount != 0);

        uint256 collateralAmount = 0;

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(this));
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(address(this));

        vm.prank(address(this));
        vm.expectEmit(true, true, true, true);
        emit Initialized(address(1), address(2), stableAmount, 0);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            collateralAmount,
            stableAmount
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(address(this));
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(address(this));

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(address(1));
        uint256 borrowerRiskSlipsAfter = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(2));

        uint256 mintAmount = (stableAmount * s_priceGranularity) / s_deployedConvertibleBondBox.currentPrice();
        uint256 expectedZ = (mintAmount * s_ratios[2]) / s_ratios[0];
 
        assertEq(matcherSafeTrancheBalanceAfter, matcherSafeTrancheBalanceBefore - mintAmount);
        assertEq(matcherRiskTrancheBalanceAfter, matcherRiskTrancheBalanceBefore - expectedZ);

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
            s_deployedConvertibleBondBox.penaltyGranularity()
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
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
            0
        );
    }

    //TODO reasses test later
    function testCannotInitializeTrancheIndexOutOfBounds() public {
        // vm.assume(trancheIndex == s_buttonWoodBondController.trancheCount() - 1);
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
            0
        );
    }

    //TODO reasses test later

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
            0
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
            0
        );
    }

    function testCannotInitializeOnlyLendOrBorrow(
        uint256 collateralAmount,
        uint256 stableAmount
    ) public {
        vm.assume(stableAmount < 10e12);
        vm.assume(collateralAmount < 10e12);
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
            collateralAmount
        );
    }

    function testInitializeAndBorrowEmitsBorrow(uint256 collateralAmount)
        public
    {
        vm.assume(collateralAmount <= s_safeTranche.balanceOf(address(this)));
        vm.assume(collateralAmount != 0);

        uint256 stableAmount = 0;

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(this));
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(address(this));

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
            0
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(address(this));
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(address(this));

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(address(1));
        uint256 borrowerRiskSlipsAfter = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(2));

        uint256 expectedZ = (collateralAmount * s_ratios[2]) /
            s_ratios[0];

        uint256 expectedStables = (collateralAmount * s_deployedConvertibleBondBox.currentPrice()) /
            s_priceGranularity;
 
        assertEq(matcherSafeTrancheBalanceAfter, matcherSafeTrancheBalanceBefore - collateralAmount);
        assertEq(matcherRiskTrancheBalanceAfter, matcherRiskTrancheBalanceBefore - expectedZ);

        assertEq(borrowerStableBalanceAfter, expectedStables);
        assertEq(borrowerRiskSlipsAfter, expectedZ);

        assertEq(lenderSafeSlipsAfter, collateralAmount);
    }

    function testInitializeAndLendEmitsLend(uint256 stableAmount) public {
        vm.assume(
            stableAmount <=
                (s_safeTranche.balanceOf(address(this)) * s_price) /
                    s_priceGranularity
        );
        vm.assume(stableAmount != 0);

        uint256 collateralAmount = 0;

        uint256 matcherSafeTrancheBalanceBefore = s_safeTranche.balanceOf(address(this));
        uint256 matcherRiskTrancheBalanceBefore = s_riskTranche.balanceOf(address(this));

        vm.expectEmit(true, true, true, true);
        emit Lend(address(this), address(1), address(2), stableAmount, s_price);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            0,
            stableAmount
        );

        uint256 matcherSafeTrancheBalanceAfter = s_safeTranche.balanceOf(address(this));
        uint256 matcherRiskTrancheBalanceAfter = s_riskTranche.balanceOf(address(this));

        uint256 borrowerStableBalanceAfter = s_stableToken.balanceOf(address(1));
        uint256 borrowerRiskSlipsAfter = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(1));

        uint256 lenderSafeSlipsAfter = ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(2));

        uint256 mintAmount = (stableAmount * s_priceGranularity) / s_deployedConvertibleBondBox.currentPrice();
        uint256 expectedZ = (mintAmount * s_ratios[2]) / s_ratios[0];
 
        assertEq(matcherSafeTrancheBalanceAfter, matcherSafeTrancheBalanceBefore - mintAmount);
        assertEq(matcherRiskTrancheBalanceAfter, matcherRiskTrancheBalanceBefore - expectedZ);

        assertEq(borrowerStableBalanceAfter, stableAmount);
        assertEq(borrowerRiskSlipsAfter, expectedZ);

        assertEq(lenderSafeSlipsAfter, mintAmount);
    }

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
        uint256 priceGranularity = s_deployedConvertibleBondBox
            .priceGranularity();
        assertEq((priceGranularity - price) / 2 + price, currentPrice);
    }

    // repay()
    // Still need to test OverPayment() revert and PayoutExceedsBalance() revert

    function testRepay(uint256 time) public {
        //More parameters can be added to this test
        uint256 stableAmount = 100000;
        uint256 zSlipAmount = 625001;
        address borrowerAddress = address(1);
        vm.assume(time < s_endOfUnixTime - s_maturityDate);
        vm.warp(s_maturityDate + time);

        vm.prank(address(this));
        s_deployedConvertibleBondBox.initialize(
            borrowerAddress,
            address(2),
            s_depositLimit,
            0
        );

        uint256 userStableBalancedBeforeRepay = s_stableToken.balanceOf(borrowerAddress);
        uint256 userSafeTrancheBalanceBeforeRepay = s_deployedConvertibleBondBox.safeTranche().balanceOf(borrowerAddress);
        uint256 userRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox.riskTranche().balanceOf(borrowerAddress);
        uint256 userRiskSlipBalancedBeforeRepay = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(borrowerAddress);

        uint256 CBBSafeTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(s_deployedConvertibleBondBox));
        uint256 CBBRiskTrancheBalancedBeforeRepay = s_deployedConvertibleBondBox.riskTranche().balanceOf(address(s_deployedConvertibleBondBox));

        uint256 safeTranchePayout = (stableAmount * s_deployedConvertibleBondBox.priceGranularity()) /
            s_deployedConvertibleBondBox.currentPrice();

        uint256 zTranchePaidFor = (safeTranchePayout * s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        uint256 zTrancheUnpaid = zSlipAmount - zTranchePaidFor;

        zTrancheUnpaid =
                zTrancheUnpaid -
                (zTrancheUnpaid * s_deployedConvertibleBondBox.penalty()) /
                s_deployedConvertibleBondBox.penaltyGranularity();

        vm.startPrank(s_deployedCBBAddress);
        CBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).mint(
            address(this),
            1e18
        );
        vm.stopPrank();

        vm.startPrank(borrowerAddress);

        //TODO Determine if the below approval needs to be moved to the CBB contract.
        s_deployedConvertibleBondBox.stableToken().approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        vm.expectEmit(true, true, true, true);
        emit Repay(borrowerAddress, stableAmount, zTranchePaidFor, zTrancheUnpaid, s_deployedConvertibleBondBox.currentPrice());
        s_deployedConvertibleBondBox.repay(stableAmount, zSlipAmount);
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
            zTrancheUnpaid,
            CBBRiskTrancheBalancedBeforeRepay,
            borrowerAddress
        );

        repayRiskSlipAssertions(
            userRiskSlipBalancedBeforeRepay,
            zTranchePaidFor,
            zTrancheUnpaid,
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
        uint256 CBBStableBalance = s_stableToken.balanceOf(address(s_deployedConvertibleBondBox));
        uint256 userStableBalancedAfterRepay = s_stableToken.balanceOf(borrowerAddress);

        assertEq(stableAmount, CBBStableBalance);
        assertEq(userStableBalancedBeforeRepay - stableAmount, userStableBalancedAfterRepay);
    }

    function repaySafeTrancheBalanceAssertions(
        uint256 userSafeTrancheBalanceBeforeRepay,
        uint256 safeTranchePayout,
        uint256 CBBSafeTrancheBalancedBeforeRepay,
        address borrowerAddress
    ) private {
        uint256 userSafeTrancheBalancedAfterRepay = s_deployedConvertibleBondBox.safeTranche().balanceOf(borrowerAddress);
        uint256 CBBSafeTrancheBalancedAfterRepay = s_deployedConvertibleBondBox.safeTranche().balanceOf(address(s_deployedConvertibleBondBox));


        assertEq(userSafeTrancheBalanceBeforeRepay + safeTranchePayout, userSafeTrancheBalancedAfterRepay);
        assertEq(CBBSafeTrancheBalancedBeforeRepay - safeTranchePayout, CBBSafeTrancheBalancedAfterRepay);
    }

    function repayRiskTrancheBalanceAssertions(
        uint256 userRiskTrancheBalancedBeforeRepay,
        uint256 zTranchePaidFor,
        uint256 zTrancheUnpaid,
        uint256 CBBRiskTrancheBalancedBeforeRepay,
        address borrowerAddress
        ) private {
        uint256 userRiskTrancheBalancedAfterRepay = s_deployedConvertibleBondBox.riskTranche().balanceOf(borrowerAddress);
        uint256 CBBRiskTrancheBalanceAfterRepay = s_deployedConvertibleBondBox.riskTranche().balanceOf(address(s_deployedConvertibleBondBox));

        assertEq(userRiskTrancheBalancedBeforeRepay + zTranchePaidFor + zTrancheUnpaid, userRiskTrancheBalancedAfterRepay);
        assertEq(CBBRiskTrancheBalancedBeforeRepay - zTranchePaidFor - zTrancheUnpaid, CBBRiskTrancheBalanceAfterRepay);
    }

    function repayRiskSlipAssertions(
        uint256 userRiskSlipBalancedBeforeRepay,
        uint256 zTranchePaidFor,
        uint256 zTrancheUnpaid,
        address borrowerAddress
    ) private {
        uint256 userRiskSlipBalancedAfterRepay = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(borrowerAddress);

        assertEq(userRiskSlipBalancedBeforeRepay - zTranchePaidFor - zTrancheUnpaid, userRiskSlipBalancedAfterRepay);
    }

    function testCannotRepayConvertibleBondBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "ConvertibleBondBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedConvertibleBondBox.repay(100000, 625001);
    }

    //redeemTranche()

    function testRedeemTranche(
        uint256 amount,
        uint256 time,
        uint256 collateralAmount
    ) public {
        (ITranche safeTranche, uint256 ratio) = s_buttonWoodBondController
            .tranches(0);
        // If the below line is commented out, we get an arithmatic underflow/overflow error. Why?
        vm.assume(time < s_endOfUnixTime - s_maturityDate);
        // vm.assume(collateralAmount <= s_depositLimit);
        // vm.assume(collateralAmount > 10e9);
        vm.assume(amount < 1e18);

        vm.warp(s_maturityDate + time);

        vm.prank(address(this));
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );

        vm.startPrank(address(s_buttonWoodBondController));
        safeTranche.mint(s_deployedCBBAddress, amount);
        vm.stopPrank();

        vm.startPrank(s_deployedCBBAddress);
        CBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).mint(
            address(this),
            amount
        );
        vm.stopPrank();

        uint256 safeSlipBalanceBeforeRedeem = CBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(this));

        vm.expectEmit(true, true, true, true);
        emit RedeemTranche(address(this), amount);
        s_deployedConvertibleBondBox.redeemTranche(amount);

        uint256 safeSlipBalanceAfterRedeem = CBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).balanceOf(address(this));

        assertEq(safeSlipBalanceBeforeRedeem - amount, safeSlipBalanceAfterRedeem);
    }

    function testCannotRedeemTrancheBondNotMatureYet(uint256 time) public {
        vm.assume(time <= s_maturityDate && time != 0);
        vm.warp(s_maturityDate - time);
        vm.prank(address(this));
        emit Initialized(address(1), address(2), 0, s_depositLimit);

        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
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
        s_deployedConvertibleBondBox.redeemTranche(s_safeSlipAmount);
    }

    // redeemStable()

    function testRedeemStable(uint256 safeSlipAmount) public {
        vm.assume(safeSlipAmount <= 1e18);
        vm.prank(address(this));
        emit Initialized(address(1), address(2), 0, s_depositLimit);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );
        vm.startPrank(s_deployedCBBAddress);
        CBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress()).mint(
            address(this),
            1e18
        );
        vm.stopPrank();
        vm.expectEmit(true, true, true, true);
        emit RedeemStable(
            address(this),
            safeSlipAmount,
            s_deployedConvertibleBondBox.currentPrice()
        );
        s_deployedConvertibleBondBox.redeemStable(safeSlipAmount);
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
            0
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
        emit Lend(address(matcher0), 
        address(borrower0), 
        address(lender0), 
        matcherSafeTrancheBalance, 
        s_deployedConvertibleBondBox.currentPrice());

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

        uint256 _stableAmount = (((riskSlipBalance * s_ratios[0]) / s_ratios[2]) * _currentPrice) /
                s_priceGranularity;

        uint256 safeTranchePayout = (_stableAmount * s_deployedConvertibleBondBox.priceGranularity()) /
            _currentPrice;

        uint256 zTranchePaidFor = (safeTranchePayout * s_deployedConvertibleBondBox.riskRatio()) /
            s_deployedConvertibleBondBox.safeRatio();

        vm.expectEmit(true, true, true, true);
        emit Repay(address(borrower), _stableAmount, zTranchePaidFor, 0, _currentPrice);

        s_deployedConvertibleBondBox.repay(
            (((riskSlipBalance * s_ratios[0]) / s_ratios[2]) * _currentPrice) /
                s_priceGranularity,
            riskSlipBalance
        );
        vm.stopPrank();

        // Matcher makes a borrow 3/4 to maturity
        vm.warp((s_maturityDate * 3) / 4);
        vm.startPrank(address(matcher1));
        matcherSafeTrancheBalance =
            s_safeTranche.balanceOf(address(matcher1)) /
            2;

        vm.expectEmit(true, true, true, true);
        emit Borrow(address(matcher1), address(borrower0), address(lender0), matcherSafeTrancheBalance, s_deployedConvertibleBondBox.currentPrice());
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
        emit RedeemTranche(address(lender), safeSlipBalance);
        s_deployedConvertibleBondBox.redeemTranche(safeSlipBalance);
        vm.stopPrank();

        // Lender redeems half of remaining safeSlips for stables
        vm.startPrank(address(lender));
        safeSlipBalance =
            ICBBSlip(s_deployedConvertibleBondBox.s_safeSlipTokenAddress())
                .balanceOf(address(lender)) /
            2;
        vm.expectEmit(true, true, true, true);
        emit RedeemStable(address(lender), safeSlipBalance, s_deployedConvertibleBondBox.currentPrice());
        s_deployedConvertibleBondBox.redeemStable(safeSlipBalance);
        vm.stopPrank();
    }
}
