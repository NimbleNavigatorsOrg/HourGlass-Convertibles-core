pragma solidity 0.8.13;

import "../../src/contracts/IBOBox.sol";
import "../../src/contracts/IBOBoxLens.sol";
import "../../src/contracts/IBOBoxFactory.sol";
import "../../test/convertibleBondBox/CBBSetup.sol";

import "forge-std/console2.sol";

contract iboBoxSetup is CBBSetup {
    uint256 s_initialFuzzPrice;

    IBOBoxFactory iboBoxFactory;
    IBOBox s_deployedIBOB;
    IBOBoxLens s_IBOLens;
    address s_deployedIBOBAddress;

    ISlip s_issueOrder;
    ISlip s_buyOrder;

    event LendDeposit(address, uint256);
    event BorrowDeposit(address, uint256);
    event CancelledBuyOrder(address, uint256);
    event CancelledIssueOrder(address, uint256);
    event RedeemIssueOrder(address, uint256);
    event RedeemBuyOrder(address, uint256);

    event IBOBoxCreated(address msgSender, address IBOBox, address slipFactory);

    function setUp() public override {
        super.setUp();

        IBOBox IBOBox = new IBOBox();
        iboBoxFactory = new IBOBoxFactory(address(IBOBox));
        s_IBOLens = new IBOBoxLens();
    }

    function setupIBOBox(uint256 _fuzzPrice) internal {
        s_initialFuzzPrice = bound(
            _fuzzPrice,
            s_priceGranularity / 100,
            s_priceGranularity
        );

        vm.prank(s_cbb_owner);
        s_deployedIBOB = IBOBox(
            iboBoxFactory.createIBOBoxOnly(
                s_slipFactory,
                s_deployedConvertibleBondBox,
                s_initialFuzzPrice,
                s_cbb_owner
            )
        );
        s_deployedIBOBAddress = address(s_deployedIBOB);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.transferOwnership(s_deployedIBOBAddress);

        s_safeTranche.approve(address(s_deployedIBOB), type(uint256).max);
        s_riskTranche.approve(address(s_deployedIBOB), type(uint256).max);
        s_stableToken.approve(address(s_deployedIBOB), type(uint256).max);

        s_issueOrder = s_deployedIBOB.issueOrder();
        s_buyOrder = s_deployedIBOB.buyOrder();
    }
}
