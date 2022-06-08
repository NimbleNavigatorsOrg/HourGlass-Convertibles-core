// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/LendingBox.sol";
import "../src/interfaces/ILendingBox.sol";
import "../src/contracts/LendingBoxFactory.sol";
import "../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../src/contracts/Slip.sol";
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
    uint256[] s_ratios;
    uint256 constant s_penalty = 500;
    uint256 constant s_price = 5e8;
    uint256 constant s_trancheIndex = 0;
    uint256 constant s_maturityDate = 1656717949;
    uint256 constant s_depositLimit = 1000e10;
    error PenaltyTooHigh(uint256 given, uint256 maxPenalty);
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

        s_deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);
    }

    // initialize()

    function testInitializeAndBorrowEmitsInitialized() public {
        vm.warp(1);
        s_collateralToken.approve(s_deployedLendingBoxAddress, 1e18);
        s_stableToken.approve(s_deployedLendingBoxAddress, 1e18);

        vm.prank(address(this));
        vm.expectEmit(true, true, true, true);
        emit Initialized(address(1), address(2), 0, s_depositLimit);
        s_deployedLendingBox.initialize(address(1), address(2), s_depositLimit, 0);
    }

    function testFailInitializePenaltyTooHigh() public {
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
        s_deployedLendingBox.initialize(address(1), address(2), s_depositLimit, 0);
    }

    function testFailInitializeBondIsMature() public {
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
        s_deployedLendingBox.initialize(address(1), address(2), s_depositLimit, 0);
    }

    function testFailInitializeTrancheIndexOutOfBonds() public {
        s_deployedLendingBoxAddress = s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            1001,
            3
        );

        s_deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);
        s_deployedLendingBox.initialize(address(1), address(2), s_depositLimit, 0);
    }

    function testFailInitializeInitialPriceTooHigh() public {
        s_deployedLendingBoxAddress = s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            1000000001,
            s_trancheIndex
        );

        s_deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);
        s_deployedLendingBox.initialize(address(1), address(2), s_depositLimit, 0);
    }

    function testFailInitializeOnlyLendOrBorrow() public {
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
        s_deployedLendingBox.initialize(address(1), address(2), 1, 1);
    }

    function testInitializeAndBorrowEmitsBorrow() public {
        s_collateralToken.approve(s_deployedLendingBoxAddress, 1e18);
        s_stableToken.approve(s_deployedLendingBoxAddress, 1e18);

        vm.prank(address(this));
        vm.expectEmit(true, true, true, true);
        emit Borrow(address(this), address(1), address(2), s_depositLimit, s_price);
        s_deployedLendingBox.initialize(address(1), address(2), s_depositLimit, 0);
    }

    function testInitializeAndLendEmitsLend() public {
        vm.warp(1);
        s_collateralToken.approve(s_deployedLendingBoxAddress, 1e18);
        s_stableToken.approve(s_deployedLendingBoxAddress, 1e18);

        vm.prank(address(this));
        vm.expectEmit(true, true, true, true);
        emit Lend(address(this), address(1), address(2), s_depositLimit/10, s_price);
        s_deployedLendingBox.initialize(address(1), address(2), 0, s_depositLimit/10);
    }

    // lend()

    function testCannotLendLendingBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature("LendingBoxNotStarted(uint256,uint256)", 0, block.timestamp);
        vm.expectRevert(customError);
        s_deployedLendingBox.lend(address(1), address(2), s_depositLimit);
    }

    //borrow()

    function testCannotBorrowLendingBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature("LendingBoxNotStarted(uint256,uint256)", 0, block.timestamp);
        vm.expectRevert(customError);
        s_deployedLendingBox.borrow(address(1), address(2), s_depositLimit);
    }

    // currentPrice()

    function testCurrentPrice() public {
        vm.warp((s_deployedLendingBox.s_startDate() + s_maturityDate) / 2);

        uint256 currentPrice = s_deployedLendingBox
            .currentPrice();
        uint256 price = s_deployedLendingBox.initialPrice();
        uint256 priceGranularity = s_deployedLendingBox
            .s_price_granularity();

        assertEq((priceGranularity - price) / 2 + price, currentPrice);
    }

    // repay()

    function testRepay() public {
        s_collateralToken.approve(s_deployedLendingBoxAddress, 1e18);
        s_stableToken.approve(s_deployedLendingBoxAddress, 1e18);
        vm.warp(s_maturityDate + 1);
        vm.prank(address(this));
        s_deployedLendingBox.initialize(address(1), address(2), s_depositLimit, 0);
        vm.startPrank(s_deployedLendingBoxAddress);
        CBBSlip(s_deployedLendingBox.s_riskSlipTokenAddress()).mint(address(this), 1e18);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit Repay(address(this), 100000, 250000, 187501, 1000000000);
        s_deployedLendingBox.repay(100000, 625001);
    }

    function testCannotRepayLendingBoxNotStarted() public {
        bytes memory customError = abi.encodeWithSignature("LendingBoxNotStarted(uint256,uint256)", 0, block.timestamp);
        vm.expectRevert(customError);
        s_deployedLendingBox.repay(100000, 625001);
    }
}
