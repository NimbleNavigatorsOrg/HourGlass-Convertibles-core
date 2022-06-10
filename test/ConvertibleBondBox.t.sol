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
        s_stableToken.mint(address(this), 1e18);
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

        s_buttonWoodBondController.deposit(10e9);

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
        vm.prank(address(this));
        vm.expectEmit(true, true, true, true);
        emit Initialized(address(1), address(2), 0, collateralAmount);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            collateralAmount,
            0
        );
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
    }

    function testInitializeAndLendEmitsLend(uint256 stableAmount) public {
        vm.assume(
            stableAmount <=
                (s_safeTranche.balanceOf(address(this)) * s_price) /
                    s_priceGranularity
        );
        vm.assume(stableAmount != 0);

        vm.expectEmit(true, true, true, true);
        emit Lend(address(this), address(1), address(2), stableAmount, s_price);
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            0,
            stableAmount
        );
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
        s_deployedConvertibleBondBox.lend(address(1), address(2), s_depositLimit);
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
        s_deployedConvertibleBondBox.borrow(address(1), address(2), s_depositLimit);
    }

    // currentPrice()

    function testCurrentPrice() public {
        vm.warp((s_deployedConvertibleBondBox.s_startDate() + s_maturityDate) / 2);
        uint256 currentPrice = s_deployedConvertibleBondBox.currentPrice();
        uint256 price = s_deployedConvertibleBondBox.initialPrice();
        uint256 priceGranularity = s_deployedConvertibleBondBox.priceGranularity();
        assertEq((priceGranularity - price) / 2 + price, currentPrice);
    }

    // repay()
    // Still need to test OverPayment() revert and PayoutExceedsBalance() revert

    function testRepay(uint256 time) public {
        //More parameters can be added to this test
        vm.assume(time < s_endOfUnixTime - s_maturityDate);
        vm.warp(s_maturityDate + time);
        vm.prank(address(this));
        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );
        vm.startPrank(s_deployedCBBAddress);
        CBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).mint(
            address(this),
            1e18
        );
        vm.stopPrank();
        vm.expectEmit(true, true, true, true);
        emit Repay(address(this), 100000, 250000, 187501, 1000000000);
        s_deployedConvertibleBondBox.repay(100000, 625001);
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

        vm.expectEmit(true, true, true, true);
        emit RedeemTranche(address(this), amount);
        s_deployedConvertibleBondBox.redeemTranche(amount);
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

    function testEndToEnd(uint256 collateralAmount, uint256 stableAmount, uint256 amount, uint256 lender, uint256 borrower) public {
        vm.assume(lender < 11);
        vm.assume(lender > 0);

        vm.borrower(lender < 11);
        vm.borrower(lender > 0);

        address address1 = address(1);
        address address2 = address(2);
        address address3 = address(3);
        address address4 = address(4);
        address address5 = address(5);
        address address6 = address(6);
        address address7 = address(7);
        address address8 = address(8);
        address address9 = address(9);
        address address10 = address(10);


        // initialize lending box
        vm.assume(collateralAmount <= s_safeTranche.balanceOf(address(this)));
        vm.assume(collateralAmount != 0);
                vm.assume(
            stableAmount <=
                (s_safeTranche.balanceOf(address(this)) * s_price) /
                    s_priceGranularity
        );
        vm.assume(stableAmount != 0);
        vm.assume(amount < 1e18);
        vm.assume(amount > 0);

        (ITranche safeTranche, uint256 ratio) = s_buttonWoodBondController
            .tranches(0);
        (ITranche riskTranche, uint256 riskRatio) = s_buttonWoodBondController
            .tranches(2);
        vm.startPrank(address(s_buttonWoodBondController));
        safeTranche.mint(address(this), amount);
        riskTranche.mint(address(this), amount);
        // safeTranche.mint(address(s_deployedConvertibleBondBox), 1e18);
        vm.stopPrank();

        safeTranche.approve(address(s_deployedConvertibleBondBox), 1e18);

        vm.prank(address(this));
        vm.expectEmit(true, true, true, true);
        emit Initialized(address(1), address(2), 0, collateralAmount);

        s_deployedConvertibleBondBox.initialize(
            address(1),
            address(2),
            collateralAmount,
            0
        );
        // call lend
        s_deployedConvertibleBondBox.lend(address(1), address(2), stableAmount);
        // call borrow
        s_deployedConvertibleBondBox.borrow(address(3), address(4), 100);
        // call repays and redeems
        s_stableToken.mint(address(3), 1e18);

        vm.startPrank(address(3));
                s_stableToken.approve(address(s_deployedConvertibleBondBox), 1e18);

        uint riskSlipBalance = ICBBSlip(s_deployedConvertibleBondBox.s_riskSlipTokenAddress()).balanceOf(address(3));

        s_deployedConvertibleBondBox.repay(10, riskSlipBalance);
        vm.stopPrank();

        vm.warp(s_maturityDate);
        vm.startPrank(address(4));
        s_deployedConvertibleBondBox.redeemTranche(5);
        vm.stopPrank();

        vm.startPrank(address(4));
        s_deployedConvertibleBondBox.redeemStable(1);
        vm.stopPrank();
    }
}
