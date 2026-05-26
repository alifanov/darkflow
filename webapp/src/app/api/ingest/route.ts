import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

interface IngestIssue {
  number: number;
  title: string;
  body?: string;
  state?: string;
  url?: string;
  status?: string;
  priority?: string;
  source?: string;
}

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
  timestamp?: string;
}

interface IngestRoutine {
  name: string;
  cron?: string | null;
  model?: string | null;
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
  branch?: string;
  language?: string;
  mergeStrategy?: string;
  modules?: string[];
  darkflowVersion?: string;
  issues?: IngestIssue[];
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
      branch: body.branch ?? "main",
      language: body.language ?? "English",
      mergeStrategy: body.mergeStrategy ?? "pr",
      modules: body.modules ?? [],
      darkflowVersion: body.darkflowVersion || null,
      lastSyncedAt: new Date(),
    },
    update: {
      name: body.name ?? undefined,
      branch: body.branch ?? undefined,
      language: body.language ?? undefined,
      mergeStrategy: body.mergeStrategy ?? undefined,
      modules: body.modules ?? undefined,
      darkflowVersion: body.darkflowVersion || undefined,
      lastSyncedAt: new Date(),
    },
  });

  if (body.issues !== undefined) {
    // Snapshot pending statuses so we can preserve those still in flight
    // (worker hasn't yet applied them in GitHub).
    const existingPending = await prisma.issue.findMany({
      where: { projectId: project.id, pendingStatus: { not: null } },
      select: { number: true, pendingStatus: true, pendingStatusAt: true },
    });
    const pendingByNumber = new Map(
      existingPending.map((i) => [i.number, i])
    );

    await prisma.issue.deleteMany({ where: { projectId: project.id } });
    if (body.issues.length > 0) {
      await prisma.issue.createMany({
        data: body.issues.map((i) => {
          const newStatus = i.status ?? "none";
          const prevPending = pendingByNumber.get(i.number);
          // Keep pendingStatus only if GitHub hasn't applied it yet AND it isn't
          // stale (> 2 h old means the worker likely never ran — clear it).
          const TWO_HOURS_MS = 2 * 60 * 60 * 1000;
          const pendingFresh =
            prevPending?.pendingStatusAt &&
            Date.now() - prevPending.pendingStatusAt.getTime() < TWO_HOURS_MS;
          const stillPending =
            prevPending && prevPending.pendingStatus !== newStatus && pendingFresh
              ? prevPending
              : null;
          return {
            projectId: project.id,
            number: i.number,
            title: i.title,
            body: i.body ?? null,
            state: i.state ?? "open",
            url: i.url ?? null,
            status: newStatus,
            pendingStatus: stillPending?.pendingStatus ?? null,
            pendingStatusAt: stillPending?.pendingStatusAt ?? null,
            priority: i.priority ?? null,
            source: i.source ?? null,
          };
        }),
      });
    }
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
    await prisma.securityStatus.upsert({
      where: { projectId: project.id },
      create: { projectId: project.id, ...body.security },
      update: body.security,
    });
  }

  if (body.architecture) {
    await prisma.architectureStatus.upsert({
      where: { projectId: project.id },
      create: { projectId: project.id, ...body.architecture },
      update: body.architecture,
    });
  }

  if (body.logs && body.logs.length > 0) {
    await prisma.routineLog.createMany({
      data: body.logs.map((l) => ({
        projectId: project.id,
        routine: l.routine,
        summary: l.summary,
        output: l.output ?? null,
        timestamp: l.timestamp ? new Date(l.timestamp) : new Date(),
      })),
    });
  }

  if (body.routines !== undefined) {
    await prisma.routineConfig.deleteMany({ where: { projectId: project.id } });
    if (body.routines.length > 0) {
      await prisma.routineConfig.createMany({
        data: body.routines.map((r) => ({
          projectId: project.id,
          name: r.name,
          cron: r.cron ?? null,
          model: r.model ?? null,
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
