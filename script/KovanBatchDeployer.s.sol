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

        //IBO box + IBO box factory
        IBOBox deployedIBOBox = new IBOBox();
        IBOBoxFactory iboFactory = new IBOBoxFactory(address(deployedIBOBox));

        //deploy IBO box router + lens
        IBOLoanRouter IBOLoanRouter = new IBOLoanRouter();
        IBOBoxLens IBOBoxLens = new IBOBoxLens();

        vm.stopBroadcast();

        console2.log(address(deployedSlip), "deployedSlip");
        console2.log(address(slipFactory), "slipFactory");
        console2.log(address(cbbFactory), "ConvertiblesFactory");
        console2.log(address(iboFactory), "IBOBoxFactory");
        console2.log(address(IBOLoanRouter), "IBOLoanRouter");
        console2.log(address(IBOBoxLens), "IBOBoxLens");
    }
}
