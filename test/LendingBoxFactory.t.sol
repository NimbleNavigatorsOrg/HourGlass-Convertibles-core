// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "../src/contracts/LendingBox.sol";
import "../src/contracts/LendingBoxFactory.sol";
import "../src/contracts/ButtonWoodBondController.sol";

// import "../src/contracts/external/ERC20.sol";

// import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
// import "../src/contracts/Slip.sol";
// import "../src/contracts/SlipFactory.sol";

contract LendingBoxFactoryTest is Test {
    ButtonWoodBondController buttonWoodBondController;
    LendingBox lendingBox;
    LendingBoxFactory lendingBoxFactory;

    // ERC20 collateralToken;
    // ERC20 stableToken;
    // TrancheFactory trancheFactory;
    // Tranche tranche;
    // Slip slip;
    // SlipFactory slipFactory;

    function setUp() public {
        // create buttonwood bond collateral token
        // collateralToken = new ERC20("CollateralToken", "CT");

        // // create stable token
        // stableToken = new ERC20("StableToken", "ST");

        // // create tranche
        // tranche = new Tranche();

        // // create buttonwood tranche factory
        // trancheFactory = new TrancheFactory(address(tranche));

        // // create slip
        // slip = new Slip();

        // // create slip factory
        // slipFactory = new SlipFactory(address(slip));

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
