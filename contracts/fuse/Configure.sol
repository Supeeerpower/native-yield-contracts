// SPDX-License-Identifier: BSL 1.1 - Copyright 2024 MetaLayer Labs Ltd.
pragma solidity ^0.8.15;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Semver} from "../universal/Semver.sol";

/**
 * @title Configure
 * @notice Manages yield configurations and governance for contracts
 * @dev Implements yield mode management and authorization controls
 */
enum YieldMode {
    AUTOMATIC,
    VOID,
    CLAIMABLE
}

interface IYield {
    function configure(address contractAddress, uint8 flags) external returns (uint256);
    function claim(address contractAddress, address recipientOfYield, uint256 desiredAmount)
        external
        returns (uint256);
    function getClaimableAmount(address contractAddress) external view returns (uint256);
    function getConfiguration(address contractAddress) external view returns (uint8);
}

interface IConfigure {
    // configure
    function configureContract(address contractAddress, YieldMode _yield, address governor) external;
    function configure(YieldMode _yield, address governor) external;

    // base configuration options
    function configureClaimableYield() external;
    function configureClaimableYieldOnBehalf(address contractAddress) external;
    function configureAutomaticYield() external;
    function configureAutomaticYieldOnBehalf(address contractAddress) external;
    function configureVoidYield() external;
    function configureVoidYieldOnBehalf(address contractAddress) external;
    function configureGovernor(address _governor) external;
    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external;

    // claim yield
    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external returns (uint256);
    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256);

    // read functions
    function readClaimableYield(address contractAddress) external view returns (uint256);
    function readYieldConfiguration(address contractAddress) external view returns (uint8);
}

contract Configure is IConfigure, Initializable, Semver {
    /// @notice Address of the yield contract
    address public immutable YIELD_CONTRACT;

    /// @notice Mapping of contract addresses to their governors
    mapping(address => address) public governorMap;

    // Events for better tracking
    event GovernorUpdated(address indexed contractAddress, address indexed newGovernor);
    event YieldModeUpdated(address indexed contractAddress, YieldMode mode);
    event YieldClaimed(address indexed contractAddress, address indexed recipient, uint256 amount);

    constructor(address _yieldContract) Semver(1, 0, 0) {
        require(_yieldContract != address(0), "Invalid yield contract");
        YIELD_CONTRACT = _yieldContract;
        _disableInitializers();
    }

    function initialize() public initializer {}

    function isGovernor(address contractAddress) public view returns (bool) {
        return msg.sender == governorMap[contractAddress];
    }

    function governorNotSet(address contractAddress) internal view returns (bool) {
        return governorMap[contractAddress] == address(0);
    }

    function isAuthorized(address contractAddress) public view returns (bool) {
        return isGovernor(contractAddress) || (governorNotSet(contractAddress) && msg.sender == contractAddress);
    }

    function configure(YieldMode _yieldMode, address governor) external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        governorMap[msg.sender] = governor;
        IYield(YIELD_CONTRACT).configure(msg.sender, uint8(_yieldMode));
        emit GovernorUpdated(msg.sender, governor);
        emit YieldModeUpdated(msg.sender, _yieldMode);
    }

    function configureContract(address contractAddress, YieldMode _yieldMode, address _newGovernor) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        governorMap[contractAddress] = _newGovernor;
        IYield(YIELD_CONTRACT).configure(contractAddress, uint8(_yieldMode));
        emit GovernorUpdated(contractAddress, _newGovernor);
        emit YieldModeUpdated(contractAddress, _yieldMode);
    }

    function configureClaimableYield() external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        IYield(YIELD_CONTRACT).configure(msg.sender, uint8(YieldMode.CLAIMABLE));
        emit YieldModeUpdated(msg.sender, YieldMode.CLAIMABLE);
    }

    function configureClaimableYieldOnBehalf(address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        IYield(YIELD_CONTRACT).configure(contractAddress, uint8(YieldMode.CLAIMABLE));
        emit YieldModeUpdated(contractAddress, YieldMode.CLAIMABLE);
    }

    function configureAutomaticYield() external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        IYield(YIELD_CONTRACT).configure(msg.sender, uint8(YieldMode.AUTOMATIC));
        emit YieldModeUpdated(msg.sender, YieldMode.AUTOMATIC);
    }

    function configureAutomaticYieldOnBehalf(address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        IYield(YIELD_CONTRACT).configure(contractAddress, uint8(YieldMode.AUTOMATIC));
        emit YieldModeUpdated(contractAddress, YieldMode.AUTOMATIC);
    }

    function configureVoidYield() external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        IYield(YIELD_CONTRACT).configure(msg.sender, uint8(YieldMode.VOID));
        emit YieldModeUpdated(msg.sender, YieldMode.VOID);
    }

    function configureVoidYieldOnBehalf(address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        IYield(YIELD_CONTRACT).configure(contractAddress, uint8(YieldMode.VOID));
        emit YieldModeUpdated(contractAddress, YieldMode.VOID);
    }

    function configureGovernor(address _governor) external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        governorMap[msg.sender] = _governor;
        emit GovernorUpdated(msg.sender, _governor);
    }

    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        governorMap[contractAddress] = _newGovernor;
        emit GovernorUpdated(contractAddress, _newGovernor);
    }

    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external returns (uint256) {
        require(isAuthorized(contractAddress), "Not authorized to claim yield");
        require(recipientOfYield != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");

        uint256 claimed = IYield(YIELD_CONTRACT).claim(contractAddress, recipientOfYield, amount);
        emit YieldClaimed(contractAddress, recipientOfYield, claimed);
        return claimed;
    }

    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256) {
        require(isAuthorized(contractAddress), "Not authorized to claim yield");
        require(recipientOfYield != address(0), "Invalid recipient");

        uint256 amount = IYield(YIELD_CONTRACT).getClaimableAmount(contractAddress);
        require(amount > 0, "No yield to claim");

        uint256 claimed = IYield(YIELD_CONTRACT).claim(contractAddress, recipientOfYield, amount);
        emit YieldClaimed(contractAddress, recipientOfYield, claimed);
        return claimed;
    }

    function readClaimableYield(address contractAddress) public view returns (uint256) {
        return IYield(YIELD_CONTRACT).getClaimableAmount(contractAddress);
    }

    function readYieldConfiguration(address contractAddress) public view returns (uint8) {
        return IYield(YIELD_CONTRACT).getConfiguration(contractAddress);
    }
}
