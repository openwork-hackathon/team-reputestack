// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Ownable.sol";

interface IBadgeNFT {
    function mint(address to, string calldata uri) external returns (uint256);
}

/// @title ReputationReceipt
/// @notice Receipt registry for verified job outcomes.
contract ReputationReceipt is Ownable {
    struct Receipt {
        address agent;
        address client;
        uint256 jobId;
        uint256 score; // 0-100
        uint256 timestamp;
        string uri; // offchain metadata / proof
    }

    mapping(bytes32 => Receipt) public receipts;
    mapping(address => bytes32[]) private _receiptsByAgent;
    mapping(address => bytes32[]) private _receiptsByClient;
    mapping(bytes32 => bool) public issued;

    uint256 public nonce;
    address public badgeNFT;

    event ReceiptIssued(bytes32 indexed receiptId, address indexed agent, address indexed client, uint256 jobId, uint256 score, string uri);
    event BadgeNFTUpdated(address indexed badgeNFT);

    function setBadgeNFT(address _badgeNFT) external onlyOwner {
        badgeNFT = _badgeNFT;
        emit BadgeNFTUpdated(_badgeNFT);
    }

    function issueReceipt(
        address agent,
        address client,
        uint256 jobId,
        uint256 score,
        string calldata uri
    ) external onlyOwner returns (bytes32) {
        return _issue(agent, client, jobId, score, uri, false, "").receiptId;
    }

    function issueReceiptWithBadge(
        address agent,
        address client,
        uint256 jobId,
        uint256 score,
        string calldata uri,
        string calldata badgeUri
    ) external onlyOwner returns (bytes32 receiptId, uint256 badgeId) {
        require(badgeNFT != address(0), "badgeNFT not set");
        IssueResult memory res = _issue(agent, client, jobId, score, uri, true, badgeUri);
        return (res.receiptId, res.badgeId);
    }

    function getReceiptsByAgent(address agent) external view returns (bytes32[] memory) {
        return _receiptsByAgent[agent];
    }

    function getReceiptsByClient(address client) external view returns (bytes32[] memory) {
        return _receiptsByClient[client];
    }

    struct IssueResult {
        bytes32 receiptId;
        uint256 badgeId;
    }

    function _issue(
        address agent,
        address client,
        uint256 jobId,
        uint256 score,
        string calldata uri,
        bool mintBadge,
        string calldata badgeUri
    ) internal returns (IssueResult memory res) {
        require(agent != address(0) && client != address(0), "zero addr");
        require(score <= 100, "score>100");

        bytes32 receiptId = keccak256(abi.encode(agent, client, jobId, nonce++));
        require(!issued[receiptId], "duplicate");
        issued[receiptId] = true;

        receipts[receiptId] = Receipt(agent, client, jobId, score, block.timestamp, uri);
        _receiptsByAgent[agent].push(receiptId);
        _receiptsByClient[client].push(receiptId);

        emit ReceiptIssued(receiptId, agent, client, jobId, score, uri);

        if (mintBadge) {
            res.badgeId = IBadgeNFT(badgeNFT).mint(agent, badgeUri);
        }
        res.receiptId = receiptId;
    }
}
