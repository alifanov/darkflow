import { prisma } from "@/lib/prisma";
import { getLatestDarkflowVersion } from "@/lib/darkflow-version";
import { ProjectRow } from "@/components/ProjectRow";
import { GhTokenForm } from "@/components/GhTokenForm";

export const dynamic = "force-dynamic";

export default async function ProjectsPage() {
  const [rawProjects, latestVersion, settings] = await Promise.all([
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
                {["#", "Name", "Branch", "Lang", "DF Version", "Worker", "Open Issues", "Last routine", "Last synced"].map((col, i) => (
                  <th
                    key={col}
                    className={`py-2 px-4 text-xs font-medium uppercase tracking-wider text-left${i === 6 ? " text-right" : ""}`}
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
                const lastLog = p.routineLogs[0] ?? null;

                return (
                  <ProjectRow
                    key={p.id}
                    index={idx + 1}
                    id={p.id}
                    name={p.name}
                    branch={p.branch}
                    language={p.language}
                    versionBadge={versionBadge}
                    darkflowVersion={p.darkflowVersion}
                    latestVersion={latestVersion}
                    workerState={workerState}
                    routine={ws?.routine ?? null}
                    proposedCount={p.issues.filter((i) => i.status === "proposed").length}
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
