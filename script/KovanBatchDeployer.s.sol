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
import "@buttonwood-protocol/tranche/contracts/interfaces/IBondFactory.sol";
import "../test/external/button-wrappers/ButtonTokenFactory.sol";
import "../test/external/button-wrappers/ButtonToken.sol";

contract KovanSlipDeployer is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // //deploy slips + slip factory
        Slip deployedSlip = new Slip();
        SlipFactory slipFactory = new SlipFactory(address(deployedSlip));

        //deploy CBB + CBB factory
        ConvertibleBondBox deployedCBB = new ConvertibleBondBox();
        CBBFactory cbbFactory = new CBBFactory(address(deployedCBB));

        //staging box + staging box factory
        StagingBox deployedStagingBox = new StagingBox();
        StagingBoxFactory sbFactory = new StagingBoxFactory(
            address(deployedStagingBox)
        );

        //deploy staging box router + lens
        StagingLoanRouter stagingLoanRouter = new StagingLoanRouter();
        StagingBoxLens stagingBoxLens = new StagingBoxLens();

        vm.stopBroadcast();

        console2.log(address(deployedSlip), "deployedSlip");
        console2.log(address(slipFactory), "slipFactory");
        console2.log(address(cbbFactory), "ConvertiblesFactory");
        console2.log(address(sbFactory), "StagingBoxFactory");
        console2.log(address(stagingLoanRouter), "StagingLoanRouter");
        console2.log(address(stagingBoxLens), "StagingBoxLens");
    }
}
