// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "clones-with-immutable-args/Clone.sol";
import "../src/interfaces/IConvertibleBondBox.sol";
import "./IIBOImmutableArgs.sol";

/**
 * @notice Defines the immutable arguments for a CBB
 * @dev using the clones-with-immutable-args library
 * we fetch args from the code section
 */
contract IBOImmutableArgs is Clone, IIBOImmutableArgs {
    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function buySlip() public pure returns (ISlip) {
        return ISlip(_getArgAddress(0));
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function borrowSlip() public pure returns (ISlip) {
        return ISlip(_getArgAddress(20));
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function convertibleBondBox() public pure returns (IConvertibleBondBox) {
        return IConvertibleBondBox(_getArgAddress(40));
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function initialPrice() public pure returns (uint256) {
        return _getArgUint256(60);
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function stableToken() public pure returns (IERC20) {
        return IERC20(_getArgAddress(92));
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function safeTranche() public pure returns (ITranche) {
        return ITranche(_getArgAddress(112));
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function bondSlipAddress() public pure returns (address) {
        return (_getArgAddress(132));
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function safeRatio() public pure returns (uint256) {
        return _getArgUint256(152);
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function riskTranche() public pure returns (ITranche) {
        return ITranche(_getArgAddress(184));
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function issuerSlipAddress() public pure returns (address) {
        return (_getArgAddress(204));
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function riskRatio() public pure returns (uint256) {
        return _getArgUint256(224);
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function priceGranularity() public pure returns (uint256) {
        return _getArgUint256(256);
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function trancheDecimals() public pure override returns (uint256) {
        return _getArgUint256(288);
    }

    /**
     * @inheritdoc IIBOImmutableArgs
     */

    function stableDecimals() public pure override returns (uint256) {
        return _getArgUint256(320);
    }
}
