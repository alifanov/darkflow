import { prisma } from "@/lib/prisma";
import { getLatestDarkflowVersion } from "@/lib/darkflow-version";
import { ProjectRow } from "@/components/ProjectRow";
import { GhTokenForm } from "@/components/GhTokenForm";
import { IssuesActivityChart, type IssueActivityDay } from "@/components/IssuesActivityChart";

export const dynamic = "force-dynamic";

type DayCount = { day: Date; count: bigint };

// Build the last-7-days (UTC, inclusive of today) created-vs-closed activity
// series across all projects. Two grouped raw queries (one per timestamp
// column) are merged into a 7-slot array seeded with every day so zero-activity
// days still render. createdAt/closedAt are nullable, so pre-update workers
// simply don't contribute.
async function getIssueActivity(): Promise<IssueActivityDay[]> {
  const [createdRaw, closedRaw] = await Promise.all([
    prisma.$queryRaw<DayCount[]>`
      SELECT date_trunc('day', "createdAt")::date AS day, COUNT(*)::bigint AS count
      FROM "Issue"
      WHERE "createdAt" >= date_trunc('day', now()) - interval '6 days'
      GROUP BY day`,
    prisma.$queryRaw<DayCount[]>`
      SELECT date_trunc('day', "closedAt")::date AS day, COUNT(*)::bigint AS count
      FROM "Issue"
      WHERE "closedAt" >= date_trunc('day', now()) - interval '6 days'
      GROUP BY day`,
  ]);

  const key = (d: Date) => d.toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
  const createdBy = new Map(createdRaw.map((r) => [key(new Date(r.day)), Number(r.count)]));
  const closedBy = new Map(closedRaw.map((r) => [key(new Date(r.day)), Number(r.count)]));

  const days: IssueActivityDay[] = [];
  const today = new Date();
  for (let i = 6; i >= 0; i--) {
    const d = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() - i));
    const k = key(d);
    days.push({
      day: `${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(d.getUTCDate()).padStart(2, "0")}`,
      created: createdBy.get(k) ?? 0,
      closed: closedBy.get(k) ?? 0,
    });
  }
  return days;
}

export default async function ProjectsPage() {
  const [rawProjects, latestVersion, settings, issueActivity] = await Promise.all([
    prisma.project.findMany({
      include: {
        _count: { select: { issues: { where: { state: { in: ["OPEN", "open"] }, status: { not: "rejected" } } } } },
        issues: {
          where: { state: { in: ["OPEN", "open"] }, status: { not: "rejected" } },
          select: { id: true, status: true, needsHuman: true },
        },
        workerStatus: true,
        routineLogs: {
          orderBy: { timestamp: "desc" },
          take: 1,
          select: { routine: true, timestamp: true },
        },
      },
    }),
    Promise.resolve(getLatestDarkflowVersion()),
    prisma.settings.findUnique({ where: { id: "global" } }),
    getIssueActivity(),
  ]);

  const projects = [...rawProjects].sort((a, b) => {
    const aProposed = a.issues.some((i) => i.status === "proposed") ? 1 : 0;
    const bProposed = b.issues.some((i) => i.status === "proposed") ? 1 : 0;
    if (bProposed !== aProposed) return bProposed - aProposed;
    return b._count.issues - a._count.issues;
  });

  const now = Date.now();
  const ALIVE_MS = 75 * 1000;

  return (
    <div>
      <div className="mb-5">
        <GhTokenForm hasToken={!!settings?.ghToken} />
      </div>

      <div className="mb-6">
        <IssuesActivityChart data={issueActivity} />
      </div>

      <div className="flex items-center gap-3 mb-6">
        <h1 className="text-2xl font-bold" style={{ color: "var(--text)" }}>
          Projects
        </h1>
        {projects.length > 0 && (
          <span
            className="rounded-full px-2.5 py-0.5 text-xs font-semibold"
            style={{ background: "var(--surface)", color: "var(--muted)", border: "1px solid var(--border)" }}
          >
            {projects.length}
          </span>
        )}
      </div>
      {projects.length === 0 ? (
        <p style={{ color: "var(--muted)" }}>
          No projects yet. Worker will register projects on first sync.
        </p>
      ) : (
        <div style={{ border: "1px solid var(--border)", borderRadius: 8, overflow: "hidden" }}>
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr style={{ background: "var(--surface)", borderBottom: "1px solid var(--border)" }}>
                {["#", "Name", "Domain", "Branch", "Lang", "DF Version", "Worker", "Open Issues", "Approved", "Needs Human", "Last routine", "Last synced"].map((col, i) => (
                  <th
                    key={col}
                    className={`py-2 px-4 text-xs font-medium uppercase tracking-wider text-left${[7, 8, 9].includes(i) ? " text-right" : ""}`}
                    style={{ color: "var(--muted)" }}
                  >
                    {col}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {projects.map((p, idx) => {
                const ws = p.workerStatus;
                const alive = ws && now - new Date(ws.updatedAt).getTime() < ALIVE_MS;
                const workerState = alive
                  ? ws.status === "running"
                    ? "running"
                    : "online"
                  : null;
                const versionBadge =
                  p.darkflowVersion == null
                    ? "missing"
                    : p.darkflowVersion === latestVersion
                    ? "current"
                    : "outdated";
                // Settings were saved in the UI after the worker last pulled config
                // (or it never has) → the running worker hasn't applied them yet.
                const settingsPending =
                  p.settingsUpdatedAt != null &&
                  (!ws?.configSyncedAt ||
                    new Date(ws.configSyncedAt).getTime() < new Date(p.settingsUpdatedAt).getTime());
                const lastLog = p.routineLogs[0] ?? null;

                return (
                  <ProjectRow
                    key={p.id}
                    index={idx + 1}
                    id={p.id}
                    name={p.name}
                    domain={p.domain}
                    branch={p.branch}
                    language={p.language}
                    versionBadge={versionBadge}
                    darkflowVersion={p.darkflowVersion}
                    latestVersion={latestVersion}
                    workerState={workerState}
                    settingsPending={settingsPending}
                    routine={ws?.routine ?? null}
                    approvedCount={p.issues.filter((i) => i.status === "approved").length}
                    needsHumanCount={p.issues.filter((i) => i.needsHuman).length}
                    totalIssues={p._count.issues}
                    lastSyncedAt={p.lastSyncedAt?.toISOString() ?? null}
                    lastRoutine={lastLog ? { routine: lastLog.routine, timestamp: lastLog.timestamp.toISOString() } : null}
                  />
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
