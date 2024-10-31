// SPDX-License-Identifier: BSL 1.1 - Copyright 2024 MetaLayer Labs Ltd.
pragma solidity ^0.8.15;

import {YieldManager} from "./YieldManager.sol";
import {Portal} from "./Portal.sol";
import {Semver} from "../universal/Semver.sol";

/// @custom:proxied
/// @title ETHYieldManager
/// @notice Coordinates the accounting, asset management and
///         yield reporting from ETH yield providers.
contract ETHYieldManager is YieldManager, Semver {
    error CallerIsNotPortal();
    error NegativeYield();

    constructor() YieldManager(address(0)) Semver(1, 0, 0) {
        initialize(Portal(payable(address(0))), address(0));
    }

    receive() external payable {}

    /// @notice initializer
    /// @param _portal Address of the Portal.
    /// @param _owner  Address of the YieldManager owner.
    function initialize(Portal _portal, address _owner) public initializer {
        __YieldManager_init(_portal, _owner);
    }

    /// @notice Reports yield to L2 through the portal
    /// @param yield The yield amount to report
    /// @dev Converts negative yields to positive values for L2 processing
    function _reportYield(int256 yield) internal override {
        if (yield <= 0) return;
        
        // Safe conversion since we checked yield > 0
        uint256 yieldAmount = uint256(yield);
        
        // Report yield to L2
        portal.depositTransaction{value: 0}(
            address(0),  // recipient
            yieldAmount, // value
            false       // isCreation
        );
    }

    /// @notice Returns the ETH balance of this contract
    /// @return The contract's ETH balance
    function tokenBalance() public view override returns (uint256) {
        return address(this).balance;
    }

    /// @notice Wrapper for WithdrawalQueue._requestWithdrawal
    function requestWithdrawal(uint256 amount) external returns (uint256) {
        if (msg.sender != address(portal)) {
            revert CallerIsNotPortal();
        }
        return _requestWithdrawal(address(portal), amount);
    }
}
