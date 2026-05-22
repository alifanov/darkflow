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
  area?: string;
  source?: string;
  effort?: string;
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
  timestamp?: string;
}

interface IngestBody {
  repoUrl: string;
  name?: string;
  branch?: string;
  language?: string;
  mergeStrategy?: string;
  modules?: string[];
  issues?: IngestIssue[];
  analytics?: IngestAnalytics;
  security?: IngestSecurity;
  architecture?: IngestArchitecture;
  logs?: IngestLog[];
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
      lastSyncedAt: new Date(),
    },
    update: {
      name: body.name ?? undefined,
      branch: body.branch ?? undefined,
      language: body.language ?? undefined,
      mergeStrategy: body.mergeStrategy ?? undefined,
      modules: body.modules ?? undefined,
      lastSyncedAt: new Date(),
    },
  });

  if (body.issues !== undefined) {
    await prisma.issue.deleteMany({ where: { projectId: project.id } });
    if (body.issues.length > 0) {
      await prisma.issue.createMany({
        data: body.issues.map((i) => ({
          projectId: project.id,
          number: i.number,
          title: i.title,
          body: i.body ?? null,
          state: i.state ?? "open",
          url: i.url ?? null,
          status: i.status ?? "none",
          priority: i.priority ?? null,
          area: i.area ?? null,
          source: i.source ?? null,
          effort: i.effort ?? null,
        })),
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
        timestamp: l.timestamp ? new Date(l.timestamp) : new Date(),
      })),
    });
  }

  return NextResponse.json({ ok: true, projectId: project.id });
}
