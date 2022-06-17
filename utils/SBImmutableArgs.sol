// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "clones-with-immutable-args/Clone.sol";
import "../src/interfaces/ICBBSlipFactory.sol";
import "../src/interfaces/IConvertibleBondBox.sol";
import "./ISBImmutableArgs.sol";

/**
 * @notice Defines the immutable arguments for a CBB
 * @dev using the clones-with-immutable-args library
 * we fetch args from the code section
 */
contract SBImmutableArgs is Clone, ISBImmutableArgs {
    /**
     * @inheritdoc ISBImmutableArgs
     */

    function slipFactory() external pure returns (ICBBSlipFactory) {
        return ICBBSlipFactory(_getArgAddress(0));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function convertibleBondBox() external pure returns (IConvertibleBondBox) {
        return IConvertibleBondBox(_getArgAddress(20));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function initialPrice() external pure returns (uint256) {
        return _getArgUint256(40);
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function stableToken() external pure returns (IERC20) {
        return IERC20(_getArgAddress(72));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function safeTranche() external pure returns (ITranche) {
        return ITranche(_getArgAddress(92));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function safeSlipAddress() external pure returns (address) {
        return (_getArgAddress(112));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function safeRatio() external pure returns (uint256) {
        return _getArgUint256(132);
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function riskTranche() external pure returns (ITranche) {
        return ITranche(_getArgAddress(164));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function riskSlipAddress() external pure returns (address) {
        return (_getArgAddress(184));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function riskRatio() external pure returns (uint256) {
        return _getArgUint256(204);
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function priceGranularity() external pure returns (uint256) {
        return _getArgUint256(236);
    }
}
