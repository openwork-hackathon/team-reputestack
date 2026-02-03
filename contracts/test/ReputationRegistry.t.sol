// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";

contract ReputationRegistryTest is Test {
    ReputationRegistry public registry;
    
    address owner = address(this);
    address attester = address(0x1);
    address agent = address(0x2);
    
    function setUp() public {
        registry = new ReputationRegistry();
    }
    
    function test_InitialState() public view {
        assertEq(registry.owner(), owner);
        assertTrue(registry.authorizedAttesters(owner));
    }
    
    function test_AuthorizeAttester() public {
        registry.authorizeAttester(attester);
        assertTrue(registry.authorizedAttesters(attester));
    }
    
    function test_RevokeAttester() public {
        registry.authorizeAttester(attester);
        registry.revokeAttester(attester);
        assertFalse(registry.authorizedAttesters(attester));
    }
    
    function test_CreateReceipt_Success() public {
        bytes32 taskId = keccak256("task1");
        bytes32 agentId = keccak256("agent1");
        
        registry.createReceipt(
            agent,
            agentId,
            taskId,
            ReputationRegistry.Category.Coding,
            ReputationRegistry.Outcome.Success,
            ReputationRegistry.VerificationMethod.Escrow,
            "ipfs://metadata"
        );
        
        ReputationRegistry.AgentScore memory score = registry.getScore(agent);
        assertEq(score.successCount, 1);
        assertEq(score.failureCount, 0);
        assertEq(score.totalReputation, 10); // SUCCESS_POINTS
        assertEq(score.level, 1);
    }
    
    function test_CreateReceipt_Failure() public {
        bytes32 taskId = keccak256("task1");
        bytes32 agentId = keccak256("agent1");
        
        registry.createReceipt(
            agent,
            agentId,
            taskId,
            ReputationRegistry.Category.Coding,
            ReputationRegistry.Outcome.Failure,
            ReputationRegistry.VerificationMethod.Escrow,
            "ipfs://metadata"
        );
        
        ReputationRegistry.AgentScore memory score = registry.getScore(agent);
        assertEq(score.successCount, 0);
        assertEq(score.failureCount, 1);
        assertEq(score.totalReputation, -5); // FAILURE_POINTS
    }
    
    function test_CreateReceipt_Disputed() public {
        bytes32 taskId = keccak256("task1");
        bytes32 agentId = keccak256("agent1");
        
        registry.createReceipt(
            agent,
            agentId,
            taskId,
            ReputationRegistry.Category.Coding,
            ReputationRegistry.Outcome.Disputed,
            ReputationRegistry.VerificationMethod.Escrow,
            "ipfs://metadata"
        );
        
        ReputationRegistry.AgentScore memory score = registry.getScore(agent);
        assertEq(score.disputeCount, 1);
        assertEq(score.totalReputation, -10); // DISPUTED_POINTS
    }
    
    function test_RevertWhen_DuplicateTask() public {
        bytes32 taskId = keccak256("task1");
        bytes32 agentId = keccak256("agent1");
        
        registry.createReceipt(
            agent, agentId, taskId,
            ReputationRegistry.Category.Coding,
            ReputationRegistry.Outcome.Success,
            ReputationRegistry.VerificationMethod.Escrow,
            "ipfs://metadata"
        );
        
        vm.expectRevert("Task already processed");
        registry.createReceipt(
            agent, agentId, taskId,
            ReputationRegistry.Category.Coding,
            ReputationRegistry.Outcome.Success,
            ReputationRegistry.VerificationMethod.Escrow,
            "ipfs://metadata"
        );
    }
    
    function test_RevertWhen_UnauthorizedAttester() public {
        bytes32 taskId = keccak256("task1");
        bytes32 agentId = keccak256("agent1");
        
        vm.prank(attester);
        vm.expectRevert("Not authorized");
        registry.createReceipt(
            agent, agentId, taskId,
            ReputationRegistry.Category.Coding,
            ReputationRegistry.Outcome.Success,
            ReputationRegistry.VerificationMethod.Escrow,
            "ipfs://metadata"
        );
    }
    
    function test_GetSuccessRate() public {
        bytes32 agentId = keccak256("agent1");
        
        // 3 successes, 1 failure = 75% success rate
        for (uint i = 0; i < 3; i++) {
            registry.createReceipt(
                agent, agentId, keccak256(abi.encodePacked("success", i)),
                ReputationRegistry.Category.Coding,
                ReputationRegistry.Outcome.Success,
                ReputationRegistry.VerificationMethod.Escrow,
                "ipfs://metadata"
            );
        }
        
        registry.createReceipt(
            agent, agentId, keccak256("failure"),
            ReputationRegistry.Category.Coding,
            ReputationRegistry.Outcome.Failure,
            ReputationRegistry.VerificationMethod.Escrow,
            "ipfs://metadata"
        );
        
        uint256 rate = registry.getSuccessRate(agent);
        assertEq(rate, 7500); // 75% in basis points
    }
    
    function test_LevelProgression() public {
        bytes32 agentId = keccak256("agent1");
        
        // 5 successes = 50 points = level 2
        for (uint i = 0; i < 5; i++) {
            registry.createReceipt(
                agent, agentId, keccak256(abi.encodePacked("task", i)),
                ReputationRegistry.Category.Coding,
                ReputationRegistry.Outcome.Success,
                ReputationRegistry.VerificationMethod.Escrow,
                "ipfs://metadata"
            );
        }
        
        ReputationRegistry.AgentScore memory score = registry.getScore(agent);
        assertEq(score.totalReputation, 50);
        assertEq(score.level, 2); // 50 / 50 + 1 = 2
    }
    
    function test_GetReceipts() public {
        bytes32 agentId = keccak256("agent1");
        
        registry.createReceipt(
            agent, agentId, keccak256("task1"),
            ReputationRegistry.Category.Coding,
            ReputationRegistry.Outcome.Success,
            ReputationRegistry.VerificationMethod.Escrow,
            "ipfs://metadata1"
        );
        
        registry.createReceipt(
            agent, agentId, keccak256("task2"),
            ReputationRegistry.Category.Research,
            ReputationRegistry.Outcome.Success,
            ReputationRegistry.VerificationMethod.ManualReview,
            "ipfs://metadata2"
        );
        
        ReputationRegistry.Receipt[] memory receipts = registry.getReceipts(agent);
        assertEq(receipts.length, 2);
        assertEq(uint(receipts[0].category), uint(ReputationRegistry.Category.Coding));
        assertEq(uint(receipts[1].category), uint(ReputationRegistry.Category.Research));
    }
    
    function test_TransferOwnership() public {
        address newOwner = address(0x99);
        registry.transferOwnership(newOwner);
        assertEq(registry.owner(), newOwner);
    }
    
    function test_RevertWhen_TransferOwnershipNotOwner() public {
        vm.prank(attester);
        vm.expectRevert("Not owner");
        registry.transferOwnership(attester);
    }
}
