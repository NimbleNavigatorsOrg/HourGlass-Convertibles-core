// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "clones-with-immutable-args/Clone.sol";
import "../src/interfaces/ISlipFactory.sol";
import "../src/interfaces/IButtonWoodBondController.sol";
import "./ICBBImmutableArgs.sol";

/**
 * @notice Defines the immutable arguments for a CBB
 * @dev using the clones-with-immutable-args library
 * we fetch args from the code section
 */
contract CBBImmutableArgs is Clone, ICBBImmutableArgs {
    /**
     * @notice The bond that holds the tranches
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function bond() public override pure returns (IButtonWoodBondController) {
        return IButtonWoodBondController(_getArgAddress(0));
    }

    /**
     * @notice The slip factory used to deploy slips
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function slipFactory() public override pure returns (ISlipFactory) {
        return ISlipFactory(_getArgAddress(20));
    }

    /**
     * @notice penalty for zslips
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function penalty() public override pure returns (uint256) {
        return _getArgUint256(40);
    }

    /**
     * @notice The collateral token used to make bonds
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function collateralToken() public override pure returns (IERC20) {
        return IERC20(_getArgAddress(72));
    }

    /**
     * @notice The stable token used to buy bonds
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function stableToken() public override pure returns (IERC20) {
        return IERC20(_getArgAddress(92));
    }

    /**
     * @notice The tranche index used to pick a safe tranche
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function trancheIndex() public override pure returns (uint256) {
        return _getArgUint256(112);
    }

    function trancheCount() public override pure returns (uint256) {
        return _getArgUint256(144);
    }

    function maturityDate() public override pure returns (uint256) {
        return _getArgUint256(176);
    }

    function safeTranche() public override pure returns (ITranche) {
        return ITranche(_getArgAddress(208));
    }

    function safeRatio() public override pure returns (uint256) {
        return _getArgUint256(228);
    }

    function riskTranche() public override pure returns (ITranche) {
        return ITranche(_getArgAddress(260));
    }

    function riskRatio() public override pure returns (uint256) {
        return _getArgUint256(280);
    }
}
