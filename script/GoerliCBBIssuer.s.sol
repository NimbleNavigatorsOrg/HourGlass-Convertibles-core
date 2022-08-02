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

contract GoerliCBBIssuer is Script {
    CBBFactory convertiblesFactory =
        CBBFactory(0x876e563786eA903e1B1F59E339aE34152d84aDB1);
    StagingBoxFactory stagingFactory =
        StagingBoxFactory(0xf90120611e2d34cdecfB526f57A18782Bd0C2B6F);
    SlipFactory slipFactory =
        SlipFactory(0xD96D4AF92CA2E89E6e423C2aC7144A0c60412156);

    IBondController poorBond =
        IBondController(0xE36A5a5CcAb4DaF557494Bb8c0838a5fF79dD677);

    address public weenus = 0xaFF4481D10270F50f203E0763e2597776068CBc5;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address createdSB1 = stagingFactory.createStagingBoxWithCBB(
            (convertiblesFactory),
            (slipFactory),
            poorBond,
            0,
            weenus,
            0,
            75e6,
            msg.sender
        );

        address createdSB2 = stagingFactory.createStagingBoxWithCBB(
            (convertiblesFactory),
            (slipFactory),
            poorBond,
            10,
            weenus,
            0,
            80e6,
            msg.sender
        );

        address createdSB3 = stagingFactory.createStagingBoxWithCBB(
            (convertiblesFactory),
            (slipFactory),
            poorBond,
            20,
            weenus,
            0,
            77e6,
            msg.sender
        );

        vm.stopBroadcast();

        console2.log(address(createdSB1), "createdSB1");
        console2.log(address(createdSB2), "createdSB2");
        console2.log(address(createdSB3), "createdSB3");
    }
}
