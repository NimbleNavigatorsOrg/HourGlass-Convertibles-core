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
    ButtonWoodBondController buttonWoodBondController;
    LendingBox lendingBox;
    LendingBoxFactory lendingBoxFactory;

    ERC20 collateralToken;

    ERC20 stableToken;
    TrancheFactory trancheFactory;
    Tranche tranche;
    CBBSlip slip;
    SlipFactory slipFactory;
    uint256[] ratios;

    function setUp() public {
        //push numbers into array
        ratios.push(200);
        ratios.push(300);
        ratios.push(500);

        // create buttonwood bond collateral token
        collateralToken = new ERC20("CollateralToken", "CT");

        // // create stable token
        stableToken = new ERC20("StableToken", "ST");

        // // create tranche
        tranche = new Tranche();

        // // create buttonwood tranche factory
        trancheFactory = new TrancheFactory(address(tranche));

        // // create slip
        slip = new CBBSlip();

        // // create slip factory
        slipFactory = new SlipFactory(address(slip));

        buttonWoodBondController = new ButtonWoodBondController();
        lendingBox = new LendingBox();
        lendingBoxFactory = new LendingBoxFactory(address(lendingBox));
    }

    function testFactoryCreatesLendingBox() public {
        // keep this assert
        assertEq(lendingBoxFactory.implementation(), address(lendingBox));

        // call init on bondcontroller
        buttonWoodBondController.init(
            address(trancheFactory),
            address(collateralToken),
            address(this),
            ratios,
            1656717949,
            1000e9
        );

        // call createLendingbox should return an address from factory
        address deployedLendingBoxAddress = lendingBoxFactory.createLendingBox(
            buttonWoodBondController,
            slipFactory,
            500,
            address(collateralToken),
            address(stableToken),
            5e8,
            1654100749,
            0
        );

        // wrap address in ILendingBox and make assertions on inital values
        LendingBox deployedLendingBox = LendingBox(deployedLendingBoxAddress);
        assertEq(
            address(deployedLendingBox.bond()),
            address(buttonWoodBondController)
        );
        assertEq(
            address(deployedLendingBox.slipFactory()),
            address(slipFactory)
        );
        assertEq(deployedLendingBox.penalty(), 500);
        assertEq(
            address(deployedLendingBox.collateralToken()),
            address(collateralToken)
        );
        assertEq(
            address(deployedLendingBox.stableToken()),
            address(stableToken)
        );
        assertEq(deployedLendingBox.price(), 5e8);
        assertEq(deployedLendingBox.startDate(), 1654100749);
        assertEq(deployedLendingBox.trancheIndex(), 0);

        //TODO: Test event emission
    }
}
