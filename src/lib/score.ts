import receipts from "../../data/receipts.json";

type Receipt = {
  agent: string;
  client: string;
  jobId: number;
  score: number;
  disputed: boolean;
};

export function scoreForWallet(wallet: string) {
  const norm = wallet.toLowerCase();
  const agentReceipts = (receipts as Receipt[]).filter(r => r.agent.toLowerCase() === norm);

  if (agentReceipts.length === 0) {
    return {
      wallet,
      score: 0,
      tier: "Unranked",
      receipts: 0,
      disputes: 0
    };
  }

  const receiptsCount = agentReceipts.length;
  const disputes = agentReceipts.filter(r => r.disputed).length;
  const avg = Math.round(agentReceipts.reduce((s, r) => s + r.score, 0) / receiptsCount);
  const penalty = disputes * 8;
  const finalScore = Math.max(0, Math.min(100, avg - penalty));

  const tier = finalScore >= 85 ? "A" : finalScore >= 70 ? "B" : finalScore >= 55 ? "C" : "D";

  return {
    wallet,
    score: finalScore,
    tier,
    receipts: receiptsCount,
    disputes
  };
}
