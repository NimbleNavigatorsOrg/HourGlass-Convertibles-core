// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/ConvertibleBondBox.sol";
import "../src/contracts/CBBFactory.sol";
import "./external/tranche/Tranche.sol";
import "./external/tranche/TrancheFactory.sol";
import "@buttonwood-protocol/tranche/contracts/external/ERC20.sol";
import "../src/contracts/Slip.sol";
import "../src/contracts/SlipFactory.sol";
import "forge-std/console2.sol";

contract SlipFactoryTest is Test {
    ERC20 s_collateralToken;
    Slip s_slip;
    SlipFactory s_slipFactory;
    address s_deployedSlip;
    event SlipCreated(address newSlipAddress);

    function setUp() public {
        s_collateralToken = new ERC20("CollateralToken", "CT");
        s_slip = new Slip();
        s_slipFactory = new SlipFactory(address(s_slip));
        s_deployedSlip = s_slipFactory.createSlip(
            "slip",
            "SLP",
            address(s_collateralToken)
        );
    }

    function testSlipFactoryConstruction() public {
        assertEq(address(s_slip), s_slipFactory.target());
    }

    function testCreateSlipEmitsEvent() public {
        vm.expectEmit(true, true, true, false);
        // The event we expect
        emit SlipCreated(s_deployedSlip);
        // The event we get
        s_slipFactory.createSlip("slip", "SLP", address(s_collateralToken));
    }

    function testFailCreateSlipWithInvalidCaller() public {
        vm.prank(address(0));
        s_slipFactory.createSlip("slip", "SLP", address(s_collateralToken));
    }

    function testFailCreateSlipWithInvalidCollateral() public {
        s_slipFactory.createSlip("slip", "SLP", address(0));
    }
}
