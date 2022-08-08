pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "../../src/interfaces/IConvertibleBondBox.sol";
import "../external/tranche/BondController.sol";
import "../external/tranche/Tranche.sol";
import "../external/tranche/TrancheFactory.sol";
import "../../src/contracts/Slip.sol";
import "../../src/contracts/SlipFactory.sol";
import "../../src/contracts/StagingLoanRouter.sol";
import "../../src/contracts/StagingBoxLens.sol";
import "../mocks/MockERC20.sol";
import "../external/button-wrappers/ButtonToken.sol";
import "../external/button-wrappers/MockOracle.sol";

import "forge-std/console2.sol";

contract RedeemLendSlipsForStablesTestSetup is Test {
    BondController s_buttonWoodBondController;
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
    uint256 constant s_maturityDate = 1664512517;
    uint256 constant s_safeSlipAmount = 10;
    uint256 constant s_endOfUnixTime = 2147483647;
    uint256 constant s_trancheGranularity = 1000;
    uint256 constant s_penaltyGranularity = 1000;
    uint256 constant s_priceGranularity = 1e8;
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
        s_ratios.push(400);
        s_ratios.push(600);

        s_oracle = new MockOracle();

        s_oracleData = 1e8;
        s_oracle.setData(s_oracleData, true);

        s_underlying = new MockERC20("CollateralToken", "CT");

        // create buttonwood bond collateral token
        s_collateralToken = new ButtonToken();

        s_collateralToken.initialize(
            address(s_underlying),
            "UnderlyingToken",
            "UT",
            address(s_oracle)
        );

        s_maxUnderlyingMint = 200000000000000000000000;

        s_stagingBoxLens = new StagingBoxLens();

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

        s_buttonWoodBondController = new BondController();
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
            stagingBoxFactory.createStagingBoxWithCBB(
                s_CBBFactory,
                s_slipFactory,
                s_buttonWoodBondController,
                s_penalty,
                address(s_stableToken),
                s_trancheIndex,
                s_price,
                s_cbb_owner
            )
        );

        s_deployedConvertibleBondBox = s_deployedSB.convertibleBondBox();
        s_deployedCBBAddress = address(s_deployedConvertibleBondBox);
    }

    function setupTranches(bool _isLend, address _user) internal {
        s_underlying.mint(_user, s_maxUnderlyingMint);

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

        s_stableToken.mint(s_user, maxStableAmount);

        s_stableToken.mint(s_owner, maxStableAmount);

        s_underlying.mint(s_borrower, s_maxUnderlyingMint);

        s_stagingLoanRouter = new StagingLoanRouter();

        vm.prank(s_borrower);
        s_underlying.approve(address(s_stagingLoanRouter), type(uint256).max);

        vm.prank(s_borrower);
        s_stableToken.approve(address(s_stagingLoanRouter), type(uint256).max);

        vm.startPrank(address(s_deployedSB));
        s_safeTranche.approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_riskTranche.approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        s_stableToken.approve(
            address(s_deployedConvertibleBondBox),
            type(uint256).max
        );
        vm.stopPrank();

        vm.startPrank(s_user);
        s_stableToken.approve(address(s_deployedSB), type(uint256).max);
        vm.stopPrank();

        s_isLend = _isLend;
    }

    function repayMaxAndUnwrapSimpleTestSetup(uint256 _lendAmount)
        internal
        returns (uint256, uint256)
    {
        vm.prank(s_borrower);
        StagingLoanRouter(s_stagingLoanRouter).simpleWrapTrancheBorrow(
            s_deployedSB,
            s_maxUnderlyingMint,
            0
        );

        uint256 userStableTokenBalanceBeforeLend = IERC20(
            s_deployedConvertibleBondBox.stableToken()
        ).balanceOf(s_user);
        _lendAmount = bound(
            _lendAmount,
            (s_deployedConvertibleBondBox.safeRatio() *
                s_deployedConvertibleBondBox.currentPrice()) /
                s_deployedConvertibleBondBox.s_priceGranularity() +
                1,
            userStableTokenBalanceBeforeLend
        );

        vm.startPrank(s_user);
        IERC20(s_deployedConvertibleBondBox.stableToken()).approve(
            address(s_deployedSB),
            _lendAmount
        );
        s_deployedSB.depositLend(s_lender, _lendAmount);
        vm.stopPrank();

        assertFalse(_lendAmount == 0);

        vm.prank(s_owner);
        s_deployedSB.transmitReInit(true);

        uint256 borrowerBorrowSlipBalanceBeforeRedeem = ISlip(
            s_deployedSB.borrowSlip()
        ).balanceOf(s_borrower);
        uint256 maxArgForRedeemBorrowSlip = s_stagingBoxLens
            .viewMaxRedeemBorrowSlip(s_deployedSB);

        if (
            borrowerBorrowSlipBalanceBeforeRedeem <= maxArgForRedeemBorrowSlip
        ) {
            vm.prank(s_borrower);

            s_deployedSB.redeemBorrowSlip(
                borrowerBorrowSlipBalanceBeforeRedeem
            );
        } else {
            vm.prank(s_borrower);
            s_deployedSB.redeemBorrowSlip(maxArgForRedeemBorrowSlip);
            uint256 borrowerBorrowSlipBalanceAfterRedeem = ISlip(
                s_deployedSB.borrowSlip()
            ).balanceOf(s_borrower);
            uint256 sbSafeTrancheBalanceBeforeRedeem = ITranche(
                s_deployedSB.safeTranche()
            ).balanceOf(address(s_deployedSB));

            vm.prank(s_borrower);
            s_deployedSB.withdrawBorrow(
                borrowerBorrowSlipBalanceAfterRedeem >
                    sbSafeTrancheBalanceBeforeRedeem
                    ? sbSafeTrancheBalanceBeforeRedeem
                    : borrowerBorrowSlipBalanceAfterRedeem
            );
        }

        uint256 borrowRiskSlipBalanceBeforeRepay = ISlip(
            s_deployedSB.riskSlipAddress()
        ).balanceOf(s_borrower);

        vm.assume(
            borrowRiskSlipBalanceBeforeRepay >=
                s_deployedConvertibleBondBox.riskRatio() * 1000
        );

        s_stableToken.mint(s_borrower, s_maxMint);

        vm.startPrank(s_borrower);
        ISlip(s_deployedSB.riskSlipAddress()).approve(
            address(s_stagingLoanRouter),
            type(uint256).max
        );
        vm.stopPrank();

        return (borrowRiskSlipBalanceBeforeRepay, _lendAmount);
    }

    function withinTolerance(
        uint256 num,
        uint256 num2,
        uint256 percentTolerance
    ) internal pure returns (bool) {
        uint256 difference = 0;
        uint256 tolerance = 0;
        if (num >= num2) {
            difference = num - num2;
            tolerance = (num2 * percentTolerance) / 100;
        } else {
            difference = num2 - num;
            tolerance = (num * percentTolerance) / 100;
        }
        return difference <= tolerance;
    }

    function redeemLendSlipsForStablesTestSetup(
        uint256 _timeWarp,
        uint256 borrowRiskSlipBalanceBeforeRepay,
        uint256 _lendSlipAmount,
        bool wantStables
    ) internal returns (uint256) {
        _timeWarp = bound(
            _timeWarp,
            block.timestamp,
            s_deployedConvertibleBondBox.maturityDate() - 1
        );

        vm.warp(_timeWarp);

        (, uint256 stablesOwed, , ) = IStagingBoxLens(s_stagingBoxLens)
            .viewRepayMaxAndUnwrapSimple(
                s_deployedSB,
                borrowRiskSlipBalanceBeforeRepay
            );

        vm.assume(stablesOwed > 0);

        if (wantStables) {
            vm.prank(s_borrower);
            StagingLoanRouter(s_stagingLoanRouter).repayMaxAndUnwrapSimple(
                s_deployedSB,
                stablesOwed,
                borrowRiskSlipBalanceBeforeRepay
            );
        }

        uint256 sbSafeSlipBalance = ISlip(s_deployedSB.safeSlipAddress())
            .balanceOf(address(s_deployedSB));
        uint256 sbSafeSlipCalc = (s_deployedSB.initialPrice() *
            sbSafeSlipBalance) / s_deployedSB.priceGranularity();
        uint256 lenderLendSlipBalance = ISlip(s_deployedSB.lendSlip())
            .balanceOf(s_lender);

        uint256 upperBound = lenderLendSlipBalance <= sbSafeSlipCalc
            ? lenderLendSlipBalance
            : sbSafeSlipCalc;

        vm.assume(upperBound > 400);

        _lendSlipAmount = bound(_lendSlipAmount, 400, upperBound);

        vm.startPrank(s_lender);
        s_deployedSB.lendSlip().approve(
            address(s_stagingLoanRouter),
            type(uint256).max
        );
        vm.stopPrank();

        return _lendSlipAmount;
    }
}
