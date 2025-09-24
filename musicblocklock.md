Architecture of the contract to be -

Perfect! If you want **everything on-chain** — i.e., subscription, timelock, and per-user key handling entirely in smart contracts — we can design a **full contract-level architecture** for Kanye-style music subscription with Blocklock. I’ll lay it out step by step.

---

# 🏗 Full Contract-Level Architecture (Pattern A, On-Chain)

### **Actors**

* **Kanye** → deploys contracts and uploads music AES key (encrypted).
* **Fan** → subscribes and later decrypts music.
* **Blocklock** → handles timelock logic on-chain.

---

## **1️⃣ Contracts Needed**

### a) `SubscriptionManager`

* Tracks subscribers.
* Collects subscription payments.
* Emits events so contract can act internally for timelock creation.

State variables:

```solidity
mapping(address => bool) public isSubscriber;
mapping(address => uint256) public fanRequestId; // maps fan to their Blocklock request
```

Functions:

```solidity
function subscribe() external payable {
    require(!isSubscriber[msg.sender], "Already subscribed");
    isSubscriber[msg.sender] = true;
    emit Subscribed(msg.sender);
    // Call BlocklockManager internally to create timelock
}
```

---

### b) `BlocklockManager` (inherits `AbstractBlocklockReceiver`)

* Stores **fan-specific timelocked ciphertexts**.
* Handles **Blocklock callbacks** when target block height is reached.

State variables:

```solidity
struct FanLock {
    TypesLib.Ciphertext cipher; // Blocklock-encrypted fan key
    bool unlocked;
}
mapping(address => FanLock) public fanLocks;
```

Key functions:

```solidity
function createTimelockForFan(
    address fan,
    TypesLib.Ciphertext calldata cipher,
    uint32 callbackGasLimit
) external onlyOwner returns (uint256 requestId) {
    require(isSubscriber[fan], "Not a subscriber");
    (uint256 _requestId, uint256 price) = _requestBlocklockPayInNative(callbackGasLimit, conditionBytes, cipher);
    fanLocks[fan] = FanLock(cipher, false);
    fanRequestId[fan] = _requestId;
    return _requestId;
}

// Blocklock callback
function _onBlocklockReceived(uint256 _requestId, bytes calldata decryptionKey) internal override {
    address fan = _findFanByRequestId(_requestId); // internal mapping
    require(fanLocks[fan].unlocked == false, "Already unlocked");
    fanLocks[fan].cipher = _decrypt(fanLocks[fan].cipher, decryptionKey); // still ECIES-encrypted per fan
    fanLocks[fan].unlocked = true;
    emit FanKeyUnlocked(fan, fanLocks[fan].cipher);
}
```

Helper mapping `_requestId → fan`:

```solidity
mapping(uint256 => address) private requestIdToFan;

function _findFanByRequestId(uint256 requestId) internal view returns (address) {
    return requestIdToFan[requestId];
}
```

---

### c) `MusicStore`

* Stores **AES-GCM music ciphertext** and metadata.
* Fans fetch ciphertext & IV + tag, then use their fan-specific decrypted key to unlock music locally.

State variables:

```solidity
bytes public musicCiphertext; 
bytes public iv; 
bytes public tag;
```

---

## **2️⃣ Full Flow On-Chain**

1. **Kanye uploads music**

   * Encrypt music off-chain with AES-GCM → `musicCiphertext`.
   * Call `MusicStore.storeMusic(musicCiphertext, iv, tag)`.

2. **Fan subscribes**

   * Call `SubscriptionManager.subscribe()` → marks `isSubscriber[fan] = true`.
   * `SubscriptionManager` calls `BlocklockManager.createTimelockForFan(fan, cipher, callbackGasLimit)`.

3. **Fan-specific Blocklock ciphertext creation**

   * The **ciphertext is still ECIES(fanPubKey, K)**.
   * Stored on-chain in `fanLocks[fan].cipher`.

4. **Blocklock triggers unlock**

   * `_onBlocklockReceived()` is called automatically.
   * Contract decrypts Blocklock timelock → now the fan has their ECIES-encrypted AES key.

5. **Fan decrypts**

   * Fan fetches `fanLocks[fan].cipher` → decrypt with their wallet private key → gets AES key `K`.
   * Fan fetches `MusicStore.musicCiphertext` → decrypts with AES key → music unlocked.

---

## **3️⃣ Security and Considerations**

* Only **subscribed fans** get a timelock request.
* The **AES key `K` is never revealed in plaintext** on-chain. Only ECIES-encrypted blobs.
* Blocklock ensures **time-based unlock**: cannot be accessed before block height.
* `_onBlocklockReceived` only allows **the correct fan** to unlock their key.

---

## **4️⃣ Optional Optimizations**

* **Batch multiple fans** in one Blocklock request for cost savings.
* **Emit events** to notify frontends when fan keys are unlocked.
* **Check fan balance** before creating timelock → prevent failed transactions.

---

✅ This architecture is **fully on-chain**:

* Subscriptions ✅
* Fan-specific timelocks ✅
* Blocklock decryption ✅
* Music storage off-chain ✅

Fans only ever need **their wallet** to decrypt their music after the unlock.

---

If you want, I can **draw a full smart-contract diagram/timeline** showing:

```
Fan subscribes → timelock created → Blocklock unlock → fan decrypts AES → music unlocked
```

This makes the entire system flow visually crystal clear.

Do you want me to do that next?
