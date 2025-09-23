// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TypesLib} from "blocklock-solidity/src/libraries/TypesLib.sol";
import {AbstractBlocklockReceiver} from "blocklock-solidity/src/AbstractBlocklockReceiver.sol";

contract MyBlocklockReceiver is AbstractBlocklockReceiver {
    uint256 public requestId;
    TypesLib.Ciphertext public encryptedValue;
    uint256 public decryptedValue;

    constructor(address blocklockSender) AbstractBlocklockReceiver(blocklockSender) {}

    function createTimelockRequestWithDirectFunding(
        uint32 callbackGasLimit,
        bytes calldata condition,
        TypesLib.Ciphertext calldata encryptedData
    ) external payable returns (uint256, uint256) {
        // create timelock request
        (uint256 _requestId, uint256 requestPrice) =
            _requestBlocklockPayInNative(callbackGasLimit, condition, encryptedData);
        // store request id
        requestId = _requestId;
        // store Ciphertext
        encryptedValue = encryptedData;
        return (requestId, requestPrice);
    }

    function _onBlocklockReceived(uint256 _requestId, bytes calldata decryptionKey) internal override {
        require(requestId == _requestId, "Invalid request id.");
        // decrypt stored Ciphertext with decryption key
        decryptedValue = abi.decode(_decrypt(encryptedValue, decryptionKey), (uint256));
        // Placeholder for builders to add any logic to consume the decrypted data in smart contract.
    }
}