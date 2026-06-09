import Link from "next/link";
import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { AnalyticsCharts } from "@/components/AnalyticsCharts";

export const dynamic = "force-dynamic";

const RANGES: { key: string; label: string; days: number | null }[] = [
  { key: "7", label: "7d", days: 7 },
  { key: "30", label: "30d", days: 30 },
  { key: "90", label: "90d", days: 90 },
  { key: "all", label: "All time", days: null },
];

export default async function AnalyticsPage({
  searchParams,
}: {
  searchParams: Promise<{ days?: string }>;
}) {
  const { days } = await searchParams;
  const active = RANGES.find((r) => r.key === days) ?? RANGES[1]; // default 30d
  const startDate =
    active.days != null ? new Date(Date.now() - active.days * 24 * 60 * 60 * 1000) : null;

  const where = startDate ? { timestamp: { gte: startDate } } : {};
  const rawWhere = startDate
    ? Prisma.sql`WHERE "timestamp" >= ${startDate}`
    : Prisma.empty;

  const [dailyRaw, byProjectRaw, byModelRaw, byRoutineRaw, projects] = await Promise.all([
    prisma.$queryRaw<{ day: Date; cost: number | null; tokens: bigint | null; runs: bigint }[]>`
      SELECT date_trunc('day', "timestamp")::date AS day,
             SUM("costUsd")            AS cost,
             SUM("totalTokens")::bigint AS tokens,
             COUNT(*)::bigint           AS runs
      FROM "RoutineLog"
      ${rawWhere}
      GROUP BY day
      ORDER BY day ASC`,
    prisma.routineLog.groupBy({
      by: ["projectId"],
      where,
      _sum: { costUsd: true, totalTokens: true },
      _count: { _all: true },
      orderBy: { _sum: { costUsd: "desc" } },
    }),
    prisma.routineLog.groupBy({
      by: ["model"],
      where,
      _sum: { costUsd: true, totalTokens: true },
      _count: { _all: true },
      orderBy: { _sum: { costUsd: "desc" } },
    }),
    prisma.routineLog.groupBy({
      by: ["routine"],
      where,
      _sum: { costUsd: true, totalTokens: true },
      _count: { _all: true },
      orderBy: { _sum: { costUsd: "desc" } },
    }),
    prisma.project.findMany({ select: { id: true, name: true } }),
  ]);

  const projectName = new Map(projects.map((p) => [p.id, p.name]));

  const daily = dailyRaw.map((d) => ({
    day: d.day.toISOString().slice(0, 10),
    cost: Number(d.cost ?? 0),
    tokens: Number(d.tokens ?? 0),
    runs: Number(d.runs),
  }));

  const byProject = byProjectRaw.map((r) => ({
    label: projectName.get(r.projectId) ?? "(deleted)",
    cost: r._sum.costUsd ?? 0,
    tokens: r._sum.totalTokens ?? 0,
    runs: r._count._all,
  }));

  const byModel = byModelRaw.map((r) => ({
    label: r.model ?? "unknown",
    cost: r._sum.costUsd ?? 0,
    tokens: r._sum.totalTokens ?? 0,
    runs: r._count._all,
  }));

  const byRoutine = byRoutineRaw.map((r) => ({
    label: r.routine,
    cost: r._sum.costUsd ?? 0,
    tokens: r._sum.totalTokens ?? 0,
    runs: r._count._all,
  }));

  const totals = byProject.reduce(
    (acc, r) => ({ cost: acc.cost + r.cost, tokens: acc.tokens + r.tokens, runs: acc.runs + r.runs }),
    { cost: 0, tokens: 0, runs: 0 },
  );

  return (
    <div>
      <div className="flex items-center justify-between gap-4 mb-6 flex-wrap">
        <h1 className="text-2xl font-bold" style={{ color: "var(--text)" }}>
          Usage analytics
        </h1>
        <div className="flex gap-1">
          {RANGES.map((r) => {
            const isActive = r.key === active.key;
            return (
              <Link
                key={r.key}
                href={`/analytics?days=${r.key}`}
                className="px-3 py-1 text-sm rounded-md no-underline cursor-pointer transition-colors"
                style={{
                  color: isActive ? "var(--text)" : "var(--muted)",
                  background: isActive ? "var(--surface)" : "transparent",
                  border: `1px solid ${isActive ? "var(--border)" : "transparent"}`,
                }}
              >
                {r.label}
              </Link>
            );
          })}
        </div>
      </div>

      <AnalyticsCharts
        daily={daily}
        byProject={byProject}
        byModel={byModel}
        byRoutine={byRoutine}
        totals={totals}
      />
    </div>
  );
}
