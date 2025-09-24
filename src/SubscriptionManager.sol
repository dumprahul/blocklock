// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "./utils/Ownable.sol";
import {BlocklockManager} from "./BlocklockManager.sol";
import {MusicStore} from "./MusicStore.sol";
import {TypesLib} from "blocklock-solidity/src/libraries/TypesLib.sol";

/// @title SubscriptionManager
/// @notice Manages subscriptions for fans to access releases
contract SubscriptionManager is Ownable {
    event Subscribed(address indexed fan, uint256 pricePaid);
    event Unsubscribed(address indexed fan);
    event TimelockRequested(address indexed fan, uint256 requestId, uint256 priceForwarded);
    event AlbumPlanSet(uint256 indexed albumId, uint256 priceWei);
    event AlbumSubscribed(address indexed fan, uint256 indexed albumId, uint256 pricePaid);

    mapping(address => bool) public isSubscriber; // global legacy toggle
    uint256 public subscribePriceWei; // legacy/global price
    BlocklockManager public blocklockManager;
    MusicStore public musicStore;

    // Per-album plans and subscriptions
    mapping(uint256 => uint256) public albumPriceWei; // albumId -> price
    mapping(address => mapping(uint256 => bool)) public isAlbumSubscriber; // fan -> albumId -> subscribed

    constructor(uint256 priceWei) {
        subscribePriceWei = priceWei;
    }

    function setBlocklockManager(address payable manager) external onlyOwner {
        blocklockManager = BlocklockManager(manager);
    }

    function setMusicStore(address store) external onlyOwner {
        musicStore = MusicStore(store);
    }

    function setPrice(uint256 priceWei) external onlyOwner {
        subscribePriceWei = priceWei;
    }

    function subscribe() external payable {
        require(!isSubscriber[msg.sender], "Already subscribed");
        require(msg.value >= subscribePriceWei, "Insufficient payment");
        isSubscriber[msg.sender] = true;
        emit Subscribed(msg.sender, msg.value);
        // Excess left in contract for owner to withdraw
    }

    function setAlbumPlan(uint256 albumId, uint256 priceWei) external onlyOwner {
        albumPriceWei[albumId] = priceWei;
        emit AlbumPlanSet(albumId, priceWei);
    }

    function subscribeAlbum(uint256 albumId) external payable {
        require(!isAlbumSubscriber[msg.sender][albumId], "Already subscribed to album");
        uint256 price = albumPriceWei[albumId];
        require(price > 0, "Album not configured");
        require(msg.value >= price, "Insufficient payment");
        isAlbumSubscriber[msg.sender][albumId] = true;
        emit AlbumSubscribed(msg.sender, albumId, msg.value);
    }

    /// @notice Single-call album creation for artists
    /// @param albumId Album identifier
    /// @param priceWei Subscription price for the album
    /// @param condition Encoded Blocklock condition
    /// @param iv 12-byte IV for AES-GCM (media)
    /// @param tag 16-byte tag for AES-GCM (media)
    /// @param blocklockCipher Blocklock ciphertext struct for timelock decrypt
    function createAlbumWithConfig(
        uint256 albumId,
        uint256 priceWei,
        bytes calldata condition,
        bytes12 iv,
        bytes16 tag,
        TypesLib.Ciphertext calldata blocklockCipher
    ) external onlyOwner {
        require(address(blocklockManager) != address(0), "Manager not set");
        require(address(musicStore) != address(0), "Store not set");
        albumPriceWei[albumId] = priceWei;
        emit AlbumPlanSet(albumId, priceWei);
        musicStore.storeAlbum(albumId,blocklockCipher,bytes.concat(iv), bytes.concat(tag));
        blocklockManager.setAlbumConfig(albumId, condition, blocklockCipher);
    }

    /// @notice Subscribe to album and auto-create timelock using artist-configured album condition/cipher
    /// @param albumId Album identifier configured in BlocklockManager
    /// @param callbackGasLimit Gas limit for callback
    function subscribeAlbumWithTimelock(
        uint256 albumId,
        uint32 callbackGasLimit
    ) external payable {
        require(address(blocklockManager) != address(0), "Manager not set");
        require(!isAlbumSubscriber[msg.sender][albumId], "Already subscribed to album");
        uint256 price = albumPriceWei[albumId];
        require(price > 0, "Album not configured");
        require(msg.value >= price, "Insufficient payment");

        uint256 forwardAmount = msg.value - price;
        isAlbumSubscriber[msg.sender][albumId] = true;
        emit AlbumSubscribed(msg.sender, albumId, msg.value);

        (uint256 requestId, uint256 _price) = blocklockManager.createTimelockForFanAlbum{value: forwardAmount}(
            msg.sender,
            albumId,
            callbackGasLimit
        );
        emit TimelockRequested(msg.sender, requestId, forwardAmount);
    }

    function unsubscribe() external {
        require(isSubscriber[msg.sender], "Not subscribed");
        isSubscriber[msg.sender] = false;
        emit Unsubscribed(msg.sender);
    }

    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        to.transfer(amount);
    }
}
