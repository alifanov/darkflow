import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(req: NextRequest) {
  let body: { repoUrl?: string; status?: string; routine?: string | null; name?: string; darkflowVersion?: string; configSyncedAt?: string | null };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const { repoUrl, status, routine, name, darkflowVersion, configSyncedAt } = body;
  if (!repoUrl || !status) {
    return NextResponse.json({ error: "repoUrl and status required" }, { status: 400 });
  }

  // Parse the worker's last successful config-sync timestamp (ISO-8601). Absent or
  // unparseable → leave whatever we already have rather than nulling it out.
  let configSyncedAtDate: Date | undefined;
  if (configSyncedAt) {
    const d = new Date(configSyncedAt);
    if (!Number.isNaN(d.getTime())) configSyncedAtDate = d;
  }

  // Auto-register project on first heartbeat so the worker doesn't need a
  // prior install/update run to appear in the UI.
  const project = await prisma.project.upsert({
    where: { repoUrl },
    create: {
      repoUrl,
      name: name ?? repoUrl.split("/").pop() ?? repoUrl,
      darkflowVersion: darkflowVersion || null,
    },
    update: {
      ...(darkflowVersion ? { darkflowVersion } : {}),
    },
  });

  await prisma.workerStatus.upsert({
    where: { projectId: project.id },
    create: { projectId: project.id, status, routine: routine ?? null, configSyncedAt: configSyncedAtDate ?? null },
    update: { status, routine: routine ?? null, ...(configSyncedAtDate ? { configSyncedAt: configSyncedAtDate } : {}) },
  });

  return NextResponse.json({ ok: true });
}
