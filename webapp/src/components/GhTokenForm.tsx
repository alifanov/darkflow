"use client";

import { useState } from "react";

export function GhTokenForm({ hasToken }: { hasToken: boolean }) {
  const [value, setValue] = useState("");
  const [status, setStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [showInput, setShowInput] = useState(false);

  const save = async () => {
    setStatus("saving");
    try {
      const res = await fetch("/api/settings/gh-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ghToken: value }),
      });
      if (!res.ok) throw new Error();
      setStatus("saved");
      setValue("");
      setShowInput(false);
      setTimeout(() => setStatus("idle"), 3000);
    } catch {
      setStatus("error");
    }
  };

  return (
    <div className="flex items-center gap-3">
      <span className="text-sm" style={{ color: "var(--muted)" }}>
        GitHub Token:
      </span>
      {!showInput && (
        <>
          <span
            className="text-xs px-2 py-0.5 rounded font-mono"
            style={{
              background: hasToken || status === "saved" ? "#1a3a1a" : "#2a1a1a",
              color: hasToken || status === "saved" ? "var(--green)" : "var(--red)",
            }}
          >
            {hasToken || status === "saved" ? "set" : "not set"}
          </span>
          <button
            onClick={() => setShowInput(true)}
            className="text-xs cursor-pointer"
            style={{ color: "var(--accent)" }}
          >
            {hasToken || status === "saved" ? "update" : "set token"}
          </button>
        </>
      )}
      {showInput && (
        <div className="flex items-center gap-2">
          <input
            type="password"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && value && save()}
            placeholder="ghp_..."
            autoFocus
            className="text-xs font-mono px-2 py-1 rounded"
            style={{
              background: "var(--surface)",
              border: "1px solid var(--border)",
              color: "var(--text)",
              width: 220,
              outline: "none",
            }}
          />
          <button
            onClick={save}
            disabled={!value || status === "saving"}
            className="text-xs px-2 py-1 rounded cursor-pointer"
            style={{
              background: value ? "var(--accent)" : "var(--surface)",
              color: value ? "#fff" : "var(--muted)",
              border: "1px solid var(--border)",
              opacity: status === "saving" ? 0.6 : 1,
            }}
          >
            {status === "saving" ? "Saving…" : "Save"}
          </button>
          <button
            onClick={() => { setShowInput(false); setValue(""); }}
            className="text-xs cursor-pointer"
            style={{ color: "var(--muted)" }}
          >
            cancel
          </button>
        </div>
      )}
      {status === "error" && (
        <span className="text-xs" style={{ color: "var(--red)" }}>Failed to save</span>
      )}
    </div>
  );
}
