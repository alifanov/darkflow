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
    // Reject closes the GitHub issue; on success drop the row (closed issues
    // don't live in the DB anymore — see ingest).
    const r = await applyStatusToGitHub(id, "rejected");
    if (!r.ok) {
      return NextResponse.json({ error: `GitHub update failed: ${r.error}` }, { status: 502 });
    }
    await prisma.issue.deleteMany({ where: { id } });
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("reject issue:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
