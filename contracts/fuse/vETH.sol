// SPDX-License-Identifier: BSL 1.1 - Copyright 2024 MetaLayer Labs Ltd.
pragma solidity ^0.8.15;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Semver} from "../universal/Semver.sol";
import {ERC20Rebasing} from "./ERC20Rebasing.sol";
import {IConfigure, YieldMode} from "./Configure.sol";
import {FuseOApp, MessageType} from "../OApp/FuseOApp.sol";

/**
 * @title vETH
 * @notice Rebasing ERC20 token with LayerZero integration
 * @dev Implements cross-chain token functionality with yield distribution
 */
contract vETH is ERC20Rebasing, Semver {
    /// @notice Address of the corresponding version of this token on the remote chain.
    address public immutable REMOTE_TOKEN;

    // Mutable state
    address public CONFIGURE;

    // Custom errors
    error CallerIsNotFrom();
    error InsufficientNativeFee();

    /// @custom:semver 1.0.0
    /// @param _reporter        Address of the Fuse Layerzero bridge.
    /// @param _remoteToken     Address of the corresponding L1 token.
    constructor(address _reporter, address _remoteToken) ERC20Rebasing(_reporter, 18) Semver(1, 0, 0) {
        REMOTE_TOKEN = _remoteToken;
        _disableInitializers();
    }

    /// @notice Initializer
    function initialize() public initializer {
        __ERC20Rebasing_init("vETH", "vETH", 1e9);
    }

    /// @custom:legacy
    /// @notice Legacy getter for REMOTE_TOKEN.
    function remoteToken() public view returns (address) {
        return REMOTE_TOKEN;
    }

    function setConfigure(address _configure) external {
        require(CONFIGURE == address(0), "Configure already set");
        require(_configure != address(0), "Configure is the zero address");
        CONFIGURE = _configure;
        IConfigure(CONFIGURE).configureContract(address(this), YieldMode.VOID, address(0xdead));
        /// don't set a governor
    }

    /// @notice Allows the StandardBridge on this network to mint tokens.
    /// @param _to     Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function mint(address _to, uint256 _amount) external virtual onlyReporter {
        if (_to == address(0)) {
            revert TransferToZeroAddress();
        }

        _deposit(_to, _amount);
        emit Transfer(address(0), _to, _amount);
    }

    /// @notice Allows the StandardBridge on this network to burn tokens.
    /// @param _from   Address to burn tokens from.
    /// @param _amount Amount of tokens to burn.
    function burn(address _from, address _to, uint256 _amount) external payable virtual {
        if (msg.sender != _from) {
            revert CallerIsNotFrom();
        }
        if (_from == address(0)) {
            revert TransferFromZeroAddress();
        }

        MessagingFee memory fee = FuseOApp(REPORTER).quote(MessageType.WITHDRAWAL, _from, _to, _amount);
        if (msg.value < fee.nativeFee) {
            revert InsufficientNativeFee();
        }

        _withdraw(_from, _amount);
        emit Transfer(_from, address(0), _amount);

        FuseOApp(REPORTER).sendMessage{value: msg.value}(MessageType.WITHDRAWAL, _from, _to, _amount);
    }

    /**
     * @dev The version parameter for the EIP712 domain.
     */
    function _EIP712Version() internal view override returns (string memory) {
        return version();
    }
}
