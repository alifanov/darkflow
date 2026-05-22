import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { setIssueStatus } from "@/lib/github";

export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const issue = await prisma.issue.findUnique({
    where: { id },
    include: { project: true },
  });
  if (!issue) {
    return NextResponse.json({ error: "Issue not found" }, { status: 404 });
  }

  try {
    await setIssueStatus(issue.project.repoUrl, issue.number, "rejected");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: msg }, { status: 500 });
  }

  await prisma.issue.update({ where: { id }, data: { status: "rejected" } });
  return NextResponse.json({ ok: true });
}
