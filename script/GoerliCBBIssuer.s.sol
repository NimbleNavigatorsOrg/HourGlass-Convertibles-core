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
        StagingBoxFactory(0xC12803558f756C726DeE05a0BC8A04c7a8c32b0f);
    SlipFactory slipFactory =
        SlipFactory(0xD96D4AF92CA2E89E6e423C2aC7144A0c60412156);
    StagingLoanRouter slr =
        StagingLoanRouter(0xA081Eb692C431749D8fa6D45FBEC726703dFe66d);
    StagingBoxLens sbLens =
        StagingBoxLens(0xdfe5010d0AfBb0b988087C43792De3212A23318a);

    address public trancheFact = 0xE0De6e1a505b69D2987fAe7230db96682d26Dfca;
    address public poorToken = 0xb7BF564674dCdA1067Cfe6AbE4775e151E91Bc1B;
    address public buttonPoor = 0x434995Ff76c3f06267aD42Cc5B646DbfEF9351E0;
    address public mockAmpl = 0x0E70417aa5F2A2b605e74Ab79637003C0e516Aa3;
    address public weenus = 0xaFF4481D10270F50f203E0763e2597776068CBc5;

    address public recipientA = 0x53462C34c2Da0aC7cF391E305327f2C566D40d8D;
    address public recipientB = 0xEcA6c389fb76f92cc68223C01498FA83Ec3CE02F;

    uint256 public basePrice = 70e6;
    uint256 public basePenalty = 10;

    uint8 public repeatCount = 1;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        //Deploy & Initialize BondController
        uint256[] memory ratios = new uint256[](2);
        ratios[0] = 200;
        ratios[1] = 800;

        BondController poorBond = new BondController();
        poorBond.init(
            trancheFact,
            buttonPoor,
            msg.sender,
            ratios,
            block.timestamp + 2592e3,
            type(uint256).max
        );

        BondController poorBondMature = new BondController();
        poorBondMature.init(
            trancheFact,
            buttonPoor,
            msg.sender,
            ratios,
            block.timestamp + 300,
            type(uint256).max
        );

        // BondController mockAmplBond = new BondController();
        // mockAmplBond.init(
        //     trancheFact,
        //     mockAmpl,
        //     msg.sender,
        //     ratios,
        //     block.timestamp + 2592e3,
        //     type(uint256).max
        // );

        // BondController mockAmplBondMature = new BondController();
        // mockAmplBondMature.init(
        //     trancheFact,
        //     mockAmpl,
        //     msg.sender,
        //     ratios,
        //     block.timestamp + 300,
        //     type(uint256).max
        // );

        //create IBO CBBs + SBs
        for (uint8 i = 0; i < repeatCount; i++) {
            address createdSBPoor = stagingFactory.createStagingBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                poorBond,
                i + basePenalty,
                weenus,
                0,
                basePrice + (i * 1e6),
                msg.sender
            );

            // address createdSBAmpl = stagingFactory.createStagingBoxWithCBB(
            //     (convertiblesFactory),
            //     (slipFactory),
            //     mockAmplBond,
            //     i + basePenalty,
            //     weenus,
            //     0,
            //     basePrice + (i * 1e6),
            //     msg.sender
            // );

            console2.log(createdSBPoor, "SB-IBO-Poor", i);

            console2.log(
                address(StagingBox(createdSBPoor).convertibleBondBox()),
                "CBB-IBO-Poor",
                i
            );
            // console2.log(createdSBAmpl, "SB-IBO-AMPL", i);
            // console2.log(
            //     address(StagingBox(createdSBAmpl).convertibleBondBox()),
            //     "CBB-IBO-AMPL",
            //     i
            // );
        }

        //create active Bonds (poorToken only)

        for (uint8 i = 0; i < repeatCount; i++) {
            address createdSBPoor = stagingFactory.createStagingBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                poorBond,
                i + basePenalty,
                weenus,
                0,
                basePrice + (i * 1e6),
                msg.sender
            );

            IERC20(weenus).approve(createdSBPoor, type(uint256).max);
            IERC20(poorToken).approve(address(slr), type(uint256).max);

            //make lendDeposits to 3 parties

            StagingBox(createdSBPoor).depositLend(msg.sender, 100e18);
            StagingBox(createdSBPoor).depositLend(recipientA, 100e18);
            StagingBox(createdSBPoor).depositLend(recipientB, 100e18);

            //make borrowDeposits & distribute to 3 parties

            slr.simpleWrapTrancheBorrow(
                IStagingBox(createdSBPoor),
                10000e18,
                0
            );
            uint256 poorBorrowSlipDistributionAmount = StagingBox(createdSBPoor)
                .borrowSlip()
                .balanceOf(msg.sender) / 3;
            StagingBox(createdSBPoor).borrowSlip().transfer(
                recipientA,
                poorBorrowSlipDistributionAmount
            );
            StagingBox(createdSBPoor).borrowSlip().transfer(
                recipientB,
                poorBorrowSlipDistributionAmount
            );

            //transmitReinit

            bool poorBool = sbLens.viewTransmitReInitBool(
                IStagingBox(createdSBPoor)
            );

            StagingBox(createdSBPoor).transmitReInit(poorBool);

            //repeat for AMPL-Token

            console2.log(createdSBPoor, "SB-ACTIVE-Poor", i);
            console2.log(
                address(StagingBox(createdSBPoor).convertibleBondBox()),
                "CBB-ACTIVE-Poor",
                i
            );
        }

        //create Mature Bonds

        for (uint8 i = 0; i < repeatCount; i++) {
            address createdSBPoor = stagingFactory.createStagingBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                poorBondMature,
                i + basePenalty,
                weenus,
                0,
                basePrice + (i * 1e6),
                msg.sender
            );

            IERC20(weenus).approve(createdSBPoor, type(uint256).max);
            IERC20(poorToken).approve(address(slr), type(uint256).max);

            //make lendDeposits to 3 parties

            StagingBox(createdSBPoor).depositLend(msg.sender, 100e18);
            StagingBox(createdSBPoor).depositLend(recipientA, 100e18);
            StagingBox(createdSBPoor).depositLend(recipientB, 100e18);

            //make borrowDeposits & distribute to 3 parties

            slr.simpleWrapTrancheBorrow(IStagingBox(createdSBPoor), 500e18, 0);
            uint256 poorBorrowSlipDistributionAmount = StagingBox(createdSBPoor)
                .borrowSlip()
                .balanceOf(msg.sender) / 3;
            StagingBox(createdSBPoor).borrowSlip().transfer(
                recipientA,
                poorBorrowSlipDistributionAmount
            );
            StagingBox(createdSBPoor).borrowSlip().transfer(
                recipientB,
                poorBorrowSlipDistributionAmount
            );

            //transmitReInit
            bool poorBool = sbLens.viewTransmitReInitBool(
                IStagingBox(createdSBPoor)
            );

            StagingBox(createdSBPoor).transmitReInit(poorBool);

            console2.log(createdSBPoor, "SB-MATURE-Poor", i);
            console2.log(
                address(StagingBox(createdSBPoor).convertibleBondBox()),
                "CBB-MATURE-Poor",
                i
            );
        }

        vm.stopBroadcast();
    }
}
