// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MusicStore} from "../src/MusicStore.sol";

contract MusicStoreTest is Test {
    MusicStore internal store;
    address internal ownerAddr = address(0xBEEF);
    address internal other = address(0xB0B);

    function setUp() public {
        vm.prank(ownerAddr);
        store = new MusicStore();
    }

    function test_StoreAlbum_OnlyOwner() public {
        bytes memory ct = hex"010203";
        bytes memory iv = hex"aabbcc";
        bytes memory tag = hex"ddeeff";

        vm.prank(ownerAddr);
        store.storeAlbum(1, ct, iv, tag);
        (bytes memory gotCt, bytes memory gotIv, bytes memory gotTag) = store.getAlbum(1);
        assertEq(gotCt, ct);
        assertEq(gotIv, iv);
        assertEq(gotTag, tag);
    }

    function test_StoreAlbum_RevertIfNotOwner() public {
        bytes memory ct = hex"00";
        vm.prank(other);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        store.storeAlbum(1, ct, bytes(""), bytes(""));
    }
}


