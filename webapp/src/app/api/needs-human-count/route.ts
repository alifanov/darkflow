import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export async function GET() {
  const count = await prisma.issue.count({
    where: {
      needsHuman: true,
      state: { in: ["OPEN", "open"] },
    },
  });
  return NextResponse.json({ count });
}
