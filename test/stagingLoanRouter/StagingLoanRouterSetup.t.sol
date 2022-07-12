pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/interfaces/IConvertibleBondBox.sol";
import "../../src/contracts/ButtonWoodBondController.sol";
import "@buttonwood-protocol/tranche/contracts/interfaces/ITranche.sol";
import "@buttonwood-protocol/tranche/contracts/Tranche.sol";
import "@buttonwood-protocol/tranche/contracts/TrancheFactory.sol";
import "../../src/contracts/Slip.sol";
import "../../src/contracts/SlipFactory.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../../src/contracts/StagingBoxLens.sol";
import "../mocks/MockERC20.sol";
import "@buttonwood-protocol/button-wrappers/contracts/ButtonToken.sol";
import "@buttonwood-protocol/button-wrappers/contracts/mocks/MockOracle.sol";

import "forge-std/console2.sol";

contract StagingLoanRouterSetup is Test {
    ButtonWoodBondController s_buttonWoodBondController;
    ConvertibleBondBox s_convertibleBondBox;
    IConvertibleBondBox s_deployedConvertibleBondBox;
    CBBFactory s_CBBFactory;

    address s_cbb_owner = address(55);

    ButtonToken s_collateralToken;
    uint256 s_oracleData;
    uint256 s_stalenessThreshold;
    uint256 s_maxUnderlyingMint;
    MockERC20 s_underlying;
    MockOracle s_oracle;
    StagingLoanRouter s_stagingLoanRouter;
    StagingBoxLens s_stagingBoxLens;

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
    uint256 constant s_maturityDate = 1659246194;
    uint256 constant s_safeSlipAmount = 10;
    uint256 constant s_endOfUnixTime = 2147483647;
    uint256 constant s_trancheGranularity = 1000;
    uint256 constant s_penaltyGranularity = 1000;
    uint256 constant s_priceGranularity = 1e9;
    uint256 constant s_BPS = 10_000;
    uint256 constant s_maxMint = 1e18;
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
    event StagingBoxCreated(
        IConvertibleBondBox convertibleBondBox,
        ISlipFactory slipFactory,
        uint256 initialPrice,
        address owner,
        address msgSender,
        address stagingBox
    );

    function setUp() public virtual {
        //push numbers into array
        s_ratios.push(200);
        s_ratios.push(300);
        s_ratios.push(500);

        s_oracle = new MockOracle();

        s_oracleData = 500;
        s_oracle.setData(s_oracleData, true);

        (uint256 data, bool success) = s_oracle.getData();

        console.log("datame", data, success);

        // s_stalenessThreshold = 1000;

        // console.log("before chainlink oracle", address(s_oracle));

        // s_chainlinkOracle = new ChainlinkOracle(address(s_oracle), s_stalenessThreshold);
        //         console.log("after chainlink oracle");

        //         (uint256 data2, bool success2) = s_chainlinkOracle.getData();
        

        // console.log("datame chain", data2, success2);

        s_underlying = new MockERC20("CollateralToken", "CT");

        // create buttonwood bond collateral token
        s_collateralToken = new ButtonToken();
        // s_collateralToken = IRebasingERC20(s_collateralToken);

        // console.log("before initialize s_collateralToken", address(s_chainlinkOracle));


        s_collateralToken.initialize(address(s_underlying), "UnderlyingToken", "UT", address(s_oracle));


        console.log("after initialize s_collateralToken");

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

        s_owner = address(55);
        s_borrower = address(1);
        s_lender = address(2);
        s_user = address(3);

        StagingBox stagingBox = new StagingBox();

        stagingBoxFactory = new StagingBoxFactory(address(stagingBox));
    }

    function setupStagingBox(uint256 _fuzzPrice) internal {
        s_price = bound(_fuzzPrice, 1, s_priceGranularity);

        s_deployedSB = StagingBox(
            stagingBoxFactory.createStagingBox(
                s_CBBFactory,
                s_slipFactory,
                s_buttonWoodBondController,
                s_penalty,
                address(s_stableToken),
                s_trancheIndex,
                s_price,
                s_owner,
                s_cbb_owner
            )
        );

        console.log(address(s_deployedSB), "s_deployedSB");


        s_deployedConvertibleBondBox = s_deployedSB.convertibleBondBox();
        s_deployedCBBAddress = address(s_deployedConvertibleBondBox);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.cbbTransferOwnership(
            address(s_deployedSB)
        );
    }

    function setupTranches(
        bool _isLend,
        address _user,
        address _approvalAddress
    ) internal {
        s_underlying.mint(_user, 200000000000000000000000);

        vm.prank(_user);
        s_underlying.approve(address(s_collateralToken), type(uint256).max);

        vm.prank(_user);
        s_collateralToken.mint(s_maxMint);

        vm.prank(_user);
        s_collateralToken.approve(
            address(s_buttonWoodBondController),
            type(uint256).max
        );

        vm.prank(_user);
        s_buttonWoodBondController.deposit(s_maxMint);
        (s_safeTranche, s_safeRatio) = s_buttonWoodBondController.tranches(
            s_trancheIndex
        );
        (s_riskTranche, s_riskRatio) = s_buttonWoodBondController.tranches(
            s_buttonWoodBondController.trancheCount() - 1
        );

        maxStableAmount =
            (s_safeTranche.balanceOf(_user) * s_price) /
            s_priceGranularity;

        s_stableToken.mint(_user, maxStableAmount);

        s_maxUnderlyingMint = 200000000000000000000000;

        s_underlying.mint(s_user, s_maxUnderlyingMint);

        s_stagingLoanRouter = new StagingLoanRouter();
        
        vm.prank(s_user);
        s_underlying.approve(address(s_stagingLoanRouter), type(uint256).max);

        s_stagingBoxLens = new StagingBoxLens();
    }
}