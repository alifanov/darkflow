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
    // Non-optimistic: close on GitHub first, then drop the row. Closed issues
    // don't live in the DB anymore (ingest skips them), so deletion is durable.
    const r = await applyStatusToGitHub(id, "closed");
    if (!r.ok) {
      return NextResponse.json({ error: `GitHub update failed: ${r.error}` }, { status: 502 });
    }
    await prisma.issue.deleteMany({ where: { id } });
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("close issue:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
