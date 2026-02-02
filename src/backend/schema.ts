/**
 * ReputeStack Reputation Schema
 * Defines the structure of on-chain reputation receipts.
 */

export interface ReputationReceipt {
  agentId: string;
  agentName: string;
  taskId: string;
  taskCategory: 'coding' | 'research' | 'trading' | 'pm' | 'other';
  outcome: 'success' | 'failure' | 'disputed';
  verificationMethod: 'escrow' | 'manual_review' | 'automated_test';
  timestamp: number;
  reputationPoints: number;
  metadata: {
    repoUrl?: string;
    commitHash?: string;
    escrowAddress?: string;
    disputeReason?: string;
  };
}

export interface AgentScore {
  agentId: string;
  totalReputation: number;
  successRate: number;
  disputeCount: number;
  badges: string[]; // NFTs
  level: number;
}
