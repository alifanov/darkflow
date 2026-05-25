"use client";

import { useState } from "react";
import { LocalTime } from "@/components/LocalTime";
import ReactMarkdown from "react-markdown";

interface LogRowProps {
  id: string;
  routine: string;
  summary: string;
  output: string | null;
  timestamp: string;
}

export function LogRow({ routine, summary, output, timestamp }: LogRowProps) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <tr
        className="project-row"
        onClick={output ? () => setOpen((o) => !o) : undefined}
        style={{
          borderBottom: open ? undefined : "1px solid var(--border)",
          cursor: output ? "pointer" : "default",
        }}
      >
        <td className="py-3 px-4 text-xs font-mono" style={{ color: "var(--muted)" }}>
          <LocalTime date={timestamp} />
        </td>
        <td className="py-3 px-4">
          <span
            className="rounded-full px-2 py-0.5 text-xs font-medium font-mono"
            style={{ background: "var(--bg)", color: "var(--text)", border: "1px solid var(--border)" }}
          >
            {routine}
          </span>
        </td>
        <td className="py-3 px-4 text-sm" style={{ color: "var(--text)" }}>
          {summary}
        </td>
        <td className="py-3 px-4 text-xs text-right" style={{ color: "var(--muted)", width: "3rem" }}>
          {output && (open ? "▾" : "▶")}
        </td>
      </tr>
      {open && output && (
        <tr style={{ borderBottom: "1px solid var(--border)" }}>
          <td colSpan={4} className="px-4 pb-4 pt-1">
            <div
              className="text-xs overflow-auto max-h-[500px] p-3 rounded prose prose-invert prose-xs max-w-none"
              style={{ background: "var(--bg)", color: "var(--text)", lineHeight: 1.5 }}
            >
              <ReactMarkdown
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
                }}
              >
                {output}
              </ReactMarkdown>
            </div>
          </td>
        </tr>
      )}
    </>
  );
}
