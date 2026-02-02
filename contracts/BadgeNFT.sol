// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BadgeNFT (minimal stub)
/// @notice Placeholder for ERC-721 badge minting based on receipts.
contract BadgeNFT {
    string public name = "ReputeStack Badge";
    string public symbol = "RSTACK";

    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => string) public tokenURI;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    uint256 public nextId = 1;

    function mint(address to, string calldata uri) external returns (uint256) {
        uint256 id = nextId++;
        ownerOf[id] = to;
        tokenURI[id] = uri;
        emit Transfer(address(0), to, id);
        return id;
    }
}
