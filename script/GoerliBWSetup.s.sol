// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import "./external/BondFactory.sol";
import "../test/external/tranche/BondController.sol";
import "../test/external/tranche/Tranche.sol";
import "../test/external/tranche/TrancheFactory.sol";

contract GeorliBWSetup is Script {
    address public buttonPoor = 0x434995Ff76c3f06267aD42Cc5B646DbfEF9351E0;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        Tranche trancheTemplate = new Tranche();
        BondController bondTemplate = new BondController();

        TrancheFactory trancheFact = new TrancheFactory(
            address(trancheTemplate)
        );
        BondFactory bondFact = new BondFactory(
            address(bondTemplate),
            address(trancheFact)
        );

        uint256[] memory ratios = new uint256[](2);
        ratios[0] = 200;
        ratios[1] = 800;

        address newBond0 = bondFact.createBond(
            buttonPoor,
            ratios,
            block.timestamp + 2592e3
        );

        vm.stopBroadcast();

        console2.log(address(trancheFact), "trancheFactory");
        console2.log(address(bondFact), "bondFact");
        console2.log(newBond0, "newbond0");
    }
}
