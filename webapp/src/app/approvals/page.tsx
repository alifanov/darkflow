import { prisma } from "@/lib/prisma";
import { IssueTableRow, type IssueComment } from "@/components/IssueTableRow";

export const dynamic = "force-dynamic";

const PRIORITY_ORDER: Record<string, number> = { critical: 0, high: 1, medium: 2, low: 3 };

// Global queue of every issue awaiting approval (status:proposed) across all
// projects — so the user doesn't have to open each project to triage.
export default async function ApprovalsPage() {
  const projects = await prisma.project.findMany({
    select: {
      id: true,
      name: true,
      issues: {
        where: { status: "proposed", state: { in: ["OPEN", "open"] } },
        orderBy: { number: "desc" },
      },
    },
  });

  const rows = projects
    .flatMap((p) =>
      p.issues.map((i) => ({
        issue: { ...i, comments: (i.comments ?? null) as IssueComment[] | null },
        project: { name: p.name, href: `/projects/${p.id}` },
      })),
    )
    .sort((a, b) => {
      const pa = PRIORITY_ORDER[a.issue.priority ?? ""] ?? 99;
      const pb = PRIORITY_ORDER[b.issue.priority ?? ""] ?? 99;
      if (pa !== pb) return pa - pb;
      return b.issue.number - a.issue.number;
    });

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6" style={{ color: "var(--text)" }}>
        Needs approval ({rows.length})
      </h1>

      {rows.length === 0 ? (
        <p style={{ color: "var(--muted)" }}>Nothing waiting for approval.</p>
      ) : (
        <div style={{ border: "1px solid var(--border)", borderRadius: 8, overflow: "hidden" }}>
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr style={{ background: "var(--surface)", borderBottom: "1px solid var(--border)" }}>
                {["Project", "#", "Title", "Priority", "Status", "Actions"].map((col) => (
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
            <tbody>
              {rows.map(({ issue, project }) => (
                <IssueTableRow
                  key={issue.id}
                  issue={issue}
                  project={project}
                  showApprove
                  showLaunch
                  showClose
                  showTaskLink
                />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
