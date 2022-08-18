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
        CBBFactory(0x26391A112CeeB898E195f4ec91F186310e29aEA2);
    StagingBoxFactory stagingFactory =
        StagingBoxFactory(0x9CC7765FDe7EC1A5b8399FDc6b323F2D6f2Eb023);
    SlipFactory slipFactory =
        SlipFactory(0xD96D4AF92CA2E89E6e423C2aC7144A0c60412156);
    StagingLoanRouter slr =
        StagingLoanRouter(0x0162EbDEff59094a693af794644D929Ef6f1f3A3);
    StagingBoxLens sbLens =
        StagingBoxLens(0x303372d4beBe0Da7CF08033A2D80095Cf64F419A);

    address public trancheFact = 0xE0De6e1a505b69D2987fAe7230db96682d26Dfca;

    //PoorTokenDetails
    address public token = 0xC5743Ed645F30659148FEf1C4315b76c6C165cFD;
    address public button = 0xf037cb06C5FeF11Fa599D52B181e726AaE3Aeb77;

    // //PeasantTokenDetails
    // address public token = 0xE7E0744803fEcdea6f2FCbC03a4804c825D0C2d4;
    // address public button = 0x4FE19a2AEf89929FDA832f250b4e6d3E3e736f89;

    address public stableCoin = 0xd3AB6Dc80c5a157397D9718a6AA778F30D82f70B;

    address public weenus = 0xaFF4481D10270F50f203E0763e2597776068CBc5;
    address public poorStable = 0xd3AB6Dc80c5a157397D9718a6AA778F30D82f70B;

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

        BondController bond = new BondController();
        bond.init(
            trancheFact,
            button,
            msg.sender,
            ratios,
            block.timestamp + 2592e3,
            type(uint256).max
        );

        BondController bondMature = new BondController();
        bondMature.init(
            trancheFact,
            button,
            msg.sender,
            ratios,
            block.timestamp + 300,
            type(uint256).max
        );

        //create IBO CBBs + SBs
        for (uint8 i = 0; i < repeatCount; i++) {
            address createdSB = stagingFactory.createStagingBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                bond,
                i + basePenalty,
                stableCoin,
                0,
                basePrice + (i * 1e6),
                msg.sender
            );

            console2.log(createdSB, "SB-IBO-", i);

            console2.log(
                address(StagingBox(createdSB).convertibleBondBox()),
                "CBB-IBO-",
                i
            );
        }

        //create active Bonds (token only)

        for (uint8 i = 0; i < repeatCount; i++) {
            address createdSB = stagingFactory.createStagingBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                bond,
                i + basePenalty,
                stableCoin,
                0,
                basePrice + (i * 1e6),
                msg.sender
            );

            IERC20(stableCoin).approve(createdSB, type(uint256).max);
            IERC20(token).approve(address(slr), type(uint256).max);

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
                500 * (10**ERC20(token).decimals()),
                0
            );
            uint256 borrowSlipDistributionAmount = StagingBox(createdSB)
                .borrowSlip()
                .balanceOf(msg.sender) / 3;
            StagingBox(createdSB).borrowSlip().transfer(
                recipientA,
                borrowSlipDistributionAmount
            );
            StagingBox(createdSB).borrowSlip().transfer(
                recipientB,
                borrowSlipDistributionAmount
            );

            //transmitReinit

            bool boolReturn = sbLens.viewTransmitReInitBool(
                IStagingBox(createdSB)
            );

            StagingBox(createdSB).transmitReInit(boolReturn);

            //repeat for AMPL-Token

            console2.log(createdSB, "SB-ACTIVE-", i);
            console2.log(
                address(StagingBox(createdSB).convertibleBondBox()),
                "CBB-ACTIVE-",
                i
            );
        }

        //create Mature Bonds

        for (uint8 i = 0; i < repeatCount; i++) {
            address createdSB = stagingFactory.createStagingBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                bondMature,
                i + basePenalty,
                stableCoin,
                0,
                basePrice + (i * 1e6),
                msg.sender
            );

            IERC20(stableCoin).approve(createdSB, type(uint256).max);
            IERC20(token).approve(address(slr), type(uint256).max);

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
                500 * (10**ERC20(token).decimals()),
                0
            );
            uint256 borrowSlipDistributionAmount = StagingBox(createdSB)
                .borrowSlip()
                .balanceOf(msg.sender) / 3;
            StagingBox(createdSB).borrowSlip().transfer(
                recipientA,
                borrowSlipDistributionAmount
            );
            StagingBox(createdSB).borrowSlip().transfer(
                recipientB,
                borrowSlipDistributionAmount
            );

            //transmitReInit
            bool boolReturn = sbLens.viewTransmitReInitBool(
                IStagingBox(createdSB)
            );

            StagingBox(createdSB).transmitReInit(boolReturn);

            console2.log(createdSB, "SB-MATURE-", i);
            console2.log(
                address(StagingBox(createdSB).convertibleBondBox()),
                "CBB-MATURE-",
                i
            );
        }

        vm.stopBroadcast();
    }
}
