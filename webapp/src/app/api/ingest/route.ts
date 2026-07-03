import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

interface IngestAnalytics {
  usersTotal?: number;
  visitors7d?: number;
  revenue7d?: number;
  adsSpend7d?: number;
  currency?: string;
}

interface IngestSecurity {
  openIssues: number;
  criticalOpen: number;
  status: string;
}

interface IngestArchitecture {
  openIssues: number;
  status: string;
}

interface IngestLog {
  routine: string;
  summary: string;
  output?: string;
  model?: string;
  costUsd?: number;
  totalTokens?: number;
  timestamp?: string;
}

interface IngestRoutine {
  name: string;
  cron?: string | null;
  model?: string | null;
  engine?: string | null;
  enabled?: boolean;
  permissionMode?: string | null;
}

interface IngestCommit {
  sha: string;
  message: string;
  author: string;
  email?: string | null;
  committedAt: string;
  url?: string | null;
}

interface IngestAlert {
  key: string;
  title: string;
  severity?: string;
  details?: string | null;
}

interface IngestBody {
  repoUrl: string;
  name?: string;
  localPath?: string;
  domain?: string;
  branch?: string;
  language?: string;
  mergeStrategy?: string;
  modules?: string[];
  obsTool?: string;
  obsUrl?: string;
  posthogProjectId?: string;
  darkflowVersion?: string;
  analytics?: IngestAnalytics;
  security?: IngestSecurity;
  architecture?: IngestArchitecture;
  logs?: IngestLog[];
  routines?: IngestRoutine[];
  commits?: IngestCommit[];
  alerts?: IngestAlert[];
}

export async function POST(req: NextRequest) {
  let body: IngestBody;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const { repoUrl } = body;
  if (!repoUrl) {
    return NextResponse.json({ error: "repoUrl is required" }, { status: 400 });
  }

  const project = await prisma.project.upsert({
    where: { repoUrl },
    create: {
      repoUrl,
      name: body.name ?? repoUrl.split("/").pop() ?? repoUrl,
      // The global worker discovers projects by their localPath, so seed it on
      // first contact. After that the Web UI is the source of truth (see below).
      localPath: body.localPath?.trim() || null,
      domain: body.domain || null,
      branch: body.branch ?? "main",
      language: body.language ?? "English",
      mergeStrategy: body.mergeStrategy ?? "pr",
      modules: body.modules ?? [],
      obsTool: body.obsTool || null,
      obsUrl: body.obsUrl || null,
      posthogProjectId: body.posthogProjectId || null,
      darkflowVersion: body.darkflowVersion || null,
      lastSyncedAt: new Date(),
    },
    update: {
      // Settings fields (branch, language, mergeStrategy, modules) are intentionally
      // NOT updated here — the Web UI is the source of truth for settings after
      // initial seeding. Only operational fields are updated on each sync.
      darkflowVersion: body.darkflowVersion || undefined,
      lastSyncedAt: new Date(),
    },
  });

  // Backfill localPath when an install/sync supplies it but the stored value is
  // still empty (e.g. the project was first created by a worker sync before the
  // installer registered its path). A non-empty UI-set value always wins, so we
  // never overwrite one here.
  const incomingLocalPath = body.localPath?.trim();
  if (incomingLocalPath && !project.localPath) {
    await prisma.project.update({
      where: { id: project.id },
      data: { localPath: incomingLocalPath },
    });
  }

  if (body.analytics) {
    await prisma.analyticsSnapshot.create({
      data: {
        projectId: project.id,
        usersTotal: body.analytics.usersTotal ?? null,
        visitors7d: body.analytics.visitors7d ?? null,
        revenue7d: body.analytics.revenue7d ?? null,
        adsSpend7d: body.analytics.adsSpend7d ?? null,
        currency: body.analytics.currency ?? "USD",
      },
    });
  }

  if (body.security) {
    // Whitelist known schema fields — the worker LLM sometimes emits extra
    // keys beyond the spec, and spreading raw JSON would crash the upsert.
    const security = {
      openIssues: body.security.openIssues ?? 0,
      criticalOpen: body.security.criticalOpen ?? 0,
      status: body.security.status ?? "ok",
    };
    await prisma.securityStatus.upsert({
      where: { projectId: project.id },
      create: { projectId: project.id, ...security },
      update: security,
    });
  }

  if (body.architecture) {
    // Whitelist known schema fields — the worker LLM sometimes emits extra
    // keys (e.g. lastReview, newIssues) beyond the spec, and spreading raw
    // JSON would crash the upsert.
    const architecture = {
      openIssues: body.architecture.openIssues ?? 0,
      status: body.architecture.status ?? "ok",
    };
    await prisma.architectureStatus.upsert({
      where: { projectId: project.id },
      create: { projectId: project.id, ...architecture },
      update: architecture,
    });
  }

  if (body.logs && body.logs.length > 0) {
    await prisma.routineLog.createMany({
      data: body.logs.map((l) => ({
        projectId: project.id,
        routine: l.routine,
        summary: l.summary,
        output: l.output ?? null,
        model: l.model ?? null,
        costUsd: l.costUsd ?? null,
        totalTokens: l.totalTokens ?? null,
        timestamp: l.timestamp ? new Date(l.timestamp) : new Date(),
      })),
    });
  }

  if (body.routines !== undefined) {
    // Seed-only: only write routineConfigs if the project has none yet.
    // Once seeded, routine configs are managed exclusively via the Web UI Settings tab
    // so that user edits aren't clobbered on every worker sync.
    const existingCount = await prisma.routineConfig.count({ where: { projectId: project.id } });
    if (existingCount === 0 && body.routines.length > 0) {
      await prisma.routineConfig.createMany({
        data: body.routines.map((r) => ({
          projectId: project.id,
          name: r.name,
          cron: r.cron ?? null,
          model: r.model ?? null,
          engine: r.engine ?? "claude",
          enabled: r.enabled ?? true,
          permissionMode: r.permissionMode ?? null,
        })),
      });
    }
  }

  if (body.commits && body.commits.length > 0) {
    await prisma.commit.createMany({
      data: body.commits.map((c) => ({
        projectId: project.id,
        sha: c.sha,
        message: c.message,
        author: c.author,
        email: c.email ?? null,
        committedAt: new Date(c.committedAt),
        url: c.url ?? null,
      })),
      skipDuplicates: true,
    });
  }

  if (body.alerts !== undefined) {
    const incomingKeys = body.alerts.map((a) => a.key);
    await prisma.projectAlert.deleteMany({
      where: { projectId: project.id, key: { notIn: incomingKeys } },
    });
    for (const a of body.alerts) {
      await prisma.projectAlert.upsert({
        where: { projectId_key: { projectId: project.id, key: a.key } },
        create: {
          projectId: project.id,
          key: a.key,
          title: a.title,
          severity: a.severity ?? "warning",
          details: a.details ?? null,
        },
        update: {
          title: a.title,
          severity: a.severity ?? "warning",
          details: a.details ?? null,
        },
      });
    }
  }

  return NextResponse.json({ ok: true, projectId: project.id });
}
