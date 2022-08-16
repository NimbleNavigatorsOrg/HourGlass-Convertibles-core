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

        //deploy buttonwood artifacts
        Tranche baseTranche = new Tranche();
        TrancheFactory trancheFact = new TrancheFactory(address(baseTranche));

        //deploy poor token & mint to msg.sender
        MockERC20 poorToken = new MockERC20("PoorToken", "goerliPOOR");
        poorToken.mint(msg.sender, 15e24);

        //deploy mock oracle
        MockOracle poorPriceOracle = new MockOracle();
        poorPriceOracle.setData(5e7, true);

        //deploy buttonToken & initialize
        ButtonToken buttonPoor = new ButtonToken();
        buttonPoor.initialize(
            address(poorToken),
            "ButtonPoor",
            "btnPOOR",
            address(poorPriceOracle)
        );

        //Deploy & Initialize BondController
        uint256[] memory ratios = new uint256[](2);
        ratios[0] = 200;
        ratios[1] = 800;

        BondController poorBond = new BondController();
        poorBond.init(
            address(trancheFact),
            address(buttonPoor),
            msg.sender,
            ratios,
            block.timestamp + 2592e3,
            type(uint256).max
        );

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

        console2.log(address(poorPriceOracle), "poorPriceOracle");
        console2.log(address(trancheFact), "TrancheFactory");
        console2.log(address(poorToken), "poorToken");
        console2.log(address(buttonPoor), "buttonPoor");
        console2.log(address(poorBond), "poorBond");

        console2.log(address(deployedSlip), "deployedSlip");
        console2.log(address(slipFactory), "slipFactory");
        console2.log(address(cbbFactory), "ConvertiblesFactory");
        console2.log(address(sbFactory), "StagingBoxFactory");
        console2.log(address(stagingLoanRouter), "StagingLoanRouter");
        console2.log(address(stagingBoxLens), "StagingBoxLens");
    }
}
