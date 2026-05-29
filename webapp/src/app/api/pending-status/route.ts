import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(req: NextRequest) {
  const repoUrl = req.nextUrl.searchParams.get("repoUrl");
  if (!repoUrl) {
    return NextResponse.json({ error: "repoUrl is required" }, { status: 400 });
  }

  try {
    const project = await prisma.project.findUnique({
      where: { repoUrl },
      select: { id: true },
    });
    if (!project) {
      return NextResponse.json({ pending: [] });
    }

    const issues = await prisma.issue.findMany({
      where: { projectId: project.id, pendingStatus: { not: null } },
      select: { number: true, pendingStatus: true, pendingStatusAt: true, pendingComment: true },
    });

    return NextResponse.json({
      pending: issues.map((i) => ({
        number: i.number,
        pendingStatus: i.pendingStatus,
        pendingStatusAt: i.pendingStatusAt?.toISOString() ?? null,
        pendingComment: i.pendingComment ?? null,
      })),
    });
  } catch (err) {
    console.error("pending-status:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
