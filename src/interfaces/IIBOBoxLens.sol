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
     * @dev provides amount of raw collateral tokens expected in return for cancelling borrowslips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _issueOrderAmount The amount of issueOrders to be cancelled
     * Requirements:
     * - for A-Z convertible only
     */

    function viewSimpleCancelIssueUnwrap(
        IIBOBox _IBOBox,
        uint256 _issueOrderAmount
    ) external view returns (uint256, uint256);

    /**
     * @dev provides amount of stable tokens expected in return for cancelling buyOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _buyOrderAmount The amount of buyOrders to be cancelled
     * Requirements:
     */

    function viewCancelBuyOrder(IIBOBox _IBOBox, uint256 _buyOrderAmount)
        external
        view
        returns (uint256);

    /**
     * @dev provides amount of debtSlips and stableToken loan in return for issueOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _issueOrderAmount The amount of issueOrders to be redeemed
     * Requirements:
     */

    function viewExecuteIssueOrderForDebtSlip(
        IIBOBox _IBOBox,
        uint256 _issueOrderAmount
    ) external view returns (uint256, uint256);

    /**
     * @dev provides amount of bondSlips expected in return for redeeming buyOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _buyOrderAmount The amount of buyOrders to be redeemed
     * Requirements:
     */

    function viewExecuteBuyOrderForBondSlip(
        IIBOBox _IBOBox,
        uint256 _buyOrderAmount
    ) external view returns (uint256);

    /**
     * @dev provides amount of stableTokens expected in return for redeeming buyOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * @param _buyOrderAmount The amount of buyOrders to be redeemed
     * Requirements:
     */

    function viewExecuteBuyOrdersRedeemStables(
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

    function viewExecuteBuyOrdersRedeemTranches(
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
     * @dev provides maximum input param for executeIssueOrder
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxExecuteIssueOrder(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming buyOrders for bondSlips
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxExecuteBuyOrderForBondSlip(
        IIBOBox _IBOBox,
        address _account
    ) external view returns (uint256);

    /**
     * @dev provides maximum input param when redeeming buyOrders for stables
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxExecuteBuyOrderRedeemStables(
        IIBOBox _IBOBox,
        address _account
    ) external view returns (uint256);

    /**
     * @dev provides maximum input param when redeeming bondSlips for stables
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemBondSlipForStables(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when cancelling buyOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxCancelBuyOrders(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when cancelling issueOrders
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxCancelIssueOrders(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming bondSlips for tranches
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxRedeemBondSlipForTranches(IIBOBox _IBOBox, address _account)
        external
        view
        returns (uint256);

    /**
     * @dev provides maximum input param when redeeming buyOrders for tranches
     * @param _IBOBox The IBO box tied to the Convertible Bond
     * Requirements:
     */

    function viewMaxExecuteBuyOrderRedeemTranches(
        IIBOBox _IBOBox,
        address _account
    ) external view returns (uint256);
}
