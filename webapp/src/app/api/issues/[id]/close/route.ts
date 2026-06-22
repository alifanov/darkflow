import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { applyStatusToGitHub } from "@/lib/github-status";

export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const result = await prisma.issue.updateMany({
      where: { id },
      data: {
        // Optimistically close in the DB (mirrors reject) so the row leaves the
        // open-issues list on refresh; the worker reconciles via pendingStatus
        // if the synchronous gh close below fails.
        state: "closed",
        needsHuman: false,
        pendingStatus: "closed",
        pendingStatusAt: new Date(),
      },
    });
    if (result.count === 0) {
      return NextResponse.json({ error: "Issue not found" }, { status: 404 });
    }
    if (await applyStatusToGitHub(id, "closed")) {
      await prisma.issue.updateMany({
        where: { id },
        data: { pendingStatus: null, pendingStatusAt: null },
      });
    }
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("close issue:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
