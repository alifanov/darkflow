import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(req: NextRequest) {
  let body: { repoUrl?: string; status?: string; routine?: string | null; name?: string; darkflowVersion?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const { repoUrl, status, routine, name, darkflowVersion } = body;
  if (!repoUrl || !status) {
    return NextResponse.json({ error: "repoUrl and status required" }, { status: 400 });
  }

  // Auto-register project on first heartbeat so the worker doesn't need a
  // prior install/update run to appear in the UI.
  const project = await prisma.project.upsert({
    where: { repoUrl },
    create: {
      repoUrl,
      name: name ?? repoUrl.split("/").pop() ?? repoUrl,
      darkflowVersion: darkflowVersion ?? null,
    },
    update: {
      ...(darkflowVersion !== undefined ? { darkflowVersion } : {}),
    },
  });

  await prisma.workerStatus.upsert({
    where: { projectId: project.id },
    create: { projectId: project.id, status, routine: routine ?? null },
    update: { status, routine: routine ?? null },
  });

  return NextResponse.json({ ok: true });
}
