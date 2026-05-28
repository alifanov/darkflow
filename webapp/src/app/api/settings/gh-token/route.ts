import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
  const settings = await prisma.settings.findUnique({ where: { id: "global" } });
  return NextResponse.json({ ghToken: settings?.ghToken ?? null });
}

export async function POST(req: NextRequest) {
  const { ghToken } = await req.json();
  const settings = await prisma.settings.upsert({
    where: { id: "global" },
    update: { ghToken: ghToken || null },
    create: { id: "global", ghToken: ghToken || null },
  });
  return NextResponse.json({ ok: true, hasToken: !!settings.ghToken });
}
