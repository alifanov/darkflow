import Link from "next/link";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export default async function ProjectsPage() {
  const projects = await prisma.project.findMany({
    orderBy: { lastSyncedAt: "desc" },
    include: {
      _count: { select: { issues: true } },
      issues: {
        where: { status: "proposed" },
        select: { id: true },
      },
    },
  });

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
        <div className="flex flex-col gap-3">
          {projects.map((p) => (
            <Link
              key={p.id}
              href={`/projects/${p.id}`}
              className="block rounded-lg border p-5 transition-colors hover:border-blue-500"
              style={{
                background: "var(--surface)",
                borderColor: "var(--border)",
              }}
            >
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="font-semibold text-base" style={{ color: "var(--text)" }}>
                    {p.name}
                  </div>
                  <div className="text-sm mt-0.5" style={{ color: "var(--muted)" }}>
                    {p.repoUrl}
                  </div>
                </div>
                <div className="flex items-center gap-4 shrink-0 text-sm">
                  {p.issues.length > 0 && (
                    <span
                      className="rounded-full px-2.5 py-0.5 font-medium"
                      style={{ background: "#1f3a5f", color: "var(--accent)" }}
                    >
                      {p.issues.length} proposed
                    </span>
                  )}
                  <span style={{ color: "var(--muted)" }}>
                    {p._count.issues} issues
                  </span>
                </div>
              </div>
              {p.lastSyncedAt && (
                <div className="text-xs mt-2" style={{ color: "var(--muted)" }}>
                  Last synced {p.lastSyncedAt.toISOString().slice(0, 16).replace("T", " ")} UTC
                </div>
              )}
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
