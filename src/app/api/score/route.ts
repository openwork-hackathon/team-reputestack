import { NextResponse } from "next/server";
import { scoreForWallet } from "../../../lib/score";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const wallet = searchParams.get("wallet") || "0x0000";

  const result = scoreForWallet(wallet);

  return NextResponse.json({
    ...result,
    lastUpdated: new Date().toISOString(),
    source: "mock-receipts"
  });
}
