// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../interfaces/IIBOBox.sol";

interface IIBOBoxLens {
    /**
     * @dev provides the bool for limiting factor for the IBO box activation
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewTransmitActivateBool(IIBOBox _IBOBox)
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
     * @param _issueOrderAmount The amount of issueOrders to be withdrawn
     * Requirements:
     * - for A-Z convertible only
     */

    function viewSimpleWithdrawBorrowUnwrap(
        IIBOBox _IBOBox,
        uint256 _issueOrderAmount
    ) external view returns (uint256, uint256);

    /**
     * @dev provides amount of stable tokens expected in return for withdrawing buyOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _buyOrderAmount The amount of buyOrders to be withdrawn
     * Requirements:
     */

    function viewWithdrawBuyOrder(IIBOBox _IBOBox, uint256 _buyOrderAmount)
        external
        view
        returns (uint256);

    /**
     * @dev provides amount of debtSlips and stableToken loan in return for issueOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _issueOrderAmount The amount of issueOrders to be redeemed
     * Requirements:
     */

    function viewRedeemIssueOrderForDebtSlip(
        IIBOBox _IBOBox,
        uint256 _issueOrderAmount
    ) external view returns (uint256, uint256);

    /**
     * @dev provides amount of bondSlips expected in return for redeeming buyOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _buyOrderAmount The amount of buyOrders to be redeemed
     * Requirements:
     */

    function viewRedeemBuyOrderForBondSlip(
        IIBOBox _IBOBox,
        uint256 _buyOrderAmount
    ) external view returns (uint256);

    /**
     * @dev provides amount of stableTokens expected in return for redeeming buyOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _buyOrderAmount The amount of buyOrders to be redeemed
     * Requirements:
     */

    function viewRedeemBuyOrdersForStables(
        IIBOBox _IBOBox,
        uint256 _buyOrderAmount
    ) external view returns (uint256, uint256);

    /**
     * @dev provides amount of stableTokens expected in return for redeeming bondSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _bondSlipAmount The amount of bondSlips to be redeemed
     * Requirements:
     */

    function viewRedeemBondSlipsForStables(
        IIBOBox _IBOBox,
        uint256 _bondSlipAmount
    ) external view returns (uint256, uint256);

    /**
     * @dev provides amount of unwrapped collateral tokens expected in return for redeeming buyOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _buyOrderAmount The amount of buyOrders to be redeemed
     * Requirements:
     */

    function viewRedeemBuyOrdersForTranches(
        IIBOBox _IBOBox,
        uint256 _buyOrderAmount
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
     * @dev provides amount of unwrapped collateral tokens expected in return for redeeming bondSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _bondSlipAmount The amount of buyOrders to be redeemed
     * Requirements:
     */

    function viewRedeemBondSlipsForTranches(
        IIBOBox _IBOBox,
        uint256 _bondSlipAmount
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
     * @dev provides amount of unwrapped collateral tokens expected in return for redeeming debtSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _debtSlipAmount The amount of debtSlips to be redeemed
     * Requirements:
     */

    function viewRedeemDebtSlipsForTranches(
        IIBOBox _IBOBox,
        uint256 _debtSlipAmount
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
     * @dev provides amount of unwrapped collateral tokens expected in return for repaying in full the DebtSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     *      - Only for prior to maturity
     *      - Only for bonds with A/Z tranches
     */

    function viewRepayMaxAndUnwrapSimple(
        IIBOBox _IBOBox,
        uint256 _debtSlipAmount
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
     * @dev provides maximum input param for redeemIssueOrder
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemIssueOrder(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming lend slips for safe slips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemBuyOrderForBondSlip(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming lend slips for stables
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemBuyOrderForStables(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming safe slips for stables
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemBondSlipForStables(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when withdrawing lend slips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxWithdrawBuyOrders(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when withdrawing borrow slips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxWithdrawIssueOrders(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming safe slips for tranches
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemBondSlipForTranches(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming lend slips for tranches
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemBuyOrderForTranches(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);
}
