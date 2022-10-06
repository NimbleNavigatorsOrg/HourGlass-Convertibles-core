// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../utils/IIBOImmutableArgs.sol";

interface IIBOBox is IIBOImmutableArgs {
    event LendDeposit(address lender, uint256 lendAmount);
    event BorrowDeposit(address borrower, uint256 safeTrancheAmount);
    event CancelledBuyOrder(address lender, uint256 buyOrderAmount);
    event CancelledIssueOrder(address borrower, uint256 issueOrderAmount);
    event RedeemIssueOrder(address caller, uint256 issueOrderAmount);
    event RedeemBuyOrder(address caller, uint256 buyOrderAmount);
    event Initialized(address owner);

    error InitialPriceTooHigh(uint256 given, uint256 maxPrice);
    error InitialPriceIsZero(uint256 given, uint256 maxPrice);
    error WithdrawAmountTooHigh(uint256 requestAmount, uint256 maxAmount);
    error CBBActivated(bool state, bool requiredState);

    function s_activateLendAmount() external view returns (uint256);

    /**
     * @dev Deposits collateral for IssueOrders
     * @param _borrower The recipent address of the IssueOrders
     * @param _borrowAmount The amount of stableTokens to be borrowed
     * Requirements:
     *  - `msg.sender` must have `approved` `stableAmount` stable tokens to this contract
     */

    function depositBorrow(address _borrower, uint256 _borrowAmount) external;

    /**
     * @dev deposit _lendAmount of stable-tokens for BuyOrders
     * @param _lender The recipent address of the LenderSlips
     * @param _lendAmount The amount of stable tokens to deposit
     * Requirements:
     *  - `msg.sender` must have `approved` `stableAmount` stable tokens to this contract
     */

    function depositLend(address _lender, uint256 _lendAmount) external;

    /**
     * @dev Withdraws SafeTranche + RiskTranche for unfilled IssueOrders
     * @param _issueOrderAmount The amount of issueOrders to cancel
     * Requirements:
     */

    function cancelIssue(uint256 _issueOrderAmount) external;

    /**
     * @dev Withdraws Lend Slips for unfilled IssueOrders
     * @param _buyOrderAmount The amount of stable tokens to cancel
     * Requirements:
     */

    function cancelBuy(uint256 _buyOrderAmount) external;

    /**
     * @dev Deposits _stableAmount of stable-tokens and then calls lend to CBB
     * @param _issueOrderAmount amount of IssueOrders to redeem DebtSlips and USDT with
     * Requirements:
     */

    function redeemIssueOrder(uint256 _issueOrderAmount) external;

    /**
     * @dev Deposits _collateralAmount of collateral-tokens and then calls borrow to CBB
     * @param _buyOrderAmount amount of BuyOrders to redeem BondSlips with
     * Requirements:
     */

    function redeemBuyOrder(uint256 _buyOrderAmount) external;

    /**
     * @dev Deposits _collateralAmount of collateral-tokens and then calls borrow to CBB
     * @param _lendOrBorrow boolean to indicate whether to activate CBB based of stableToken balance or safeTranche balance
     * Requirements:
     */

    function transmitActivate(bool _lendOrBorrow) external;

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external;

    /**
     * @dev Transfers ownership of the CBB contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferCBBOwnership(address newOwner) external;
}
