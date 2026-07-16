import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    let body: { until?: string | null };
    try {
      body = await req.json();
    } catch {
      return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
    }
    const until = body.until ? new Date(body.until) : null;
    if (until && isNaN(until.getTime())) {
      return NextResponse.json({ error: "until must be an ISO date" }, { status: 400 });
    }
    const result = await prisma.issue.updateMany({
      where: { id },
      data: { scheduledFor: until },
    });
    if (result.count === 0) {
      return NextResponse.json({ error: "Issue not found" }, { status: 404 });
    }
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("snooze issue:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
