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
  proposedCount: number;
  approvedCount: number;
  needsHumanCount: number;
  totalIssues: number;
  errorCount: number;
  lastRoutine: { routine: string; timestamp: string } | null;
}

export function ProjectRow({
  index,
  id,
  name,
  domain,
  branch,
  language,
  proposedCount,
  approvedCount,
  needsHumanCount,
  totalIssues,
  errorCount,
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

      {/* Errors (failed routine runs, last 7 days) */}
      <td
        className="py-3 px-4 text-right text-sm"
        style={{ color: errorCount > 0 ? "var(--red)" : "var(--muted)" }}
        title={errorCount > 0 ? `${errorCount} failed routine run(s) in the last 24h` : "No routine errors in the last 24h"}
      >
        {errorCount > 0 ? errorCount : "—"}
      </td>

      {/* Last routine */}
      <td className="py-3 px-4 text-xs" style={{ color: "var(--muted)" }}>
        {lastRoutine ? (
          <span>
            {lastRoutine.routine} · <LocalTime date={lastRoutine.timestamp} />
          </span>
        ) : "—"}
      </td>
    </tr>
  );
}
