// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "./utils/Ownable.sol";
import {BlocklockManager} from "./BlocklockManager.sol";
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

    // Per-album plans and subscriptions
    mapping(uint256 => uint256) public albumPriceWei; // albumId -> price
    mapping(address => mapping(uint256 => bool)) public isAlbumSubscriber; // fan -> albumId -> subscribed

    constructor(uint256 priceWei) {
        subscribePriceWei = priceWei;
    }

    function setBlocklockManager(address payable manager) external onlyOwner {
        blocklockManager = BlocklockManager(manager);
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

    /// @notice Subscribe and immediately create a Blocklock timelock for the fan
    /// @dev msg.value must cover subscription price + Blocklock callback funding
    /// @param condition Encoded Blocklock condition (e.g., target block height)
    /// @param cipher Fan-specific Blocklock ciphertext
    /// @param callbackGasLimit Gas limit for Blocklock callback
    function subscribeWithTimelock(
        bytes calldata condition,
        TypesLib.Ciphertext calldata cipher,
        uint32 callbackGasLimit
    ) external payable {
        require(address(blocklockManager) != address(0), "Manager not set");
        require(!isSubscriber[msg.sender], "Already subscribed");
        require(msg.value >= subscribePriceWei, "Insufficient payment");

        uint256 forwardAmount = msg.value - subscribePriceWei;
        isSubscriber[msg.sender] = true;
        emit Subscribed(msg.sender, msg.value);

        (uint256 requestId, uint256 price) = blocklockManager.createTimelockForFan{value: forwardAmount}(
            msg.sender,
            cipher,
            condition,
            callbackGasLimit
        );
        emit TimelockRequested(msg.sender, requestId, forwardAmount);
        // Note: If forwardAmount < price, BlocklockManager call will revert
    }

    /// @notice Subscribe to album and auto-create timelock in one call
    /// @param albumId Album identifier whose plan must be set
    /// @param condition Encoded Blocklock condition
    /// @param cipher Fan-specific Blocklock ciphertext (album-specific if needed)
    /// @param callbackGasLimit Gas limit for callback
    function subscribeAlbumWithTimelock(
        uint256 albumId,
        bytes calldata condition,
        TypesLib.Ciphertext calldata cipher,
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

        (uint256 requestId, uint256 _price) = blocklockManager.createTimelockForFan{value: forwardAmount}(
            msg.sender,
            cipher,
            condition,
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
