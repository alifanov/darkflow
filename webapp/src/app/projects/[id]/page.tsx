import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "@/lib/prisma";
import { IssueActions } from "@/components/IssueActions";
import { DeleteProjectButton } from "@/components/DeleteProjectButton";

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
  { key: "proposed", label: "Требуют одобрения", statuses: ["proposed"] },
  { key: "approved", label: "Одобрены", statuses: ["approved"] },
  { key: "in-progress", label: "В процессе", statuses: ["in-progress"] },
  { key: "rejected", label: "Отменены", statuses: ["rejected", "blocked"] },
];

export default async function ProjectPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ filter?: string }>;
}) {
  const { id } = await params;
  const { filter } = await searchParams;
  const project = await prisma.project.findUnique({
    where: { id },
    include: {
      issues: { orderBy: [{ status: "asc" }, { number: "desc" }] },
      securityStatus: true,
      architectureStatus: true,
      workerStatus: true,
    },
  });

  if (!project) notFound();

  const activeCard = CARDS.find((c) => c.key === filter);
  const displayed = activeCard
    ? project.issues.filter((i) => activeCard.statuses.includes(i.status))
    : project.issues;

  const now = Date.now();
  const ALIVE_MS = 2 * 60 * 1000;
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
              Основная ветка:{" "}
              <span className="font-mono" style={{ color: "var(--text)" }}>
                {project.branch}
              </span>
            </div>
            {project.lastSyncedAt && (
              <div className="text-sm mt-1" style={{ color: "var(--muted)" }}>
                Last synced {project.lastSyncedAt.toISOString().slice(0, 16).replace("T", " ")} UTC
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

      {project.issues.length > 0 && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
          {CARDS.map((card) => {
            const count = project.issues.filter((i) =>
              card.statuses.includes(i.status)
            ).length;
            const isActive = filter === card.key;
            const accent = STATUS_TEXT[card.key] ?? "var(--muted)";
            return (
              <Link
                key={card.key}
                href={isActive ? `/projects/${project.id}` : `/projects/${project.id}?filter=${card.key}`}
                className="rounded-lg border p-4 flex flex-col gap-1 transition-colors"
                style={{
                  background: isActive
                    ? STATUS_COLORS[card.key] ?? "var(--surface)"
                    : "var(--surface)",
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
        </div>
      )}

      {project.issues.length > 0 && (
        <section>
          <h2 className="text-lg font-semibold mb-3" style={{ color: "var(--text)" }}>
            {activeCard ? activeCard.label : "All issues"} ({displayed.length})
          </h2>
          {displayed.length > 0 ? (
            <div className="flex flex-col gap-2">
              {displayed.map((issue) => (
                <IssueRow
                  key={issue.id}
                  issue={issue}
                  showActions={issue.status === "proposed"}
                />
              ))}
            </div>
          ) : (
            <p style={{ color: "var(--muted)" }}>Нет issues в этой категории.</p>
          )}
        </section>
      )}

      {project.issues.length === 0 && (
        <p style={{ color: "var(--muted)" }}>No issues synced yet.</p>
      )}
    </div>
  );
}

function IssueRow({
  issue,
  showActions,
}: {
  issue: {
    id: string;
    number: number;
    title: string;
    status: string;
    pendingStatus: string | null;
    priority: string | null;
    url: string | null;
  };
  showActions?: boolean;
}) {
  const bg = STATUS_COLORS[issue.status] ?? STATUS_COLORS.none;
  const color = STATUS_TEXT[issue.status] ?? "var(--muted)";
  const isPending = issue.pendingStatus !== null;

  return (
    <div
      className="flex items-center gap-3 rounded-lg border p-4"
      style={{ background: "var(--surface)", borderColor: "var(--border)" }}
    >
      <span className="text-sm font-mono shrink-0" style={{ color: "var(--muted)" }}>
        #{issue.number}
      </span>
      <div className="flex-1 min-w-0">
        <div className="font-medium truncate" style={{ color: "var(--text)" }}>
          {issue.url ? (
            <a
              href={issue.url}
              target="_blank"
              rel="noopener noreferrer"
              className="hover:underline"
            >
              {issue.title}
            </a>
          ) : (
            issue.title
          )}
        </div>
        {issue.priority && (
          <div className="flex items-center gap-2 mt-1 text-xs" style={{ color: "var(--muted)" }}>
            <span>{issue.priority}</span>
          </div>
        )}
      </div>
      <div className="flex items-center gap-3 shrink-0">
        <span
          className="rounded-full px-2.5 py-0.5 text-xs font-medium"
          style={{ background: bg, color }}
        >
          {issue.status}
        </span>
        {isPending && (
          <span
            className="rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide"
            style={{
              background: "transparent",
              color: "var(--muted)",
              border: "1px dashed var(--border)",
            }}
            title="Ожидает синхронизации с GitHub"
          >
            pending sync
          </span>
        )}
        {showActions && <IssueActions issueId={issue.id} />}
      </div>
    </div>
  );
}
