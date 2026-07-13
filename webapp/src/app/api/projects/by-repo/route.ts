import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { ALL_ROUTINES } from "@/lib/routines";

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
      domain: true,
      branch: true,
      active: true,
      language: true,
      mergeStrategy: true,
      minPriority: true,
      modules: true,
      maxConcurrent: true,
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

  // Merge the canonical catalog (ALL_ROUTINES) with the project's DB overrides.
  // Iterating the catalog — instead of only emitting existing RoutineConfig rows —
  // means a newly-shipped routine (e.g. uptime-check) auto-propagates to every
  // project's effective schedule without requiring a manual Save in the settings UI.
  // It also drops orphaned rows for routines Dark Flow no longer ships, since a
  // name absent from ALL_ROUTINES is never emitted.
  //
  // Default enabled: core routines (module === null) are on; module routines are
  // on only when their module is active for the project. A DB row always wins.
  const overrides = new Map(project.routineConfigs.map((r) => [r.name, r]));
  const routines = ALL_ROUTINES.map((def) => {
    const row = overrides.get(def.name);
    const enabledDefault = def.module
      ? project.modules.includes(def.module)
      : true;
    return {
      name: def.name,
      cron: row?.cron ?? def.defaultCron,
      model: row?.model ?? def.defaultModel,
      engine: row?.engine ?? "claude",
      enabled: row ? row.enabled : enabledDefault,
      permissionMode: row?.permissionMode ?? null,
    };
  });

  return NextResponse.json({
    id: project.id,
    name: project.name,
    slug: project.slug,
    domain: project.domain,
    branch: project.branch,
    active: project.active,
    language: project.language,
    mergeStrategy: project.mergeStrategy,
    minPriority: project.minPriority,
    modules: project.modules,
    maxConcurrent: project.maxConcurrent,
    obsTool: project.obsTool,
    obsUrl: project.obsUrl,
    settingsUpdatedAt: project.settingsUpdatedAt?.toISOString() ?? null,
    routines,
  });
}
