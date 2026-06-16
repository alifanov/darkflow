"use client";

import { useState } from "react";
import { LocalTime } from "@/components/LocalTime";

interface MailboxRowProps {
  fromAddr: string;
  subject: string;
  body: string;
  seen: boolean;
  sentAt: string | null;
}

export function MailboxRow({ fromAddr, subject, body, seen, sentAt }: MailboxRowProps) {
  const [open, setOpen] = useState(false);
  const weight = seen ? 400 : 600;

  return (
    <>
      <tr
        className="project-row"
        onClick={() => setOpen((o) => !o)}
        style={{
          borderBottom: open ? undefined : "1px solid var(--border)",
          cursor: "pointer",
        }}
      >
        <td className="py-3 px-4 text-xs font-mono whitespace-nowrap" style={{ color: "var(--muted)" }}>
          {sentAt ? <LocalTime date={sentAt} /> : "—"}
        </td>
        <td className="py-3 px-4 text-sm" style={{ color: "var(--text)", fontWeight: weight }}>
          <div className="flex items-center gap-2">
            {!seen && (
              <span
                style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--accent)", display: "inline-block", flexShrink: 0 }}
              />
            )}
            <span className="max-w-xs truncate">{fromAddr || "—"}</span>
          </div>
        </td>
        <td className="py-3 px-4 text-sm" style={{ color: "var(--text)", fontWeight: weight }}>
          {subject || "(no subject)"}
        </td>
        <td className="py-3 px-4 text-xs text-right" style={{ color: "var(--muted)", width: "3rem" }}>
          {open ? "▾" : "▶"}
        </td>
      </tr>
      {open && (
        <tr style={{ borderBottom: "1px solid var(--border)" }}>
          <td colSpan={4} className="px-4 pb-4 pt-1">
            <pre
              className="text-xs overflow-auto max-h-[500px] p-3 rounded whitespace-pre-wrap break-words font-mono"
              style={{ background: "var(--bg)", color: "var(--text)", lineHeight: 1.5 }}
            >
              {body || "(empty body)"}
            </pre>
          </td>
        </tr>
      )}
    </>
  );
}
