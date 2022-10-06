//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "../../utils/ICBBImmutableArgs.sol";

/**
 * @dev Convertible Bond Box for a ButtonTranche bond
 */

interface IConvertibleBondBox is ICBBImmutableArgs {
    event Lend(
        address caller,
        address borrower,
        address lender,
        uint256 stableAmount,
        uint256 price
    );
    event Borrow(
        address caller,
        address borrower,
        address lender,
        uint256 stableAmount,
        uint256 price
    );
    event RedeemStable(address caller, uint256 bondSlipAmount, uint256 price);
    event RedeemSafeTranche(address caller, uint256 bondSlipAmount);
    event RedeemRiskTranche(address caller, uint256 issuerSlipAmount);
    event Repay(
        address caller,
        uint256 stablesPaid,
        uint256 riskTranchePayout,
        uint256 price
    );
    event Initialized(address owner);
    event Activated(uint256 initialPrice, uint256 timestamp);
    event FeeUpdate(uint256 newFee);

    error PenaltyTooHigh(uint256 given, uint256 maxPenalty);
    error BondIsMature(uint256 currentTime, uint256 maturity);
    error InitialPriceTooHigh(uint256 given, uint256 maxPrice);
    error InitialPriceIsZero(uint256 given, uint256 maxPrice);
    error ConvertibleBondBoxNotStarted(uint256 given, uint256 minStartDate);
    error BondNotMatureYet(uint256 maturityDate, uint256 currentTime);
    error MinimumInput(uint256 input, uint256 reqInput);
    error FeeTooLarge(uint256 input, uint256 maximum);

    //Need to add getters for state variables

    /**
     * @dev Sets startdate to be block.timestamp, sets initialPrice, and takes initial atomic deposit
     * @param _initialPrice the initialPrice for the CBB
     * Requirements:
     *  - `msg.sender` is owner
     */

    function activate(uint256 _initialPrice) external;

    /**
     * @dev Lends stableAmount of stable-tokens for safe-Tranche slips when provided with matching borrow collateral
     * @param _borrower The address to send the Z* and stableTokens to 
     * @param _lender The address to send the bondSlips to 
     * @param _stableAmount The amount of stable tokens to lend
     * Requirements:
     *  - `msg.sender` must have `approved` `stableAmount` stable tokens to this contract
        - initial price of bond must be set
     */

    function lend(
        address _borrower,
        address _lender,
        uint256 _stableAmount
    ) external;

    /**
     * @dev Borrows with collateralAmount of collateral-tokens when provided with a matching amount of stableTokens.
     * Collateral tokens get tranched and any non-convertible bond box tranches get sent back to borrower 
     * @param _borrower The address to send the Z* and stableTokens to 
     * @param _lender The address to send the bondSlips to 
     * @param _collateralAmount The buttonTranche bond tied to this Convertible Bond Box
     * Requirements:
     *  - `msg.sender` must have `approved` `collateralAmount` collateral tokens to this contract
        - initial price of bond must be set
        - must be enough stable tokens inside convertible bond box to borrow 
     */

    function borrow(
        address _borrower,
        address _lender,
        uint256 _collateralAmount
    ) external;

    /**
     * @dev returns time-weighted current price for Tranches, with final price as $1.00 at maturity
     */

    function currentPrice() external view returns (uint256);

    /**
     * @dev allows repayment of loan in exchange for proportional amount of safe-Tranche and Z-tranche
     * - any unpaid amount of Z-slips after maturity will be penalized upon redeeming
     * @param _stableAmount The amount of stable-Tokens to repay with
     * Requirements:
     *  - `msg.sender` must have `approved` `stableAmount` of stable tokens to this contract
     */

    function repay(uint256 _stableAmount) external;

    /**
     * @dev enables full repayment of issuerSlips
     * - any unpaid amount of Z-slips after maturity will be penalized upon redeeming
     * @param _issuerSlipAmount The amount of issuerSlips to repaid
     * Requirements:
     *  - `msg.sender` must have `approved` calculated amount of stable tokens to this contract
     */

    function repayMax(uint256 _issuerSlipAmount) external;

    /**
     * @dev allows lender to redeem safe-slip for tranches
     * @param _bondSlipAmount The amount of safe-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `bondSlipAmount` of safe-Slip tokens to this contract
     */

    function redeemSafeTranche(uint256 _bondSlipAmount) external;

    /**
     * @dev allows borrower to redeem risk-slip for tranches without repaying
     * @param _issuerSlipAmount The amount of risk-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `issuerSlipAmount` of safe-Slip tokens to this contract
     */

    function redeemRiskTranche(uint256 _issuerSlipAmount) external;

    /**
     * @dev allows lender to redeem safe-slip for stables
     * @param _bondSlipAmount The amount of safe-slips to redeem
     * Requirements:
     *  - `msg.sender` must have `approved` `bondSlipAmount` of safe-Slip tokens to this contract
     */

    function redeemStable(uint256 _bondSlipAmount) external;

    /**
     * @dev Updates the fee taken on deposit to the given new fee
     *
     * Requirements
     * - `msg.sender` has admin role
     * - `newFeeBps` is in range [0, 50]
     */

    function setFee(uint256 newFeeBps) external;

    /**
     * @dev Gets the start date
     */
    function s_startDate() external view returns (uint256);

    /**
     * @dev Gets the total repaid safe slips to date
     */
    function s_repaidBondSlips() external view returns (uint256);

    /**
     * @dev Gets the tranche granularity constant
     */
    function s_trancheGranularity() external view returns (uint256);

    /**
     * @dev Gets the penalty granularity constant
     */
    function s_penaltyGranularity() external view returns (uint256);

    /**
     * @dev Gets the price granularity constant
     */
    function s_priceGranularity() external view returns (uint256);

    /**
     * @dev Gets the fee basis points
     */
    function feeBps() external view returns (uint256);

    /**
     * @dev Gets the basis points denominator constant. AKA a fee granularity constant
     */
    function BPS() external view returns (uint256);

    /**
     * @dev Gets the max fee basis points constant.
     */
    function maxFeeBPS() external view returns (uint256);

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external;

    /**
     * @dev Returns initialPrice of safeTranche.
     */
    function s_initialPrice() external view returns (uint256);
}
