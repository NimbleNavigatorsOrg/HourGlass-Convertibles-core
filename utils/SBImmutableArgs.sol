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

    function slipFactory() public pure returns (ICBBSlipFactory) {
        return ICBBSlipFactory(_getArgAddress(0));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function convertibleBondBox() public pure returns (IConvertibleBondBox) {
        return IConvertibleBondBox(_getArgAddress(20));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function initialPrice() public pure returns (uint256) {
        return _getArgUint256(40);
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function stableToken() public pure returns (IERC20) {
        return IERC20(_getArgAddress(72));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function safeTranche() public pure returns (ITranche) {
        return ITranche(_getArgAddress(92));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function safeSlipAddress() public pure returns (address) {
        return (_getArgAddress(112));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function safeRatio() public pure returns (uint256) {
        return _getArgUint256(132);
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function riskTranche() public pure returns (ITranche) {
        return ITranche(_getArgAddress(164));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function riskSlipAddress() public pure returns (address) {
        return (_getArgAddress(184));
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function riskRatio() public pure returns (uint256) {
        return _getArgUint256(204);
    }

    /**
     * @inheritdoc ISBImmutableArgs
     */

    function priceGranularity() public pure returns (uint256) {
        return _getArgUint256(236);
    }
}
