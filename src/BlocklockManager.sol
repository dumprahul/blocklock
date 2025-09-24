// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TypesLib} from "blocklock-solidity/src/libraries/TypesLib.sol";
import {AbstractBlocklockReceiver} from "blocklock-solidity/src/AbstractBlocklockReceiver.sol";
import {SubscriptionManager} from "./SubscriptionManager.sol";

/// @title BlocklockManager
/// @notice Stores fan-specific timelocked ciphertexts and handles Blocklock callbacks
contract BlocklockManager is AbstractBlocklockReceiver {
    address public admin;
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }
    struct FanLock {
        TypesLib.Ciphertext cipher; // original Blocklock ciphertext
        bytes decryptedPayload; // set after unlock
        bool unlocked;
    }

    event FanTimelockCreated(address indexed fan, uint256 indexed requestId);
    event FanKeyUnlocked(address indexed fan);
    event AlbumConfigSet(uint256 indexed albumId);

    SubscriptionManager public subscriptionManager;

    // album-aware: fan -> albumId -> lock
    mapping(address => mapping(uint256 => FanLock)) public fanAlbumLocks;
    mapping(uint256 => address) private requestIdToFan;
    mapping(uint256 => uint256) private requestIdToAlbumId;

    // Per-album stored Blocklock config (artist-defined)
    struct AlbumConfig {
        bytes condition;
        TypesLib.Ciphertext cipher;
        bool exists;
    }
    mapping(uint256 => AlbumConfig) public albumConfigs;

    constructor(address blocklockSender, address subscriptionManagerAddress)
        AbstractBlocklockReceiver(blocklockSender)
    {
        admin = msg.sender;
        subscriptionManager = SubscriptionManager(subscriptionManagerAddress);
    }

    function setSubscriptionManager(address subscriptionManagerAddress) external onlyAdmin {
        subscriptionManager = SubscriptionManager(subscriptionManagerAddress);
    }

    function setAlbumConfig(
        uint256 albumId,
        bytes calldata condition,
        TypesLib.Ciphertext calldata cipher
    ) external onlyAdmin {
        albumConfigs[albumId] = AlbumConfig({condition: condition, cipher: cipher, exists: true});
        emit AlbumConfigSet(albumId);
    }

    // raw setter removed in favor of setAlbumConfig with full Ciphertext

    function createTimelockForFan(
        address fan,
        TypesLib.Ciphertext calldata cipher,
        bytes calldata condition,
        uint32 callbackGasLimit
    ) public payable onlyAdmin returns (uint256 requestId, uint256 price) {
        require(subscriptionManager.isSubscriber(fan), "Not a subscriber");
        (uint256 _requestId, uint256 _price) = _requestBlocklockPayInNative(callbackGasLimit, condition, cipher);
        fanAlbumLocks[fan][0] = FanLock({cipher: cipher, decryptedPayload: bytes(""), unlocked: false});
        requestIdToFan[_requestId] = fan;
        requestIdToAlbumId[_requestId] = 0;
        emit FanTimelockCreated(fan, _requestId);
        return (_requestId, _price);
    }

    function createTimelockForFanAlbum(
        address fan,
        uint256 albumId,
        uint32 callbackGasLimit
    ) external payable onlyAdmin returns (uint256 requestId, uint256 price) {
        require(subscriptionManager.isAlbumSubscriber(fan, albumId), "Not subscribed to album");
        AlbumConfig storage cfg = albumConfigs[albumId];
        require(cfg.exists, "Album config missing");
        // Call external helper to satisfy calldata requirements
        (uint256 _requestId, uint256 _price) = this._createTimelockForFanAlbumFromConfig{
            value: msg.value
        }(fan, albumId, cfg.condition, cfg.cipher, callbackGasLimit);
        return (_requestId, _price);
    }

    // External helper restricted to self-calls to pass calldata into _requestBlocklockPayInNative
    function _createTimelockForFanAlbumFromConfig(
        address fan,
        uint256 albumId,
        bytes calldata condition,
        TypesLib.Ciphertext calldata cipher,
        uint32 callbackGasLimit
    ) external payable returns (uint256 requestId, uint256 price) {
        require(msg.sender == address(this), "Internal only");
        (uint256 _requestId, uint256 _price) = _requestBlocklockPayInNative(callbackGasLimit, condition, cipher);
        fanAlbumLocks[fan][albumId] = FanLock({cipher: cipher, decryptedPayload: bytes(""), unlocked: false});
        requestIdToFan[_requestId] = fan;
        requestIdToAlbumId[_requestId] = albumId;
        emit FanTimelockCreated(fan, _requestId);
        return (_requestId, _price);
    }

    function _onBlocklockReceived(uint256 _requestId, bytes calldata decryptionKey) internal override {
        address fan = requestIdToFan[_requestId];
        require(fan != address(0), "Unknown requestId");
        uint256 albumId = requestIdToAlbumId[_requestId];
        FanLock storage lockRef = fanAlbumLocks[fan][albumId];
        require(!lockRef.unlocked, "Already unlocked");

        // Decrypt the ciphertext; store decrypted bytes for fan-side ECIES flow
        bytes memory decrypted = _decrypt(lockRef.cipher, decryptionKey);
        lockRef.decryptedPayload = decrypted;
        lockRef.unlocked = true;
        emit FanKeyUnlocked(fan);
    }
}


