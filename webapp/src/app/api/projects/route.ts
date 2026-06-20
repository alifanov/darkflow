import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

// Discovery endpoint for the global Dark Flow worker. It polls this on every
// tick to learn which projects to service and where they live on disk. Only
// projects with a Local path set are returned — without one the worker can't
// cd into the repo to dispatch routines.
export async function GET() {
  const projects = await prisma.project.findMany({
    where: { localPath: { not: null } },
    select: { repoUrl: true, name: true, slug: true, localPath: true },
    orderBy: { name: "asc" },
  });

  // Drop empty-string paths (a cleared UI field can persist as "" rather than null).
  const usable = projects.filter((p) => p.localPath && p.localPath.trim() !== "");

  return NextResponse.json(usable);
}
