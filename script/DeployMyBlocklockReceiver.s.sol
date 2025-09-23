// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MyBlocklockReceiver} from "../src/MyBlocklockReceiver.sol";

contract DeployMyBlocklockReceiver is Script {
    MyBlocklockReceiver public receiver;
    address public blocklockSender;


    // Run with: forge script script/DeployMyBlocklockReceiver.s.sol:DeployMyBlocklockReceiver --sig "run(address)" <blocklockSender> --rpc-url <rpc> --private-key <pk>
    function run(address blocklockSender) public {
        vm.startBroadcast();
        receiver = new MyBlocklockReceiver(blocklockSender);
        vm.stopBroadcast();
    }
}


