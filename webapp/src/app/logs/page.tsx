import { prisma } from "@/lib/prisma";
import { RoutineLogsTable } from "@/components/RoutineLogsTable";
import { GlobalLogsChart, type MinutePoint } from "@/components/GlobalLogsChart";

export const dynamic = "force-dynamic";

export default async function GlobalLogsPage() {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const [logs, projects, minuteRaw] = await Promise.all([
    prisma.routineLog.findMany({
      where: { timestamp: { gte: since } },
      orderBy: { timestamp: "desc" },
      select: {
        id: true,
        projectId: true,
        routine: true,
        summary: true,
        output: true,
        costUsd: true,
        totalTokens: true,
        timestamp: true,
      },
    }),
    prisma.project.findMany({ select: { id: true, name: true } }),
    // Per-minute success/error counts over the last 24h. Error = `exit:` in the
    // summary, the same rule as logIsError() in LogRow.tsx.
    prisma.$queryRaw<{ minute: Date; ok: number; err: number }[]>`
      SELECT date_trunc('minute', "timestamp")                      AS minute,
             COUNT(*) FILTER (WHERE "summary" NOT LIKE '%exit:%')::int AS ok,
             COUNT(*) FILTER (WHERE "summary" LIKE '%exit:%')::int     AS err
      FROM "RoutineLog"
      WHERE "timestamp" >= now() - interval '24 hours'
      GROUP BY minute
      ORDER BY minute ASC`,
  ]);

  const projectName = new Map(projects.map((p) => [p.id, p.name]));
  const rows = logs.map((l) => ({
    id: l.id,
    routine: l.routine,
    summary: l.summary,
    output: l.output,
    costUsd: l.costUsd,
    totalTokens: l.totalTokens,
    timestamp: l.timestamp.toISOString(),
    project: projectName.get(l.projectId) ?? "(deleted)",
  }));

  const chartData: MinutePoint[] = minuteRaw.map((m) => ({
    minute: m.minute.toISOString(),
    ok: Number(m.ok),
    err: Number(m.err),
  }));

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6" style={{ color: "var(--text)" }}>
        Global logs
      </h1>

      <GlobalLogsChart data={chartData} />

      {rows.length === 0 ? (
        <p style={{ color: "var(--muted)" }}>No logs in the last 24 hours.</p>
      ) : (
        <RoutineLogsTable logs={rows} />
      )}
    </div>
  );
}
