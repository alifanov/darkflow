"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function DeleteProjectButton({ projectId, projectName }: { projectId: string; projectName: string }) {
  const router = useRouter();
  const [confirming, setConfirming] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleDelete() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/projects/${projectId}`, { method: "DELETE" });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error ?? res.statusText);
      }
      router.push("/");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
      setLoading(false);
      setConfirming(false);
    }
  }

  if (confirming) {
    return (
      <div className="flex items-center gap-2">
        {error && (
          <span className="text-xs" style={{ color: "var(--red)" }}>
            {error}
          </span>
        )}
        <span className="text-sm" style={{ color: "var(--muted)" }}>
          Delete <strong style={{ color: "var(--text)" }}>{projectName}</strong> and all its data?
        </span>
        <button
          onClick={handleDelete}
          disabled={loading}
          className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
          style={{ background: "#3a1a1a", color: "var(--red)", border: "1px solid #5a2d2d" }}
        >
          {loading ? "Deleting…" : "Yes, delete"}
        </button>
        <button
          onClick={() => setConfirming(false)}
          disabled={loading}
          className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
          style={{ background: "var(--surface)", color: "var(--muted)", border: "1px solid var(--border)" }}
        >
          Cancel
        </button>
      </div>
    );
  }

  return (
    <button
      onClick={() => setConfirming(true)}
      className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity hover:opacity-80"
      style={{ background: "var(--surface)", color: "var(--red)", border: "1px solid #5a2d2d" }}
    >
      Delete project
    </button>
  );
}
