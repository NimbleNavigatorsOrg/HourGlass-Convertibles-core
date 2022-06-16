// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./CBBSlip.sol";
import "../interfaces/ICBBSlipFactory.sol";

/**
 * @dev Factory for Iou minimal proxy contracts
 */
contract CBBSlipFactory is ICBBSlipFactory, Context {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    address public target;

    constructor(address _target) {
        target = _target;
    }

    /**
     * @inheritdoc ICBBSlipFactory
     */
    function createSlip(
        string memory name,
        string memory symbol,
        address _collateralToken
    ) external override returns (address) {
        address clone = Clones.clone(target);
        CBBSlip(clone).init(name, symbol, _msgSender(), _collateralToken);
        emit SlipCreated(clone);
        return clone;
    }
}