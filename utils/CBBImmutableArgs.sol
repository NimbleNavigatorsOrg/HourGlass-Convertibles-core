// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "clones-with-immutable-args/Clone.sol";
import "../src/interfaces/ISlip.sol";
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
     */
    function bond() public pure override returns (IButtonWoodBondController) {
        return IButtonWoodBondController(_getArgAddress(0));
    }

    /**
     * @notice The safe slip
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     */
    function safeSlip() public pure override returns (ISlip) {
        return ISlip(_getArgAddress(20));
    }

    /**
     * @notice The risk slip
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     */
    function riskSlip() public pure override returns (ISlip) {
        return ISlip(_getArgAddress(40));
    }

    /**
     * @notice penalty for zslips
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     */
    function penalty() public pure override returns (uint256) {
        return _getArgUint256(60);
    }

    /**
     * @notice The collateral token used to make bonds
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function collateralToken() public pure override returns (IERC20) {
        return IERC20(_getArgAddress(92));
    }

    /**
     * @notice The stable token used to buy bonds
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function stableToken() public pure override returns (IERC20) {
        return IERC20(_getArgAddress(112));
    }

    /**
     * @notice The tranche index used to pick a safe tranche
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function trancheIndex() public pure override returns (uint256) {
        return _getArgUint256(132);
    }

    function maturityDate() public pure override returns (uint256) {
        return _getArgUint256(164);
    }

    function safeTranche() public pure override returns (ITranche) {
        return ITranche(_getArgAddress(196));
    }

    function safeRatio() public pure override returns (uint256) {
        return _getArgUint256(216);
    }

    function riskTranche() public pure override returns (ITranche) {
        return ITranche(_getArgAddress(248));
    }

    function riskRatio() public pure override returns (uint256) {
        return _getArgUint256(268);
    }
}
