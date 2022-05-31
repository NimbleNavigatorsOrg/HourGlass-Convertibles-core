// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/LendingBoxFactory.sol";
import "../src/contracts/LendingBox.sol";
import "../src/contracts/ButtonWoodBondController.sol";

contract LendingBoxFactoryTest is Test {

    ButtonWoodBondController buttonWoodBondController;
    LendingBox lendingBox;
    LendingBoxFactory lendingBoxFactory;

    function setUp() public {

        // create buttonwood tranche factory

        // create buttonwood bond collateral token

        // create stable token

        // create slip

        // create slip factory

        buttonWoodBondController = new ButtonWoodBondController();
        lendingBox = new LendingBox();
        lendingBoxFactory = new LendingBoxFactory(address(lendingBox));
    }

    function testFactoryCreatesLendingBox() public {
        // keep this assert
        assertEq(lendingBoxFactory.implementation(), address(lendingBox));



        // call init on bondcontroller

        // call createLendingbox should return an address from factory

        // wrap address in ILendingBox and make assertions on inital values
        // example assertEq(lendingbox.penalty, 1000)
    }
}
