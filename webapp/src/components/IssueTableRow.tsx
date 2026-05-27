"use client";

import { useState } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { IssueActions } from "@/components/IssueActions";
import { CloseIssueButton } from "@/components/CloseIssueButton";

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

interface IssueTableRowProps {
  issue: {
    id: string;
    number: number;
    title: string;
    body: string | null;
    status: string;
    pendingStatus: string | null;
    priority: string | null;
    url: string | null;
    needsHuman: boolean;
  };
  showActions?: boolean;
  showClose?: boolean;
}

export function IssueTableRow({ issue, showActions, showClose }: IssueTableRowProps) {
  const [open, setOpen] = useState(false);
  const bg = STATUS_COLORS[issue.status] ?? STATUS_COLORS.none;
  const color = STATUS_TEXT[issue.status] ?? "var(--muted)";
  const isPending = issue.pendingStatus !== null;
  const hasBody = !!issue.body;

  return (
    <>
      <tr
        className="project-row"
        style={{
          borderBottom: open ? undefined : "1px solid var(--border)",
          cursor: hasBody ? "pointer" : "default",
        }}
        onClick={hasBody ? () => setOpen((o) => !o) : undefined}
      >
        <td className="py-3 px-4 font-mono text-xs" style={{ color: "var(--muted)", width: "3.5rem" }}>
          #{issue.number}
        </td>
        <td className="py-3 px-4">
          <div className="flex items-center gap-1.5 font-medium" style={{ color: "var(--text)" }}>
            {hasBody && (
              <span className="text-xs shrink-0" style={{ color: "var(--muted)" }}>
                {open ? "▾" : "▶"}
              </span>
            )}
            <span>{issue.title}</span>
            {issue.url && (
              <a
                href={issue.url}
                target="_blank"
                rel="noopener noreferrer"
                aria-label="Open in GitHub"
                className="shrink-0 cursor-pointer hover:opacity-80"
                style={{ color: "var(--muted)" }}
                onClick={(e) => e.stopPropagation()}
              >
                ↗
              </a>
            )}
          </div>
        </td>
        <td className="py-3 px-4 text-xs" style={{ color: "var(--muted)" }}>
          {issue.priority ?? "—"}
        </td>
        <td className="py-3 px-4">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="rounded-full px-2.5 py-0.5 text-xs font-medium" style={{ background: bg, color }}>
              {issue.status}
            </span>
            {isPending && (
              <span
                className="rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide"
                style={{ background: "transparent", color: "var(--muted)", border: "1px dashed var(--border)" }}
                title="Pending sync with GitHub"
              >
                pending sync
              </span>
            )}
          </div>
        </td>
        <td className="py-3 px-4">
          {showActions && <IssueActions issueId={issue.id} />}
          {showClose && <CloseIssueButton issueId={issue.id} />}
        </td>
      </tr>
      {open && hasBody && (
        <tr style={{ borderBottom: "1px solid var(--border)" }}>
          <td colSpan={5} className="px-4 pb-4 pt-1">
            <div
              className="text-xs overflow-auto max-h-[500px] p-3 rounded prose prose-invert prose-xs max-w-none"
              style={{ background: "var(--bg)", color: "var(--text)", lineHeight: 1.5 }}
            >
              <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                components={{
                  code: ({ children, className }) => {
                    const isBlock = className?.includes("language-");
                    return isBlock ? (
                      <pre className="font-mono text-xs whitespace-pre-wrap break-words rounded p-2 my-1" style={{ background: "var(--card)", color: "var(--text)" }}>
                        <code>{children}</code>
                      </pre>
                    ) : (
                      <code className="font-mono px-1 rounded text-xs" style={{ background: "var(--card)", color: "var(--text)" }}>{children}</code>
                    );
                  },
                  pre: ({ children }) => <>{children}</>,
                  p: ({ children }) => <p className="mb-1 last:mb-0">{children}</p>,
                  ul: ({ children }) => <ul className="list-disc pl-4 mb-1">{children}</ul>,
                  ol: ({ children }) => <ol className="list-decimal pl-4 mb-1">{children}</ol>,
                  li: ({ children }) => <li className="mb-0.5">{children}</li>,
                  h1: ({ children }) => <h1 className="text-sm font-bold mb-1">{children}</h1>,
                  h2: ({ children }) => <h2 className="text-sm font-semibold mb-1">{children}</h2>,
                  h3: ({ children }) => <h3 className="text-xs font-semibold mb-1">{children}</h3>,
                  strong: ({ children }) => <strong className="font-semibold">{children}</strong>,
                  em: ({ children }) => <em className="italic">{children}</em>,
                  hr: () => <hr className="my-2 border-t" style={{ borderColor: "var(--border)" }} />,
                  blockquote: ({ children }) => (
                    <blockquote className="border-l-2 pl-2 my-1 italic" style={{ borderColor: "var(--muted)", color: "var(--muted)" }}>
                      {children}
                    </blockquote>
                  ),
                  table: ({ children }) => (
                    <div className="overflow-x-auto my-2">
                      <table className="text-xs border-collapse w-auto" style={{ borderColor: "var(--border)" }}>{children}</table>
                    </div>
                  ),
                  thead: ({ children }) => <thead>{children}</thead>,
                  tbody: ({ children }) => <tbody>{children}</tbody>,
                  tr: ({ children }) => <tr style={{ borderBottom: "1px solid var(--border)" }}>{children}</tr>,
                  th: ({ children }) => (
                    <th className="px-3 py-1 text-left font-semibold" style={{ borderBottom: "1px solid var(--border)", color: "var(--muted)" }}>
                      {children}
                    </th>
                  ),
                  td: ({ children }) => <td className="px-3 py-1">{children}</td>,
                }}
              >
                {issue.body}
              </ReactMarkdown>
            </div>
          </td>
        </tr>
      )}
    </>
  );
}
