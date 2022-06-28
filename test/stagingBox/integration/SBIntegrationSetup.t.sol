pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../../src/contracts/StagingBox.sol";
import "../../../src/contracts/StagingBoxFactory.sol";
import "../../../src/contracts/CBBFactory.sol";
import "../../../src/contracts/ConvertibleBondBox.sol";
import "../SBSetup.t.sol";
import "../../../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../../src/contracts/Slip.sol";
import "../../../src/contracts/SlipFactory.sol";
import "../../mocks/MockERC20.sol";

import "forge-std/console2.sol";

contract SBIntegrationSetup is Test {
    ButtonWoodBondController s_buttonWoodBondController;
    ConvertibleBondBox s_convertibleBondBox;
    ConvertibleBondBox s_deployedConvertibleBondBox;
    CBBFactory s_CBBFactory;

    address s_cbb_owner = address(55);

    MockERC20 s_collateralToken;

    MockERC20 s_stableToken;
    TrancheFactory s_trancheFactory;
    Tranche s_tranche;
    Slip s_slip;
    SlipFactory s_slipFactory;
    ITranche s_safeTranche;
    ITranche s_riskTranche;
    uint256[] s_ratios;
    uint256 s_depositLimit;
    uint256 s_safeRatio;
    uint256 s_riskRatio;
    uint256 s_price;
    uint256 maxStableAmount;
    bool s_isLend;
    uint256 constant s_penalty = 500;
    uint256 constant s_trancheIndex = 0;
    uint256 constant s_maturityDate = 1656717949;
    uint256 constant s_safeSlipAmount = 10;
    uint256 constant s_endOfUnixTime = 2147483647;
    uint256 constant s_trancheGranularity = 1000;
    uint256 constant s_penaltyGranularity = 1000;
    uint256 constant s_priceGranularity = 1e9;
    uint256 constant s_BPS = 10_000;
    uint256 public constant s_maxFeeBPS = 50;
    address s_deployedCBBAddress;

    address s_owner; 
    address s_borrower;
    address s_lender;
    address s_user;

    StagingBoxFactory stagingBoxFactory;
    StagingBox s_deployedSB;
    event LendDeposit(address, uint256);
    event BorrowDeposit(address, uint256);
    event LendWithdrawal(address, uint256);
    event BorrowWithdrawal(address, uint256);
    event RedeemBorrowSlip(address, uint256);
    event RedeemLendSlip(address, uint256);
    event TrasmitReint(bool, uint256);
    event Initialized(address index, address, address);
    event Lend(address, address, address, uint256, uint256);
    event Borrow(address, address, address, uint256, uint256);
    event RedeemStable(address, uint256, uint256);
    event RedeemSafeTranche(address, uint256);
    event RedeemRiskTranche(address, uint256);
    event Repay(address, uint256, uint256, uint256);
    event Initialized(address, address, uint256, uint256);
    event FeeUpdate(uint256);

    function setUp() public virtual {
        //push numbers into array
        s_ratios.push(200);
        s_ratios.push(300);
        s_ratios.push(500);

        // create buttonwood bond collateral token
        s_collateralToken = new MockERC20("CollateralToken", "CT");

        // // create stable token
        s_stableToken = new MockERC20("StableToken", "ST");
        // // create tranche
        s_tranche = new Tranche();

        // // create buttonwood tranche factory
        s_trancheFactory = new TrancheFactory(address(s_tranche));

        // // create s_slip
        s_slip = new Slip();

        // // create s_slip factory
        s_slipFactory = new SlipFactory(address(s_slip));

        s_buttonWoodBondController = new ButtonWoodBondController();
        s_convertibleBondBox = new ConvertibleBondBox();
        s_CBBFactory = new CBBFactory(address(s_convertibleBondBox));

        s_buttonWoodBondController.init(
            address(s_trancheFactory),
            address(s_collateralToken),
            s_cbb_owner,
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
            s_trancheIndex,
            s_cbb_owner
        );

        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        s_owner = address(55);
        s_borrower = address(1);
        s_lender = address(2);
        s_user = address(3);

        StagingBox stagingBox = new StagingBox();
        
        stagingBoxFactory = new StagingBoxFactory(address(stagingBox));
    }

    function createAndSetupStagingBox(uint256 _fuzzPrice) private {
        s_price = bound(_fuzzPrice, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            s_price,
            s_cbb_owner
        ));

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.cbbTransferOwnership(address(s_deployedSB));
    }

    function transmitReinitIntegrationSetup (uint256 _fuzzPrice, bool _isLend) internal {
        createAndSetupStagingBox(_fuzzPrice);

        s_collateralToken.mint(address(s_deployedSB), 1e18);

        vm.prank(address(s_deployedSB));
        s_collateralToken.approve(
            address(s_buttonWoodBondController),
            type(uint256).max
        );

        vm.prank(address(s_deployedSB));
        s_buttonWoodBondController.deposit(1e18);
        (s_safeTranche, s_safeRatio) = s_buttonWoodBondController.tranches(
            s_trancheIndex
        );
        (s_riskTranche, s_riskRatio) = s_buttonWoodBondController.tranches(
            s_buttonWoodBondController.trancheCount() - 1
        );

        maxStableAmount =
            (s_safeTranche.balanceOf(address(s_deployedSB)) * s_price) /
                s_priceGranularity;

        s_stableToken.mint(address(s_deployedSB), maxStableAmount);

        vm.startPrank(address(s_deployedSB));
        s_safeTranche.approve(s_deployedCBBAddress, type(uint256).max);
        s_riskTranche.approve(s_deployedCBBAddress, type(uint256).max);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);
        vm.stopPrank();

        s_isLend = _isLend;
    }

    function depositBorrowSetup(uint256 _fuzzPrice) internal {
        createAndSetupStagingBox(_fuzzPrice);

        s_collateralToken.mint(s_user, 1e18);

        vm.prank(s_user);
        s_collateralToken.approve(
            address(s_buttonWoodBondController),
            type(uint256).max
        );

        vm.prank(s_user);
        s_buttonWoodBondController.deposit(1e18);
        (s_safeTranche, s_safeRatio) = s_buttonWoodBondController.tranches(
            s_trancheIndex
        );
        (s_riskTranche, s_riskRatio) = s_buttonWoodBondController.tranches(
            s_buttonWoodBondController.trancheCount() - 1
        );

        maxStableAmount =
            (s_safeTranche.balanceOf(s_user) * s_price) /
                s_priceGranularity;

        s_stableToken.mint(s_user, maxStableAmount);

        vm.startPrank(s_user);
        s_safeTranche.approve(address(s_deployedSB), type(uint256).max);
        s_riskTranche.approve(address(s_deployedSB), type(uint256).max);
        s_stableToken.approve(address(s_deployedSB), type(uint256).max);
        vm.stopPrank();
    }
}