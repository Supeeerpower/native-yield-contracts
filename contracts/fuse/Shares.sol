// SPDX-License-Identifier: BSL 1.1 - Copyright 2024 MetaLayer Labs Ltd.
pragma solidity ^0.8.15;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {YieldMode} from "./Configure.sol";

/**
 * @title SharesBase
 * @notice Base contract for tracking share rebasing and yield reporting
 * @dev Implements core yield distribution logic
 */
abstract contract SharesBase is Initializable {
    /// @notice Approved yield reporter.
    address public immutable REPORTER;

    /// @notice Share price. This value can only increase.
    uint256 public price;

    /// @notice Accumulated yield that has not been distributed
    ///         to the share price.
    uint256 public pending;

    // Events
    event NewPrice(uint256 price);

    // Custom errors
    error InvalidReporter();
    error DistributeFailed(uint256 count, uint256 pending);
    error PriceIsInitialized();
    error ZeroAddress();

    uint256[48] private __gap;

    modifier onlyReporter() {
        if (msg.sender != REPORTER) revert InvalidReporter();
        _;
    }

    constructor(address _reporter) {
        if (_reporter == address(0)) revert ZeroAddress();
        REPORTER = _reporter;
    }

    /// @notice Initializer.
    /// @param _price Initial share price.
    // solhint-disable-next-line func-name-mixedcase
    function __SharesBase_init(uint256 _price) internal onlyInitializing {
        if (price != 0) {
            revert PriceIsInitialized();
        }
        price = _price;
    }
    /// @notice Get the total number of shares. Needs to be
    ///         overridden by the child contract.
    /// @return Total number of shares.

    function count() public view virtual returns (uint256);

    /// @notice Report a yield event and update the share price.
    /// @param value Amount of new yield
    function addValue(uint256 value) external onlyReporter {
        _addValue(value);
    }

    function _addValue(uint256 value) internal virtual {
        if (msg.sender != REPORTER) {
            revert InvalidReporter();
        }

        if (value > 0) {
            pending += value;
        }

        _tryDistributePending();
    }

    /// @notice Attempt to distribute pending yields if there
    ///         are sufficient pending yields to increase the
    ///         share price.
    /// @return True if there were sufficient pending yields to
    ///         increase the share price.
    function _tryDistributePending() internal returns (bool) {
        if (pending < count() || count() == 0) {
            return false;
        }

        price += pending / count();
        pending = pending % count();

        emit NewPrice(price);

        return true;
    }
}
