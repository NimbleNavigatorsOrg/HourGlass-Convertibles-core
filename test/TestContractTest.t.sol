// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/contracts/TestContract.sol";

contract TestContractTest is Test {

    TestContract testContract;

    function setUp() public {
        testContract = new TestContract();
    }

    function testInitialize() public {
        // testContract.initialize(address(this));
        // assertEq(testContract.owner(), address(this));
        testContract.reinitialize(address(1));
        assertEq(testContract.owner(), address(1));
    }
}