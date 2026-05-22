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

export default async function ProjectPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const project = await prisma.project.findUnique({
    where: { id },
    include: {
      issues: { orderBy: [{ status: "asc" }, { number: "desc" }] },
      securityStatus: true,
      architectureStatus: true,
    },
  });

  if (!project) notFound();

  const proposed = project.issues.filter((i) => i.status === "proposed");
  const others = project.issues.filter((i) => i.status !== "proposed");

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
            {project.lastSyncedAt && (
              <div className="text-sm mt-1" style={{ color: "var(--muted)" }}>
                Last synced {project.lastSyncedAt.toISOString().slice(0, 16).replace("T", " ")} UTC
              </div>
            )}
          </div>
          <div className="shrink-0 mt-1">
            <DeleteProjectButton projectId={project.id} projectName={project.name} />
          </div>
        </div>
      </div>

      {proposed.length > 0 && (
        <section className="mb-8">
          <h2 className="text-lg font-semibold mb-3" style={{ color: "var(--text)" }}>
            Awaiting approval ({proposed.length})
          </h2>
          <div className="flex flex-col gap-2">
            {proposed.map((issue) => (
              <IssueRow key={issue.id} issue={issue} showActions />
            ))}
          </div>
        </section>
      )}

      {others.length > 0 && (
        <section>
          <h2 className="text-lg font-semibold mb-3" style={{ color: "var(--text)" }}>
            All issues ({others.length})
          </h2>
          <div className="flex flex-col gap-2">
            {others.map((issue) => (
              <IssueRow key={issue.id} issue={issue} />
            ))}
          </div>
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
    priority: string | null;
    area: string | null;
    url: string | null;
  };
  showActions?: boolean;
}) {
  const bg = STATUS_COLORS[issue.status] ?? STATUS_COLORS.none;
  const color = STATUS_TEXT[issue.status] ?? "var(--muted)";

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
        <div className="flex items-center gap-2 mt-1 text-xs" style={{ color: "var(--muted)" }}>
          {issue.area && <span>{issue.area}</span>}
          {issue.priority && <span>· {issue.priority}</span>}
        </div>
      </div>
      <div className="flex items-center gap-3 shrink-0">
        <span
          className="rounded-full px-2.5 py-0.5 text-xs font-medium"
          style={{ background: bg, color }}
        >
          {issue.status}
        </span>
        {showActions && <IssueActions issueId={issue.id} />}
      </div>
    </div>
  );
}
