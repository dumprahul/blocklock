This is-

In practice, the data encryption is done off-chain using blocklock-js. So, let's install the JS library to your project.

npm install blocklock-js

For the purpose of quickstart, we will create a script to simulate the blocklock encryption request.

Connect to your deployed MyBlocklockReceiver contract
Prepare the blocklock encryption payload, including blockHeight, encrypted message, callBack gaslimt and price, etc.
Call the myBlocklockReceiver contract to request blocklock encryption with direct funding.



import { ethers } from "hardhat";
import { getBytes, Signer } from "ethers";
import { Blocklock, encodeCiphertextToSolidity, encodeCondition, encodeParams } from "blocklock-js";
import { MyBlocklockReceiver } from "../typechain-types";

async function main() {
    // Get the signer from hardhat config
    const [signer] = await ethers.getSigners();

    // 1. Connect to the deployed myBlocklockReceiver contract
    const contractAddress = '0xMyBlocklockReceiverContractAddress';
    const ContractFactory = await ethers.getContractFactory("MyBlocklockReceiver");
    const contract = ContractFactory.connect(signer).attach(contractAddress) as MyBlocklockReceiver;

	// 2. Create blocklock request payload
    // Set block height for blocklock decryption (current block + 10)
    const blockHeight = BigInt(await ethers.provider.getBlockNumber() + 10);
    const conditionBytes = encodeCondition(blockHeight);

    // Set the message to encrypt
    const msg = ethers.parseEther("8"); // Example: BigInt for blocklock ETH transfer
    const msgBytes = encodeParams(["uint256"], [msg]);
    const encodedMessage = getBytes(msgBytes);

    // Encrypt the encoded message usng Blocklock.js library
    const blocklockjs = Blocklock.createBaseSepolia(signer as unknown as Signer);
    const cipherMessage = blocklockjs.encrypt(encodedMessage, blockHeight);

    // Set the callback gas limit and price
    // Best practice is to estimate the callback gas limit e.g., by extracting gas reports from Solidity tests
    const callbackGasLimit = 700_000n;
    // Based on the callbackGasLimit, we can estimate the request price by calling BlocklockSender
    // Note: Add a buffer to the estimated request price to cover for fluctuating gas prices between blocks
    const [requestCallBackPrice] = await blocklockjs.calculateRequestPriceNative(callbackGasLimit)

    console.log("Target block for unlock:", blockHeight);
    console.log("Callback gas limit:", callbackGasLimit);
    console.log("Request CallBack price:", ethers.formatEther(requestCallBackPrice), "ETH");
    
    //Ensure wallet has enought token to cover the callback fee
    const balance = await ethers.provider.getBalance(signer.address);
    console.log("Wallet balance:", ethers.formatEther(balance), "ETH");
    if (balance < requestCallBackPrice) {
        throw new Error(`Insufficient balance. Need ${ethers.formatEther(requestCallBackPrice)} ETH but have ${ethers.formatEther(balance)} ETH`);
    }

    // 3. Invoke myBlocklockReceiver contract to request blocklock encryption with direct funding.
    console.log("Sending transaction...");
    const tx = await contract.createTimelockRequestWithDirectFunding(
        callbackGasLimit,
        conditionBytes,
        encodeCiphertextToSolidity(cipherMessage),
        { value: requestCallBackPrice }
    );
    
    console.log("Transaction sent, waiting for confirmation...");
    const receipt = await tx.wait(1);
    if (!receipt) {
        throw new Error("Transaction failed");
    }
    console.log("BlockLock requested in tx:", receipt.hash);
}

main().catch((err) => {
  console.error("Invocation failed:", err);
  process.exitCode = 1;
});

