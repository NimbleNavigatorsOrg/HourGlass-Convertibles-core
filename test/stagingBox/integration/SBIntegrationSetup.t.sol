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
    uint256 price;
    uint256 maxStableAmount;
    uint256 constant s_penalty = 500;
    uint256 constant s_price = 5e8;
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
        // s_borrower = address(1);
        // s_lender = address(2);

        StagingBox stagingBox = new StagingBox();
        
        stagingBoxFactory = new StagingBoxFactory(address(stagingBox));
    }
}