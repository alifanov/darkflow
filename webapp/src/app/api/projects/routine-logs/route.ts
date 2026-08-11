import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

// Run history for one routine, newest first.
//
// This exists for the observation threshold (P4): an improvement is only worth
// filing once the same observation has survived 3 consecutive runs. A clean run
// deliberately writes nothing to the daily log, so the log alone cannot tell
// "ran 3 times, saw it every time" from "ran 10 times, saw it 3 times". The run
// timestamps here are the other half of that count.
export async function GET(req: NextRequest) {
  const sp = req.nextUrl.searchParams;
  const repoUrl = sp.get("repoUrl");
  const routine = sp.get("routine");
  if (!repoUrl) {
    return NextResponse.json({ error: "repoUrl is required" }, { status: 400 });
  }

  const project = await prisma.project.findUnique({
    where: { repoUrl },
    select: { id: true },
  });
  if (!project) {
    return NextResponse.json({ error: "project not found for repoUrl" }, { status: 404 });
  }

  const limitRaw = parseInt(sp.get("limit") ?? "10", 10);
  const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 100) : 10;

  const logs = await prisma.routineLog.findMany({
    where: { projectId: project.id, ...(routine ? { routine } : {}) },
    orderBy: { timestamp: "desc" },
    take: limit,
    select: { routine: true, summary: true, timestamp: true },
  });

  return NextResponse.json(
    logs.map((l) => ({
      routine: l.routine,
      summary: l.summary,
      timestamp: l.timestamp.toISOString(),
    })),
  );
}
