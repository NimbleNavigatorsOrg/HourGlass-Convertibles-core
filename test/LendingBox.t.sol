// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/LendingBox.sol";
import "../src/contracts/LendingBoxFactory.sol";
import "../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/external/ERC20.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../src/contracts/Slip.sol";
import "../src/contracts/SlipFactory.sol";
import "forge-std/console2.sol";

contract LendingBoxTest is Test {
    ButtonWoodBondController s_buttonWoodBondController;
    LendingBox s_lendingBox;
    LendingBoxFactory s_lendingBoxFactory;

    ERC20 s_collateralToken;

    ERC20 s_stableToken;
    TrancheFactory s_trancheFactory;
    Tranche s_tranche;
    CBBSlip s_slip;
    SlipFactory s_slipFactory;
    uint256[] s_ratios;
    uint256 constant s_penalty = 500;
    uint256 constant s_price = 5e8;
    uint256 constant s_startDate = 1654100749;
    uint256 constant s_trancheIndex = 0;
    uint256 constant s_maturityDate = 1656717949;
    uint256 constant s_depositLimit = 1000e9;
    error PenaltyTooHigh(uint256 given, uint256 maxPenalty);
    address s_deployedLendingBoxAddress;

    event LendingBoxCreated(
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
        s_slipFactory = new SlipFactory(address(s_slip));

        s_buttonWoodBondController = new ButtonWoodBondController();
        s_lendingBox = new LendingBox();
        s_lendingBoxFactory = new LendingBoxFactory(address(s_lendingBox));

        s_buttonWoodBondController.init(
            address(s_trancheFactory),
            address(s_collateralToken),
            address(this),
            s_ratios,
            s_maturityDate,
            s_depositLimit
        );

        s_deployedLendingBoxAddress = s_lendingBoxFactory.createLendingBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_collateralToken),
            address(s_stableToken),
            s_price,
            s_startDate,
            s_trancheIndex
        );
    }

    function testCurrentPrice() public {
        vm.warp((s_startDate + s_maturityDate) / 2);

        uint256 currentPrice = LendingBox(s_deployedLendingBoxAddress)
            .currentPrice();
        uint256 price = LendingBox(s_deployedLendingBoxAddress).initialPrice();
        uint256 priceGranularity = LendingBox(s_deployedLendingBoxAddress)
            .s_price_granularity();

        assertEq((priceGranularity - price) / 2 + price, currentPrice);
    }

    function testRepay() public {
        vm.warp(s_startDate + 1);
        uint256 stableAmount = 10;
        uint256 zSlipAmount = 20;
        LendingBox(s_deployedLendingBoxAddress).repay(
            stableAmount,
            zSlipAmount
        );
    }

    function testFailRepayLendingBoxNotStarted() public {
        uint256 stableAmount = 10;
        uint256 zSlipAmount = 20;
        LendingBox(s_deployedLendingBoxAddress).repay(
            stableAmount,
            zSlipAmount
        );
    }
}
