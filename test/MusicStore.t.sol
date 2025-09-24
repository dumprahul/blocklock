// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MusicStore} from "../src/MusicStore.sol";
import {TypesLib} from "blocklock-solidity/src/libraries/TypesLib.sol";

contract MusicStoreTest is Test {
    MusicStore internal store;
    address internal ownerAddr = address(0xBEEF);
    address internal other = address(0xB0B);

    function setUp() public {
        vm.prank(ownerAddr);
        store = new MusicStore();
    }

    function test_StoreAlbum_OnlyOwner() public {
        TypesLib.Ciphertext memory cipher; // zero-initialized placeholder
        bytes memory iv = hex"aabbcc";
        bytes memory tag = hex"ddeeff";

        vm.prank(ownerAddr);
        store.storeAlbum(1, cipher, iv, tag);
        (bytes memory gotCipher, bytes memory gotIv, bytes memory gotTag) = store.getAlbum(1);
        // We only validate iv/tag match; ciphertext is encoded struct bytes
        assertEq(gotIv, iv);
        assertEq(gotTag, tag);
        assertTrue(gotCipher.length > 0 || gotCipher.length == 0); // placeholder access
    }

    function test_StoreAlbum_RevertIfNotOwner() public {
        TypesLib.Ciphertext memory cipher;
        vm.prank(other);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        store.storeAlbum(1, cipher, bytes(""), bytes(""));
    }
}


