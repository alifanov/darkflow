import { prisma } from "@/lib/prisma";
import { getLatestDarkflowVersion } from "@/lib/darkflow-version";
import { ProjectRow } from "@/components/ProjectRow";

export const dynamic = "force-dynamic";

export default async function ProjectsPage() {
  const [projects, latestVersion] = await Promise.all([
    prisma.project.findMany({
      orderBy: { lastSyncedAt: "desc" },
      include: {
        _count: { select: { issues: true } },
        issues: {
          where: { status: "proposed" },
          select: { id: true },
        },
        workerStatus: true,
      },
    }),
    Promise.resolve(getLatestDarkflowVersion()),
  ]);

  const now = Date.now();
  const ALIVE_MS = 75 * 1000;

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6" style={{ color: "var(--text)" }}>
        Projects
      </h1>
      {projects.length === 0 ? (
        <p style={{ color: "var(--muted)" }}>
          No projects yet. Worker will register projects on first sync.
        </p>
      ) : (
        <div style={{ border: "1px solid var(--border)", borderRadius: 8, overflow: "hidden" }}>
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr style={{ background: "var(--surface)", borderBottom: "1px solid var(--border)" }}>
                {["Name", "Repo", "Version", "Worker", "Proposed", "Issues", "Last synced"].map((col, i) => (
                  <th
                    key={col}
                    className={`py-2 px-4 text-xs font-medium uppercase tracking-wider text-left${i >= 4 && i <= 5 ? " text-right" : ""}`}
                    style={{ color: "var(--muted)" }}
                  >
                    {col}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {projects.map((p) => {
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

                return (
                  <ProjectRow
                    key={p.id}
                    id={p.id}
                    name={p.name}
                    repoUrl={p.repoUrl}
                    versionBadge={versionBadge}
                    darkflowVersion={p.darkflowVersion}
                    latestVersion={latestVersion}
                    workerState={workerState}
                    routine={ws?.routine ?? null}
                    proposedCount={p.issues.length}
                    totalIssues={p._count.issues}
                    lastSyncedAt={p.lastSyncedAt?.toISOString() ?? null}
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
