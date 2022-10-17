// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../../utils/ISBImmutableArgs.sol";

interface IStagingBox is ISBImmutableArgs {
    event LendDeposit(address lender, uint256 lendAmount);
    event BorrowDeposit(address borrower, uint256 safeTrancheAmount);
    event LendWithdrawal(address lender, uint256 lendSlipAmount);
    event BorrowWithdrawal(address borrower, uint256 borrowSlipAmount);
    event RedeemBorrowSlip(address caller, uint256 borrowSlipAmount);
    event RedeemLendSlip(address caller, uint256 lendSlipAmount);
    event Initialized(address owner);

    error InitialPriceTooHigh(uint256 given, uint256 maxPrice);
    error InitialPriceIsZero(uint256 given, uint256 maxPrice);
    error WithdrawAmountTooHigh(uint256 requestAmount, uint256 maxAmount);
    error CBBReinitialized(bool state, bool requiredState);

    function s_reinitLendAmount() external view returns (uint256);

    /**
     * @dev Deposits collateral for BorrowSlips
     * @param _borrower The recipent address of the BorrowSlips
     * @param _borrowAmount The amount of stableTokens to be borrowed
     * Requirements:
     *  - `msg.sender` must have `approved` `stableAmount` stable tokens to this contract
     */

    function depositBorrow(address _borrower, uint256 _borrowAmount) external;

    /**
     * @dev deposit _lendAmount of stable-tokens for LendSlips
     * @param _lender The recipent address of the LenderSlips
     * @param _lendAmount The amount of stable tokens to deposit
     * Requirements:
     *  - `msg.sender` must have `approved` `stableAmount` stable tokens to this contract
     */

    function depositLend(address _lender, uint256 _lendAmount) external;

    /**
     * @dev Withdraws SafeTranche + RiskTranche for unfilled BorrowSlips
     * @param _borrowSlipAmount The amount of borrowSlips to withdraw
     * Requirements:
     */

    function withdrawBorrow(uint256 _borrowSlipAmount) external;

    /**
     * @dev Withdraws Lend Slips for unfilled BorrowSlips
     * @param _lendSlipAmount The amount of stable tokens to withdraw
     * Requirements:
     */

    function withdrawLend(uint256 _lendSlipAmount) external;

    /**
     * @dev Deposits _stableAmount of stable-tokens and then calls lend to CBB
     * @param _borrowSlipAmount amount of BorrowSlips to redeem RiskSlips and USDT with
     * Requirements:
     */

    function redeemBorrowSlip(uint256 _borrowSlipAmount) external;

    /**
     * @dev Deposits _collateralAmount of collateral-tokens and then calls borrow to CBB
     * @param _lendSlipAmount amount of LendSlips to redeem SafeSlips with
     * Requirements:
     */

    function redeemLendSlip(uint256 _lendSlipAmount) external;

    /**
     * @dev Deposits _collateralAmount of collateral-tokens and then calls borrow to CBB
     * @param _lendOrBorrow boolean to indicate whether to reinitialize CBB based of stableToken balance or safeTranche balance
     * Requirements:
     * - StagingBox must be the owner of the CBB to call this function
     * - Change owner of CBB to be the SB prior to calling this function if not already done
     */

    function transmitReInit(bool _lendOrBorrow) external;

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
