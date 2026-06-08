import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { KNOWN_ROUTINE_NAMES } from "@/lib/routines";

export async function GET(req: NextRequest) {
  const repoUrl = req.nextUrl.searchParams.get("repoUrl");
  if (!repoUrl) {
    return NextResponse.json({ error: "repoUrl is required" }, { status: 400 });
  }

  const project = await prisma.project.findUnique({
    where: { repoUrl },
    select: {
      id: true,
      name: true,
      slug: true,
      branch: true,
      language: true,
      mergeStrategy: true,
      modules: true,
      maxConcurrent: true,
      posthogProjectId: true,
      obsTool: true,
      obsUrl: true,
      settingsUpdatedAt: true,
      routineConfigs: {
        orderBy: { name: "asc" },
        select: {
          name: true,
          cron: true,
          model: true,
          engine: true,
          enabled: true,
          permissionMode: true,
        },
      },
    },
  });

  if (!project) {
    return NextResponse.json({ error: "Project not found" }, { status: 404 });
  }

  // Drop orphaned RoutineConfig rows for routines Dark Flow no longer ships.
  // A removed routine (e.g. coolify-check-logs) leaves a stale enabled row in the
  // DB; emitting it would write a `name: enabled: true` block into routines.yml
  // whose command file is gone, bricking the worker's preflight check.
  const routines = project.routineConfigs.filter((r) =>
    KNOWN_ROUTINE_NAMES.has(r.name)
  );

  return NextResponse.json({
    id: project.id,
    name: project.name,
    slug: project.slug,
    branch: project.branch,
    language: project.language,
    mergeStrategy: project.mergeStrategy,
    modules: project.modules,
    maxConcurrent: project.maxConcurrent,
    posthogProjectId: project.posthogProjectId,
    obsTool: project.obsTool,
    obsUrl: project.obsUrl,
    settingsUpdatedAt: project.settingsUpdatedAt?.toISOString() ?? null,
    routines,
  });
}
