// SPDX-License-Identifier: GPL-3.0-only
// Source https://github.com/ampleforth/token-geyser-v2/blob/main/contracts/Factory/InstanceRegistry.sol
pragma solidity ^0.8.4;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IInstanceRegistry {
    /* events */

    event InstanceAdded(address instance);
    event InstanceRemoved(address instance);

    /* view functions */

    function isInstance(address instance) external view returns (bool validity);

    function instanceCount() external view returns (uint256 count);

    function instanceAt(uint256 index) external view returns (address instance);
}

/// @title InstanceRegistry
/// @dev Security contact: dev-support@ampleforth.org
contract InstanceRegistry is IInstanceRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* storage */

    EnumerableSet.AddressSet private _instanceSet;

    /* view functions */

    function isInstance(address instance)
        external
        view
        override
        returns (bool validity)
    {
        return _instanceSet.contains(instance);
    }

    function instanceCount() external view override returns (uint256 count) {
        return _instanceSet.length();
    }

    function instanceAt(uint256 index)
        external
        view
        override
        returns (address instance)
    {
        return _instanceSet.at(index);
    }

    /* admin functions */

    function _register(address instance) internal {
        require(
            _instanceSet.add(instance),
            "InstanceRegistry: already registered"
        );
        emit InstanceAdded(instance);
    }

    function _deregister(address instance) internal {
        require(
            _instanceSet.remove(instance),
            "InstanceRegistry: not registered"
        );
        emit InstanceRemoved(instance);
    }
}
