import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const count = await prisma.issue.count({
      where: {
        status: { not: "closed" },
        OR: [{ needsHuman: true }, { status: "proposed" }],
      },
    });
    return NextResponse.json({ count });
  } catch (err) {
    console.error("needs-human-count:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
