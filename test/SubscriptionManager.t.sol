// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SubscriptionManager} from "../src/SubscriptionManager.sol";

contract SubscriptionManagerTest is Test {
    SubscriptionManager internal manager;
    address internal creator = address(0xCAFE);
    address internal fan = address(0xF00D);

    function setUp() public {
        vm.prank(creator);
        manager = new SubscriptionManager(0.1 ether);
    }

    function test_Subscribe_SetsMappingAndEmits() public {
        vm.deal(fan, 1 ether);
        vm.prank(fan);
        vm.expectEmit(true, false, false, true);
        emit SubscriptionManager.Subscribed(fan, 0.1 ether);
        manager.subscribe{value: 0.1 ether}();
        assertTrue(manager.isSubscriber(fan));
    }

    function test_Subscribe_RevertsIfAlreadySubscribed() public {
        vm.deal(fan, 1 ether);
        vm.startPrank(fan);
        manager.subscribe{value: 0.1 ether}();
        vm.expectRevert(bytes("Already subscribed"));
        manager.subscribe{value: 0.1 ether}();
        vm.stopPrank();
    }

    function test_Subscribe_RevertsIfInsufficientPayment() public {
        vm.deal(fan, 1 ether);
        vm.prank(fan);
        vm.expectRevert(bytes("Insufficient payment"));
        manager.subscribe{value: 0.05 ether}();
    }

    function test_Unsubscribe_ClearsMapping() public {
        vm.deal(fan, 1 ether);
        vm.startPrank(fan);
        manager.subscribe{value: 0.1 ether}();
        manager.unsubscribe();
        assertFalse(manager.isSubscriber(fan));
        vm.stopPrank();
    }

    function test_Withdraw_TransfersFundsToOwner() public {
        vm.deal(fan, 1 ether);
        vm.prank(fan);
        manager.subscribe{value: 0.2 ether}();

        // Owner is deployer (creator)
        vm.prank(creator);
        uint256 balBefore = creator.balance;
        manager.withdraw(payable(creator), 0.2 ether);
        uint256 balAfter = creator.balance;
        assertEq(balAfter - balBefore, 0.2 ether);
    }
}


