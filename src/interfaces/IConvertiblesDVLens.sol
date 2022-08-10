// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IStagingBox.sol";
import "../interfaces/IConvertibleBondBox.sol";

struct NumFixedPoint {
    uint256 value;
    uint256 decimals;
}

struct StagingDataIBO {
    NumFixedPoint lendSlipSupply;
    NumFixedPoint borrowSlipSupply;
    NumFixedPoint safeTrancheBalance;
    NumFixedPoint riskTrancheBalance;
    NumFixedPoint safeTrancheCollateral;
    NumFixedPoint riskTrancheCollateral;
    NumFixedPoint stableTokenBalance;
    NumFixedPoint tvl;
    NumFixedPoint tvb;
}

struct StagingDataActive {
    NumFixedPoint lendSlipSupply;
    NumFixedPoint borrowSlipSupply;
    NumFixedPoint safeTrancheBalance;
    NumFixedPoint riskTrancheBalance;
    NumFixedPoint safeTrancheCollateral;
    NumFixedPoint riskTrancheCollateral;
    NumFixedPoint stableTokenBalance;
    NumFixedPoint tvl;
    NumFixedPoint tvb;
    NumFixedPoint safeSlipBalance;
    NumFixedPoint riskSlipBalance;
}

struct CBBDataActive {
    NumFixedPoint safeSlipSupply;
    NumFixedPoint riskSlipSupply;
    NumFixedPoint repaidSafeSlips;
    NumFixedPoint safeTrancheBalance;
    NumFixedPoint riskTrancheBalance;
    NumFixedPoint safeTrancheCollateral;
    NumFixedPoint riskTrancheCollateral;
    NumFixedPoint stableTokenBalance;
    NumFixedPoint currentPrice;
    NumFixedPoint tvl;
    NumFixedPoint tvb;
}

struct CBBDataMature {
    NumFixedPoint safeSlipSupply;
    NumFixedPoint riskSlipSupply;
    NumFixedPoint repaidSafeSlips;
    NumFixedPoint safeTrancheBalance;
    NumFixedPoint riskTrancheBalance;
    NumFixedPoint zPenaltyTrancheBalance;
    NumFixedPoint safeTrancheCollateral;
    NumFixedPoint riskTrancheCollateral;
    NumFixedPoint zPenaltyTrancheCollateral;
    NumFixedPoint stableTokenBalance;
    NumFixedPoint currentPrice;
    NumFixedPoint tvl;
    NumFixedPoint tvb;
}

interface IConvertiblesDVLens {
    /**
     * @dev provides the stats for Staging Box in IBO period
     * @param _stagingBox The staging box tied to the Convertible Bond
     * Requirements:
     */

    function viewStagingStatsIBO(IStagingBox _stagingBox)
        external
        view
        returns (StagingDataIBO memory);

    /**
     * @dev provides the stats for Staging Box in IBO period
     * @param _stagingBox The staging box tied to the Convertible Bond
     * Requirements:
     */

    function viewStagingStatsActive(IStagingBox _stagingBox)
        external
        view
        returns (StagingDataActive memory);

    /**
     * @dev provides the stats for Staging Box in IBO period
     * @param _convertibleBondBox The staging box tied to the Convertible Bond
     * Requirements:
     */

    function viewCBBStatsActive(IConvertibleBondBox _convertibleBondBox)
        external
        view
        returns (CBBDataActive memory);

    /**
     * @dev provides the stats for Staging Box in IBO period
     * @param _convertibleBondBox The staging box tied to the Convertible Bond
     * Requirements:
     */

    function viewCBBStatsMature(IConvertibleBondBox _convertibleBondBox)
        external
        view
        returns (CBBDataMature memory);
}
