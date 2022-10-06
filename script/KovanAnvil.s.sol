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
import "@buttonwood-protocol/tranche/contracts/interfaces/IBondFactory.sol";
import "../test/external/button-wrappers/ButtonTokenFactory.sol";
import "../test/external/button-wrappers/ButtonToken.sol";

contract KovanAnvil is Script {
    IBondFactory s_bondFactory =
        IBondFactory(0x8c0D2e727bE5a421EE9cFf96A3cC4FCaf811424f);
    ButtonTokenFactory s_buttonTokenFactory =
        ButtonTokenFactory(0xCCcadb93F162F7516ba7C046f74b628Adf63E6d9);
    address public s_forthChainlinkOracleAddress =
        0xEA68d72c6Fe193D74847C5dc537725cd48453f35;

    uint256 public s_penalty = 0;
    uint256 public s_trancheIndex = 0;
    uint256 public s_initialPrice = (1e8 * 4) / 5;
    address public s_weenus = 0xaFF4481D10270F50f203E0763e2597776068CBc5;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // create mock FORTH token and mint to self
        MockERC20 anvilForth = new MockERC20("ForgeForth", "fgFORTH", 18);

        // //deploy slips + slip factory
        Slip deployedSlip = new Slip();
        SlipFactory slipFactory = new SlipFactory(address(deployedSlip));

        //deploy CBB + CBB factory
        ConvertibleBondBox deployedCBB = new ConvertibleBondBox();
        CBBFactory cbbFactory = new CBBFactory(address(deployedCBB));

        //IBO box + IBO box factory
        IBOBox deployedIBOBox = new IBOBox();
        IBOBoxFactory iboFactory = new IBOBoxFactory(address(deployedIBOBox));

        //deploy IBO box router + lens
        IBOLoanRouter IBOLoanRouter = new IBOLoanRouter();
        IBOBoxLens IBOBoxLens = new IBOBoxLens();

        //deploy buttonToken
        ButtonToken buttonForth = ButtonToken(
            s_buttonTokenFactory.create(
                address(anvilForth),
                "button-Forge-Forth",
                "bFgFORTH",
                s_forthChainlinkOracleAddress
            )
        );

        //deploy buttonForthBond with 20/80 ratio for maturity in 30 days
        uint256[] memory ratios = new uint256[](2);
        ratios[0] = 200;
        ratios[1] = 800;

        address createdBond = s_bondFactory.createBond(
            address(buttonForth),
            ratios,
            block.timestamp + 2592e3
        );

        //create new IBO with CBB
        address createdIBO = iboFactory.createIBOBoxWithCBB(
            cbbFactory,
            slipFactory,
            IBondController(createdBond),
            s_penalty,
            s_weenus,
            s_trancheIndex,
            s_initialPrice,
            msg.sender
        );

        //some test transactions

        // //deposit mockFORTH and send to msg.sender
        // anvilForth.mint(msg.sender, 15e24);

        vm.stopBroadcast();

        console2.log(address(anvilForth), "anvilForthAddress");
        console2.log(address(buttonForth), "buttonForth");
        console2.log(address(deployedSlip), "deployedSlip");
        console2.log(address(slipFactory), "slipFactory");
        console2.log(address(cbbFactory), "ConvertiblesFactory");
        console2.log(address(iboFactory), "IBOBoxFactory");
        console2.log(address(IBOLoanRouter), "IBOLoanRouter");
        console2.log(address(IBOBoxLens), "IBOBoxLens");
        console2.log(createdIBO, "createdIBO");
        console2.log(createdBond, "createdBond");
    }
}
