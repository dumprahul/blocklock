// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "./utils/Ownable.sol";
import {TypesLib} from "blocklock-solidity/src/libraries/TypesLib.sol";


/// @title MusicStore
/// @notice Stores AES-GCM ciphertext and metadata for music content, per album ID
contract MusicStore is Ownable {
    struct AlbumCipher {
        TypesLib.Ciphertext ciphertext; // store full Blocklock ciphertext struct
        bytes iv;
        bytes tag;
    }

    mapping(uint256 => AlbumCipher) private albums;
    uint256[] private albumIds;
    mapping(uint256 => bool) private albumExists;

    event MusicStored(uint256 indexed albumId);

    function storeAlbum(
        uint256 albumId,
        TypesLib.Ciphertext calldata ciphertext,
        bytes calldata ivBytes,
        bytes calldata tagBytes
    ) external onlyOwner {
        if (!albumExists[albumId]) {
            albumExists[albumId] = true;
            albumIds.push(albumId);
        }
        albums[albumId] = AlbumCipher(ciphertext, ivBytes, tagBytes);
        emit MusicStored(albumId);
    }

    function getAlbum(uint256 albumId) external view returns (bytes memory, bytes memory, bytes memory) {
        AlbumCipher storage a = albums[albumId];
        return (abi.encode(a.ciphertext), a.iv, a.tag);
    }

    function getAlbumIds() external view returns (uint256[] memory) {
        return albumIds;
    }
}



