// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SubscriptionManager} from "../src/SubscriptionManager.sol";
import {MusicStore} from "../src/MusicStore.sol";
import {BlocklockManager} from "../src/BlocklockManager.sol";

contract DeployMusicBlocklock is Script {
    SubscriptionManager public subscriptionManager;
    MusicStore public musicStore;
    BlocklockManager public blocklockManager;

    // Example run:
    // forge script script/DeployMusicBlocklock.s.sol:DeployMusicBlocklock \
    //   --sig "run(address,uint256)" 0xBlocklockSenderAddress 100000000000000000 \
    //   --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
    function run(address blocklockSender, uint256 subscribePriceWei) public {
        vm.startBroadcast();

        subscriptionManager = new SubscriptionManager(subscribePriceWei);
        musicStore = new MusicStore();
        blocklockManager = new BlocklockManager(blocklockSender, address(subscriptionManager));

        subscriptionManager.setBlocklockManager(payable(address(blocklockManager)));

        console.log("SubscriptionManager:", address(subscriptionManager));
        console.log("MusicStore:", address(musicStore));
        console.log("BlocklockManager:", address(blocklockManager));

        vm.stopBroadcast();
    }
}


