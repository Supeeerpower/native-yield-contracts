// SPDX-License-Identifier: BSL 1.1 - Copyright 2024 MetaLayer Labs Ltd.
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ERC20PermitUpgradeable
 * @dev Implementation of ERC20 Permit extension (EIP-2612) allowing approvals via signatures
 * @custom:security-contact security@metalayer.xyz
 */
abstract contract ERC20PermitUpgradeable is Initializable, IERC20PermitUpgradeable, EIP712Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // State variables
    mapping(address => CountersUpgradeable.Counter) private _nonces;

    // Constants
    /// @dev TypeHash for the permit function's parameters
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @dev Reserved storage slot for backwards compatibility
     * @custom:oz-renamed-from _PERMIT_TYPEHASH
     */
    bytes32 private _PERMIT_TYPEHASH_DEPRECATED_SLOT;

    // Custom errors for gas optimization
    error PermitExpired();
    error InvalidSignature();

    // Events
    event PermitUsed(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Initializes the EIP712 domain separator
     * @param name Token name for EIP712 domain
     */
    function __ERC20Permit_init(string memory name) internal onlyInitializing {
        __EIP712_init_unchained(name, "1");
    }

    function __ERC20Permit_init_unchained(string memory) internal onlyInitializing {}

    /**
     * @notice Approves spending via signature
     * @param owner Token owner address
     * @param spender Spender address
     * @param value Amount to approve
     * @param deadline Signature expiration timestamp
     * @param v Signature parameter v
     * @param r Signature parameter r
     * @param s Signature parameter s
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
        override
    {
        // Check deadline
        if (block.timestamp > deadline) revert PermitExpired();

        // Create and hash the permit message
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        // Verify signature
        address signer = ECDSAUpgradeable.recover(hash, v, r, s);
        if (signer != owner) revert InvalidSignature();

        // Approve the spending
        _approve(owner, spender, value);

        emit PermitUsed(owner, spender, value);
    }

    /**
     * @notice Gets the current nonce for an address
     * @param owner Address to get nonce for
     * @return Current nonce value
     */
    function nonces(address owner) public view virtual override returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @notice Gets the domain separator for EIP712 signing
     * @return Domain separator value
     */
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev Consumes a nonce for message signing
     * @param owner Address whose nonce to consume
     * @return current The current nonce before increment
     */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        CountersUpgradeable.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    /**
     * @dev Virtual approve function to be implemented by inheriting contract
     * @param owner Token owner
     * @param spender Approved spender
     * @param amount Approved amount
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual;

    /**
     * @dev Reserved storage gap for future upgrades
     */
    uint256[49] private __gap;
}
