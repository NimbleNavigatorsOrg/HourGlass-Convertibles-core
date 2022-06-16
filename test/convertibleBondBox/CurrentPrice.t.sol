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

contract CurrentPrice is CBBSetup {
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
}