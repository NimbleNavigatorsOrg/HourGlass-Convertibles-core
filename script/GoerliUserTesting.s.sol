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

contract GoerliUserTesting is Script {
    //PoorTokenDetails
    address public poorToken = 0xC5743Ed645F30659148FEf1C4315b76c6C165cFD;
    address public button = 0xf037cb06C5FeF11Fa599D52B181e726AaE3Aeb77;

    // //PeasantTokenDetails
    address public peasantToken = 0xE7E0744803fEcdea6f2FCbC03a4804c825D0C2d4;
    // address public button = 0x4FE19a2AEf89929FDA832f250b4e6d3E3e736f89;

    address public stableCoin = 0xaFF4481D10270F50f203E0763e2597776068CBc5;

    address public weenus = 0xaFF4481D10270F50f203E0763e2597776068CBc5;
    address public poorStable = 0xd3AB6Dc80c5a157397D9718a6AA778F30D82f70B;

    address public recipientX = 0xd847F3212E0B7C02e64c8114Cb82c24058d02224;

    uint8 public repeatCount = 1;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        MockERC20(peasantToken).mint(recipientX, 10000 * 10**18);
        MockERC20(poorToken).mint(recipientX, 10000 * 10**8);
        MockERC20(poorStable).mint(recipientX, 10000 * 10**6);
        (bool sent, bytes memory data) = weenus.call{value: 0}("");
        ERC20(weenus).transfer(recipientX, 1000 * 10**18);

        (bool sentEth, bytes memory dataEth) = recipientX.call{
            value: 0.01 ether
        }("");

        vm.stopBroadcast();
    }
}
