// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IStagingBox.sol";
import "../interfaces/IConvertibleBondBox.sol";
import "../interfaces/IButtonWoodBondController.sol";

interface IStagingLoanRouter {
    /**
     * @dev Wraps and tranches raw token and then deposits into staging box for a simple underlying bond (A/Z)
     * @param _stagingBox The staging box tied to the Convertible Bond
     * @param _amountRaw The amount of SafeTranche tokens to borrow against
     * Requirements:
     *  - `msg.sender` must have `approved` `_amountRaw` collateral tokens to this contract
     */

    function simpleWrapTrancheBorrow(
        IStagingBox _stagingBox,
        uint256 _amountRaw
    ) external;

    /**
     * @dev Wraps and tranches raw token and then deposits into staging box for any underlying bond
     * @param _stagingBox The staging box tied to the Convertible Bond
     * @param _amountRaw The amount of SafeTranche tokens to borrow against
     * Requirements:
     *  - `msg.sender` must have `approved` `_amountRaw` collateral tokens to this contract
     */

    function multiWrapTrancheBorrow(IStagingBox _stagingBox, uint256 _amountRaw)
        external;

    /**
     * @dev redeems lendSlips for safeSlips and safeSlips for stables
     * @param _stagingBox The staging box tied to the Convertible Bond
     * @param _lendSlipAmount The amount of lendSlips to be redeemed
     * Requirements:
     *  - can only be called when there are stables in the CBB to be repaid
     */

    function redeemLendSlipsForStables(
        IStagingBox _stagingBox,
        uint256 _lendSlipAmount
    ) external;

    /**
     * @dev redeems lendSlips for safeSlips and safeSlips for tranches, redeems tranches for rebasing
     * collateral, unwraps rebasing collateral, and then swaps for stableToken
     * @param _stagingBox The staging box tied to the Convertible Bond
     * @param _lendSlipAmount The amount of lendSlips to be redeemed
     * Requirements:
     *  - can only be called after maturity
     */

    function redeemLendSlipsForTranchesAndUnwrap(
        IStagingBox _stagingBox,
        uint256 _lendSlipAmount
    ) external;

    /**
     * @dev redeems riskSlips for risTranches, redeems tranches for rebasing
     * collateral, unwraps rebasing collateral
     * @param _stagingBox The staging box tied to the Convertible Bond
     * @param _riskSlipAmount The amount of riskSlips to be redeemed
     * Requirements:
     *  - can only be called after maturity
     */

    function redeemRiskSlipsForTranchesAndUnwrap(
        IStagingBox _stagingBox,
        uint256 _riskSlipAmount
    ) external;

    /**
     * @dev provides amount of stableTokens expected in return for a given collateral amount
     * @param _stagingBox The staging box tied to the Convertible Bond
     * @param _amountRaw The amount of unwrapped tokens to be used as collateral
     * Requirements:
     */

    function viewSimpleWrapTrancheBorrow(
        IStagingBox _stagingBox,
        uint256 _amountRaw
    ) external view returns (uint256);

    /**
     * @dev provides amount of stableTokens expected in return for redeeming lendSlips
     * @param _stagingBox The staging box tied to the Convertible Bond
     * @param _lendSlipAmount The amount of lendSlips to be redeemed
     * Requirements:
     */

    function viewRedeemLendSlipsForStables(
        IStagingBox _stagingBox,
        uint256 _lendSlipAmount
    ) external view returns (uint256);

    /**
     * @dev provides amount of unwrapped collateral tokens expected in return for redeeming lendSlips
     * @param _stagingBox The staging box tied to the Convertible Bond
     * @param _lendSlipAmount The amount of lendSlips to be redeemed
     * Requirements:
     */

    function viewRedeemLendSlipsForTranches(
        IStagingBox _stagingBox,
        uint256 _lendSlipAmount
    ) external view returns (uint256);

    /**
     * @dev provides amount of unwrapped collateral tokens expected in return for redeeming riskSlips
     * @param _stagingBox The staging box tied to the Convertible Bond
     * @param _riskSlipAmount The amount of riskSlips to be redeemed
     * Requirements:
     */

    function viewRedeemRiskSlipsForTranches(
        IStagingBox _stagingBox,
        uint256 _riskSlipAmount
    ) external view returns (uint256);
}
