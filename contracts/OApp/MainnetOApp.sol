// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OApp, MessagingFee, Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {Portal} from "../mainnet-bridge/Portal.sol";

enum MessageType {
    DEPOSIT,
    REPORT_YIELD,
    WITHDRAWAL
}

contract MainnetOApp is OApp {
    using OptionsBuilder for bytes;

    Portal public portal;

    string public data = "Nothing received yet.";
    uint32 immutable DSTEID = 40138;

    error CallerIsNotPortal();

    modifier onlyPortal() {
        if (msg.sender != address(portal)) {
            revert CallerIsNotPortal();
        }
        _;
    }

    constructor(address _endpoint, address _delegate) OApp(_endpoint, _delegate) Ownable(_delegate) {}

    function setPortalAddress(Portal _portal) external onlyOwner {
        require(address(_portal) != address(0), "MainnetOApp: Portal address cannot be the zero address");
        require(address(portal) == address(0), "MainnetOApp: Portal address already set");
        portal = _portal;
    }

    /// @notice Creates options for executing `lzReceive` on the destination chain.
    /// @param _gas The gas amount for the `lzReceive` execution.
    /// @param _value The msg.value for the `lzReceive` execution.
    /// @return bytes-encoded option set for `lzReceive` executor.
    function createLzReceiveOption(uint128 _gas, uint128 _value) public pure returns (bytes memory) {
        return OptionsBuilder.newOptions().addExecutorLzReceiveOption(_gas, _value);
    }

    function sendMessage(MessageType _messageType, address _from, address _to, uint256 _value)
        public
        payable
        onlyPortal
        returns (MessagingReceipt memory receipt)
    {
        bytes memory _payload = abi.encode(_messageType, _from, _to, _value);
        receipt =
            _lzSend(DSTEID, _payload, createLzReceiveOption(300000, 0), MessagingFee(msg.value, 0), payable(msg.sender));
    }

    /**
     * @notice Quotes the gas needed to pay for the full omnichain transaction in native gas or ZRO token.
     * @param _messageType The message type.
     * @param _to The address to send the message to.
     * @param _value The value to send with the message.
     * @return fee A `MessagingFee` struct containing the calculated gas fee in either the native token or ZRO token.
     */
    function quote(MessageType _messageType, address _from, address _to, uint256 _value)
        public
        view
        returns (MessagingFee memory fee)
    {
        bytes memory payload = abi.encode(_messageType, _from, _to, _value);
        fee = _quote(DSTEID, payload, createLzReceiveOption(300000, 0), false);
    }

    /**
     * @dev Internal function override to handle incoming messages from another chain.
     * @dev _origin A struct containing information about the message sender.
     * @dev _guid A unique global packet identifier for the message.
     * @param payload The encoded message payload being received.
     *
     * @dev The following params are unused in the current implementation of the OApp.
     * @dev _executor The address of the Executor responsible for processing the message.
     * @dev _extraData Arbitrary data appended by the Executor to the message.
     *
     * Decodes the received payload and processes it as per the business logic defined in the function.
     */
    function _lzReceive(
        Origin calldata, /*_origin*/
        bytes32, /*_guid*/
        bytes calldata payload,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) internal override {
        (MessageType messageType, address from, address to, uint256 value) =
            abi.decode(payload, (MessageType, address, address, uint256));
        if (messageType == MessageType.WITHDRAWAL) {
            portal.proveWithdrawalTransaction(from, to, value);
        }
        data = "Withdrawal received";
    }
}
