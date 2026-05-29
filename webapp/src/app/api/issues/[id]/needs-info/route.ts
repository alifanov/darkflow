import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await req.json();
    const question = typeof body.question === "string" ? body.question.trim() : "";
    if (!question) {
      return NextResponse.json({ error: "question is required" }, { status: 400 });
    }

    const result = await prisma.issue.updateMany({
      where: { id },
      data: {
        status: "needs-info",
        pendingStatus: "needs-info",
        pendingStatusAt: new Date(),
        pendingComment: question,
      },
    });
    if (result.count === 0) {
      return NextResponse.json({ error: "Issue not found" }, { status: 404 });
    }
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("needs-info issue:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
