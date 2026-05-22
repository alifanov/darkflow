import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(req: NextRequest) {
  let body: { repoUrl?: string; status?: string; routine?: string | null };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const { repoUrl, status, routine } = body;
  if (!repoUrl || !status) {
    return NextResponse.json({ error: "repoUrl and status required" }, { status: 400 });
  }

  const project = await prisma.project.findUnique({ where: { repoUrl } });
  if (!project) {
    return NextResponse.json({ error: "Project not found" }, { status: 404 });
  }

  await prisma.workerStatus.upsert({
    where: { projectId: project.id },
    create: { projectId: project.id, status, routine: routine ?? null },
    update: { status, routine: routine ?? null },
  });

  return NextResponse.json({ ok: true });
}
