// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IStagingBox.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "../interfaces/IButtonWoodBondController.sol";

interface IStagingLoanRouter {
    function simpleWrapTrancheBorrow(
        IStagingBox _stagingBox,
        uint256 _amountRaw
    ) external;

    function multiWrapTrancheBorrow(IStagingBox _stagingBox, uint256 _amountRaw)
        external;
}
