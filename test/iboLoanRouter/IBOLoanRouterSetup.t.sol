pragma solidity 0.8.13;

import "../../test/convertibleBondBox/CBBSetup.sol";

import "../../src/contracts/IBOBox.sol";
import "../../src/contracts/IBOBoxFactory.sol";
import "../../src/contracts/IBOBoxLens.sol";
import "../../src/contracts/IBOLoanRouter.sol";

import "../mocks/MockERC20.sol";
import "../external/button-wrappers/ButtonToken.sol";
import "../external/button-wrappers/MockOracle.sol";

contract IBOLoanRouterSetup is CBBSetup {
    IBOBoxFactory iboBoxFactory;
    IBOBox s_deployedIBOB;
    IBOBoxLens s_IBOLens;
    IBOLoanRouter s_IBOLoanRouter;
    address s_deployedIBOBAddress;

    ButtonToken s_buttonCollatToken;
    MockOracle s_mockOracle;

    uint256 s_initMockData = 5e8;

    ISlip s_issueOrder;
    ISlip s_buyOrder;

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

        IBOBox iboBox = new IBOBox();
        iboBoxFactory = new IBOBoxFactory(address(iboBox));
        s_IBOLens = new IBOBoxLens();
        s_IBOLoanRouter = new IBOLoanRouter();

        vm.prank(s_cbb_owner);
        s_deployedIBOB = IBOBox(
            iboBoxFactory.createIBOBoxWithCBB(
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

        s_deployedCBBAddress = address(s_deployedIBOB.convertibleBondBox());
        s_deployedConvertibleBondBox = ConvertibleBondBox(s_deployedCBBAddress);

        s_deployedIBOBAddress = address(s_deployedIBOB);

        s_bondSlip = s_deployedConvertibleBondBox.bondSlip();
        s_debtSlip = s_deployedConvertibleBondBox.debtSlip();
        s_issueOrder = s_deployedIBOB.issueOrder();
        s_buyOrder = s_deployedIBOB.buyOrder();

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
        s_collateralToken.approve(address(s_IBOLoanRouter), type(uint256).max);
        s_issueOrder.approve(address(s_IBOLoanRouter), type(uint256).max);
        s_debtSlip.approve(address(s_IBOLoanRouter), type(uint256).max);
        s_stableToken.approve(address(s_IBOLoanRouter), type(uint256).max);
        s_stableToken.approve(s_deployedCBBAddress, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(s_lender);
        s_stableToken.approve(address(s_IBOLoanRouter), type(uint256).max);
        s_stableToken.approve(s_deployedIBOBAddress, type(uint256).max);
        s_bondSlip.approve(address(s_IBOLoanRouter), type(uint256).max);
        s_buyOrder.approve(address(s_IBOLoanRouter), type(uint256).max);
        vm.stopPrank();
    }
}
