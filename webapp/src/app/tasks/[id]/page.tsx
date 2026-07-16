import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "@/lib/prisma";
import { Markdown } from "@/components/Markdown";
import { LocalTime } from "@/components/LocalTime";
import type { IssueComment } from "@/components/IssueTableRow";

export const dynamic = "force-dynamic";

const STATUS_COLORS: Record<string, string> = {
  proposed: "#1f3a5f",
  approved: "#1a3a1a",
  closed: "#3a1a1a",
  "in-progress": "#2a2a0a",
};

const STATUS_TEXT: Record<string, string> = {
  proposed: "var(--accent)",
  approved: "var(--green)",
  closed: "var(--red)",
  "in-progress": "#e3b341",
};

function Meta({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="text-[10px] font-semibold uppercase tracking-wide mb-0.5" style={{ color: "var(--muted)" }}>
        {label}
      </div>
      <div className="text-sm">{children}</div>
    </div>
  );
}

export default async function TaskPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const issue = await prisma.issue.findUnique({ where: { id }, include: { project: true } });
  if (!issue) notFound();

  const bg = STATUS_COLORS[issue.status] ?? "#1a1a1a";
  const color = STATUS_TEXT[issue.status] ?? "var(--muted)";
  const comments = (issue.comments ?? []) as IssueComment[];

  return (
    <div className="max-w-3xl mx-auto px-4 py-8">
      <Link href={`/projects/${issue.projectId}`} className="cursor-pointer text-sm hover:underline" style={{ color: "var(--accent)" }}>
        ← {issue.project.name}
      </Link>

      <h1 className="text-xl font-semibold mt-3 mb-4" style={{ color: "var(--text)" }}>
        <span className="font-mono text-sm mr-2" style={{ color: "var(--muted)" }}>#{issue.number}</span>
        {issue.title}
      </h1>

      <div className="flex items-center gap-4 flex-wrap mb-6 pb-4" style={{ borderBottom: "1px solid var(--border)" }}>
        <span className="rounded-full px-2.5 py-0.5 text-xs font-medium" style={{ background: bg, color }}>
          {issue.status}
        </span>
        {issue.priority && <Meta label="Priority">{issue.priority}</Meta>}
        {issue.source && <Meta label="Source">{issue.source}</Meta>}
        {issue.action && <Meta label="Action">{issue.action}</Meta>}
        {issue.needsHuman && <Meta label="Needs human">yes</Meta>}
        {issue.createdAt && (
          <Meta label="Created">
            <LocalTime date={issue.createdAt} />
          </Meta>
        )}
        {issue.scheduledFor && issue.scheduledFor > new Date() && (
          <Meta label="Snoozed until">
            <LocalTime date={issue.scheduledFor} />
          </Meta>
        )}
        {issue.url && (
          <a href={issue.url} target="_blank" rel="noopener noreferrer" className="cursor-pointer text-sm hover:underline" style={{ color: "var(--muted)" }}>
            External link ↗
          </a>
        )}
      </div>

      {issue.body && (
        <div className="text-sm prose prose-invert prose-sm max-w-none mb-6" style={{ color: "var(--text)", lineHeight: 1.6 }}>
          <Markdown>{issue.body}</Markdown>
        </div>
      )}

      {comments.length > 0 && (
        <div>
          <div className="text-xs font-semibold uppercase tracking-wide mb-2 pb-1 border-b" style={{ color: "var(--muted)", borderColor: "var(--border)" }}>
            Comments ({comments.length})
          </div>
          <div className="flex flex-col gap-2">
            {comments.map((c, idx) => (
              <div key={idx} className="rounded p-3" style={{ background: "var(--surface)", border: "1px solid var(--border)" }}>
                <div className="flex items-center gap-2 mb-1 text-xs" style={{ color: "var(--muted)" }}>
                  <span className="font-semibold" style={{ color: "var(--text)" }}>{c.author ?? "unknown"}</span>
                  {c.createdAt && <span>{new Date(c.createdAt).toLocaleString()}</span>}
                </div>
                {c.body ? <Markdown>{c.body}</Markdown> : <span style={{ color: "var(--muted)" }}>(empty)</span>}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
