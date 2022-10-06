// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import "../src/contracts/Slip.sol";
import "../src/contracts/SlipFactory.sol";
import "../src/contracts/ConvertibleBondBox.sol";
import "../src/contracts/CBBFactory.sol";
import "../src/contracts/IBOBox.sol";
import "../src/contracts/IBOBoxFactory.sol";
import "../src/contracts/IBOBoxLens.sol";
import "../src/contracts/IBOLoanRouter.sol";
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
        CBBFactory(0xD76BEAfB4239f7648844Eb7B478DCc4Ad00Dd1E3);
    IBOBoxFactory IBOFactory =
        IBOBoxFactory(0x528576d130099a33bea94E43f7752E7f5dAd0B50);
    SlipFactory slipFactory =
        SlipFactory(0xD96D4AF92CA2E89E6e423C2aC7144A0c60412156);
    IBOLoanRouter slr =
        IBOLoanRouter(0x0162EbDEff59094a693af794644D929Ef6f1f3A3);
    IBOBoxLens IBOLens = IBOBoxLens(0x5054300d1a213CacBd96f837733775585045C99B);

    address public trancheFact = 0xE0De6e1a505b69D2987fAe7230db96682d26Dfca;

    // //WETH Token Details
    // address public token = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    // address public button = 0x084c3A0929Bc6D6C38B2C53e880e340528468571;

    // //PoorTokenDetails
    // address public token = 0xC5743Ed645F30659148FEf1C4315b76c6C165cFD;
    // address public button = 0xf037cb06C5FeF11Fa599D52B181e726AaE3Aeb77;

    //PeasantTokenDetails
    address public token = 0xE7E0744803fEcdea6f2FCbC03a4804c825D0C2d4;
    address public button = 0x4FE19a2AEf89929FDA832f250b4e6d3E3e736f89;

    address public stableCoin = 0xaFF4481D10270F50f203E0763e2597776068CBc5;

    address public weenus = 0xaFF4481D10270F50f203E0763e2597776068CBc5;
    address public poorStable = 0xd3AB6Dc80c5a157397D9718a6AA778F30D82f70B;

    address public recipientA = 0x53462C34c2Da0aC7cF391E305327f2C566D40d8D;
    address public recipientB = 0xEcA6c389fb76f92cc68223C01498FA83Ec3CE02F;

    uint256 public basePrice = 72e6;
    uint256 public basePenalty = 10;

    uint8 public repeatCount = 1;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

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

        BondController bondActive = new BondController();
        bondActive.init(
            trancheFact,
            button,
            msg.sender,
            ratios,
            block.timestamp + (2592e3) * 2,
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
        for (uint8 i = 1; i < repeatCount + 1; i++) {
            address createdIBO = IBOFactory.createIBOBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                bond,
                i + basePenalty,
                stableCoin,
                0,
                basePrice + (i * 1e6),
                msg.sender
            );

            console2.log(createdIBO, "SB-IBO-", i);

            console2.log(
                address(IBOBox(createdIBO).convertibleBondBox()),
                "CBB-IBO-",
                i
            );
        }

        //create active Bonds (token only)

        for (uint8 i = 1; i < repeatCount + 1; i++) {
            address createdIBO = IBOFactory.createIBOBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                bondActive,
                i * 2 + basePenalty,
                stableCoin,
                0,
                basePrice + (i * 3 * 1e6),
                msg.sender
            );

            IERC20(stableCoin).approve(createdIBO, type(uint256).max);
            IERC20(token).approve(address(slr), type(uint256).max);

            //make lendDeposits to 3 parties

            IBOBox(createdIBO).depositLend(
                msg.sender,
                325 * (10**ERC20(stableCoin).decimals())
            );
            IBOBox(createdIBO).depositLend(
                recipientA,
                325 * (10**ERC20(stableCoin).decimals())
            );
            IBOBox(createdIBO).depositLend(
                recipientB,
                325 * (10**ERC20(stableCoin).decimals())
            );

            //make borrowDeposits & distribute to 3 parties
            MockERC20(token).mint(
                msg.sender,
                3000 * 10**ERC20(token).decimals()
            );
            uint256 tokenBalance = 3000 * 10**ERC20(token).decimals();

            slr.simpleWrapTrancheBorrow(
                IIBOBox(createdIBO),
                tokenBalance / 3,
                0
            );
            uint256 borrowSlipDistributionAmount = IBOBox(createdIBO)
                .borrowSlip()
                .balanceOf(msg.sender) / 3;
            IBOBox(createdIBO).borrowSlip().transfer(
                recipientA,
                borrowSlipDistributionAmount
            );
            IBOBox(createdIBO).borrowSlip().transfer(
                recipientB,
                borrowSlipDistributionAmount
            );

            //transmitReinit

            bool boolReturn = IBOLens.viewTransmitReInitBool(
                IIBOBox(createdIBO)
            );

            IBOBox(createdIBO).transmitReInit(boolReturn);

            //repeat for AMPL-Token

            console2.log(createdIBO, "SB-ACTIVE-", i);
            console2.log(
                address(IBOBox(createdIBO).convertibleBondBox()),
                "CBB-ACTIVE-",
                i
            );
        }

        //create Mature Bonds

        for (uint8 i = 1; i < repeatCount + 1; i++) {
            address createdIBO = IBOFactory.createIBOBoxWithCBB(
                (convertiblesFactory),
                (slipFactory),
                bondMature,
                i * 3 + basePenalty,
                stableCoin,
                0,
                basePrice + (i * 2 * 1e6),
                msg.sender
            );

            IBOBox(createdIBO).transferCBBOwnership(msg.sender);
            IBOBox(createdIBO).convertibleBondBox().setFee(50);
            IBOBox(createdIBO).convertibleBondBox().transferOwnership(
                createdIBO
            );

            IERC20(stableCoin).approve(createdIBO, type(uint256).max);
            IERC20(token).approve(address(slr), type(uint256).max);

            //make lendDeposits to 3 parties

            IBOBox(createdIBO).depositLend(
                msg.sender,
                235 * (10**ERC20(stableCoin).decimals())
            );
            IBOBox(createdIBO).depositLend(
                recipientA,
                235 * (10**ERC20(stableCoin).decimals())
            );
            IBOBox(createdIBO).depositLend(
                recipientB,
                235 * (10**ERC20(stableCoin).decimals())
            );

            //make borrowDeposits & distribute to 3 parties
            MockERC20(token).mint(
                msg.sender,
                3000 * 10**ERC20(token).decimals()
            );
            uint256 tokenBalance = 3000 * 10**ERC20(token).decimals();

            slr.simpleWrapTrancheBorrow(
                IIBOBox(createdIBO),
                tokenBalance / 3,
                0
            );
            uint256 borrowSlipDistributionAmount = IBOBox(createdIBO)
                .borrowSlip()
                .balanceOf(msg.sender) / 3;
            IBOBox(createdIBO).borrowSlip().transfer(
                recipientA,
                borrowSlipDistributionAmount
            );
            IBOBox(createdIBO).borrowSlip().transfer(
                recipientB,
                borrowSlipDistributionAmount
            );

            //transmitReInit
            bool boolReturn = IBOLens.viewTransmitReInitBool(
                IIBOBox(createdIBO)
            );

            IBOBox(createdIBO).transmitReInit(boolReturn);

            console2.log(createdIBO, "SB-MATURE-", i);
            console2.log(
                address(IBOBox(createdIBO).convertibleBondBox()),
                "CBB-MATURE-",
                i
            );
        }

        vm.stopBroadcast();
    }
}
