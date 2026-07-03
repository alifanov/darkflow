import { NextRequest, NextResponse } from "next/server";
import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import type { IssueComment } from "@/components/IssueTableRow";

export const dynamic = "force-dynamic";

export async function POST(req: NextRequest, { params }: { params: Promise<{ number: string }> }) {
  const { number } = await params;
  const repoUrl = req.nextUrl.searchParams.get("repoUrl");
  if (!repoUrl) {
    return NextResponse.json({ error: "repoUrl is required" }, { status: 400 });
  }
  let body: { body: string; author?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }
  if (!body.body) {
    return NextResponse.json({ error: "body is required" }, { status: 400 });
  }

  const project = await prisma.project.findUnique({ where: { repoUrl }, select: { id: true } });
  if (!project) {
    return NextResponse.json({ error: "project not found for repoUrl" }, { status: 404 });
  }

  const task = await prisma.issue.findUnique({
    where: { projectId_number: { projectId: project.id, number: Number(number) } },
    select: { id: true, comments: true },
  });
  if (!task) {
    return NextResponse.json({ error: "task not found" }, { status: 404 });
  }

  const comments = ((task.comments as IssueComment[] | null) ?? []).concat([
    { author: body.author ?? "darkflow", body: body.body, createdAt: new Date().toISOString() },
  ]);
  await prisma.issue.update({ where: { id: task.id }, data: { comments: comments as unknown as Prisma.InputJsonValue } });

  return NextResponse.json({ ok: true, comments });
}
