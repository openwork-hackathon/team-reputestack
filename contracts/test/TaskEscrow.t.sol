// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TaskEscrow} from "../src/TaskEscrow.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract TaskEscrowTest is Test {
    TaskEscrow public escrow;
    MockERC20 public token;
    
    address owner = address(this);
    address arbitrator = address(0x1);
    address poster = address(0x2);
    address agent = address(0x3);
    
    bytes32 taskId = keccak256("task1");
    uint256 amount = 1 ether;
    uint256 deadline;
    
    function setUp() public {
        escrow = new TaskEscrow(arbitrator);
        token = new MockERC20("Test Token", "TEST");
        
        // Fund accounts
        vm.deal(poster, 10 ether);
        vm.deal(agent, 1 ether);
        token.mint(poster, 100 ether);
        
        // Set deadline
        deadline = block.timestamp + 1 days;
        
        // Approve escrow for token transfers
        vm.prank(poster);
        token.approve(address(escrow), type(uint256).max);
    }
    
    // ============ Create Task Tests ============
    
    function test_CreateTask_ETH() public {
        vm.prank(poster);
        escrow.createTask{value: amount}(taskId, address(0), amount, deadline);
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(task.poster, poster);
        assertEq(task.amount, amount);
        assertEq(task.paymentToken, address(0));
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.Funded));
    }
    
    function test_CreateTask_Token() public {
        vm.prank(poster);
        escrow.createTask(taskId, address(token), amount, deadline);
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(task.poster, poster);
        assertEq(task.amount, amount);
        assertEq(task.paymentToken, address(token));
        assertEq(token.balanceOf(address(escrow)), amount);
    }
    
    function test_RevertWhen_DuplicateTaskId() public {
        vm.startPrank(poster);
        escrow.createTask{value: amount}(taskId, address(0), amount, deadline);
        
        vm.expectRevert("Task ID already exists");
        escrow.createTask{value: amount}(taskId, address(0), amount, deadline);
        vm.stopPrank();
    }
    
    function test_RevertWhen_DeadlineTooSoon() public {
        vm.prank(poster);
        vm.expectRevert("Deadline too soon");
        escrow.createTask{value: amount}(taskId, address(0), amount, block.timestamp + 30 minutes);
    }
    
    function test_RevertWhen_DeadlineTooFar() public {
        vm.prank(poster);
        vm.expectRevert("Deadline too far");
        escrow.createTask{value: amount}(taskId, address(0), amount, block.timestamp + 60 days);
    }
    
    function test_RevertWhen_IncorrectETH() public {
        vm.prank(poster);
        vm.expectRevert("Incorrect ETH amount");
        escrow.createTask{value: 0.5 ether}(taskId, address(0), amount, deadline);
    }
    
    // ============ Claim Task Tests ============
    
    function test_ClaimTask() public {
        vm.prank(poster);
        escrow.createTask{value: amount}(taskId, address(0), amount, deadline);
        
        vm.prank(agent);
        escrow.claimTask(taskId);
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(task.agent, agent);
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.InProgress));
    }
    
    function test_RevertWhen_ClaimExpiredTask() public {
        vm.prank(poster);
        escrow.createTask{value: amount}(taskId, address(0), amount, deadline);
        
        vm.warp(deadline + 1);
        
        vm.prank(agent);
        vm.expectRevert("Task expired");
        escrow.claimTask(taskId);
    }
    
    // ============ Submit Work Tests ============
    
    function test_SubmitWork() public {
        _createAndClaimTask();
        
        vm.prank(agent);
        escrow.submitWork(taskId, "ipfs://submission");
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(task.submissionUri, "ipfs://submission");
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.Submitted));
    }
    
    function test_RevertWhen_SubmitNotAgent() public {
        _createAndClaimTask();
        
        vm.prank(poster);
        vm.expectRevert("Not the assigned agent");
        escrow.submitWork(taskId, "ipfs://submission");
    }
    
    // ============ Approve Submission Tests ============
    
    function test_ApproveSubmission_ETH() public {
        _createClaimAndSubmitTask(address(0));
        
        uint256 agentBalanceBefore = agent.balance;
        
        vm.prank(poster);
        escrow.approveSubmission(taskId);
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.Completed));
        
        // 2.5% fee
        uint256 expectedPayout = amount - (amount * 250 / 10000);
        assertEq(agent.balance - agentBalanceBefore, expectedPayout);
    }
    
    function test_ApproveSubmission_Token() public {
        _createClaimAndSubmitTask(address(token));
        
        uint256 agentBalanceBefore = token.balanceOf(agent);
        
        vm.prank(poster);
        escrow.approveSubmission(taskId);
        
        uint256 expectedPayout = amount - (amount * 250 / 10000);
        assertEq(token.balanceOf(agent) - agentBalanceBefore, expectedPayout);
    }
    
    // ============ Auto Complete Tests ============
    
    function test_AutoComplete() public {
        _createClaimAndSubmitTask(address(0));
        
        // Warp past deadline + dispute window
        vm.warp(deadline + 3 days + 1);
        
        uint256 agentBalanceBefore = agent.balance;
        
        escrow.autoComplete(taskId);
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.Completed));
        
        uint256 expectedPayout = amount - (amount * 250 / 10000);
        assertEq(agent.balance - agentBalanceBefore, expectedPayout);
    }
    
    function test_RevertWhen_AutoCompleteBeforeWindow() public {
        _createClaimAndSubmitTask(address(0));
        
        vm.expectRevert("Dispute window active");
        escrow.autoComplete(taskId);
    }
    
    // ============ Dispute Tests ============
    
    function test_OpenDispute_ByPoster() public {
        _createClaimAndSubmitTask(address(0));
        
        vm.prank(poster);
        escrow.openDispute(taskId, "Work not acceptable");
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.Disputed));
        
        TaskEscrow.Dispute memory dispute = escrow.getDispute(taskId);
        assertEq(dispute.initiator, poster);
        assertEq(dispute.reason, "Work not acceptable");
    }
    
    function test_OpenDispute_ByAgent() public {
        _createClaimAndSubmitTask(address(0));
        
        vm.prank(agent);
        escrow.openDispute(taskId, "Poster not responding");
        
        TaskEscrow.Dispute memory dispute = escrow.getDispute(taskId);
        assertEq(dispute.initiator, agent);
    }
    
    function test_ResolveDispute_FavorAgent() public {
        _createClaimAndSubmitTask(address(0));
        
        vm.prank(poster);
        escrow.openDispute(taskId, "Dispute reason");
        
        uint256 agentBalanceBefore = agent.balance;
        
        vm.prank(arbitrator);
        escrow.resolveDispute(taskId, true);
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.Completed));
        
        uint256 expectedPayout = amount - (amount * 250 / 10000);
        assertEq(agent.balance - agentBalanceBefore, expectedPayout);
    }
    
    function test_ResolveDispute_FavorPoster() public {
        _createClaimAndSubmitTask(address(0));
        
        vm.prank(poster);
        escrow.openDispute(taskId, "Dispute reason");
        
        uint256 posterBalanceBefore = poster.balance;
        
        vm.prank(arbitrator);
        escrow.resolveDispute(taskId, false);
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.Refunded));
        
        // Full refund (no fee)
        assertEq(poster.balance - posterBalanceBefore, amount);
    }
    
    function test_RevertWhen_ResolveDisputeNotArbitrator() public {
        _createClaimAndSubmitTask(address(0));
        
        vm.prank(poster);
        escrow.openDispute(taskId, "Dispute reason");
        
        vm.prank(poster);
        vm.expectRevert("Not arbitrator");
        escrow.resolveDispute(taskId, true);
    }
    
    // ============ Cancel Task Tests ============
    
    function test_CancelTask() public {
        vm.prank(poster);
        escrow.createTask{value: amount}(taskId, address(0), amount, deadline);
        
        uint256 posterBalanceBefore = poster.balance;
        
        vm.prank(poster);
        escrow.cancelTask(taskId);
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.Cancelled));
        assertEq(poster.balance - posterBalanceBefore, amount);
    }
    
    function test_RevertWhen_CancelClaimedTask() public {
        _createAndClaimTask();
        
        vm.prank(poster);
        vm.expectRevert("Cannot cancel");
        escrow.cancelTask(taskId);
    }
    
    // ============ Refund Expired Tests ============
    
    function test_RefundExpired_Funded() public {
        vm.prank(poster);
        escrow.createTask{value: amount}(taskId, address(0), amount, deadline);
        
        vm.warp(deadline + 1);
        
        uint256 posterBalanceBefore = poster.balance;
        
        escrow.refundExpired(taskId);
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.Refunded));
        assertEq(poster.balance - posterBalanceBefore, amount);
    }
    
    function test_RefundExpired_InProgress() public {
        _createAndClaimTask();
        
        vm.warp(deadline + 1);
        
        uint256 posterBalanceBefore = poster.balance;
        
        escrow.refundExpired(taskId);
        
        TaskEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.state), uint(TaskEscrow.TaskState.Refunded));
        assertEq(poster.balance - posterBalanceBefore, amount);
    }
    
    // ============ Admin Tests ============
    
    function test_SetArbitrator() public {
        address newArbitrator = address(0x99);
        escrow.setArbitrator(newArbitrator);
        assertEq(escrow.arbitrator(), newArbitrator);
    }
    
    function test_SetProtocolFee() public {
        escrow.setProtocolFee(500); // 5%
        assertEq(escrow.protocolFee(), 500);
    }
    
    function test_RevertWhen_FeeTooHigh() public {
        vm.expectRevert("Fee too high");
        escrow.setProtocolFee(1500); // 15%
    }
    
    function test_WithdrawFees() public {
        _createClaimAndSubmitTask(address(0));
        
        vm.prank(poster);
        escrow.approveSubmission(taskId);
        
        uint256 expectedFee = amount * 250 / 10000;
        assertEq(escrow.collectedFees(address(0)), expectedFee);
        
        address payable recipient = payable(address(0x999));
        uint256 recipientBalanceBefore = recipient.balance;
        escrow.withdrawFees(address(0), recipient);
        
        assertEq(recipient.balance - recipientBalanceBefore, expectedFee);
        assertEq(escrow.collectedFees(address(0)), 0);
    }
    
    // ============ Helpers ============
    
    function _createAndClaimTask() internal {
        vm.prank(poster);
        escrow.createTask{value: amount}(taskId, address(0), amount, deadline);
        
        vm.prank(agent);
        escrow.claimTask(taskId);
    }
    
    function _createClaimAndSubmitTask(address paymentToken) internal {
        if (paymentToken == address(0)) {
            vm.prank(poster);
            escrow.createTask{value: amount}(taskId, address(0), amount, deadline);
        } else {
            vm.prank(poster);
            escrow.createTask(taskId, paymentToken, amount, deadline);
        }
        
        vm.prank(agent);
        escrow.claimTask(taskId);
        
        vm.prank(agent);
        escrow.submitWork(taskId, "ipfs://submission");
    }
}
