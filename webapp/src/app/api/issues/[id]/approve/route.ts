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
        status: "approved",
        pendingStatus: "approved",
        pendingStatusAt: new Date(),
      },
    });
    if (result.count === 0) {
      return NextResponse.json({ error: "Issue not found" }, { status: 404 });
    }
    if (await applyStatusToGitHub(id, "approved")) {
      await prisma.issue.updateMany({
        where: { id },
        data: { pendingStatus: null, pendingStatusAt: null },
      });
    }
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("approve issue:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
