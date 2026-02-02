import { NextRequest, NextResponse } from 'next/server';
import { calculateScore, compositeScore, Attestation } from '@/lib/scoring';

// In-memory store for MVP (replace with DB in production)
const attestations: Map<string, Attestation[]> = new Map();

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const agentId = searchParams.get('agentId');
  
  if (!agentId) {
    return NextResponse.json(
      { error: 'agentId required' },
      { status: 400 }
    );
  }
  
  const agentAttestations = attestations.get(agentId) || [];
  const score = calculateScore(agentAttestations);
  const composite = compositeScore(score);
  
  return NextResponse.json({
    agentId,
    score,
    composite,
    tier: getTier(composite),
    updatedAt: Date.now(),
  });
}

export async function POST(request: NextRequest) {
  const body = await request.json();
  const { agentId, taskId, outcome, escrowAmount, chain } = body;
  
  if (!agentId || !taskId || !outcome) {
    return NextResponse.json(
      { error: 'Missing required fields: agentId, taskId, outcome' },
      { status: 400 }
    );
  }
  
  const attestation: Attestation = {
    agentId,
    taskId,
    outcome,
    timestamp: Date.now(),
    escrowAmount: BigInt(escrowAmount || 0),
    chain: chain || 'base',
  };
  
  const existing = attestations.get(agentId) || [];
  attestations.set(agentId, [...existing, attestation]);
  
  return NextResponse.json({
    success: true,
    attestation: {
      ...attestation,
      escrowAmount: escrowAmount || '0',
    },
  });
}

function getTier(score: number): string {
  if (score >= 90) return 'legendary';
  if (score >= 75) return 'expert';
  if (score >= 60) return 'verified';
  if (score >= 40) return 'novice';
  return 'unverified';
}
