"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function IssueActions({ issueId }: { issueId: string }) {
  const router = useRouter();
  const [loading, setLoading] = useState<"approve" | "reject" | "needs-info" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [needsInfoOpen, setNeedsInfoOpen] = useState(false);
  const [question, setQuestion] = useState("");

  async function act(action: "approve" | "reject") {
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

  async function sendNeedsInfo() {
    if (!question.trim()) return;
    setLoading("needs-info");
    setError(null);
    try {
      const res = await fetch(`/api/issues/${issueId}/needs-info`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ question: question.trim() }),
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error ?? res.statusText);
      }
      setNeedsInfoOpen(false);
      setQuestion("");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(null);
    }
  }

  if (needsInfoOpen) {
    return (
      <div className="flex flex-col gap-2" onClick={(e) => e.stopPropagation()}>
        {error && (
          <span className="text-xs" style={{ color: "var(--red)" }}>
            {error}
          </span>
        )}
        <textarea
          className="rounded px-2 py-1 text-xs font-mono resize-none"
          style={{
            background: "var(--card)",
            color: "var(--text)",
            border: "1px solid var(--border)",
            width: "280px",
            height: "64px",
          }}
          placeholder="What's unclear? Agent will reply in the issue comments."
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          autoFocus
          onKeyDown={(e) => {
            if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) sendNeedsInfo();
            if (e.key === "Escape") { setNeedsInfoOpen(false); setQuestion(""); }
          }}
        />
        <div className="flex gap-2">
          <button
            onClick={sendNeedsInfo}
            disabled={!question.trim() || !!loading}
            className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
            style={{ background: "#1f1f3a", color: "#d4c5f9", border: "1px solid #3a3a6a" }}
          >
            {loading === "needs-info" ? "…" : "Send"}
          </button>
          <button
            onClick={() => { setNeedsInfoOpen(false); setQuestion(""); }}
            disabled={!!loading}
            className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
            style={{ background: "transparent", color: "var(--muted)", border: "1px solid var(--border)" }}
          >
            Cancel
          </button>
        </div>
      </div>
    );
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
        onClick={(e) => { e.stopPropagation(); setNeedsInfoOpen(true); }}
        disabled={!!loading}
        className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
        style={{ background: "#1f1f3a", color: "#d4c5f9", border: "1px solid #3a3a6a" }}
        title="Ask the agent for clarification"
      >
        ?
      </button>
      <button
        onClick={() => act("reject")}
        disabled={!!loading}
        className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
        style={{ background: "#3a1a1a", color: "var(--red)", border: "1px solid #5a2d2d" }}
      >
        {loading === "reject" ? "…" : "Reject"}
      </button>
    </div>
  );
}
