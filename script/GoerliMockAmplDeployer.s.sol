// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import "../src/contracts/Slip.sol";
import "../src/contracts/SlipFactory.sol";
import "../src/contracts/ConvertibleBondBox.sol";
import "../src/contracts/CBBFactory.sol";
import "../src/contracts/StagingBox.sol";
import "../src/contracts/StagingBoxFactory.sol";
import "../src/contracts/StagingBoxLens.sol";
import "../src/contracts/StagingLoanRouter.sol";
import "../test/mocks/MockERC20.sol";
import "../test/external/button-wrappers/MockOracle.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/IBondFactory.sol";
import "../test/external/tranche/BondController.sol";
import "../test/external/tranche/Tranche.sol";
import "../test/external/tranche/TrancheFactory.sol";
import "../test/external/button-wrappers/ButtonTokenFactory.sol";
import "../test/external/button-wrappers/ButtonToken.sol";

contract GoerliBatchDeployer is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        //deploy poor token & mint to msg.sender
        MockERC20 mockAMPL = new MockERC20("mockAMPL", "mockAMPL", 18);
        mockAMPL.mint(msg.sender, 15e24);
        mockAMPL.mint(0x53462C34c2Da0aC7cF391E305327f2C566D40d8D, 15e24);
        mockAMPL.mint(0xEcA6c389fb76f92cc68223C01498FA83Ec3CE02F, 15e24);

        //Deploy & Initialize BondController
        uint256[] memory ratios = new uint256[](3);
        ratios[0] = 200;
        ratios[1] = 300;
        ratios[2] = 500;

        BondController mockAmplBond = new BondController();
        mockAmplBond.init(
            address(0xE0De6e1a505b69D2987fAe7230db96682d26Dfca),
            address(mockAMPL),
            msg.sender,
            ratios,
            block.timestamp + 2592e3,
            type(uint256).max
        );

        vm.stopBroadcast();

        console2.log(address(mockAMPL), "mockAMPL");
        console2.log(address(mockAmplBond), "mockAmplBond");
    }
}
