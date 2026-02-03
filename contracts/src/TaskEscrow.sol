// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TaskEscrow
 * @notice Escrow contract for AI agent task payments with dispute resolution
 * @dev Holds funds until task completion, supports disputes and arbitration
 */
contract TaskEscrow {
    using SafeERC20 for IERC20;
    
    // Task state enumeration
    enum TaskState {
        Created,
        Funded,
        InProgress,
        Submitted,
        Completed,
        Disputed,
        Refunded,
        Cancelled
    }
    
    // Task structure
    struct Task {
        bytes32 taskId;
        address poster;
        address agent;
        address paymentToken;
        uint256 amount;
        uint256 createdAt;
        uint256 deadline;
        TaskState state;
        string submissionUri;
        string disputeReason;
    }
    
    // Dispute structure
    struct Dispute {
        bytes32 taskId;
        address initiator;
        string reason;
        uint256 createdAt;
        bool resolved;
        bool agentFavored;
    }
    
    // Storage
    mapping(bytes32 => Task) public tasks;
    mapping(bytes32 => Dispute) public disputes;
    bytes32[] public allTaskIds;
    
    // Protocol settings
    address public owner;
    address public arbitrator;
    uint256 public protocolFee = 250; // 2.5% in basis points
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MIN_DEADLINE = 1 hours;
    uint256 public constant MAX_DEADLINE = 30 days;
    uint256 public constant DISPUTE_WINDOW = 3 days;
    
    // Fee collection
    mapping(address => uint256) public collectedFees;
    
    // Reputation registry integration
    address public reputationRegistry;
    
    // Events
    event TaskCreated(bytes32 indexed taskId, address indexed poster, uint256 amount);
    event TaskFunded(bytes32 indexed taskId, address indexed agent);
    event TaskSubmitted(bytes32 indexed taskId, string submissionUri);
    event TaskCompleted(bytes32 indexed taskId, address indexed agent, uint256 payout);
    event TaskDisputed(bytes32 indexed taskId, address indexed initiator, string reason);
    event DisputeResolved(bytes32 indexed taskId, bool agentFavored);
    event TaskRefunded(bytes32 indexed taskId, address indexed poster);
    event TaskCancelled(bytes32 indexed taskId);
    event ArbitratorUpdated(address indexed newArbitrator);
    event ReputationRegistryUpdated(address indexed newRegistry);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyArbitrator() {
        require(msg.sender == arbitrator, "Not arbitrator");
        _;
    }
    
    modifier taskExists(bytes32 taskId) {
        require(tasks[taskId].poster != address(0), "Task does not exist");
        _;
    }
    
    constructor(address _arbitrator) {
        owner = msg.sender;
        arbitrator = _arbitrator;
    }
    
    /**
     * @notice Create a new task with escrowed payment
     * @param taskId Unique task identifier
     * @param paymentToken ERC20 token for payment (address(0) for ETH)
     * @param amount Payment amount
     * @param deadline Task deadline timestamp
     */
    function createTask(
        bytes32 taskId,
        address paymentToken,
        uint256 amount,
        uint256 deadline
    ) external payable {
        require(tasks[taskId].poster == address(0), "Task ID already exists");
        require(amount > 0, "Amount must be positive");
        require(deadline >= block.timestamp + MIN_DEADLINE, "Deadline too soon");
        require(deadline <= block.timestamp + MAX_DEADLINE, "Deadline too far");
        
        if (paymentToken == address(0)) {
            require(msg.value == amount, "Incorrect ETH amount");
        } else {
            require(msg.value == 0, "ETH not accepted for token tasks");
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        }
        
        tasks[taskId] = Task({
            taskId: taskId,
            poster: msg.sender,
            agent: address(0),
            paymentToken: paymentToken,
            amount: amount,
            createdAt: block.timestamp,
            deadline: deadline,
            state: TaskState.Funded,
            submissionUri: "",
            disputeReason: ""
        });
        
        allTaskIds.push(taskId);
        
        emit TaskCreated(taskId, msg.sender, amount);
    }
    
    /**
     * @notice Agent claims a task
     * @param taskId Task identifier
     */
    function claimTask(bytes32 taskId) external taskExists(taskId) {
        Task storage task = tasks[taskId];
        require(task.state == TaskState.Funded, "Task not available");
        require(task.agent == address(0), "Task already claimed");
        require(block.timestamp < task.deadline, "Task expired");
        
        task.agent = msg.sender;
        task.state = TaskState.InProgress;
        
        emit TaskFunded(taskId, msg.sender);
    }
    
    /**
     * @notice Agent submits completed work
     * @param taskId Task identifier
     * @param submissionUri URI to submission (IPFS, GitHub, etc)
     */
    function submitWork(bytes32 taskId, string calldata submissionUri) external taskExists(taskId) {
        Task storage task = tasks[taskId];
        require(task.state == TaskState.InProgress, "Task not in progress");
        require(task.agent == msg.sender, "Not the assigned agent");
        require(bytes(submissionUri).length > 0, "Submission URI required");
        
        task.submissionUri = submissionUri;
        task.state = TaskState.Submitted;
        
        emit TaskSubmitted(taskId, submissionUri);
    }
    
    /**
     * @notice Poster approves submission and releases payment
     * @param taskId Task identifier
     */
    function approveSubmission(bytes32 taskId) external taskExists(taskId) {
        Task storage task = tasks[taskId];
        require(task.state == TaskState.Submitted, "No submission to approve");
        require(task.poster == msg.sender, "Not the poster");
        
        task.state = TaskState.Completed;
        
        uint256 fee = (task.amount * protocolFee) / FEE_DENOMINATOR;
        uint256 payout = task.amount - fee;
        
        collectedFees[task.paymentToken] += fee;
        
        _transfer(task.paymentToken, task.agent, payout);
        
        emit TaskCompleted(taskId, task.agent, payout);
    }
    
    /**
     * @notice Auto-complete after dispute window passes
     * @param taskId Task identifier
     */
    function autoComplete(bytes32 taskId) external taskExists(taskId) {
        Task storage task = tasks[taskId];
        require(task.state == TaskState.Submitted, "Not in submitted state");
        require(block.timestamp > task.deadline + DISPUTE_WINDOW, "Dispute window active");
        
        task.state = TaskState.Completed;
        
        uint256 fee = (task.amount * protocolFee) / FEE_DENOMINATOR;
        uint256 payout = task.amount - fee;
        
        collectedFees[task.paymentToken] += fee;
        
        _transfer(task.paymentToken, task.agent, payout);
        
        emit TaskCompleted(taskId, task.agent, payout);
    }
    
    /**
     * @notice Open a dispute
     * @param taskId Task identifier
     * @param reason Dispute reason
     */
    function openDispute(bytes32 taskId, string calldata reason) external taskExists(taskId) {
        Task storage task = tasks[taskId];
        require(
            task.state == TaskState.Submitted || task.state == TaskState.InProgress,
            "Cannot dispute in current state"
        );
        require(
            msg.sender == task.poster || msg.sender == task.agent,
            "Not a party to this task"
        );
        require(bytes(reason).length > 0, "Reason required");
        
        task.state = TaskState.Disputed;
        task.disputeReason = reason;
        
        disputes[taskId] = Dispute({
            taskId: taskId,
            initiator: msg.sender,
            reason: reason,
            createdAt: block.timestamp,
            resolved: false,
            agentFavored: false
        });
        
        emit TaskDisputed(taskId, msg.sender, reason);
    }
    
    /**
     * @notice Arbitrator resolves dispute
     * @param taskId Task identifier
     * @param favorAgent True to pay agent, false to refund poster
     */
    function resolveDispute(bytes32 taskId, bool favorAgent) external onlyArbitrator taskExists(taskId) {
        Task storage task = tasks[taskId];
        Dispute storage dispute = disputes[taskId];
        
        require(task.state == TaskState.Disputed, "Not disputed");
        require(!dispute.resolved, "Already resolved");
        
        dispute.resolved = true;
        dispute.agentFavored = favorAgent;
        
        if (favorAgent && task.agent != address(0)) {
            task.state = TaskState.Completed;
            uint256 fee = (task.amount * protocolFee) / FEE_DENOMINATOR;
            uint256 payout = task.amount - fee;
            collectedFees[task.paymentToken] += fee;
            _transfer(task.paymentToken, task.agent, payout);
            emit TaskCompleted(taskId, task.agent, payout);
        } else {
            task.state = TaskState.Refunded;
            _transfer(task.paymentToken, task.poster, task.amount);
            emit TaskRefunded(taskId, task.poster);
        }
        
        emit DisputeResolved(taskId, favorAgent);
    }
    
    /**
     * @notice Cancel unclaimed task and refund
     * @param taskId Task identifier
     */
    function cancelTask(bytes32 taskId) external taskExists(taskId) {
        Task storage task = tasks[taskId];
        require(task.poster == msg.sender, "Not the poster");
        require(task.state == TaskState.Funded, "Cannot cancel");
        require(task.agent == address(0), "Task already claimed");
        
        task.state = TaskState.Cancelled;
        
        _transfer(task.paymentToken, task.poster, task.amount);
        
        emit TaskCancelled(taskId);
    }
    
    /**
     * @notice Refund expired uncompleted task
     * @param taskId Task identifier
     */
    function refundExpired(bytes32 taskId) external taskExists(taskId) {
        Task storage task = tasks[taskId];
        require(
            task.state == TaskState.Funded || task.state == TaskState.InProgress,
            "Cannot refund in current state"
        );
        require(block.timestamp > task.deadline, "Not expired yet");
        
        task.state = TaskState.Refunded;
        
        _transfer(task.paymentToken, task.poster, task.amount);
        
        emit TaskRefunded(taskId, task.poster);
    }
    
    // View functions
    
    function getTask(bytes32 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }
    
    function getDispute(bytes32 taskId) external view returns (Dispute memory) {
        return disputes[taskId];
    }
    
    function getTaskCount() external view returns (uint256) {
        return allTaskIds.length;
    }
    
    // Admin functions
    
    function setArbitrator(address _arbitrator) external onlyOwner {
        arbitrator = _arbitrator;
        emit ArbitratorUpdated(_arbitrator);
    }
    
    function setReputationRegistry(address _registry) external onlyOwner {
        reputationRegistry = _registry;
        emit ReputationRegistryUpdated(_registry);
    }
    
    function setProtocolFee(uint256 _fee) external onlyOwner {
        require(_fee <= 1000, "Fee too high"); // Max 10%
        protocolFee = _fee;
    }
    
    function withdrawFees(address token, address recipient) external onlyOwner {
        uint256 amount = collectedFees[token];
        require(amount > 0, "No fees to withdraw");
        collectedFees[token] = 0;
        _transfer(token, recipient, amount);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
    
    // Internal
    
    function _transfer(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }
    
    receive() external payable {}
}
