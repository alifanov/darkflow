"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function IssueActions({ issueId }: { issueId: string }) {
  const router = useRouter();
  const [loading, setLoading] = useState<"approve" | "close" | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function act(action: "approve" | "close") {
    setLoading(action);
    setError(null);
    try {
      const res = await fetch(`/api/issues/${issueId}/${action}`, { method: "POST" });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error ?? res.statusText);
      }
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(null);
    }
  }

  return (
    <div className="flex items-center gap-2">
      {error && (
        <span className="text-xs mr-2" style={{ color: "var(--red)" }}>
          {error}
        </span>
      )}
      <button
        onClick={() => act("approve")}
        disabled={!!loading}
        className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
        style={{ background: "#1a3a1a", color: "var(--green)", border: "1px solid #2d5a2d" }}
      >
        {loading === "approve" ? "…" : "Approve"}
      </button>
      <button
        onClick={(e) => { e.stopPropagation(); act("close"); }}
        disabled={!!loading}
        className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
        style={{ background: "var(--card)", color: "var(--muted)", border: "1px solid var(--border)" }}
        title="Close this issue"
      >
        {loading === "close" ? "…" : "Close"}
      </button>
    </div>
  );
}
