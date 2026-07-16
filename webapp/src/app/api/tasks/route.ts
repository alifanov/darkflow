import { NextRequest, NextResponse } from "next/server";
import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { isTaskStatus, TASK_STATUSES } from "@/lib/task-status";

export const dynamic = "force-dynamic";

const PRIORITY_RANK: Record<string, number> = { critical: 0, high: 1, medium: 2, low: 3 };

interface CreateTaskBody {
  repoUrl: string;
  title: string;
  body?: string;
  priority?: string;
  source?: string;
  status?: string;
  needsHuman?: boolean;
  action?: string;
  scheduledFor?: string;
  // Only set by the one-time GitHub Issues import script, to preserve history.
  comments?: { author?: string; body?: string; createdAt?: string }[];
  createdAt?: string;
}

// Number is per-project and human-facing ("#N"), so it's generated here rather
// than left to the caller. Retries on the rare unique-constraint race between
// two routines/the worker creating a task for the same project at once.
async function createWithNextNumber(projectId: string, data: Omit<Prisma.IssueUncheckedCreateInput, "projectId" | "number">) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const agg = await prisma.issue.aggregate({ where: { projectId }, _max: { number: true } });
    const number = (agg._max.number ?? 0) + 1;
    try {
      return await prisma.issue.create({ data: { ...data, projectId, number } });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002" && attempt < 4) continue;
      throw e;
    }
  }
  throw new Error("unreachable");
}

export async function POST(req: NextRequest) {
  let body: CreateTaskBody;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }
  if (!body.repoUrl || !body.title) {
    return NextResponse.json({ error: "repoUrl and title are required" }, { status: 400 });
  }
  if (body.status !== undefined && !isTaskStatus(body.status)) {
    return NextResponse.json({ error: `status must be one of: ${TASK_STATUSES.join(", ")}` }, { status: 400 });
  }

  const project = await prisma.project.findUnique({
    where: { repoUrl: body.repoUrl },
    select: { id: true, minPriority: true },
  });
  if (!project) {
    return NextResponse.json({ error: "project not found for repoUrl" }, { status: 404 });
  }

  const priority = body.priority ?? "medium";
  const source = body.source ?? null;

  // Routine-filed tasks below the project's configured floor never enter the
  // queue — mirrors the old close_routine_below_priority worker behavior, just
  // skipping the insert instead of creating-then-closing. Manual tasks are exempt.
  if (source && source !== "manual") {
    const thresholdRank = PRIORITY_RANK[project.minPriority] ?? PRIORITY_RANK.medium;
    const rank = PRIORITY_RANK[priority] ?? PRIORITY_RANK.medium;
    if (rank > thresholdRank) {
      return NextResponse.json({ skipped: true, reason: `priority ${priority} below project minPriority ${project.minPriority}` });
    }
  }

  const task = await createWithNextNumber(project.id, {
    title: body.title,
    body: body.body ?? null,
    status: body.status ?? "proposed",
    priority,
    source,
    action: body.action ?? null,
    needsHuman: body.needsHuman ?? false,
    scheduledFor: body.scheduledFor ? new Date(body.scheduledFor) : null,
    comments: body.comments?.length ? (body.comments as unknown as Prisma.InputJsonValue) : undefined,
    createdAt: body.createdAt ? new Date(body.createdAt) : new Date(),
  });

  return NextResponse.json({ number: task.number, id: task.id });
}

export async function GET(req: NextRequest) {
  const sp = req.nextUrl.searchParams;
  const repoUrl = sp.get("repoUrl");
  if (!repoUrl) {
    return NextResponse.json({ error: "repoUrl is required" }, { status: 400 });
  }

  const project = await prisma.project.findUnique({ where: { repoUrl }, select: { id: true } });
  if (!project) {
    return NextResponse.json([]);
  }

  // `state` is a compat alias for callers still passing --state open|closed|all
  // (df CLI, worker, routine templates) — "closed" is just a status value now.
  const state = sp.get("state") ?? "open";
  const where: Prisma.IssueWhereInput = { projectId: project.id };
  if (state === "open") where.status = { not: "closed" };
  else if (state === "closed") where.status = "closed";
  const status = sp.get("status");
  if (status) where.status = status;
  const source = sp.get("source");
  if (source) where.source = source;
  const action = sp.get("action");
  if (action) where.action = action;
  if (sp.get("needsHuman") === "true") where.needsHuman = true;

  const tasks = await prisma.issue.findMany({
    where,
    orderBy: { number: "asc" },
    select: {
      number: true,
      title: true,
      body: true,
      status: true,
      priority: true,
      source: true,
      action: true,
      needsHuman: true,
      scheduledFor: true,
      comments: true,
      createdAt: true,
      closedAt: true,
      updatedAt: true,
    },
  });

  return NextResponse.json(tasks);
}
