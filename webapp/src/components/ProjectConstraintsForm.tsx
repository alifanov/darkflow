"use client";

import { useEffect, useRef, useState } from "react";

interface ProjectConstraintsFormProps {
  projectId: string;
  initialConstraints: string;
  hasLocalPath: boolean;
}

export function ProjectConstraintsForm({
  projectId,
  initialConstraints,
  hasLocalPath,
}: ProjectConstraintsFormProps) {
  const [text, setText] = useState(initialConstraints);
  const [status, setStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState("");

  const skipNextSave = useRef(true);
  const savedTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Debounced auto-save: fires shortly after the text changes, skipping the
  // initial mount so loading the form doesn't trigger a save.
  useEffect(() => {
    if (skipNextSave.current) {
      skipNextSave.current = false;
      return;
    }
    const timer = setTimeout(async () => {
      setStatus("saving");
      setErrorMsg("");
      try {
        const res = await fetch(`/api/projects/${projectId}/constraints`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ constraints: text }),
        });
        if (!res.ok) {
          const data = await res.json().catch(() => ({}));
          throw new Error(data.error ?? "Save failed");
        }
        setStatus("saved");
        if (savedTimer.current) clearTimeout(savedTimer.current);
        savedTimer.current = setTimeout(() => setStatus("idle"), 2000);
      } catch (e) {
        setStatus("error");
        setErrorMsg(e instanceof Error ? e.message : "Save failed");
      }
    }, 600);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [text]);

  return (
    <section className="flex flex-col gap-4 max-w-2xl">
      <h3 className="text-sm font-semibold uppercase tracking-wider" style={{ color: "var(--muted)" }}>
        Routine constraints
      </h3>

      {!hasLocalPath && (
        <span className="text-xs" style={{ color: "var(--muted)" }}>
          Set the project’s <strong>Local path</strong> above to enable constraints.
        </span>
      )}

      <div className="flex flex-col gap-1">
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          disabled={!hasLocalPath}
          rows={8}
          placeholder={"e.g.\n- Don't propose framework migrations\n- No new runtime dependencies\n- Keep changes scoped to one module per issue"}
          className="text-sm px-3 py-2 rounded font-mono"
          style={{
            background: "var(--surface)",
            border: "1px solid var(--border)",
            color: "var(--text)",
            outline: "none",
            width: "100%",
            resize: "vertical",
            opacity: hasLocalPath ? 1 : 0.5,
          }}
        />
        <span className="text-xs" style={{ color: "var(--muted)" }}>
          Plain text added to every agent’s context. Routines that analyze and propose changes
          honor these — findings that violate a constraint are dropped, not filed.
        </span>
      </div>

      <div className="flex items-center gap-3 h-5 text-sm">
        {status === "saving" && (
          <span style={{ color: "var(--muted)" }}>Saving…</span>
        )}
        {status === "saved" && (
          <span style={{ color: "var(--green)" }}>Saved ✓</span>
        )}
        {status === "error" && (
          <span style={{ color: "var(--red)" }}>{errorMsg || "Failed to save"}</span>
        )}
      </div>
    </section>
  );
}
