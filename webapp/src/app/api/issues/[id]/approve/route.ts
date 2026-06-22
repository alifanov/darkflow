import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { applyStatusToGitHub } from "@/lib/github-status";

export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const issue = await prisma.issue.findUnique({ where: { id }, select: { id: true } });
    if (!issue) {
      return NextResponse.json({ error: "Issue not found" }, { status: 404 });
    }
    // Non-optimistic: push to GitHub first, only touch the DB once it succeeds.
    const r = await applyStatusToGitHub(id, "approved");
    if (!r.ok) {
      return NextResponse.json({ error: `GitHub update failed: ${r.error}` }, { status: 502 });
    }
    await prisma.issue.updateMany({
      where: { id },
      data: { status: "approved", pendingStatus: null, pendingStatusAt: null },
    });
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("approve issue:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
