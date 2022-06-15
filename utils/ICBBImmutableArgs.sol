// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "clones-with-immutable-args/Clone.sol";
import "../src/interfaces/ICBBSlipFactory.sol";
import "../src/interfaces/IButtonWoodBondController.sol";

interface ICBBImmutableArgs {
        /**
     * @notice The bond that holds the tranches
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function bond() external pure returns (IButtonWoodBondController);

    /**
     * @notice The slip factory used to deploy slips
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function slipFactory() external pure returns (ICBBSlipFactory);

    /**
     * @notice penalty for zslips
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function penalty() external pure returns (uint256);

    /**
     * @notice The collateral token used to make bonds
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function collateralToken() external pure returns (IERC20);

    /**
     * @notice The stable token used to buy bonds
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function stableToken() external pure returns (IERC20);

    /**
     * @notice The initial price
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function initialPrice() external pure returns (uint256);

    /**
     * @notice The tranche index used to pick a safe tranche
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function trancheIndex() external pure returns (uint256);

    function trancheCount() external pure returns (uint256);

    function maturityDate() external pure returns (uint256);

    function safeTranche() external pure returns (ITranche);

    function safeRatio() external pure returns (uint256);

    function riskTranche() external pure returns (ITranche);

    function riskRatio() external pure returns (uint256);
}