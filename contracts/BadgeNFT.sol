// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Ownable.sol";

/// @title BadgeNFT (minimal ERC-721)
/// @notice Badge NFTs minted from reputation receipts.
contract BadgeNFT is Ownable {
    string public name = "ReputeStack Badge";
    string public symbol = "RSTACK";

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => string) public tokenURI;

    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event MinterUpdated(address indexed minter);

    uint256 public nextId = 1;
    address public minter;

    modifier onlyMinter() {
        require(msg.sender == minter, "not minter");
        _;
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
        emit MinterUpdated(_minter);
    }

    function mint(address to, string calldata uri) external onlyMinter returns (uint256) {
        require(to != address(0), "zero addr");
        uint256 id = nextId++;
        ownerOf[id] = to;
        balanceOf[to] += 1;
        tokenURI[id] = uri;
        emit Transfer(address(0), to, id);
        return id;
    }

    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf[tokenId];
        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "not owner/approved");
        getApproved[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(to != address(0), "zero addr");
        address owner = ownerOf[tokenId];
        require(owner == from, "not owner");
        require(
            msg.sender == owner || msg.sender == getApproved[tokenId] || isApprovedForAll[owner][msg.sender],
            "not approved"
        );

        // clear approval
        if (getApproved[tokenId] != address(0)) {
            getApproved[tokenId] = address(0);
            emit Approval(owner, address(0), tokenId);
        }

        ownerOf[tokenId] = to;
        balanceOf[from] -= 1;
        balanceOf[to] += 1;
        emit Transfer(from, to, tokenId);
    }

    // minimal safeTransferFrom (no receiver checks)
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
    }
}
