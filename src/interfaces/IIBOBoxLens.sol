// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IIBOBox.sol";

interface IIBOBoxLens {
    /**
     * @dev provides the bool for limiting factor for the IBO box reinit
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewTransmitReInitBool(IIBOBox _IBOBox)
        external
        view
        returns (bool);

    /**
     * @dev provides amount of stableTokens expected in return for a given collateral amount
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _amountRaw The amount of unwrapped tokens to be used as collateral
     * Requirements:
     */

    function viewSimpleWrapTrancheBorrow(IIBOBox _IBOBox, uint256 _amountRaw)
        external
        view
        returns (uint256, uint256);

    /**
     * @dev provides amount of raw collateral tokens expected in return for withdrawing borrowslips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _borrowSlipAmount The amount of borrowSlips to be withdrawn
     * Requirements:
     * - for A-Z convertible only
     */

    function viewSimpleWithdrawBorrowUnwrap(
        IIBOBox _IBOBox,
        uint256 _borrowSlipAmount
    ) external view returns (uint256, uint256);

    /**
     * @dev provides amount of stable tokens expected in return for withdrawing lendSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _lendSlipAmount The amount of lendSlips to be withdrawn
     * Requirements:
     */

    function viewWithdrawLendSlip(IIBOBox _IBOBox, uint256 _lendSlipAmount)
        external
        view
        returns (uint256);

    /**
     * @dev provides amount of riskSlips and stableToken loan in return for borrowSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _borrowSlipAmount The amount of borrowSlips to be redeemed
     * Requirements:
     */

    function viewRedeemBorrowSlipForRiskSlip(
        IIBOBox _IBOBox,
        uint256 _borrowSlipAmount
    ) external view returns (uint256, uint256);

    /**
     * @dev provides amount of safeSlips expected in return for redeeming lendSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _lendSlipAmount The amount of lendSlips to be redeemed
     * Requirements:
     */

    function viewRedeemLendSlipForSafeSlip(
        IIBOBox _IBOBox,
        uint256 _lendSlipAmount
    ) external view returns (uint256);

    /**
     * @dev provides amount of stableTokens expected in return for redeeming lendSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _lendSlipAmount The amount of lendSlips to be redeemed
     * Requirements:
     */

    function viewRedeemLendSlipsForStables(
        IIBOBox _IBOBox,
        uint256 _lendSlipAmount
    ) external view returns (uint256, uint256);

    /**
     * @dev provides amount of stableTokens expected in return for redeeming safeSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _safeSlipAmount The amount of safeSlips to be redeemed
     * Requirements:
     */

    function viewRedeemSafeSlipsForStables(
        IIBOBox _IBOBox,
        uint256 _safeSlipAmount
    ) external view returns (uint256, uint256);

    /**
     * @dev provides amount of unwrapped collateral tokens expected in return for redeeming lendSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _lendSlipAmount The amount of lendSlips to be redeemed
     * Requirements:
     */

    function viewRedeemLendSlipsForTranches(
        IIBOBox _IBOBox,
        uint256 _lendSlipAmount
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    /**
     * @dev provides amount of unwrapped collateral tokens expected in return for redeeming safeSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _safeSlipAmount The amount of lendSlips to be redeemed
     * Requirements:
     */

    function viewRedeemSafeSlipsForTranches(
        IIBOBox _IBOBox,
        uint256 _safeSlipAmount
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    /**
     * @dev provides amount of unwrapped collateral tokens expected in return for redeeming riskSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _riskSlipAmount The amount of riskSlips to be redeemed
     * Requirements:
     */

    function viewRedeemRiskSlipsForTranches(
        IIBOBox _IBOBox,
        uint256 _riskSlipAmount
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    /**
     * @dev provides amount of unwrapped collateral tokens expected in return for repaying a specified amount of stables
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _stableAmount The amount of stables being repaid
     * Requirements:
     *      - Only for prior to maturity
     *      - Only for bonds with A/Z tranches
     */

    function viewRepayAndUnwrapSimple(IIBOBox _IBOBox, uint256 _stableAmount)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    /**
     * @dev provides amount of unwrapped collateral tokens expected in return for repaying in full the RiskSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     *      - Only for prior to maturity
     *      - Only for bonds with A/Z tranches
     */

    function viewRepayMaxAndUnwrapSimple(
        IIBOBox _IBOBox,
        uint256 _riskSlipAmount
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    /**
     * @dev provides amount of unwrapped collateral tokens expected in return for repaying a specified amount of stables
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _stableAmount The amount of stables being repaid
     * Requirements:
     *      - Only for after maturity
     
     */

    function viewRepayAndUnwrapMature(IIBOBox _IBOBox, uint256 _stableAmount)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    /**
     * @dev provides amount of unwrapped collateral tokens expected in return for repaying a specified amount of stables
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _stableAmount The amount of stables being repaid
     * Requirements:
     *      - Only for after maturity
     */

    function viewRepayMaxAndUnwrapMature(IIBOBox _IBOBox, uint256 _stableAmount)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    /**
     * @dev provides maximum input param for redeemBorrowSlip
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemBorrowSlip(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming lend slips for safe slips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemLendSlipForSafeSlip(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming lend slips for stables
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemLendSlipForStables(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming safe slips for stables
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemSafeSlipForStables(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when withdrawing lend slips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxWithdrawLendSlips(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when withdrawing borrow slips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxWithdrawBorrowSlips(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming safe slips for tranches
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemSafeSlipForTranches(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming lend slips for tranches
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemLendSlipForTranches(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);
}
