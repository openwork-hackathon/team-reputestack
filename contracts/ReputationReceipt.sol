// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ReputationReceipt
/// @notice Minimal receipt registry for verified job outcomes.
contract ReputationReceipt {
    struct Receipt {
        address agent;
        address client;
        uint256 jobId;
        uint256 score; // 0-100
        uint256 timestamp;
        string uri; // offchain metadata / proof
    }

    mapping(bytes32 => Receipt) public receipts;

    event ReceiptIssued(bytes32 indexed receiptId, address indexed agent, address indexed client, uint256 jobId, uint256 score, string uri);

    function issueReceipt(
        address agent,
        address client,
        uint256 jobId,
        uint256 score,
        string calldata uri
    ) external returns (bytes32) {
        require(score <= 100, "score>100");
        bytes32 receiptId = keccak256(abi.encodePacked(agent, client, jobId, block.timestamp, uri));
        receipts[receiptId] = Receipt(agent, client, jobId, score, block.timestamp, uri);
        emit ReceiptIssued(receiptId, agent, client, jobId, score, uri);
        return receiptId;
    }
}
