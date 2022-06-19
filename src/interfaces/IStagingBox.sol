// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../utils/ISBImmutableArgs.sol";

interface IStagingBox is ISBImmutableArgs {
    event LendDeposit(address, uint256);
    event BorrowDeposit(address, uint256);

    event LendWithdrawal(address, uint256);
    event BorrowWithdrawal(address, uint256);

    event RedeemBorrowSlip(address, uint256);
    event RedeemLendSlip(address, uint256);

    event TrasmitReint(bool, uint256);

    error InitialPriceTooHigh(uint256 given, uint256 maxPrice);

    //Getters

    function s_lendSlipTokenAddress() external view returns (address);

    function s_borrowSlipTokenAddress() external view returns (address);

    /**
     * @dev Deposits collateral for BorrowSlips
     * @param _borrower The recipent address of the BorrowSlips
     * @param _safeTrancheAmount The amount of SafeTranche tokens to borrow against
     * Requirements:
     *  - `msg.sender` must have `approved` `stableAmount` stable tokens to this contract
     */

    function depositBorrow(address _borrower, uint256 _safeTrancheAmount)
        external;

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
     */

    function transmitReInit(bool _lendOrBorrow) external;

    /**
     * @dev Transfers ownership.
     * @param _newOwner address of the new owner of SB
     */
    function sbTransferOwnership(address _newOwner) external;
}
