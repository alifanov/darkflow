"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export function MailboxSyncButton({ projectId }: { projectId: string }) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSync() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/projects/${projectId}/mailbox/sync`, { method: "POST" });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        throw new Error(data.error ?? res.statusText);
      }
      if (data.configured === false) {
        throw new Error("Mailbox not configured — set MAILBOX_IMAP_* in the project's .env");
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
        onClick={handleSync}
        disabled={loading}
        title="Fetch the latest messages from the project's IMAP mailbox"
        className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50 whitespace-nowrap"
        style={{ background: "var(--surface)", color: "var(--text)", border: "1px solid var(--border)" }}
      >
        {loading ? "Syncing…" : "Sync"}
      </button>
    </div>
  );
}
