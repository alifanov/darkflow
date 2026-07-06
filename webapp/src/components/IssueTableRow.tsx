"use client";

import { useState } from "react";
import Link from "next/link";

const TASK_MANAGER_URL = "https://flow.chatindex.app/tasks";
import { ApproveIssueButton } from "@/components/ApproveIssueButton";
import { CloseIssueButton } from "@/components/CloseIssueButton";
import { LaunchInCmuxButton } from "@/components/LaunchInCmuxButton";
import { Markdown } from "@/components/Markdown";

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

export interface IssueComment {
  author?: string;
  body?: string;
  createdAt?: string;
}

interface IssueTableRowProps {
  issue: {
    id: string;
    number: number;
    title: string;
    body: string | null;
    status: string;
    priority: string | null;
    url: string | null;
    needsHuman: boolean;
    comments?: IssueComment[] | null;
  };
  showApprove?: boolean;
  showClose?: boolean;
  showTaskLink?: boolean;
  showLaunch?: boolean;
  /** Issue priority is below the project's configured minimum — flagged in the list. */
  belowThreshold?: boolean;
  /** When set, renders a leading "Project" cell (used by the global approvals page). */
  project?: { name: string; href: string };
}

export function IssueTableRow({ issue, showApprove, showClose, showTaskLink, showLaunch, belowThreshold, project }: IssueTableRowProps) {
  const [open, setOpen] = useState(false);
  const bg = STATUS_COLORS[issue.status] ?? "#1a1a1a";
  const color = STATUS_TEXT[issue.status] ?? "var(--muted)";
  const hasBody = !!issue.body;
  const comments = issue.comments ?? [];
  const hasContent = hasBody || comments.length > 0;

  return (
    <>
      <tr
        className="project-row"
        style={{
          borderBottom: open ? undefined : "1px solid var(--border)",
          ...(belowThreshold && {
            borderLeft: "3px solid var(--yellow)",
            background: "rgba(210, 153, 34, 0.07)",
          }),
        }}
      >
        {project && (
          <td className="py-3 px-4 text-xs">
            <a href={project.href} className="cursor-pointer hover:underline" style={{ color: "var(--accent)" }}>
              {project.name}
            </a>
          </td>
        )}
        <td className="py-3 px-4 font-mono text-xs" style={{ color: "var(--muted)", width: "3.5rem" }}>
          #{issue.number}
        </td>
        <td className="py-3 px-4">
          <div className="flex items-center gap-2 font-medium" style={{ color: "var(--text)" }}>
            {hasContent && (
              <button
                type="button"
                onClick={() => setOpen((o) => !o)}
                aria-label={open ? "Collapse details" : "Expand details"}
                aria-expanded={open}
                title={open ? "Hide details" : "Show body & comments"}
                className="shrink-0 cursor-pointer rounded px-1.5 py-0.5 text-xs transition-colors"
                style={{ color: "var(--muted)", border: "1px solid var(--border)", background: open ? "var(--surface)" : "transparent" }}
              >
                {open ? "▾" : "▶"}
                {comments.length > 0 && <span className="ml-1">{comments.length}💬</span>}
              </button>
            )}
            <Link href={`/tasks/${issue.id}`} title="Open" className="cursor-pointer hover:underline">
              {issue.title}
            </Link>
            {issue.url && (
              <a
                href={issue.url}
                target="_blank"
                rel="noopener noreferrer"
                title="Open external link"
                className="shrink-0 cursor-pointer hover:underline"
                style={{ color: "var(--muted)" }}
              >
                ↗
              </a>
            )}
          </div>
        </td>
        <td
          className="py-3 px-4 text-xs"
          style={{ color: belowThreshold ? "var(--yellow)" : "var(--muted)", fontWeight: belowThreshold ? 600 : undefined }}
          title={belowThreshold ? "Below this project's minimum issue priority" : undefined}
        >
          {issue.priority ?? "—"}
        </td>
        <td className="py-3 px-4">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="rounded-full px-2.5 py-0.5 text-xs font-medium" style={{ background: bg, color }}>
              {issue.status}
            </span>
            {issue.needsHuman && (
              <span
                className="rounded-full px-2.5 py-0.5 text-xs font-medium"
                style={{ background: "#3a2a0a", color: "var(--yellow, #d29922)" }}
                title="Was approved, then bounced back — needs a manual step, then Close (not Approve)"
              >
                needs human
              </span>
            )}
          </div>
        </td>
        <td className="py-3 px-4">
          <div className="flex items-center gap-2">
            {showApprove && <ApproveIssueButton issueId={issue.id} />}
            {showLaunch && <LaunchInCmuxButton issueId={issue.id} />}
            {showClose && <CloseIssueButton issueId={issue.id} />}
            {showTaskLink && (
              <a
                href={`${TASK_MANAGER_URL}?title=${encodeURIComponent(issue.title)}`}
                target="_blank"
                rel="noopener noreferrer"
                className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity hover:opacity-80 inline-block whitespace-nowrap"
                style={{ background: "#1a1a2e", color: "var(--accent)", border: "1px solid var(--border)" }}
              >
                + Task
              </a>
            )}
          </div>
        </td>
      </tr>
      {open && hasContent && (
        <tr style={{ borderBottom: "1px solid var(--border)" }}>
          <td colSpan={project ? 6 : 5} className="px-4 pb-4 pt-1">
            <div
              className="text-xs overflow-auto max-h-[500px] p-3 rounded prose prose-invert prose-xs max-w-none"
              style={{ background: "var(--bg)", color: "var(--text)", lineHeight: 1.5 }}
            >
              {hasBody && <Markdown>{issue.body!}</Markdown>}
              {comments.length > 0 && (
                <div className="mt-3">
                  <div
                    className="text-[10px] font-semibold uppercase tracking-wide mb-2 pb-1 border-b"
                    style={{ color: "var(--muted)", borderColor: "var(--border)" }}
                  >
                    Comments ({comments.length})
                  </div>
                  <div className="flex flex-col gap-2">
                    {comments.map((c, idx) => (
                      <div
                        key={idx}
                        className="rounded p-2"
                        style={{ background: "var(--surface)", border: "1px solid var(--border)" }}
                      >
                        <div className="flex items-center gap-2 mb-1 text-[10px]" style={{ color: "var(--muted)" }}>
                          <span className="font-semibold" style={{ color: "var(--text)" }}>
                            {c.author ?? "unknown"}
                          </span>
                          {c.createdAt && <span>{new Date(c.createdAt).toLocaleString()}</span>}
                        </div>
                        {c.body ? <Markdown>{c.body}</Markdown> : <span style={{ color: "var(--muted)" }}>(empty)</span>}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </td>
        </tr>
      )}
    </>
  );
}
