pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../src/contracts/StagingBox.sol";
import "../../src/contracts/StagingBoxFactory.sol";
import "../../src/contracts/CBBFactory.sol";
import "../../src/contracts/ConvertibleBondBox.sol";
import "./SBSetup.t.sol";

contract TransmitReinit is SBSetup {

    function testTransmitReInit(uint256 price, uint256 _borrowSlipAmount, bool _isLend) public {
        price = bound(price, 1, s_deployedConvertibleBondBox.s_priceGranularity());

        s_deployedSB = StagingBox(stagingBoxFactory.createStagingBox(
            s_deployedConvertibleBondBox,
            s_slipFactory,
            price,
            s_cbb_owner
        ));

        vm.startPrank(s_cbb_owner);

        // TODO: can we mock these?
        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.reinitialize.selector),
            abi.encode(true)
        );

        vm.mockCall(
            address(s_deployedConvertibleBondBox), 
            abi.encodeWithSelector(s_deployedConvertibleBondBox.cbbTransferOwnership.selector),
            abi.encode(true)
        );

        s_deployedSB.transmitReInit(_isLend);
        vm.stopPrank();
    }
}