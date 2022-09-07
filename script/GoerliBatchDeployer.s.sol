// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/contracts/Slip.sol";
import "../src/contracts/SlipFactory.sol";
import "../src/contracts/ConvertibleBondBox.sol";
import "../src/contracts/ConvertiblesDVLens.sol";
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

        // //deploy buttonwood artifacts
        // Tranche baseTranche = new Tranche();
        // TrancheFactory trancheFact = new TrancheFactory(address(baseTranche));

        // {
        //     //deploy poor token & mint to msg.sender
        //     MockERC20 poorToken = new MockERC20("PoorToken", "goerliPOOR", 8);
        //     poorToken.mint(msg.sender, 15e6 * (10**poorToken.decimals()));

        //     //deploy poor token & mint to msg.sender
        //     MockERC20 peasantToken = new MockERC20(
        //         "PeasantToken",
        //         "goerliPSNT",
        //         18
        //     );
        //     peasantToken.mint(msg.sender, 15e6 * (10**peasantToken.decimals()));

        //     //deploy poor token & mint to msg.sender
        //     MockERC20 poorStable = new MockERC20(
        //         "poorStable",
        //         "goerliPRSTBL",
        //         6
        //     );
        //     poorStable.mint(msg.sender, 15e6 * (10**poorStable.decimals()));

        //     //deploy mock oracle
        //     MockOracle poorOracle = new MockOracle();
        //     poorOracle.setData(5e7, true);

        //     //deploy mock oracle
        //     MockOracle peasantOracle = new MockOracle();
        //     peasantOracle.setData(3e7, true);

        //     //deploy buttonToken & initialize
        //     ButtonToken buttonPoor = new ButtonToken();
        //     buttonPoor.initialize(
        //         address(poorToken),
        //         "ButtonPoor",
        //         "btnPOOR",
        //         address(poorOracle)
        //     );

        //     //deploy buttonToken & initialize
        //     ButtonToken buttonPeasant = new ButtonToken();
        //     buttonPeasant.initialize(
        //         address(peasantToken),
        //         "ButtonPeasant",
        //         "btnPSNT",
        //         address(peasantOracle)
        //     );

        //     console2.log(address(poorOracle), "poorOracle");
        //     console2.log(address(peasantOracle), "peasantOracle");
        //     console2.log(address(poorToken), "poorToken");
        //     console2.log(address(buttonPoor), "buttonPoor");
        //     console2.log(address(peasantToken), "peasantToken");
        //     console2.log(address(buttonPeasant), "buttonPeasant");
        //     console2.log(address(poorStable), "poorStable");
        // }

        // //deploy slips + slip factory
        // Slip deployedSlip = new Slip();
        // SlipFactory slipFactory = new SlipFactory(address(deployedSlip));

        //deploy CBB + CBB factory
        ConvertibleBondBox deployedCBB = new ConvertibleBondBox();
        CBBFactory cbbFactory = new CBBFactory(address(deployedCBB));

        //staging box + staging box factory
        StagingBox deployedStagingBox = new StagingBox();
        StagingBoxFactory sbFactory = new StagingBoxFactory(
            address(deployedStagingBox)
        );

        // //deploy staging box router + lens
        // StagingLoanRouter stagingLoanRouter = new StagingLoanRouter();
        // StagingBoxLens stagingBoxLens = new StagingBoxLens();
        // ConvertiblesDVLens DVLens = new ConvertiblesDVLens();

        vm.stopBroadcast();

        // console2.log(address(deployedSlip), "deployedSlip");
        // console2.log(address(slipFactory), "slipFactory");
        console2.log(address(sbFactory), "StagingBoxFactory");
        console2.log(address(cbbFactory), "ConvertiblesFactory");
        // console2.log(address(stagingLoanRouter), "StagingLoanRouter");
        // console2.log(address(stagingBoxLens), "StagingBoxLens");
        // console2.log(address(DVLens), "DVLens");
    }
}
