"use client";

import { useState, type ReactNode } from "react";

const TASK_MANAGER_URL = "https://flow.chatindex.app/tasks";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { IssueActions } from "@/components/IssueActions";
import { CloseIssueButton } from "@/components/CloseIssueButton";
import { LaunchInCmuxButton } from "@/components/LaunchInCmuxButton";

const STATUS_COLORS: Record<string, string> = {
  proposed: "#1f3a5f",
  approved: "#1a3a1a",
  rejected: "#3a1a1a",
  "in-progress": "#2a2a0a",
  none: "#1a1a1a",
};

const STATUS_TEXT: Record<string, string> = {
  proposed: "var(--accent)",
  approved: "var(--green)",
  rejected: "var(--red)",
  "in-progress": "#e3b341",
  none: "var(--muted)",
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
    pendingStatus: string | null;
    priority: string | null;
    url: string | null;
    needsHuman: boolean;
    comments?: IssueComment[] | null;
  };
  showActions?: boolean;
  showClose?: boolean;
  showTaskLink?: boolean;
  showLaunch?: boolean;
}

const MD_COMPONENTS = {
  code: ({ children, className }: { children?: ReactNode; className?: string }) => {
    const isBlock = className?.includes("language-");
    return isBlock ? (
      <pre className="font-mono text-xs whitespace-pre-wrap break-words rounded p-2 my-1" style={{ background: "var(--card)", color: "var(--text)" }}>
        <code>{children}</code>
      </pre>
    ) : (
      <code className="font-mono px-1 rounded text-xs" style={{ background: "var(--card)", color: "var(--text)" }}>{children}</code>
    );
  },
  pre: ({ children }: { children?: ReactNode }) => <>{children}</>,
  p: ({ children }: { children?: ReactNode }) => <p className="mb-1 last:mb-0">{children}</p>,
  ul: ({ children }: { children?: ReactNode }) => <ul className="list-disc pl-4 mb-1">{children}</ul>,
  ol: ({ children }: { children?: ReactNode }) => <ol className="list-decimal pl-4 mb-1">{children}</ol>,
  li: ({ children }: { children?: ReactNode }) => <li className="mb-0.5">{children}</li>,
  h1: ({ children }: { children?: ReactNode }) => <h1 className="text-sm font-bold mb-1">{children}</h1>,
  h2: ({ children }: { children?: ReactNode }) => <h2 className="text-sm font-semibold mb-1">{children}</h2>,
  h3: ({ children }: { children?: ReactNode }) => <h3 className="text-xs font-semibold mb-1">{children}</h3>,
  strong: ({ children }: { children?: ReactNode }) => <strong className="font-semibold">{children}</strong>,
  em: ({ children }: { children?: ReactNode }) => <em className="italic">{children}</em>,
  hr: () => <hr className="my-2 border-t" style={{ borderColor: "var(--border)" }} />,
  blockquote: ({ children }: { children?: ReactNode }) => (
    <blockquote className="border-l-2 pl-2 my-1 italic" style={{ borderColor: "var(--muted)", color: "var(--muted)" }}>
      {children}
    </blockquote>
  ),
  table: ({ children }: { children?: ReactNode }) => (
    <div className="overflow-x-auto my-2">
      <table className="text-xs border-collapse w-auto" style={{ borderColor: "var(--border)" }}>{children}</table>
    </div>
  ),
  thead: ({ children }: { children?: ReactNode }) => <thead>{children}</thead>,
  tbody: ({ children }: { children?: ReactNode }) => <tbody>{children}</tbody>,
  tr: ({ children }: { children?: ReactNode }) => <tr style={{ borderBottom: "1px solid var(--border)" }}>{children}</tr>,
  th: ({ children }: { children?: ReactNode }) => (
    <th className="px-3 py-1 text-left font-semibold" style={{ borderBottom: "1px solid var(--border)", color: "var(--muted)" }}>
      {children}
    </th>
  ),
  td: ({ children }: { children?: ReactNode }) => <td className="px-3 py-1">{children}</td>,
};

function Markdown({ children }: { children: string }) {
  return (
    <ReactMarkdown remarkPlugins={[remarkGfm]} components={MD_COMPONENTS}>
      {children}
    </ReactMarkdown>
  );
}

export function IssueTableRow({ issue, showActions, showClose, showTaskLink, showLaunch }: IssueTableRowProps) {
  const [open, setOpen] = useState(false);
  const bg = STATUS_COLORS[issue.status] ?? STATUS_COLORS.none;
  const color = STATUS_TEXT[issue.status] ?? "var(--muted)";
  const isPending = issue.pendingStatus !== null;
  const hasBody = !!issue.body;
  const comments = issue.comments ?? [];
  const hasContent = hasBody || comments.length > 0;

  return (
    <>
      <tr
        className="project-row"
        style={{ borderBottom: open ? undefined : "1px solid var(--border)" }}
      >
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
            {issue.url ? (
              <a
                href={issue.url}
                target="_blank"
                rel="noopener noreferrer"
                title="Open issue on GitHub"
                className="cursor-pointer hover:underline"
              >
                {issue.title}
              </a>
            ) : (
              <span>{issue.title}</span>
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
          <div className="flex items-center gap-2">
            {showActions && <IssueActions issueId={issue.id} />}
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
          <td colSpan={5} className="px-4 pb-4 pt-1">
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
