// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/LendingBox.sol";
import "../src/contracts/LendingBoxFactory.sol";
import "../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/external/ERC20.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../src/contracts/Slip.sol";
import "../src/contracts/SlipFactory.sol";

contract LendingBoxFactoryTest is Test {
    ButtonWoodBondController s_buttonWoodBondController;
    LendingBox s_lendingBox;
    LendingBoxFactory s_lendingBoxFactory;

    ERC20 s_collateralToken;

    ERC20 s_stableToken;
    TrancheFactory s_trancheFactory;
    Tranche s_tranche;
    CBBSlip s_slip;
    SlipFactory s_slipFactory;
    uint256[] s_ratios;
    uint256 constant s_penalty = 500;
    uint256 constant s_price = 5e8;
    uint256 constant s_startDate = 1654100749;
    uint256 constant s_trancheIndex = 0;
    uint256 constant s_maturityDate = 1656717949;
    uint256 constant s_depositLimit = 1000e9;
    error PenaltyTooHigh(uint256 given, uint256 maxPenalty);
    address s_deployedLendingBoxAddress;

    event LendingBoxCreated(
        address s_collateralToken,
        address s_stableToken,
        uint256 trancheIndex,
        uint256 penalty,
        address creator
    );

    function setUp() public {
        //push numbers into array
        s_ratios.push(200);
        s_ratios.push(300);
        s_ratios.push(500);

        // create buttonwood bond collateral token
        s_collateralToken = new ERC20("CollateralToken", "CT");

        // // create stable token
        s_stableToken = new ERC20("StableToken", "ST");

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
    }

    function testFactoryCreatesLendingBox() public {
        // wrap address in ILendingBox and make assertions on inital values
        LendingBox deployedLendingBox = LendingBox(s_deployedLendingBoxAddress);

        // keep this assert
        assertEq(s_lendingBoxFactory.implementation(), address(s_lendingBox));

        assertEq(
            address(deployedLendingBox.bond()),
            address(s_buttonWoodBondController)
        );
        assertEq(
            address(deployedLendingBox.slipFactory()),
            address(s_slipFactory)
        );
        assertEq(deployedLendingBox.penalty(), s_penalty);
        assertEq(
            address(deployedLendingBox.collateralToken()),
            address(s_collateralToken)
        );
        assertEq(
            address(deployedLendingBox.stableToken()),
            address(s_stableToken)
        );
        assertEq(deployedLendingBox.initialPrice(), s_price);
        assertEq(deployedLendingBox.s_startDate(), block.timestamp);
        assertEq(deployedLendingBox.trancheIndex(), s_trancheIndex);
    }

    function testCreateLendingBoxEmitsExpectedEvent() public {
        vm.expectEmit(true, true, true, true);
        // The event we expect
        emit LendingBoxCreated(
            address(s_collateralToken),
            address(s_stableToken),
            s_trancheIndex,
            s_penalty,
            address(this)
        );
        // The event we get
        s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_trancheIndex
        );
    }

    function testFailIncorrectlyInitializePenalty() public {
        s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            1001,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_trancheIndex
        );
    }

    function testFailBondIsMature() public {
        s_buttonWoodBondController.mature();

        s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_trancheIndex
        );
    }

    function testFailTrancheIndexOutOfBounds() public {
        s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            3
        );
    }

    function testFailInitialPriceTooHigh() public {
        s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            1000000001,
            s_trancheIndex
        );
    }

    function testFailStartDateAfterMaturity() public {
        s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_trancheIndex
        );
    }
}
