pragma solidity 0.8.13;

import "../../test/convertibleBondBox/CBBSetup.sol";

import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/StagingBoxLens.sol";
import "../../src/contracts/StagingLoanRouter.sol";

import "../mocks/MockERC20.sol";
import "../external/button-wrappers/ButtonToken.sol";
import "../external/button-wrappers/MockOracle.sol";

contract StagingLoanRouterSetup is CBBSetup {
    StagingBoxFactory stagingBoxFactory;
    StagingBox s_deployedSB;
    StagingBoxLens s_SBLens;
    StagingLoanRouter s_stagingLoanRouter;
    address s_deployedSBAddress;

    ButtonToken s_buttonCollatToken;
    MockOracle s_mockOracle;

    uint256 s_initMockData = 5e8;

    ISlip s_borrowSlip;
    ISlip s_lendSlip;

    address s_borrower = address(1);
    address s_lender = address(2);

    function setUp() public override {
        s_trancheIndex = 0;
        //push numbers into array
        s_ratios.push(200);
        s_ratios.push(800);

        s_collateralToken = new MockERC20(
            "CollateralToken",
            "CT",
            s_collateralDecimals
        );
        s_buttonCollatToken = new ButtonToken();

        s_mockOracle = new MockOracle();
        s_mockOracle.setData(s_initMockData, true);

        s_buttonCollatToken.initialize(
            address(s_collateralToken),
            "RebasingToken",
            "bUT",
            address(s_mockOracle)
        );

        s_collateralToken.approve(
            address(s_buttonCollatToken),
            type(uint256).max
        );

        s_stableToken = new MockERC20("StableToken", "ST", s_stableDecimals);

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
            address(s_buttonCollatToken),
            s_cbb_owner,
            s_ratios,
            s_maturityDate,
            type(uint256).max
        );

        (s_safeTranche, s_safeRatio) = s_buttonWoodBondController.tranches(
            s_trancheIndex
        );

        (s_riskTranche, s_riskRatio) = s_buttonWoodBondController.tranches(
            s_buttonWoodBondController.trancheCount() - 1
        );

        StagingBox stagingBox = new StagingBox();
        stagingBoxFactory = new StagingBoxFactory(address(stagingBox));
        s_SBLens = new StagingBoxLens();
        s_stagingLoanRouter = new StagingLoanRouter();

        vm.prank(s_cbb_owner);
        s_deployedSB = StagingBox(
            stagingBoxFactory.createStagingBoxWithCBB(
                s_CBBFactory,
                s_slipFactory,
                s_buttonWoodBondController,
                s_penalty,
                address(s_stableToken),
                s_trancheIndex,
                s_initialPrice,
                s_cbb_owner
            )
        );

        s_deployedCBBAddress = address(s_deployedSB.convertibleBondBox());
        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        s_deployedSBAddress = address(s_deployedSB);

        s_safeSlip = s_deployedConvertibleBondBox.safeSlip();
        s_riskSlip = s_deployedConvertibleBondBox.riskSlip();
        s_borrowSlip = s_deployedSB.borrowSlip();
        s_lendSlip = s_deployedSB.lendSlip();

        s_collateralToken.mint(
            address(this),
            10000 * (10**s_collateralDecimals)
        );
        s_collateralToken.approve(
            address(s_buttonCollatToken),
            type(uint256).max
        );
        s_buttonCollatToken.deposit(s_collateralToken.balanceOf(address(this)));
        s_buttonCollatToken.approve(
            address(s_buttonWoodBondController),
            type(uint256).max
        );
        s_buttonWoodBondController.deposit(
            s_buttonCollatToken.balanceOf(address(this))
        );

        s_collateralToken.mint(s_borrower, 10000 * (10**s_collateralDecimals));
        s_stableToken.mint(s_lender, 10000 * (10**s_stableDecimals));

        vm.startPrank(s_borrower);
        s_collateralToken.approve(
            address(s_stagingLoanRouter),
            type(uint256).max
        );
        s_borrowSlip.approve(address(s_stagingLoanRouter), type(uint256).max);
        s_riskSlip.approve(address(s_stagingLoanRouter), type(uint256).max);
        s_stableToken.approve(address(s_stagingLoanRouter), type(uint256).max);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(s_lender);
        s_stableToken.approve(address(s_stagingLoanRouter), type(uint256).max);
        s_stableToken.approve(s_deployedSBAddress, type(uint256).max);
        s_safeSlip.approve(address(s_stagingLoanRouter), type(uint256).max);
        s_lendSlip.approve(address(s_stagingLoanRouter), type(uint256).max);
        vm.stopPrank();
    }
}
