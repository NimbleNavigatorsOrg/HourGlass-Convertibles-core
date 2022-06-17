// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "clones-with-immutable-args/Clone.sol";
import "../src/interfaces/ICBBSlipFactory.sol";
import "../src/interfaces/IConvertibleBondBox.sol";

interface ISBImmutableArgs {
    /**
     * @notice The slip factory used to deploy slips
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     */
    function slipFactory() external pure returns (ICBBSlipFactory);

    /**
     * @notice The stable token used to buy bonds
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     */
    function convertibleBondBox() external pure returns (IConvertibleBondBox);

    /**
     * @notice The initial price
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     */
    function initialPrice() external pure returns (uint256);

    /**
     * @notice The stable token used to buy bonds
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     */
    function stableToken() external pure returns (IERC20);

    function safeTranche() external pure returns (ITranche);

    function safeSlipAddress() external pure returns (address);

    function safeRatio() external pure returns (uint256);

    function riskTranche() external pure returns (ITranche);

    function riskSlipAddress() external pure returns (address);

    function riskRatio() external pure returns (uint256);

    function priceGranularity() external pure returns (uint256);
}
