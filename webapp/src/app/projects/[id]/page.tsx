import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "@/lib/prisma";
import { IssueTableRow } from "@/components/IssueTableRow";
import { DeleteProjectButton } from "@/components/DeleteProjectButton";
import { LocalTime } from "@/components/LocalTime";
import { LogRow } from "@/components/LogRow";
import { ProjectSettingsForm } from "@/components/ProjectSettingsForm";
import { RoutineConfigForm } from "@/components/RoutineConfigForm";

export const dynamic = "force-dynamic";

const STATUS_COLORS: Record<string, string> = {
  proposed: "#1f3a5f",
  approved: "#1a3a1a",
  rejected: "#3a1a1a",
  "in-progress": "#2a2a0a",
  blocked: "#3a2a0a",
  none: "#1a1a1a",
};

const STATUS_TEXT: Record<string, string> = {
  proposed: "var(--accent)",
  approved: "var(--green)",
  rejected: "var(--red)",
  "in-progress": "#e3b341",
  blocked: "#d29922",
  none: "var(--muted)",
};

const CARDS: { key: string; label: string; statuses: string[] }[] = [
  { key: "proposed", label: "Needs approval", statuses: ["proposed"] },
  { key: "approved", label: "Approved", statuses: ["approved"] },
  { key: "in-progress", label: "In progress", statuses: ["in-progress"] },
  { key: "rejected", label: "Rejected", statuses: ["rejected", "blocked"] },
];

const TABS: { key: "issues" | "logs" | "routines" | "commits" | "settings"; label: string }[] = [
  { key: "issues", label: "Issues" },
  { key: "logs", label: "Logs" },
  { key: "routines", label: "Routines" },
  { key: "commits", label: "Commits" },
  { key: "settings", label: "Settings" },
];

type TabKey = (typeof TABS)[number]["key"];

function isTab(v: string | undefined): v is TabKey {
  return v === "issues" || v === "logs" || v === "routines" || v === "commits" || v === "settings";
}

function TableContainer({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ border: "1px solid var(--border)", borderRadius: 8, overflow: "hidden" }}>
      <table className="w-full border-collapse text-sm">{children}</table>
    </div>
  );
}

function TableHead({ cols }: { cols: string[] }) {
  return (
    <thead>
      <tr style={{ background: "var(--surface)", borderBottom: "1px solid var(--border)" }}>
        {cols.map((col) => (
          <th
            key={col}
            className="py-2 px-4 text-xs font-medium uppercase tracking-wider text-left"
            style={{ color: "var(--muted)" }}
          >
            {col}
          </th>
        ))}
      </tr>
    </thead>
  );
}

export default async function ProjectPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ filter?: string; tab?: string }>;
}) {
  const { id } = await params;
  const { filter, tab } = await searchParams;
  const project = await prisma.project.findUnique({
    where: { id },
    include: {
      issues: { where: { state: { in: ["OPEN", "open"] } }, orderBy: [{ status: "asc" }, { number: "desc" }] },
      securityStatus: true,
      architectureStatus: true,
      workerStatus: true,
      routineLogs: { orderBy: { timestamp: "desc" }, take: 100, select: { id: true, routine: true, summary: true, output: true, costUsd: true, totalTokens: true, timestamp: true } },
      routineConfigs: { orderBy: { name: "asc" } },
      commits: { orderBy: { committedAt: "desc" }, take: 50 },
    },
  });

  if (!project) notFound();

  // Cross-project spend rollups (by day / project / model / routine) live on the
  // dedicated /analytics page now.

  const PRIORITY_ORDER: Record<string, number> = { critical: 0, high: 1, medium: 2, low: 3 };
  const activeTab: TabKey = isTab(tab) ? tab : "issues";

  const sortedIssues = [...project.issues].sort((a, b) => {
    const pa = PRIORITY_ORDER[a.priority ?? ""] ?? 99;
    const pb = PRIORITY_ORDER[b.priority ?? ""] ?? 99;
    if (pa !== pb) return pa - pb;
    return b.number - a.number;
  });

  const showAll = filter === "all";
  const effectiveFilter = showAll ? undefined : (filter ?? "proposed");
  const activeCard = CARDS.find((c) => c.key === effectiveFilter);
  const displayed = activeCard
    ? sortedIssues.filter((i) => activeCard.statuses.includes(i.status))
    : sortedIssues;

  const now = Date.now();
  // Worker heartbeats every 30 s; 75 s tolerates one missed beat before flipping offline.
  const ALIVE_MS = 75 * 1000;
  const ws = project.workerStatus;
  const workerAlive = ws && now - new Date(ws.updatedAt).getTime() < ALIVE_MS;

  return (
    <div>
      <div className="mb-6">
        <Link href="/" className="text-sm" style={{ color: "var(--muted)" }}>
          ← Projects
        </Link>
        <div className="flex items-start justify-between gap-4 mt-2">
          <div>
            <h1 className="text-2xl font-bold" style={{ color: "var(--text)" }}>
              {project.name}
            </h1>
            <a
              href={project.repoUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm"
              style={{ color: "var(--accent)" }}
            >
              {project.repoUrl}
            </a>
            <div className="text-sm mt-1" style={{ color: "var(--muted)" }}>
              Main branch:{" "}
              <span className="font-mono" style={{ color: "var(--text)" }}>
                {project.branch}
              </span>
            </div>
            {project.lastSyncedAt && (
              <div className="text-sm mt-1" style={{ color: "var(--muted)" }}>
                Last synced <LocalTime date={project.lastSyncedAt} />
              </div>
            )}
            {workerAlive && ws.status === "running" && (
              <div className="flex items-center gap-1.5 text-sm mt-1" style={{ color: "var(--green)" }}>
                <span
                  className="worker-dot-running"
                  style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--green)", display: "inline-block", flexShrink: 0 }}
                />
                Worker running: {ws.routine ?? "routine"}
              </div>
            )}
            {workerAlive && ws.status === "idle" && (
              <div className="flex items-center gap-1.5 text-sm mt-1" style={{ color: "var(--green)" }}>
                <span
                  style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--green)", display: "inline-block", flexShrink: 0, opacity: 0.55 }}
                />
                Worker online
              </div>
            )}
          </div>
          <div className="shrink-0 mt-1">
            <DeleteProjectButton projectId={project.id} projectName={project.name} />
          </div>
        </div>
      </div>

      <div className="flex gap-1 mb-6 border-b" style={{ borderColor: "var(--border)" }}>
        {TABS.map((t) => {
          const isActive = activeTab === t.key;
          const href = t.key === "issues" ? `/projects/${project.id}` : `/projects/${project.id}?tab=${t.key}`;
          return (
            <Link
              key={t.key}
              href={href}
              className="px-4 py-2 text-sm border-b-2 -mb-px transition-colors"
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

      {activeTab === "issues" && (
        <IssuesTab
          projectId={project.id}
          issues={sortedIssues}
          effectiveFilter={effectiveFilter}
          showAll={showAll}
          displayed={displayed}
          activeCard={activeCard}
        />
      )}

      {activeTab === "logs" && <RoutineLogsList logs={project.routineLogs} />}

      {activeTab === "routines" && (
        <RoutineConfigForm
          projectId={project.id}
          routineConfigs={project.routineConfigs}
          modules={project.modules}
        />
      )}

      {activeTab === "commits" && <CommitList commits={project.commits} />}

      {activeTab === "settings" && (
        <ProjectSettingsForm
          projectId={project.id}
          initialValues={{
            name: project.name,
            slug: project.slug ?? null,
            branch: project.branch,
            language: project.language,
            mergeStrategy: project.mergeStrategy,
            maxConcurrent: project.maxConcurrent,
            posthogProjectId: project.posthogProjectId ?? null,
            obsTool: project.obsTool ?? null,
            obsUrl: project.obsUrl ?? null,
            settingsUpdatedAt: project.settingsUpdatedAt ?? null,
          }}
        />
      )}
    </div>
  );
}

function IssuesTab({
  projectId,
  issues,
  effectiveFilter,
  showAll,
  displayed,
  activeCard,
}: {
  projectId: string;
  issues: {
    id: string;
    number: number;
    title: string;
    body: string | null;
    status: string;
    pendingStatus: string | null;
    priority: string | null;
    url: string | null;
    needsHuman: boolean;
  }[];
  effectiveFilter: string | undefined;
  showAll: boolean;
  displayed: typeof issues;
  activeCard: (typeof CARDS)[number] | undefined;
}) {
  const needsHumanIssues = issues.filter((i) => i.needsHuman);

  return (
    <>
      {needsHumanIssues.length > 0 && (
        <section id="needs-human" className="mb-8">
          <div className="flex items-center gap-2 mb-3">
            <h2 className="text-lg font-semibold" style={{ color: "var(--text)" }}>
              Needs Human
            </h2>
            <span
              className="rounded-full px-2 py-0.5 text-xs font-bold"
              style={{ background: "#3a1a3a", color: "#c084fc" }}
            >
              {needsHumanIssues.length}
            </span>
          </div>
          <TableContainer>
            <TableHead cols={["#", "Title", "Priority", "Status", "Actions"]} />
            <tbody>
              {needsHumanIssues.map((issue) => (
                <IssueTableRow
                  key={issue.id}
                  issue={issue}
                  showActions={false}
                  showClose
                  showTaskLink
                />
              ))}
            </tbody>
          </TableContainer>
        </section>
      )}

      {issues.length > 0 && (
        <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-6">
          {CARDS.map((card) => {
            const count = issues.filter((i) => card.statuses.includes(i.status)).length;
            const isActive = !showAll && effectiveFilter === card.key;
            const accent = STATUS_TEXT[card.key] ?? "var(--muted)";
            return (
              <Link
                key={card.key}
                href={isActive ? `/projects/${projectId}?filter=all` : `/projects/${projectId}?filter=${card.key}`}
                className="rounded-lg border p-4 flex flex-col gap-1 transition-colors"
                style={{
                  background: isActive ? STATUS_COLORS[card.key] ?? "var(--surface)" : "var(--surface)",
                  borderColor: isActive ? accent : "var(--border)",
                }}
              >
                <span className="text-2xl font-bold" style={{ color: accent }}>
                  {count}
                </span>
                <span className="text-xs" style={{ color: "var(--muted)" }}>
                  {card.label}
                </span>
              </Link>
            );
          })}
          <Link
            href={needsHumanIssues.length > 0 ? `#needs-human` : `#`}
            className="rounded-lg border p-4 flex flex-col gap-1 transition-colors"
            style={{
              background: needsHumanIssues.length > 0 ? "#3a1a3a" : "var(--surface)",
              borderColor: needsHumanIssues.length > 0 ? "#c084fc" : "var(--border)",
            }}
          >
            <span className="text-2xl font-bold" style={{ color: needsHumanIssues.length > 0 ? "#c084fc" : "var(--muted)" }}>
              {needsHumanIssues.length}
            </span>
            <span className="text-xs" style={{ color: "var(--muted)" }}>
              Needs Human
            </span>
          </Link>
        </div>
      )}

      {issues.length > 0 && (
        <section>
          <h2 className="text-lg font-semibold mb-3" style={{ color: "var(--text)" }}>
            {activeCard ? activeCard.label : "All issues"} ({displayed.length})
          </h2>
          {displayed.length > 0 ? (
            <TableContainer>
              <TableHead cols={["#", "Title", "Priority", "Status", "Actions"]} />
              <tbody>
                {displayed.map((issue) => (
                  <IssueTableRow
                    key={issue.id}
                    issue={issue}
                    showActions={issue.status === "proposed"}
                    showTaskLink={issue.status === "proposed"}
                  />
                ))}
              </tbody>
            </TableContainer>
          ) : (
            <p style={{ color: "var(--muted)" }}>No issues in this category.</p>
          )}
        </section>
      )}

      {issues.length === 0 && (
        <p style={{ color: "var(--muted)" }}>No issues synced yet.</p>
      )}
    </>
  );
}


function RoutineLogsList({
  logs,
}: {
  logs: { id: string; routine: string; summary: string; output: string | null; costUsd: number | null; totalTokens: number | null; timestamp: Date }[];
}) {
  if (logs.length === 0) {
    return <p style={{ color: "var(--muted)" }}>No logs yet.</p>;
  }
  return (
    <section>
      <h2 className="text-lg font-semibold mb-3" style={{ color: "var(--text)" }}>
        Recent runs ({logs.length})
      </h2>
      <TableContainer>
        <TableHead cols={["Time", "Routine", "Summary", "Tokens", "Cost", ""]} />
        <tbody>
          {logs.map((l) => (
            <LogRow
              key={l.id}
              id={l.id}
              routine={l.routine}
              summary={l.summary}
              output={l.output}
              costUsd={l.costUsd}
              totalTokens={l.totalTokens}
              timestamp={l.timestamp.toISOString()}
            />
          ))}
        </tbody>
      </TableContainer>
    </section>
  );
}

function CommitList({
  commits,
}: {
  commits: {
    id: string;
    sha: string;
    message: string;
    author: string;
    email: string | null;
    committedAt: Date;
    url: string | null;
  }[];
}) {
  if (commits.length === 0) {
    return <p style={{ color: "var(--muted)" }}>No commits synced yet.</p>;
  }
  return (
    <section>
      <h2 className="text-lg font-semibold mb-3" style={{ color: "var(--text)" }}>
        Recent commits ({commits.length})
      </h2>
      <TableContainer>
        <TableHead cols={["SHA", "Message", "Author", "Date"]} />
        <tbody>
          {commits.map((c) => (
            <tr key={c.id} className="project-row" style={{ borderBottom: "1px solid var(--border)" }}>
              <td className="py-3 px-4 font-mono text-xs" style={{ color: "var(--accent)", width: "5rem" }}>
                {c.url ? (
                  <a href={c.url} target="_blank" rel="noopener noreferrer" className="hover:underline">
                    {c.sha.slice(0, 7)}
                  </a>
                ) : (
                  c.sha.slice(0, 7)
                )}
              </td>
              <td className="py-3 px-4 max-w-md truncate" style={{ color: "var(--text)" }}>
                {c.message}
              </td>
              <td className="py-3 px-4 text-xs" style={{ color: "var(--muted)" }}>
                {c.author}
              </td>
              <td className="py-3 px-4 text-xs" style={{ color: "var(--muted)" }}>
                <LocalTime date={c.committedAt} />
              </td>
            </tr>
          ))}
        </tbody>
      </TableContainer>
    </section>
  );
}

