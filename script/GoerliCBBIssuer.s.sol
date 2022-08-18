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
        CBBFactory(0x94760138F9F6728388cacE7eaA7547382902c46A);
    StagingBoxFactory stagingFactory =
        StagingBoxFactory(0xe34D69cc7A07bFbADf4c6dAc3352c74826c013D7);
    SlipFactory slipFactory =
        SlipFactory(0xD96D4AF92CA2E89E6e423C2aC7144A0c60412156);
    StagingLoanRouter slr =
        StagingLoanRouter(0x60E8271E19e63b8f1591A1f57226f50e218C8664);
    StagingBoxLens sbLens =
        StagingBoxLens(0x119c9541e1fe46a42e8cbd9A458677A8262F10fC);

    address public trancheFact = 0xE0De6e1a505b69D2987fAe7230db96682d26Dfca;
    address public Token = 0xd10A82cba40695B5FDCb37d81Dcf48CE6c9FcDB1;
    address public button = 0x5A07FB993C30F04DD2908411b46A871BAdB88A45;
    address public mockAmpl = 0x0E70417aa5F2A2b605e74Ab79637003C0e516Aa3;
    address public stableCoin = 0xaFF4481D10270F50f203E0763e2597776068CBc5;
    address public weenus = 0xaFF4481D10270F50f203E0763e2597776068CBc5;

    address public recipientA = 0x53462C34c2Da0aC7cF391E305327f2C566D40d8D;
    address public recipientB = 0xEcA6c389fb76f92cc68223C01498FA83Ec3CE02F;

    uint256 public basePrice = 70e6;
    uint256 public basePenalty = 10;

    uint8 public repeatCount = 1;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // MockERC20(Token).mint(msg.sender, 15e24);
        // IERC20(Token).approve(address(slr), 15e24);

        //Deploy & Initialize BondController
        uint256[] memory ratios = new uint256[](2);
        ratios[0] = 200;
        ratios[1] = 800;

        BondController Bond = new BondController();
        Bond.init(
            trancheFact,
            button,
            msg.sender,
            ratios,
            block.timestamp + 2592e3,
            type(uint256).max
        );

        BondController BondMature = new BondController();
        BondMature.init(
            trancheFact,
            button,
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
            address createdSB = stagingFactory.createStagingBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                Bond,
                i + basePenalty,
                stableCoin,
                0,
                basePrice + (i * 1e6),
                msg.sender
            );

            // address createdSBAmpl = stagingFactory.createStagingBoxWithCBB(
            //     (convertiblesFactory),
            //     (slipFactory),
            //     mockAmplBond,
            //     i + basePenalty,
            //     stableCoin,
            //     0,
            //     basePrice + (i * 1e6),
            //     msg.sender
            // );

            console2.log(createdSB, "SB-IBO", i);

            console2.log(
                address(StagingBox(createdSB).convertibleBondBox()),
                "CBB-IBO",
                i
            );
            // console2.log(createdSBAmpl, "SB-IBO-AMPL", i);
            // console2.log(
            //     address(StagingBox(createdSBAmpl).convertibleBondBox()),
            //     "CBB-IBO-AMPL",
            //     i
            // );
        }

        //create active Bonds (Token only)

        for (uint8 i = 0; i < repeatCount; i++) {
            address createdSB = stagingFactory.createStagingBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                Bond,
                i + basePenalty,
                stableCoin,
                0,
                basePrice + (i * 1e6),
                msg.sender
            );

            IERC20(stableCoin).approve(createdSB, type(uint256).max);
            IERC20(Token).approve(address(slr), type(uint256).max);

            //make lendDeposits to 3 parties

            StagingBox(createdSB).depositLend(
                msg.sender,
                100 * (10**ERC20(stableCoin).decimals())
            );
            StagingBox(createdSB).depositLend(
                recipientA,
                100 * (10**ERC20(stableCoin).decimals())
            );
            StagingBox(createdSB).depositLend(
                recipientB,
                100 * (10**ERC20(stableCoin).decimals())
            );

            //make borrowDeposits & distribute to 3 parties

            slr.simpleWrapTrancheBorrow(
                IStagingBox(createdSB),
                100 * (10**ERC20(Token).decimals()),
                0
            );
            uint256 BorrowSlipDistributionAmount = StagingBox(createdSB)
                .borrowSlip()
                .balanceOf(msg.sender) / 3;
            StagingBox(createdSB).borrowSlip().transfer(
                recipientA,
                BorrowSlipDistributionAmount
            );
            StagingBox(createdSB).borrowSlip().transfer(
                recipientB,
                BorrowSlipDistributionAmount
            );

            //transmitReinit

            bool Bool = sbLens.viewTransmitReInitBool(IStagingBox(createdSB));

            StagingBox(createdSB).transmitReInit(Bool);

            //repeat for AMPL-Token

            console2.log(createdSB, "SB-ACTIVE", i);
            console2.log(
                address(StagingBox(createdSB).convertibleBondBox()),
                "CBB-ACTIVE",
                i
            );
        }

        //create Mature Bonds

        for (uint8 i = 0; i < repeatCount; i++) {
            address createdSB = stagingFactory.createStagingBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                BondMature,
                i + basePenalty,
                stableCoin,
                0,
                basePrice + (i * 1e6),
                msg.sender
            );

            IERC20(stableCoin).approve(createdSB, type(uint256).max);
            IERC20(Token).approve(address(slr), type(uint256).max);

            //make lendDeposits to 3 parties

            StagingBox(createdSB).depositLend(
                msg.sender,
                100 * (10**ERC20(stableCoin).decimals())
            );
            StagingBox(createdSB).depositLend(
                recipientA,
                100 * (10**ERC20(stableCoin).decimals())
            );
            StagingBox(createdSB).depositLend(
                recipientB,
                100 * (10**ERC20(stableCoin).decimals())
            );

            //make borrowDeposits & distribute to 3 parties

            slr.simpleWrapTrancheBorrow(
                IStagingBox(createdSB),
                100 * (10**ERC20(Token).decimals()),
                0
            );
            uint256 BorrowSlipDistributionAmount = StagingBox(createdSB)
                .borrowSlip()
                .balanceOf(msg.sender) / 3;
            StagingBox(createdSB).borrowSlip().transfer(
                recipientA,
                BorrowSlipDistributionAmount
            );
            StagingBox(createdSB).borrowSlip().transfer(
                recipientB,
                BorrowSlipDistributionAmount
            );

            //transmitReInit
            bool Bool = sbLens.viewTransmitReInitBool(IStagingBox(createdSB));

            StagingBox(createdSB).transmitReInit(Bool);

            console2.log(createdSB, "SB-MATURE", i);
            console2.log(
                address(StagingBox(createdSB).convertibleBondBox()),
                "CBB-MATURE",
                i
            );
        }

        vm.stopBroadcast();
    }
}
