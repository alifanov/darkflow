"use client";

import { useState } from "react";

export function LaunchInCmuxButton({ issueId }: { issueId: string }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleLaunch() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/issues/${issueId}/launch`, { method: "POST" });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error ?? res.statusText);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex items-center gap-2">
      {error && (
        <span className="text-xs" style={{ color: "var(--red)" }}>
          {error}
        </span>
      )}
      <button
        onClick={handleLaunch}
        disabled={loading}
        title="Open a cmux workspace with Claude to fix this issue"
        className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50 whitespace-nowrap"
        style={{ background: "#3a1a3a", color: "#c084fc", border: "1px solid #5a2d5a" }}
      >
        {loading ? "…" : "Fix in cmux"}
      </button>
    </div>
  );
}
