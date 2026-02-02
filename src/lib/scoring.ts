// Scoring Engine for ReputeStack
// Calculates reputation scores from on-chain attestations

export interface Attestation {
  agentId: string;
  taskId: string;
  outcome: 'success' | 'failure' | 'disputed';
  timestamp: number;
  escrowAmount: bigint;
  chain: 'base' | 'ethereum';
}

export interface Score {
  agentId: string;
  totalTasks: number;
  successRate: number; // 0-1
  volumeScore: number; // weighted by escrow
  disputeRate: number; // 0-1, lower is better
  streakDays: number;
  lastActive: number;
}

const WEIGHTS = {
  success: 1.0,
  failure: -0.5,
  disputed: -0.25,
};

export function calculateScore(attestations: Attestation[]): Score {
  if (attestations.length === 0) {
    return {
      agentId: '',
      totalTasks: 0,
      successRate: 0,
      volumeScore: 0,
      disputeRate: 0,
      streakDays: 0,
      lastActive: 0,
    };
  }

  const agentId = attestations[0].agentId;
  const totalTasks = attestations.length;
  
  const successes = attestations.filter(a => a.outcome === 'success').length;
  const disputes = attestations.filter(a => a.outcome === 'disputed').length;
  
  const successRate = successes / totalTasks;
  const disputeRate = disputes / totalTasks;
  
  // Volume score: sum of successful escrow amounts / 1e18
  const volumeScore = Number(
    attestations
      .filter(a => a.outcome === 'success')
      .reduce((sum, a) => sum + a.escrowAmount, 0n) / BigInt(1e18)
  );
  
  // Streak calculation
  const timestamps = attestations.map(a => a.timestamp).sort((a, b) => b - a);
  const lastActive = timestamps[0];
  
  let streakDays = 0;
  const dayMs = 24 * 60 * 60 * 1000;
  for (let i = 0; i < timestamps.length - 1; i++) {
    const diff = timestamps[i] - timestamps[i + 1];
    if (diff <= dayMs * 2) { // Allow 1 day gap
      streakDays++;
    } else {
      break;
    }
  }

  return {
    agentId,
    totalTasks,
    successRate,
    volumeScore,
    disputeRate,
    streakDays,
    lastActive,
  };
}

// Composite score for ranking (0-100)
export function compositeScore(score: Score): number {
  if (score.totalTasks === 0) return 0;
  
  const successWeight = 40;
  const volumeWeight = 30;
  const streakWeight = 20;
  const disputePenalty = 10;
  
  const successComponent = score.successRate * successWeight;
  const volumeComponent = Math.min(score.volumeScore / 100, 1) * volumeWeight;
  const streakComponent = Math.min(score.streakDays / 30, 1) * streakWeight;
  const disputeComponent = (1 - score.disputeRate) * disputePenalty;
  
  return Math.round(
    successComponent + volumeComponent + streakComponent + disputeComponent
  );
}
