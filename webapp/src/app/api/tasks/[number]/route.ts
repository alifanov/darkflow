import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

async function findTask(repoUrl: string, number: number) {
  const project = await prisma.project.findUnique({ where: { repoUrl }, select: { id: true } });
  if (!project) return null;
  return prisma.issue.findUnique({ where: { projectId_number: { projectId: project.id, number } } });
}

export async function GET(req: NextRequest, { params }: { params: Promise<{ number: string }> }) {
  const { number } = await params;
  const repoUrl = req.nextUrl.searchParams.get("repoUrl");
  if (!repoUrl) {
    return NextResponse.json({ error: "repoUrl is required" }, { status: 400 });
  }
  const task = await findTask(repoUrl, Number(number));
  if (!task) {
    return NextResponse.json({ error: "task not found" }, { status: 404 });
  }
  return NextResponse.json(task);
}

interface PatchTaskBody {
  status?: string;
  priority?: string;
  needsHuman?: boolean;
  action?: string | null;
}

export async function PATCH(req: NextRequest, { params }: { params: Promise<{ number: string }> }) {
  const { number } = await params;
  const repoUrl = req.nextUrl.searchParams.get("repoUrl");
  if (!repoUrl) {
    return NextResponse.json({ error: "repoUrl is required" }, { status: 400 });
  }
  let body: PatchTaskBody;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const project = await prisma.project.findUnique({ where: { repoUrl }, select: { id: true } });
  if (!project) {
    return NextResponse.json({ error: "project not found for repoUrl" }, { status: 404 });
  }

  const data: Record<string, unknown> = {};
  if (body.status !== undefined) {
    data.status = body.status;
    if (body.status === "closed") data.closedAt = new Date();
  }
  if (body.priority !== undefined) data.priority = body.priority;
  if (body.needsHuman !== undefined) data.needsHuman = body.needsHuman;
  if (body.action !== undefined) data.action = body.action;

  try {
    const task = await prisma.issue.update({
      where: { projectId_number: { projectId: project.id, number: Number(number) } },
      data,
    });
    return NextResponse.json(task);
  } catch {
    return NextResponse.json({ error: "task not found" }, { status: 404 });
  }
}
