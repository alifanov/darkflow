import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const issue = await prisma.issue.findUnique({ where: { id } });
  if (!issue) {
    return NextResponse.json({ error: "Issue not found" }, { status: 404 });
  }

  await prisma.issue.update({
    where: { id },
    data: {
      needsHuman: false,
      pendingStatus: "closed",
      pendingStatusAt: new Date(),
    },
  });
  return NextResponse.json({ ok: true });
}
