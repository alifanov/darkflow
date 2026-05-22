"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function BranchEditor({
  projectId,
  branch,
}: {
  projectId: string;
  branch: string;
}) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(branch);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSave() {
    const next = value.trim();
    if (!next) {
      setError("Введите имя ветки");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/projects/${projectId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ branch: next }),
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error ?? res.statusText);
      }
      setEditing(false);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }

  if (editing) {
    return (
      <div className="flex items-center gap-2 mt-1">
        <input
          value={value}
          onChange={(e) => setValue(e.target.value)}
          disabled={loading}
          autoFocus
          className="rounded px-2 py-1 text-sm font-mono"
          style={{
            background: "var(--surface)",
            color: "var(--text)",
            border: "1px solid var(--border)",
          }}
        />
        <button
          onClick={handleSave}
          disabled={loading}
          className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
          style={{ background: "#1a3a1a", color: "var(--green)", border: "1px solid #2d5a2d" }}
        >
          {loading ? "Сохранение…" : "Сохранить"}
        </button>
        <button
          onClick={() => {
            setEditing(false);
            setValue(branch);
            setError(null);
          }}
          disabled={loading}
          className="cursor-pointer rounded px-3 py-1 text-sm font-medium transition-opacity disabled:opacity-50"
          style={{ background: "var(--surface)", color: "var(--muted)", border: "1px solid var(--border)" }}
        >
          Отмена
        </button>
        {error && (
          <span className="text-xs" style={{ color: "var(--red)" }}>
            {error}
          </span>
        )}
      </div>
    );
  }

  return (
    <div className="flex items-center gap-2 mt-1 text-sm" style={{ color: "var(--muted)" }}>
      <span>
        Основная ветка:{" "}
        <span className="font-mono" style={{ color: "var(--text)" }}>
          {branch}
        </span>
      </span>
      <button
        onClick={() => setEditing(true)}
        className="cursor-pointer text-xs hover:underline"
        style={{ color: "var(--accent)" }}
      >
        изменить
      </button>
    </div>
  );
}
