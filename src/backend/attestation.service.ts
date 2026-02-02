import { ReputationReceipt, AgentScore } from './schema';

/**
 * Service for managing Reputation Receipts (Attestations).
 */
export class AttestationService {
  private receipts: ReputationReceipt[] = [];

  /**
   * Generates a new Reputation Receipt based on a task outcome.
   */
  public generateReceipt(params: Omit<ReputationReceipt, 'timestamp' | 'reputationPoints'>): ReputationReceipt {
    const reputationPoints = this.calculatePoints(params.outcome, params.taskCategory);
    
    const receipt: ReputationReceipt = {
      ...params,
      timestamp: Date.now(),
      reputationPoints,
    };

    this.receipts.push(receipt);
    console.log(`[AttestationService] Generated receipt for agent ${receipt.agentId}: ${receipt.reputationPoints} points.`);
    
    return receipt;
  }

  /**
   * Logic to calculate reputation points based on outcome and category.
   * Basic logic:
   * - Success: +10 points
   * - Failure: -5 points
   * - Disputed: -10 points
   */
  private calculatePoints(outcome: ReputationReceipt['outcome'], category: ReputationReceipt['taskCategory']): number {
    let base = 0;
    switch (outcome) {
      case 'success':
        base = 10;
        break;
      case 'failure':
        base = -5;
        break;
      case 'disputed':
        base = -10;
        break;
    }
    return base;
  }

  /**
   * Returns all receipts for a specific agent.
   */
  public getAgentReceipts(agentId: string): ReputationReceipt[] {
    return this.receipts.filter(r => r.agentId === agentId);
  }

  /**
   * Calculates the current AgentScore based on their history.
   */
  public getAgentScore(agentId: string): AgentScore {
    const agentReceipts = this.getAgentReceipts(agentId);
    
    if (agentReceipts.length === 0) {
      return {
        agentId,
        totalReputation: 0,
        successRate: 0,
        disputeCount: 0,
        badges: [],
        level: 1
      };
    }

    const totalReputation = agentReceipts.reduce((acc, r) => acc + r.reputationPoints, 0);
    const successCount = agentReceipts.filter(r => r.outcome === 'success').length;
    const disputeCount = agentReceipts.filter(r => r.outcome === 'disputed').length;
    const successRate = (successCount / agentReceipts.length) * 100;
    
    // Simple level logic: 1 level per 50 points
    const level = Math.max(1, Math.floor(totalReputation / 50) + 1);

    return {
      agentId,
      totalReputation,
      successRate,
      disputeCount,
      badges: [], // TODO: Integrate NFT badge logic
      level
    };
  }
}
