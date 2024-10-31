// SPDX-License-Identifier: BSL 1.1 - Copyright 2024 MetaLayer Labs Ltd.
pragma solidity ^0.8.15;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ISemver} from "../universal/ISemver.sol";
import {ETHYieldManager} from "../mainnet-bridge/ETHYieldManager.sol";
import {MainnetOApp, MessageType} from "../OApp/MainnetOApp.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

/// @title Portal
/// @notice The Portal is a low-level contract responsible for passing messages between L1
///         and L2. Messages sent directly to the Portal have no form of replayability.
///         Users are encouraged to use the L1CrossDomainMessenger for a higher-level interface.
/// @custom:proxied
contract Portal is Initializable, ISemver {
    /// @notice Represents a proven withdrawal.
    struct ProvenWithdrawal {
        address sender;
        address target;
        uint256 value;
        bool claimed;
    }

    // Constants
    uint256 private constant DEPOSIT_VERSION = 0;
    uint64 private constant RECEIVE_DEFAULT_GAS_LIMIT = 100_000;
    uint64 private constant SEND_DEFAULT_GAS_LIMIT = 100_000;

    // State variables
    uint256 public totalProvenWithdrawal;
    mapping(uint256 => ProvenWithdrawal) public provenWithdrawals;
    bool public paused;
    address public guardian;
    ETHYieldManager public yieldManager;

    MainnetOApp public mainnetOApp;

    // Events
    event TransactionDeposited(address indexed from, address indexed to, uint256 indexed version, bytes opaqueData);
    event WithdrawalProven(uint256 requestId, address indexed sender, address indexed target, uint256 value);
    event WithdrawalFinalized(uint256 requestId, uint256 hintId, bool success);
    event Paused(address account);
    event Unpaused(address account);

    // Errors
    error Unauthorized();
    error AlreadyInitialized();
    error InvalidTarget();
    error InvalidCaller();
    error WithdrawalAlreadyClaimed();
    error TransferFailed();
    error IsPaused();
    error CallerIsNotMainnetOApp();

    /// @notice Reverts when paused
    modifier whenNotPaused() {
        if (paused) revert IsPaused();
        _;
    }

    /// @notice Only guardian can call
    modifier onlyGuardian() {
        if (msg.sender != guardian) revert Unauthorized();
        _;
    }

    modifier onlyMainnetOApp() {
        if (msg.sender != address(mainnetOApp)) revert CallerIsNotMainnetOApp();
        _;
    }

    /// @notice Semantic version
    /// @custom:semver 1.10.0
    string public constant version = "1.10.0";

    constructor() {
        initialize({
            _guardian: address(0),
            _paused: true,
            _yieldManager: ETHYieldManager(payable(address(0))),
            _mainnetOApp: MainnetOApp(address(0))
        });
    }

    /// @notice Initializer
    function initialize(address _guardian, bool _paused, ETHYieldManager _yieldManager, MainnetOApp _mainnetOApp)
        public
        reinitializer(1)
    {
        guardian = _guardian;
        paused = _paused;
        yieldManager = _yieldManager;
        mainnetOApp = _mainnetOApp;
    }

    /// @notice Set the ETH yield manager
    function setETHYieldManager(ETHYieldManager _yieldManager) external onlyGuardian {
        require(address(_yieldManager) != address(0), "Portal: Yield manager cannot be the zero address");
        require(address(yieldManager) == address(0), "Portal: Yield manager already set");
        yieldManager = _yieldManager;
    }

    /// @notice Getter for the Guardian
    function GUARDIAN() external view returns (address) {
        return guardian;
    }

    /// @notice Pauses withdrawals
    function pause() external onlyGuardian {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpauses withdrawals
    function unpause() external onlyGuardian {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Accepts ETH deposits
    receive() external payable {
        if (msg.sender != address(yieldManager)) {
            depositTransaction(msg.sender, msg.value, false);
        }
    }

    /// @notice Proves a withdrawal transaction
    function proveWithdrawalTransaction(address _sender, address _target, uint256 _value)
        external
        onlyMainnetOApp
        whenNotPaused
        returns (uint256 requestId)
    {
        if (_target == address(this)) revert InvalidTarget();

        requestId = yieldManager.requestWithdrawal(_value);

        provenWithdrawals[requestId] =
            ProvenWithdrawal({sender: _sender, target: _target, value: _value, claimed: false});

        totalProvenWithdrawal++;

        emit WithdrawalProven(requestId, _sender, _target, _value);
    }

    /// @notice Finalizes a withdrawal transaction
    function finalizeWithdrawalTransaction(uint256 requestId, uint256 hintId) external whenNotPaused {
        ProvenWithdrawal storage withdrawal = provenWithdrawals[requestId];

        if (msg.sender != withdrawal.target) revert InvalidCaller();
        if (withdrawal.claimed) revert WithdrawalAlreadyClaimed();

        withdrawal.claimed = true;

        uint256 txValueWithDiscount;
        if (withdrawal.value > 0) {
            uint256 etherBalance = address(this).balance;
            yieldManager.claimWithdrawal(requestId, hintId);
            txValueWithDiscount = address(this).balance - etherBalance;
        }

        (bool success,) = payable(withdrawal.target).call{value: withdrawal.value}("");
        if (!success) revert TransferFailed();

        emit WithdrawalFinalized(requestId, hintId, success);
    }

    /// @notice Deposits ETH and data for L2 transactions or processes yield reports
    /// @param _to The recipient address on L2
    /// @param _value The amount of ETH to deposit
    /// @param _isCreation Whether this is a contract creation transaction
    /// @dev When called by ETHYieldManager, it only processes yield reports
    function depositTransaction(address _to, uint256 _value, bool _isCreation) public payable {
        // Validate regular deposit parameters
        if (_isCreation) {
            require(_to == address(0), "Portal: contract creation must send to address(0)");
        }
        // Handle deposits from ETHYieldManager separately
        if (msg.sender == address(yieldManager)) {
            _handleYieldManagerDeposit(_to, _value);
            return;
        }

        // Calculate fees and validate deposit amount
        MessagingFee memory fee = mainnetOApp.quote(MessageType.DEPOSIT, msg.sender, _to, _value);
        uint256 requiredValue = _value + fee.nativeFee;
        require(msg.value >= requiredValue, "Portal: insufficient funds");

        // Handle ETH deposit to yield manager if value is present
        if (_value > 0) {
            (bool success,) = payable(address(yieldManager)).call{value: _value}("");
            if (!success) revert TransferFailed();
        }

        // Prepare and emit deposit data
        bytes memory opaqueData = abi.encodePacked(msg.sender, _to, _value);
        emit TransactionDeposited(msg.sender, _to, DEPOSIT_VERSION, opaqueData);

        // Send message to L2
        mainnetOApp.sendMessage{value: fee.nativeFee}(MessageType.DEPOSIT, msg.sender, _to, _value);
    }

    /// @dev Handles deposits specifically from the ETHYieldManager
    function _handleYieldManagerDeposit(address _to, uint256 _value) private {
        require(_to == address(0), "Portal: ETHYieldManager must send to address(0)");
        MessagingFee memory fee = mainnetOApp.quote(MessageType.REPORT_YIELD, msg.sender, _to, _value);
        require(msg.value >= fee.nativeFee, "Portal: insufficient funds");
        mainnetOApp.sendMessage{value: fee.nativeFee}(MessageType.REPORT_YIELD, msg.sender, _to, _value);
    }
}
