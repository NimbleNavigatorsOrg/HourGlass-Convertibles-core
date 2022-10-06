// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IIBOBox.sol";
import "../interfaces/IConvertibleBondBox.sol";

struct NumFixedPoint {
    uint256 value;
    uint256 decimals;
}

struct IBODataIBO {
    NumFixedPoint buyOrderSupply;
    NumFixedPoint issueOrderSupply;
    NumFixedPoint safeTrancheBalance;
    NumFixedPoint riskTrancheBalance;
    NumFixedPoint stableTokenBalance;
    NumFixedPoint safeTrancheCollateral;
    NumFixedPoint riskTrancheCollateral;
    NumFixedPoint tvlBorrow;
    NumFixedPoint tvlLend;
}

struct IBODataActive {
    NumFixedPoint buyOrderSupply;
    NumFixedPoint issueOrderSupply;
    NumFixedPoint safeTrancheBalance;
    NumFixedPoint riskTrancheBalance;
    NumFixedPoint bondSlipBalance;
    NumFixedPoint debtSlipBalance;
    NumFixedPoint stableTokenBalanceBorrow;
    NumFixedPoint stableTokenBalanceLend;
    NumFixedPoint safeTrancheCollateral;
    NumFixedPoint riskTrancheCollateral;
    NumFixedPoint bondSlipCollateral;
    NumFixedPoint debtSlipCollateral;
    NumFixedPoint tvlBorrow;
    NumFixedPoint tvlLend;
}

struct CBBDataActive {
    NumFixedPoint bondSlipSupply;
    NumFixedPoint debtSlipSupply;
    NumFixedPoint repaidBondSlips;
    NumFixedPoint safeTrancheBalance;
    NumFixedPoint riskTrancheBalance;
    NumFixedPoint stableTokenBalance;
    NumFixedPoint safeTrancheCollateral;
    NumFixedPoint riskTrancheCollateral;
    NumFixedPoint currentPrice;
    NumFixedPoint tvlBorrow;
    NumFixedPoint tvlLend;
}

struct CBBDataMature {
    NumFixedPoint bondSlipSupply;
    NumFixedPoint debtSlipSupply;
    NumFixedPoint repaidBondSlips;
    NumFixedPoint safeTrancheBalance;
    NumFixedPoint riskTrancheBalance;
    NumFixedPoint zPenaltyTrancheBalance;
    NumFixedPoint stableTokenBalance;
    NumFixedPoint safeTrancheCollateral;
    NumFixedPoint riskTrancheCollateral;
    NumFixedPoint zPenaltyTrancheCollateral;
    NumFixedPoint currentPrice;
    NumFixedPoint tvlBorrow;
    NumFixedPoint tvlLend;
}

interface IConvertiblesDVLens {
    /**
     * @dev provides the stats for IBO Box in IBO period
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewIBOStatsIBO(IIBOBox _IBOBox)
        external
        view
        returns (IBODataIBO memory);

    /**
     * @dev provides the stats for IBO Box in IBO period
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewIBOStatsActive(IIBOBox _IBOBox)
        external
        view
        returns (IBODataActive memory);

    /**
     * @dev provides the stats for IBO Box in IBO period
     * @param _convertibleBondBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewCBBStatsActive(IConvertibleBondBox _convertibleBondBox)
        external
        view
        returns (CBBDataActive memory);

    /**
     * @dev provides the stats for IBO Box in IBO period
     * @param _convertibleBondBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewCBBStatsMature(IConvertibleBondBox _convertibleBondBox)
        external
        view
        returns (CBBDataMature memory);
}
