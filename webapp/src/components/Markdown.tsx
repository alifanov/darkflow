"use client";

import type { ReactNode } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

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

export function Markdown({ children }: { children: string }) {
  return (
    <ReactMarkdown remarkPlugins={[remarkGfm]} components={MD_COMPONENTS}>
      {children}
    </ReactMarkdown>
  );
}
