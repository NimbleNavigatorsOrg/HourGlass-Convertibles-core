// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/ConvertibleBondBox.sol";
import "../src/contracts/CBBFactory.sol";
import "../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/external/ERC20.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../src/contracts/CBBSlip.sol";
import "../src/contracts/CBBSlipFactory.sol";

import "forge-std/console2.sol";

contract CBBFactoryTest is Test {
    ButtonWoodBondController s_buttonWoodBondController;
    ConvertibleBondBox s_convertibleBondBox;
    CBBFactory s_CBBFactory;

    ERC20 s_collateralToken;

    ERC20 s_stableToken;
    TrancheFactory s_trancheFactory;
    Tranche s_tranche;
    CBBSlip s_slip;
    CBBSlipFactory s_slipFactory;
    uint256[] s_ratios;
    uint256 constant s_penalty = 500;
    uint256 constant s_price = 5e8;
    uint256 constant s_startDate = 1654100749;
    uint256 constant s_trancheIndex = 0;
    uint256 constant s_maturityDate = 1656717949;
    uint256 constant s_depositLimit = 1000e9;
    uint256 constant s_trancheGranularity = 1000;
    uint256 constant s_penaltyGranularity = 1000;
    uint256 constant s_priceGranularity = 1000000000;
    error PenaltyTooHigh(uint256 given, uint256 maxPenalty);
    address s_deployedCBBAddress;

    event ConvertibleBondBoxCreated(
        address s_collateralToken,
        address s_stableToken,
        uint256 trancheIndex,
        uint256 penalty,
        address creator
    );

    function setUp() public {
        //push numbers into array
        s_ratios.push(200);
        s_ratios.push(300);
        s_ratios.push(500);

        // create buttonwood bond collateral token
        s_collateralToken = new ERC20("CollateralToken", "CT");

        // // create stable token
        s_stableToken = new ERC20("StableToken", "ST");

        // // create tranche
        s_tranche = new Tranche();

        // // create buttonwood tranche factory
        s_trancheFactory = new TrancheFactory(address(s_tranche));

        // // create s_slip
        s_slip = new CBBSlip();

        // // create s_slip factory
        s_slipFactory = new CBBSlipFactory(address(s_slip));

        s_buttonWoodBondController = new ButtonWoodBondController();
        s_convertibleBondBox = new ConvertibleBondBox();
        s_CBBFactory = new CBBFactory(address(s_convertibleBondBox));

        s_buttonWoodBondController.init(
            address(s_trancheFactory),
            address(s_collateralToken),
            address(this),
            s_ratios,
            s_maturityDate,
            s_depositLimit
        );

        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_trancheIndex
        );
    }

    function testFactoryCreatesConvertibleBondBox() public {
        // wrap address in IConvertibleBondBox and make assertions on inital values
        ConvertibleBondBox deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        // keep this assert
        assertEq(s_CBBFactory.implementation(), address(s_convertibleBondBox));

        assertEq(
            address(deployedConvertibleBondBox.bond()),
            address(s_buttonWoodBondController)
        );
        assertEq(
            address(deployedConvertibleBondBox.slipFactory()),
            address(s_slipFactory)
        );
        assertEq(deployedConvertibleBondBox.penalty(), s_penalty);
        assertEq(
            address(deployedConvertibleBondBox.collateralToken()),
            address(s_collateralToken)
        );
        assertEq(
            address(deployedConvertibleBondBox.stableToken()),
            address(s_stableToken)
        );
        assertEq(deployedConvertibleBondBox.initialPrice(), s_price);
        assertEq(deployedConvertibleBondBox.s_startDate(), 0);
        assertEq(deployedConvertibleBondBox.trancheIndex(), s_trancheIndex);
    }

    function testCreateConvertibleBondBoxEmitsConvertibleBondBoxCreated() public {
        vm.expectEmit(true, true, true, true);
        // The event we expect
        emit ConvertibleBondBoxCreated(
            address(s_collateralToken),
            address(s_stableToken),
            s_trancheIndex,
            s_penalty,
            address(this)
        );
        // The event we get
        s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_trancheIndex
        );
    }
}
