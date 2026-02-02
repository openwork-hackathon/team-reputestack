import { NextResponse } from "next/server";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const wallet = searchParams.get("wallet") || "0x0000";

  const mock = {
    wallet,
    score: 82,
    tier: "A",
    receipts: 12,
    disputes: 0,
    lastUpdated: new Date().toISOString()
  };

  return NextResponse.json(mock);
}
