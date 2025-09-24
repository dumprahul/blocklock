// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "./utils/Ownable.sol";

/// @title MusicStore
/// @notice Stores AES-GCM ciphertext and metadata for music content, per album ID
contract MusicStore is Ownable {
    struct AlbumCipher {
        bytes ciphertext;
        bytes iv;
        bytes tag;
    }

    mapping(uint256 => AlbumCipher) private albums;
    uint256[] private albumIds;
    mapping(uint256 => bool) private albumExists;

    event MusicStored(uint256 indexed albumId, uint256 ciphertextLength);

    function storeAlbum(
        uint256 albumId,
        bytes calldata ciphertext,
        bytes calldata ivBytes,
        bytes calldata tagBytes
    ) external onlyOwner {
        if (!albumExists[albumId]) {
            albumExists[albumId] = true;
            albumIds.push(albumId);
        }
        albums[albumId] = AlbumCipher(ciphertext, ivBytes, tagBytes);
        emit MusicStored(albumId, ciphertext.length);
    }

    function getAlbum(uint256 albumId) external view returns (bytes memory, bytes memory, bytes memory) {
        AlbumCipher storage a = albums[albumId];
        return (a.ciphertext, a.iv, a.tag);
    }

    function getAlbumIds() external view returns (uint256[] memory) {
        return albumIds;
    }
}



