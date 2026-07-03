import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const result = await prisma.issue.updateMany({
      where: { id },
      // Approving overrides the needs-human gate — the worker excludes
      // needs-human from its queue, so leaving it on would make an approved
      // task silently never get picked up.
      data: { status: "approved", needsHuman: false },
    });
    if (result.count === 0) {
      return NextResponse.json({ error: "Issue not found" }, { status: 404 });
    }
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("approve issue:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
