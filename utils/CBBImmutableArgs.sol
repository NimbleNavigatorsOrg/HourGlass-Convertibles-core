// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@rari-capital/solmate/src/tokens/ERC20.sol";
import "clones-with-immutable-args/Clone.sol";
import '../src/interfaces/ISlipFactory.sol';
import '../src/interfaces/IButtonWoodBondController.sol';

/**
 * @notice Defines the immutable arguments for a CBB
 * @dev using the clones-with-immutable-args library
 * we fetch args from the code section
 */
contract CBBImmutableArgs is Clone {

    /**
     * @notice The bond that holds the tranches
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function bond() public pure returns (IButtonWoodBondController) {
        return IButtonWoodBondController(_getArgAddress(0));
    }

    /**
     * @notice The slip factory used to deploy slips
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function slipFactory() public pure returns (ISlipFactory) {
        return ISlipFactory(_getArgAddress(20));
    }

    /**
     * @notice penalty for zslips
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function penalty() public pure returns (uint256) {
        return _getArgUint256(40);
    }

    /**
     * @notice The collateral token used to make bonds
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function collateralToken() public pure returns (ERC20) {
        return ERC20(_getArgAddress(72));
    }

    /**
     * @notice The stable token used to buy bonds
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function stableToken() public pure returns (ERC20) {
        return ERC20(_getArgAddress(92));
    }

        /**
     * @notice The initial price
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function price() public pure returns (uint256) {
        return _getArgUint256(112);
    }

    /**
     * @notice The start date
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function startDate() public pure returns (uint256) {
        return _getArgUint256(144);
    }

    /**
     * @notice The tranche index used to pick a safe tranche
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function trancheIndex() public pure returns (uint256) {
        return _getArgUint256(176);
    }


}