// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/LendingBox.sol";
import "../src/interfaces/ILendingBox.sol";
import "../src/contracts/LendingBoxFactory.sol";
import "../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../src/contracts/CBBSlip.sol";
import "../src/contracts/SlipFactory.sol";
import "forge-std/console2.sol";
import "../test/mocks/MockERC20.sol";

contract LendingBoxTest is Test {
    ButtonWoodBondController s_buttonWoodBondController;
    LendingBox s_lendingBox;
    LendingBox s_deployedLendingBox;
    LendingBoxFactory s_lendingBoxFactory;

    MockERC20 s_collateralToken;

    MockERC20 s_stableToken;
    TrancheFactory s_trancheFactory;
    Tranche s_tranche;
    CBBSlip s_slip;
    SlipFactory s_slipFactory;
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
    address s_deployedLendingBoxAddress;

    event LendingBoxCreated(
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
        s_slipFactory = new SlipFactory(address(s_slip));

        s_buttonWoodBondController = new ButtonWoodBondController();
        s_lendingBox = new LendingBox();
        s_lendingBoxFactory = new LendingBoxFactory(address(s_lendingBox));

        s_buttonWoodBondController.init(
            address(s_trancheFactory),
            address(s_collateralToken),
            address(this),
            s_ratios,
            s_maturityDate,
            s_depositLimit
        );

        s_deployedLendingBoxAddress = s_lendingBoxFactory.createLendingBox(
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

        s_safeTranche.approve(s_deployedLendingBoxAddress, type(uint256).max);
        s_riskTranche.approve(s_deployedLendingBoxAddress, type(uint256).max);
        s_stableToken.approve(s_deployedLendingBoxAddress, type(uint256).max);

        s_deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);

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
        s_deployedLendingBox.initialize(
            address(1),
            address(2),
            collateralAmount,
            0
        );
    }

    function testCannotInitializePenaltyTooHigh(uint256 penalty) public {
        vm.assume(penalty > s_penaltyGranularity);
        s_deployedLendingBoxAddress = s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_trancheIndex
        );

        s_deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);

        bytes memory customError = abi.encodeWithSignature(
            "PenaltyTooHigh(uint256,uint256)",
            penalty,
            s_deployedLendingBox.penaltyGranularity()
        );
        vm.expectRevert(customError);
        s_deployedLendingBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );
    }

    function testCannotInitializeBondIsMature() public {
        s_buttonWoodBondController.mature();
        s_deployedLendingBoxAddress = s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            1001,
            s_trancheIndex
        );

        s_deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);

        bytes memory customError = abi.encodeWithSignature(
            "BondIsMature(bool,bool)",
            s_buttonWoodBondController.isMature(),
            false
        );
        vm.expectRevert(customError);
        s_deployedLendingBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );
    }

    //TODO reasses test later
    function testCannotInitializeTrancheIndexOutOfBounds() public {
        // vm.assume(trancheIndex == s_buttonWoodBondController.trancheCount() - 1);
        s_deployedLendingBoxAddress = s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            1001,
            s_buttonWoodBondController.trancheCount() - 1
        );
        s_deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);

        bytes memory customError = abi.encodeWithSignature(
            "TrancheIndexOutOfBounds(uint256,uint256)",
            s_buttonWoodBondController.trancheCount() - 1,
            s_buttonWoodBondController.trancheCount() - 2
        );
        vm.expectRevert(customError);
        s_deployedLendingBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );
    }

    //TODO reasses test later

    function testFailInitializeTrancheBW(uint256 trancheIndex) public {
        vm.assume(trancheIndex > s_buttonWoodBondController.trancheCount() - 1);
        s_deployedLendingBoxAddress = s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            1001,
            trancheIndex
        );
        s_deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);

        s_deployedLendingBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );
    }

    function testCannotInitializeInitialPriceTooHigh(uint256 price) public {
        vm.assume(price > s_priceGranularity);
        s_deployedLendingBoxAddress = s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            price,
            s_trancheIndex
        );

        s_deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);
        bytes memory customError = abi.encodeWithSignature(
            "InitialPriceTooHigh(uint256,uint256)",
            price,
            s_priceGranularity
        );
        vm.expectRevert(customError);
        s_deployedLendingBox.initialize(
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

        s_deployedLendingBoxAddress = s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_trancheIndex
        );

        s_deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);

        bytes memory customError = abi.encodeWithSignature(
            "OnlyLendOrBorrow(uint256,uint256)",
            collateralAmount,
            stableAmount
        );
        vm.expectRevert(customError);
        s_deployedLendingBox.initialize(
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
        s_deployedLendingBox.initialize(
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
        s_deployedLendingBox.initialize(
            address(1),
            address(2),
            0,
            stableAmount
        );
    }

    // lend()

    function testCannotLendLendingBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "LendingBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedLendingBox.lend(address(1), address(2), s_depositLimit);
    }

    //borrow()

    function testCannotBorrowLendingBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "LendingBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedLendingBox.borrow(address(1), address(2), s_depositLimit);
    }

    // currentPrice()

    function testCurrentPrice() public {
        vm.warp((s_deployedLendingBox.s_startDate() + s_maturityDate) / 2);
        uint256 currentPrice = s_deployedLendingBox.currentPrice();
        uint256 price = s_deployedLendingBox.initialPrice();
        uint256 priceGranularity = s_deployedLendingBox.priceGranularity();
        assertEq((priceGranularity - price) / 2 + price, currentPrice);
    }

    // repay()

    function testRepay(uint256 time) public {
        //More parameters can be added to this test
        vm.assume(time < s_endOfUnixTime - s_maturityDate);
        vm.warp(s_maturityDate + time);
        vm.prank(address(this));
        s_deployedLendingBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );
        vm.startPrank(s_deployedLendingBoxAddress);
        CBBSlip(s_deployedLendingBox.s_riskSlipTokenAddress()).mint(
            address(this),
            1e18
        );
        vm.stopPrank();
        vm.expectEmit(true, true, true, true);
        emit Repay(address(this), 100000, 250000, 187501, 1000000000);
        s_deployedLendingBox.repay(100000, 625001);
    }

    function testCannotRepayLendingBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "LendingBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedLendingBox.repay(100000, 625001);
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
        s_deployedLendingBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );

        vm.startPrank(address(s_buttonWoodBondController));
        safeTranche.mint(s_deployedLendingBoxAddress, amount);
        vm.stopPrank();

        vm.startPrank(s_deployedLendingBoxAddress);
        CBBSlip(s_deployedLendingBox.s_safeSlipTokenAddress()).mint(
            address(this),
            amount
        );
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit RedeemTranche(address(this), amount);
        s_deployedLendingBox.redeemTranche(amount);
    }

    function testCannotRedeemTrancheBondNotMatureYet(uint256 time) public {
        vm.assume(time <= s_maturityDate && time != 0);
        vm.warp(s_maturityDate - time);
        vm.prank(address(this));
        emit Initialized(address(1), address(2), 0, s_depositLimit);

        s_deployedLendingBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );
        vm.startPrank(s_deployedLendingBoxAddress);
        CBBSlip(s_deployedLendingBox.s_safeSlipTokenAddress()).mint(
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
        s_deployedLendingBox.redeemTranche(s_safeSlipAmount);
    }

    // redeemStable()

    function testRedeemStable(uint256 safeSlipAmount) public {
        vm.assume(safeSlipAmount <= 1e18);
        vm.prank(address(this));
        emit Initialized(address(1), address(2), 0, s_depositLimit);
        s_deployedLendingBox.initialize(
            address(1),
            address(2),
            s_depositLimit,
            0
        );
        vm.startPrank(s_deployedLendingBoxAddress);
        CBBSlip(s_deployedLendingBox.s_safeSlipTokenAddress()).mint(
            address(this),
            1e18
        );
        vm.stopPrank();
        vm.expectEmit(true, true, true, true);
        emit RedeemStable(
            address(this),
            safeSlipAmount,
            s_deployedLendingBox.currentPrice()
        );
        s_deployedLendingBox.redeemStable(safeSlipAmount);
    }

    function testCannotRedeemStableLendingBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature(
            "LendingBoxNotStarted(uint256,uint256)",
            0,
            block.timestamp
        );
        vm.expectRevert(customError);
        s_deployedLendingBox.redeemStable(s_safeSlipAmount);
    }
}
