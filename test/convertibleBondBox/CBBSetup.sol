// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/contracts/CBBFactory.sol";
import "../external/tranche/BondController.sol";
import "../external/tranche/Tranche.sol";
import "../external/tranche/TrancheFactory.sol";
import "../../src/contracts/Slip.sol";
import "../../src/contracts/SlipFactory.sol";
import "forge-std/console2.sol";
import "../../test/mocks/MockERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract CBBSetup is Test {
    BondController s_buttonWoodBondController;
    ConvertibleBondBox s_convertibleBondBox;
    ConvertibleBondBox s_deployedConvertibleBondBox;
    CBBFactory s_CBBFactory;

    address s_cbb_owner = address(55);

    MockERC20 s_collateralToken;

    MockERC20 s_stableToken;
    TrancheFactory s_trancheFactory;
    Tranche s_tranche;
    Slip s_slip;
    ISlip s_issuerSlip;
    ISlip s_bondSlip;
    SlipFactory s_slipFactory;
    ITranche s_safeTranche;
    ITranche s_riskTranche;
    uint256[] s_ratios;
    uint256 s_safeRatio;
    uint256 s_riskRatio;
    uint256 constant s_penalty = 500;
    uint256 constant s_initialPrice = 5e7;
    uint256 s_trancheIndex = 1;
    uint256 constant s_maturityDate = 1864512517;
    uint256 constant s_endOfUnixTime = 2147483647;
    uint256 constant s_trancheGranularity = 1000;
    uint256 constant s_penaltyGranularity = 1000;
    uint256 constant s_priceGranularity = 1e8;
    uint256 constant s_BPS = 10_000;
    uint256 public constant s_maxFeeBPS = 50;
    uint8 constant s_stableDecimals = 6;
    uint8 constant s_collateralDecimals = 18;
    address s_deployedCBBAddress;

    event ConvertibleBondBoxCreated(
        address s_collateralToken,
        address s_stableToken,
        uint256 trancheIndex,
        uint256 penalty,
        address creator
    );

    event Lend(address, address, address, uint256, uint256);
    event Borrow(address, address, address, uint256, uint256);
    event RedeemStable(address, uint256, uint256);
    event RedeemSafeTranche(address, uint256);
    event RedeemRiskTranche(address, uint256);
    event Repay(address, uint256, uint256, uint256);
    event Initialized(address);
    event Activated(uint256, uint256);
    event FeeUpdate(uint256);

    function setUp() public virtual {
        //push numbers into array
        s_ratios.push(200);
        s_ratios.push(300);
        s_ratios.push(500);

        // create buttonwood bond collateral token
        s_collateralToken = new MockERC20(
            "CollateralToken",
            "CT",
            s_collateralDecimals
        );
        s_collateralToken.mint(
            address(this),
            10000 * (10**s_collateralDecimals)
        );

        // create stable token
        s_stableToken = new MockERC20("StableToken", "ST", s_stableDecimals);
        s_stableToken.mint(address(this), 10000 * (10**s_stableDecimals));

        // create tranche
        s_tranche = new Tranche();

        // create buttonwood tranche factory
        s_trancheFactory = new TrancheFactory(address(s_tranche));

        // create s_slip
        s_slip = new Slip();

        // create s_slip factory
        s_slipFactory = new SlipFactory(address(s_slip));

        s_buttonWoodBondController = new BondController();
        s_convertibleBondBox = new ConvertibleBondBox();
        s_CBBFactory = new CBBFactory(address(s_convertibleBondBox));

        s_buttonWoodBondController.init(
            address(s_trancheFactory),
            address(s_collateralToken),
            s_cbb_owner,
            s_ratios,
            s_maturityDate,
            type(uint256).max
        );

        s_deployedCBBAddress = s_CBBFactory.createConvertibleBondBox(
            s_buttonWoodBondController,
            s_slipFactory,
            s_penalty,
            address(s_stableToken),
            s_trancheIndex,
            s_cbb_owner
        );

        s_collateralToken.approve(
            address(s_buttonWoodBondController),
            type(uint256).max
        );

        s_buttonWoodBondController.deposit(
            s_collateralToken.balanceOf(address(this))
        );
        (s_safeTranche, s_safeRatio) = s_buttonWoodBondController.tranches(
            s_trancheIndex
        );
        (s_riskTranche, s_riskRatio) = s_buttonWoodBondController.tranches(
            s_buttonWoodBondController.trancheCount() - 1
        );

        s_safeTranche.approve(s_deployedCBBAddress, type(uint256).max);
        s_riskTranche.approve(s_deployedCBBAddress, type(uint256).max);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);

        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        s_bondSlip = s_deployedConvertibleBondBox.bondSlip();
        s_issuerSlip = s_deployedConvertibleBondBox.issuerSlip();
    }
}
