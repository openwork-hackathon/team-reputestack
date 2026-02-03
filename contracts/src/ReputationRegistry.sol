// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ReputationRegistry
 * @notice On-chain registry for AI agent reputation attestations
 * @dev Stores reputation receipts and calculates agent scores
 */
contract ReputationRegistry {
    
    // Task outcome enumeration
    enum Outcome { Success, Failure, Disputed }
    
    // Task category enumeration  
    enum Category { Coding, Research, Trading, PM, Other }
    
    // Verification method enumeration
    enum VerificationMethod { Escrow, ManualReview, AutomatedTest }
    
    // Reputation receipt structure
    struct Receipt {
        address agentWallet;
        bytes32 agentId;
        bytes32 taskId;
        Category category;
        Outcome outcome;
        VerificationMethod verification;
        int256 points;
        uint256 timestamp;
        string metadataUri;
    }
    
    // Agent score structure
    struct AgentScore {
        int256 totalReputation;
        uint256 successCount;
        uint256 failureCount;
        uint256 disputeCount;
        uint256 level;
        uint256 lastUpdated;
    }
    
    // Storage
    mapping(address => AgentScore) public agentScores;
    mapping(address => Receipt[]) public agentReceipts;
    mapping(bytes32 => bool) public taskProcessed;
    
    // Authorized attesters (escrow contracts, verified reviewers)
    mapping(address => bool) public authorizedAttesters;
    
    // Owner
    address public owner;
    
    // Points configuration
    int256 public constant SUCCESS_POINTS = 10;
    int256 public constant FAILURE_POINTS = -5;
    int256 public constant DISPUTED_POINTS = -10;
    uint256 public constant POINTS_PER_LEVEL = 50;
    
    // Events
    event ReceiptCreated(
        address indexed agentWallet,
        bytes32 indexed taskId,
        Outcome outcome,
        int256 points
    );
    event AttesterAuthorized(address indexed attester);
    event AttesterRevoked(address indexed attester);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedAttesters[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        authorizedAttesters[msg.sender] = true;
    }
    
    /**
     * @notice Create a new reputation receipt for an agent
     * @param agentWallet The wallet address of the agent
     * @param agentId Off-chain agent identifier
     * @param taskId Unique task identifier
     * @param category Task category
     * @param outcome Task outcome
     * @param verification How the outcome was verified
     * @param metadataUri IPFS or HTTP URI for additional metadata
     */
    function createReceipt(
        address agentWallet,
        bytes32 agentId,
        bytes32 taskId,
        Category category,
        Outcome outcome,
        VerificationMethod verification,
        string calldata metadataUri
    ) external onlyAuthorized {
        require(!taskProcessed[taskId], "Task already processed");
        require(agentWallet != address(0), "Invalid agent wallet");
        
        taskProcessed[taskId] = true;
        
        int256 points = _calculatePoints(outcome);
        
        Receipt memory receipt = Receipt({
            agentWallet: agentWallet,
            agentId: agentId,
            taskId: taskId,
            category: category,
            outcome: outcome,
            verification: verification,
            points: points,
            timestamp: block.timestamp,
            metadataUri: metadataUri
        });
        
        agentReceipts[agentWallet].push(receipt);
        _updateScore(agentWallet, outcome, points);
        
        emit ReceiptCreated(agentWallet, taskId, outcome, points);
    }
    
    /**
     * @notice Get an agent's current score
     * @param agentWallet The wallet address of the agent
     * @return score The agent's score struct
     */
    function getScore(address agentWallet) external view returns (AgentScore memory) {
        return agentScores[agentWallet];
    }
    
    /**
     * @notice Get all receipts for an agent
     * @param agentWallet The wallet address of the agent
     * @return Array of receipts
     */
    function getReceipts(address agentWallet) external view returns (Receipt[] memory) {
        return agentReceipts[agentWallet];
    }
    
    /**
     * @notice Get receipt count for an agent
     * @param agentWallet The wallet address of the agent
     * @return count Number of receipts
     */
    function getReceiptCount(address agentWallet) external view returns (uint256) {
        return agentReceipts[agentWallet].length;
    }
    
    /**
     * @notice Calculate success rate for an agent (basis points)
     * @param agentWallet The wallet address of the agent
     * @return rate Success rate in basis points (10000 = 100%)
     */
    function getSuccessRate(address agentWallet) external view returns (uint256) {
        AgentScore memory score = agentScores[agentWallet];
        uint256 total = score.successCount + score.failureCount + score.disputeCount;
        if (total == 0) return 0;
        return (score.successCount * 10000) / total;
    }
    
    /**
     * @notice Authorize a new attester
     * @param attester Address to authorize
     */
    function authorizeAttester(address attester) external onlyOwner {
        authorizedAttesters[attester] = true;
        emit AttesterAuthorized(attester);
    }
    
    /**
     * @notice Revoke an attester's authorization
     * @param attester Address to revoke
     */
    function revokeAttester(address attester) external onlyOwner {
        authorizedAttesters[attester] = false;
        emit AttesterRevoked(attester);
    }
    
    /**
     * @notice Transfer ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    // Internal functions
    
    function _calculatePoints(Outcome outcome) internal pure returns (int256) {
        if (outcome == Outcome.Success) return SUCCESS_POINTS;
        if (outcome == Outcome.Failure) return FAILURE_POINTS;
        return DISPUTED_POINTS;
    }
    
    function _updateScore(address agentWallet, Outcome outcome, int256 points) internal {
        AgentScore storage score = agentScores[agentWallet];
        
        score.totalReputation += points;
        score.lastUpdated = block.timestamp;
        
        if (outcome == Outcome.Success) {
            score.successCount++;
        } else if (outcome == Outcome.Failure) {
            score.failureCount++;
        } else {
            score.disputeCount++;
        }
        
        // Calculate level (minimum 1)
        if (score.totalReputation > 0) {
            score.level = uint256(score.totalReputation) / POINTS_PER_LEVEL + 1;
        } else {
            score.level = 1;
        }
    }
}
