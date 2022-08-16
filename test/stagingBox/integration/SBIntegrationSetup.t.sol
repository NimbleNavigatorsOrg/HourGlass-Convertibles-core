pragma solidity 0.8.13;

import "../../../src/contracts/StagingBox.sol";
import "../../../src/contracts/StagingBoxLens.sol";
import "../../../src/contracts/StagingBoxFactory.sol";
import "../../../test/convertibleBondBox/CBBSetup.sol";

import "forge-std/console2.sol";

contract SBIntegrationSetup is CBBSetup {
    uint256 s_initialFuzzPrice;

    StagingBoxFactory stagingBoxFactory;
    StagingBox s_deployedSB;
    StagingBoxLens s_SBLens;
    address s_deployedSBAddress;

    ISlip s_borrowSlip;
    ISlip s_lendSlip;

    event LendDeposit(address, uint256);
    event BorrowDeposit(address, uint256);
    event LendWithdrawal(address, uint256);
    event BorrowWithdrawal(address, uint256);
    event RedeemBorrowSlip(address, uint256);
    event RedeemLendSlip(address, uint256);

    event StagingBoxCreated(
        IConvertibleBondBox convertibleBondBox,
        uint256 initialPrice,
        address owner,
        address msgSender,
        address stagingBox
    );

    function setUp() public override {
        super.setUp();

        StagingBox stagingBox = new StagingBox();
        stagingBoxFactory = new StagingBoxFactory(address(stagingBox));
        s_SBLens = new StagingBoxLens();
    }

    function setupStagingBox(uint256 _fuzzPrice) internal {
        s_initialFuzzPrice = bound(
            _fuzzPrice,
            s_priceGranularity / 100,
            s_priceGranularity
        );

        vm.prank(s_cbb_owner);
        s_deployedSB = StagingBox(
            stagingBoxFactory.createStagingBoxOnly(
                s_slipFactory,
                s_deployedConvertibleBondBox,
                s_initialFuzzPrice,
                s_cbb_owner
            )
        );
        s_deployedSBAddress = address(s_deployedSB);

        vm.prank(s_cbb_owner);
        s_deployedConvertibleBondBox.transferOwnership(s_deployedSBAddress);

        s_safeTranche.approve(address(s_deployedSB), type(uint256).max);
        s_riskTranche.approve(address(s_deployedSB), type(uint256).max);
        s_stableToken.approve(address(s_deployedSB), type(uint256).max);

        s_borrowSlip = s_deployedSB.borrowSlip();
        s_lendSlip = s_deployedSB.lendSlip();
    }
}
