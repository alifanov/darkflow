"use client";

import { useRouter } from "next/navigation";
import { LocalTime } from "@/components/LocalTime";

interface ProjectRowProps {
  index: number;
  id: string;
  name: string;
  branch: string | null;
  language: string;
  versionBadge: "current" | "outdated" | "missing";
  darkflowVersion: string | null;
  latestVersion: string;
  workerState: "running" | "online" | null;
  routine: string | null;
  proposedCount: number;
  totalIssues: number;
  lastSyncedAt: string | null;
  lastRoutine: { routine: string; timestamp: string } | null;
}

export function ProjectRow({
  index,
  id,
  name,
  branch,
  language,
  versionBadge,
  darkflowVersion,
  latestVersion,
  workerState,
  routine,
  proposedCount,
  totalIssues,
  lastSyncedAt,
  lastRoutine,
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
      {/* Index */}
      <td className="py-3 px-4 font-mono text-xs" style={{ color: "var(--muted)", width: "2.5rem" }}>
        {index}
      </td>

      {/* Name */}
      <td className="py-3 px-4 font-semibold" style={{ color: "var(--text)" }}>
        {name}
      </td>

      {/* Branch */}
      <td className="py-3 px-4 font-mono text-xs" style={{ color: "var(--muted)" }}>
        {branch ?? "—"}
      </td>

      {/* Language */}
      <td className="py-3 px-4 text-xs" style={{ color: "var(--muted)" }}>
        {language}
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

      {/* Open Issues */}
      <td className="py-3 px-4 text-right text-sm" style={{ color: "var(--muted)" }}>
        {totalIssues}
        {proposedCount > 0 && (
          <span className="ml-1 text-xs font-semibold" style={{ color: "var(--accent)" }}>
            ({proposedCount})
          </span>
        )}
      </td>

      {/* Last routine */}
      <td className="py-3 px-4 text-xs" style={{ color: "var(--muted)" }}>
        {lastRoutine ? (
          <span>
            {lastRoutine.routine} · <LocalTime date={lastRoutine.timestamp} />
          </span>
        ) : "—"}
      </td>

      {/* Last synced */}
      <td className="py-3 px-4 text-xs" style={{ color: "var(--muted)" }}>
        {lastSyncedAt ? <LocalTime date={lastSyncedAt} /> : "—"}
      </td>
    </tr>
  );
}
