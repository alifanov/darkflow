"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";

// ponytail: native <input type="date"> opened via showPicker — no picker lib.
export function SnoozeIssueButton({ issueId, scheduledFor }: { issueId: string; scheduledFor?: string | null }) {
  const router = useRouter();
  const inputRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const snoozed = !!scheduledFor && new Date(scheduledFor) > new Date();

  async function setUntil(until: string | null) {
    setBusy(true);
    try {
      const res = await fetch(`/api/issues/${issueId}/snooze`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ until }),
      });
      if (res.ok) router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <span className="inline-flex items-center">
      <input
        ref={inputRef}
        type="date"
        className="sr-only"
        tabIndex={-1}
        aria-hidden="true"
        onChange={(e) => {
          if (e.target.value) setUntil(new Date(`${e.target.value}T00:00:00`).toISOString());
        }}
      />
      <button
        type="button"
        disabled={busy}
        onClick={() => {
          if (snoozed) setUntil(null);
          else inputRef.current?.showPicker?.();
        }}
        title={snoozed ? `Snoozed until ${new Date(scheduledFor!).toLocaleDateString()} — click to clear` : "Snooze: don't pick up before a date"}
        className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity hover:opacity-80 whitespace-nowrap disabled:opacity-50"
        style={{ background: "#2a2a0a", color: "var(--yellow, #d29922)", border: "1px solid var(--border)" }}
      >
        {snoozed ? "Unsnooze" : "Snooze"}
      </button>
    </span>
  );
}
