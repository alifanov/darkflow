"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function CloseIssueButton({ issueId }: { issueId: string }) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleClose() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/issues/${issueId}/close`, { method: "POST" });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error ?? res.statusText);
      }
      router.refresh();
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
        onClick={handleClose}
        disabled={loading}
        className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
        style={{ background: "#1a1a2e", color: "var(--accent)", border: "1px solid #2d2d4e" }}
      >
        {loading ? "…" : "Close"}
      </button>
    </div>
  );
}
