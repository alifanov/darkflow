import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
  try {
    const settings = await prisma.settings.findUnique({ where: { id: "global" } });
    return NextResponse.json({ ghToken: settings?.ghToken ?? null });
  } catch (err) {
    console.error("gh-token GET:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const { ghToken } = await req.json();
    const settings = await prisma.settings.upsert({
      where: { id: "global" },
      update: { ghToken: ghToken || null },
      create: { id: "global", ghToken: ghToken || null },
    });
    return NextResponse.json({ ok: true, hasToken: !!settings.ghToken });
  } catch (err) {
    console.error("gh-token POST:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
