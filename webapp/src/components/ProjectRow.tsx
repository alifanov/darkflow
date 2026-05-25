"use client";

import { useRouter } from "next/navigation";
import { LocalTime } from "@/components/LocalTime";

interface ProjectRowProps {
  id: string;
  name: string;
  repoUrl: string | null;
  versionBadge: "current" | "outdated" | "missing";
  darkflowVersion: string | null;
  latestVersion: string;
  workerState: "running" | "online" | null;
  routine: string | null;
  proposedCount: number;
  totalIssues: number;
  lastSyncedAt: string | null;
}

export function ProjectRow({
  id,
  name,
  repoUrl,
  versionBadge,
  darkflowVersion,
  latestVersion,
  workerState,
  routine,
  proposedCount,
  totalIssues,
  lastSyncedAt,
}: ProjectRowProps) {
  const router = useRouter();

  const navigate = () => router.push(`/projects/${id}`);

  return (
    <tr
      className="project-row cursor-pointer"
      onClick={navigate}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          navigate();
        }
      }}
      role="link"
      tabIndex={0}
      style={{ borderBottom: "1px solid var(--border)" }}
    >
      {/* Name */}
      <td className="py-3 px-4 font-semibold" style={{ color: "var(--text)" }}>
        {name}
      </td>

      {/* Repo */}
      <td className="py-3 px-4 max-w-xs truncate font-mono text-xs" style={{ color: "var(--muted)" }}>
        {repoUrl ?? "—"}
      </td>

      {/* Version */}
      <td className="py-3 px-4">
        {versionBadge === "missing" && (
          <span className="text-xs font-mono px-1.5 py-0.5 rounded" style={{ background: "var(--border)", color: "var(--muted)" }}>
            DF —
          </span>
        )}
        {versionBadge === "current" && (
          <span className="text-xs font-mono px-1.5 py-0.5 rounded" style={{ background: "var(--border)", color: "var(--muted)" }}>
            v{darkflowVersion}
          </span>
        )}
        {versionBadge === "outdated" && (
          <span className="text-xs font-mono px-1.5 py-0.5 rounded bg-yellow-100 text-yellow-900 dark:bg-yellow-900/30 dark:text-yellow-200">
            v{darkflowVersion} ⚠ →{latestVersion}
          </span>
        )}
      </td>

      {/* Worker */}
      <td className="py-3 px-4">
        {workerState === "running" && (
          <span className="flex items-center gap-1.5 text-xs" style={{ color: "var(--green)" }}>
            <span
              className="worker-dot-running shrink-0"
              style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--green)", display: "inline-block" }}
            />
            {routine ?? "running"}
          </span>
        )}
        {workerState === "online" && (
          <span className="flex items-center gap-1.5 text-xs" style={{ color: "var(--green)" }}>
            <span
              className="shrink-0"
              style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--green)", opacity: 0.55, display: "inline-block" }}
            />
            online
          </span>
        )}
      </td>

      {/* Proposed */}
      <td className="py-3 px-4 text-right">
        {proposedCount > 0 && (
          <span
            className="rounded-full px-2.5 py-0.5 text-xs font-medium"
            style={{ background: "#1f3a5f", color: "var(--accent)" }}
          >
            {proposedCount} proposed
          </span>
        )}
      </td>

      {/* Issues */}
      <td className="py-3 px-4 text-right text-sm" style={{ color: "var(--muted)" }}>
        {totalIssues}
      </td>

      {/* Last synced */}
      <td className="py-3 px-4 text-xs" style={{ color: "var(--muted)" }}>
        {lastSyncedAt ? <LocalTime date={lastSyncedAt} /> : "—"}
      </td>
    </tr>
  );
}
