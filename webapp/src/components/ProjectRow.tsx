"use client";

import { useRouter } from "next/navigation";
import { LocalTime } from "@/components/LocalTime";

const LANG_EMOJI: Record<string, string> = {
  russian: "🇷🇺",
  ru: "🇷🇺",
  english: "🇺🇸",
  en: "🇺🇸",
  spanish: "🇪🇸",
  es: "🇪🇸",
  french: "🇫🇷",
  fr: "🇫🇷",
  german: "🇩🇪",
  de: "🇩🇪",
  chinese: "🇨🇳",
  zh: "🇨🇳",
  japanese: "🇯🇵",
  ja: "🇯🇵",
  portuguese: "🇵🇹",
  pt: "🇵🇹",
  italian: "🇮🇹",
  it: "🇮🇹",
  korean: "🇰🇷",
  ko: "🇰🇷",
  arabic: "🇸🇦",
  ar: "🇸🇦",
  turkish: "🇹🇷",
  tr: "🇹🇷",
  polish: "🇵🇱",
  pl: "🇵🇱",
  ukrainian: "🇺🇦",
  uk: "🇺🇦",
};

function langEmoji(language: string): string {
  return LANG_EMOJI[language.toLowerCase()] ?? "🌐";
}

interface ProjectRowProps {
  index: number;
  id: string;
  name: string;
  domain: string | null;
  branch: string | null;
  language: string;
  versionBadge: "current" | "outdated" | "missing";
  darkflowVersion: string | null;
  latestVersion: string;
  workerState: "running" | "online" | null;
  settingsPending?: boolean;
  routine: string | null;
  proposedCount: number;
  approvedCount: number;
  needsHumanCount: number;
  totalIssues: number;
  lastSyncedAt: string | null;
  lastRoutine: { routine: string; timestamp: string } | null;
}

export function ProjectRow({
  index,
  id,
  name,
  domain,
  branch,
  language,
  versionBadge,
  darkflowVersion,
  latestVersion,
  workerState,
  settingsPending,
  routine,
  proposedCount,
  approvedCount,
  needsHumanCount,
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

      {/* Domain */}
      <td className="py-3 px-4 text-xs font-mono" style={{ color: "var(--muted)" }}>
        {domain ? (
          <a
            href={domain.startsWith("http") ? domain : `https://${domain}`}
            target="_blank"
            rel="noopener noreferrer"
            onClick={(e) => e.stopPropagation()}
            className="hover:underline"
            style={{ color: "var(--accent)" }}
          >
            {domain.replace(/^https?:\/\//, "")}
          </a>
        ) : (
          "—"
        )}
      </td>

      {/* Branch */}
      <td className="py-3 px-4 font-mono text-xs" style={{ color: "var(--muted)" }}>
        {branch ?? "—"}
      </td>

      {/* Language */}
      <td className="py-3 px-4 text-xs" style={{ color: "var(--muted)" }}>
        <span className="flex items-center gap-1">
          <span>{langEmoji(language)}</span>
          <span>{language}</span>
        </span>
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
        {settingsPending && (
          <span
            className="inline-block mb-1 text-xs font-medium px-1.5 py-0.5 rounded bg-amber-100 text-amber-900 dark:bg-amber-900/30 dark:text-amber-200"
            title="Settings changed in the UI but the worker hasn't pulled them yet"
          >
            settings pending
          </span>
        )}
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
      <td className="py-3 px-4 text-right text-sm" style={{ color: "var(--text)" }}>
        {totalIssues}
      </td>

      {/* Needs approval */}
      <td className="py-3 px-4 text-right text-sm" style={{ color: proposedCount > 0 ? "var(--accent)" : "var(--muted)" }}>
        {proposedCount > 0 ? proposedCount : "—"}
      </td>

      {/* Approved */}
      <td className="py-3 px-4 text-right text-sm" style={{ color: approvedCount > 0 ? "var(--green)" : "var(--muted)" }}>
        {approvedCount > 0 ? approvedCount : "—"}
      </td>

      {/* Needs Human */}
      <td className="py-3 px-4 text-right text-sm" style={{ color: needsHumanCount > 0 ? "#c084fc" : "var(--muted)" }}>
        {needsHumanCount > 0 ? `${needsHumanCount} 👤` : "—"}
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
      <td
        className="py-3 px-4 text-xs"
        style={{
          color: lastSyncedAt && Date.now() - new Date(lastSyncedAt).getTime() > 60 * 60 * 1000
            ? "var(--red)"
            : "var(--muted)",
        }}
      >
        {lastSyncedAt ? <LocalTime date={lastSyncedAt} /> : "—"}
      </td>
    </tr>
  );
}
