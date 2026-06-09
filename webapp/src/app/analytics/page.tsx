import Link from "next/link";
import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { OverTimeChart, BreakdownChart, type Row } from "@/components/AnalyticsCharts";

export const dynamic = "force-dynamic";

const RANGES: { key: string; label: string; days: number | null }[] = [
  { key: "7", label: "7d", days: 7 },
  { key: "30", label: "30d", days: 30 },
  { key: "90", label: "90d", days: 90 },
  { key: "all", label: "All time", days: null },
];

const TABS = [
  { key: "over-time", label: "Over time" },
  { key: "breakdown", label: "Breakdown" },
] as const;
type TabKey = (typeof TABS)[number]["key"];

// Dimensions the user can group by. `col` is the RoutineLog column; all three
// (projectId via name lookup, model, routine) are columns on RoutineLog.
const DIMENSIONS = [
  { key: "project", label: "Project", col: "projectId" },
  { key: "model", label: "Model", col: "model" },
  { key: "routine", label: "Routine", col: "routine" },
] as const;
type DimKey = (typeof DIMENSIONS)[number]["key"];

function fmtCost(n: number) {
  return `$${n.toFixed(n >= 1 ? 2 : 4)}`;
}

export default async function AnalyticsPage({
  searchParams,
}: {
  searchParams: Promise<{ days?: string; tab?: string; group?: string }>;
}) {
  const sp = await searchParams;
  const active = RANGES.find((r) => r.key === sp.days) ?? RANGES[1]; // default 30d
  const tab: TabKey = TABS.some((t) => t.key === sp.tab) ? (sp.tab as TabKey) : "over-time";

  // Selected grouping dims, kept in canonical order so combined labels are stable.
  const requested = new Set((sp.group ?? "project").split(",").filter(Boolean));
  const selectedDims = DIMENSIONS.filter((d) => requested.has(d.key)).map((d) => d.key);

  const startDate =
    active.days != null ? new Date(Date.now() - active.days * 24 * 60 * 60 * 1000) : null;
  const where = startDate ? { timestamp: { gte: startDate } } : {};

  // Totals are independent of grouping — always show for the window.
  const totalsAgg = await prisma.routineLog.aggregate({
    where,
    _sum: { costUsd: true, totalTokens: true },
    _count: { _all: true },
  });
  const totals = {
    cost: totalsAgg._sum.costUsd ?? 0,
    tokens: totalsAgg._sum.totalTokens ?? 0,
    runs: totalsAgg._count._all,
  };

  // ── Over time ──────────────────────────────────────────────────────────────
  let daily: { day: string; cost: number; tokens: number; runs: number }[] = [];
  if (tab === "over-time") {
    const rawWhere = startDate ? Prisma.sql`WHERE "timestamp" >= ${startDate}` : Prisma.empty;
    const dailyRaw = await prisma.$queryRaw<
      { day: Date; cost: number | null; tokens: bigint | null; runs: bigint }[]
    >`
      SELECT date_trunc('day', "timestamp")::date AS day,
             SUM("costUsd")             AS cost,
             SUM("totalTokens")::bigint AS tokens,
             COUNT(*)::bigint           AS runs
      FROM "RoutineLog"
      ${rawWhere}
      GROUP BY day
      ORDER BY day ASC`;
    daily = dailyRaw.map((d) => ({
      day: d.day.toISOString().slice(0, 10),
      cost: Number(d.cost ?? 0),
      tokens: Number(d.tokens ?? 0),
      runs: Number(d.runs),
    }));
  }

  // ── Breakdown (multi-dimension groupBy) ──────────────────────────────────────
  let breakdownRows: Row[] = [];
  if (tab === "breakdown" && selectedDims.length > 0) {
    const byCols = DIMENSIONS.filter((d) => requested.has(d.key)).map((d) => d.col);
    const needsProjects = selectedDims.includes("project");

    type GroupedRow = {
      projectId?: string;
      model?: string | null;
      routine?: string;
      _sum: { costUsd: number | null; totalTokens: number | null };
      _count: { _all: number };
    };
    // `by` is dynamic, so the typed groupBy overload can't be satisfied — cast the
    // args through `never` and assert the well-known result shape.
    const groupedPromise = prisma.routineLog.groupBy({
      by: byCols,
      where,
      _sum: { costUsd: true, totalTokens: true },
      _count: { _all: true },
    } as never) as unknown as Promise<GroupedRow[]>;

    const [grouped, projects] = await Promise.all([
      groupedPromise,
      needsProjects
        ? prisma.project.findMany({ select: { id: true, name: true } })
        : Promise.resolve([] as { id: string; name: string }[]),
    ]);

    const projectName = new Map(projects.map((p) => [p.id, p.name]));

    breakdownRows = grouped
      .map((g) => {
        const parts = selectedDims.map((d) => {
          if (d === "project") return projectName.get(g.projectId ?? "") ?? "(deleted)";
          if (d === "model") return g.model ?? "unknown";
          return g.routine ?? "—";
        });
        return {
          label: parts.join(" / "),
          cost: g._sum.costUsd ?? 0,
          tokens: g._sum.totalTokens ?? 0,
          runs: g._count._all,
        };
      })
      .sort((a, b) => b.cost - a.cost);
  }

  const dimLabel = selectedDims.length
    ? DIMENSIONS.filter((d) => requested.has(d.key)).map((d) => d.label).join(" / ")
    : "Group";

  // URL helpers that preserve days + tab.
  const withParams = (next: Partial<{ tab: string; group: string }>) => {
    const params = new URLSearchParams();
    params.set("days", active.key);
    params.set("tab", next.tab ?? tab);
    const group = next.group ?? selectedDims.join(",");
    if (group) params.set("group", group);
    return `/analytics?${params.toString()}`;
  };
  // Toggle a dimension in/out of the current selection.
  const toggleDim = (dim: DimKey) => {
    const set = new Set(selectedDims);
    if (set.has(dim)) set.delete(dim);
    else set.add(dim);
    const ordered = DIMENSIONS.filter((d) => set.has(d.key)).map((d) => d.key);
    return withParams({ group: ordered.join(",") });
  };

  return (
    <div>
      <div className="flex items-center justify-between gap-4 mb-6 flex-wrap">
        <h1 className="text-2xl font-bold" style={{ color: "var(--text)" }}>
          Usage analytics
        </h1>
        <div className="flex gap-1">
          {RANGES.map((r) => {
            const isActive = r.key === active.key;
            const params = new URLSearchParams();
            params.set("days", r.key);
            params.set("tab", tab);
            if (selectedDims.length) params.set("group", selectedDims.join(","));
            return (
              <Link
                key={r.key}
                href={`/analytics?${params.toString()}`}
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

      {/* Totals */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <StatCard label="Total cost" value={fmtCost(totals.cost)} accent="#58a6ff" />
        <StatCard label="Total tokens" value={totals.tokens.toLocaleString()} accent="#3fb950" />
        <StatCard label="Total runs" value={totals.runs.toLocaleString()} accent="#8b949e" />
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-6 border-b" style={{ borderColor: "var(--border)" }}>
        {TABS.map((t) => {
          const isActive = tab === t.key;
          return (
            <Link
              key={t.key}
              href={withParams({ tab: t.key })}
              className="px-4 py-2 text-sm border-b-2 -mb-px transition-colors no-underline"
              style={{
                color: isActive ? "var(--text)" : "var(--muted)",
                borderBottomColor: isActive ? "var(--accent)" : "transparent",
                fontWeight: isActive ? 600 : 400,
              }}
            >
              {t.label}
            </Link>
          );
        })}
      </div>

      {tab === "over-time" && <OverTimeChart daily={daily} />}

      {tab === "breakdown" && (
        <>
          <div className="flex items-center gap-2 mb-4 flex-wrap">
            <span className="text-sm" style={{ color: "var(--muted)" }}>
              Group by:
            </span>
            {DIMENSIONS.map((d) => {
              const isOn = requested.has(d.key);
              return (
                <Link
                  key={d.key}
                  href={toggleDim(d.key)}
                  className="px-3 py-1 text-sm rounded-full no-underline cursor-pointer transition-colors"
                  style={{
                    color: isOn ? "var(--bg)" : "var(--muted)",
                    background: isOn ? "var(--accent)" : "transparent",
                    border: `1px solid ${isOn ? "var(--accent)" : "var(--border)"}`,
                  }}
                >
                  {d.label}
                </Link>
              );
            })}
          </div>

          {selectedDims.length === 0 ? (
            <p style={{ color: "var(--muted)" }}>Pick at least one dimension to group by.</p>
          ) : (
            <BreakdownChart rows={breakdownRows} dimLabel={dimLabel} />
          )}
        </>
      )}
    </div>
  );
}

function StatCard({ label, value, accent }: { label: string; value: string; accent: string }) {
  return (
    <div style={{ border: "1px solid var(--border)", borderRadius: 8, padding: 16, background: "var(--surface)" }}>
      <div className="text-xs uppercase tracking-wider mb-1" style={{ color: "var(--muted)" }}>
        {label}
      </div>
      <div className="text-2xl font-bold font-mono" style={{ color: accent }}>
        {value}
      </div>
    </div>
  );
}
