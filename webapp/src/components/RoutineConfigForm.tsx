"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { ALL_ROUTINES } from "@/lib/routines";

// Which models each engine offers. Used to populate the per-routine model
// dropdown and to reset an out-of-range model when the engine is switched.
const MODELS_BY_ENGINE: Record<string, string[]> = {
  claude: ["sonnet", "opus"],
  codex: ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini"],
};

function defaultModelFor(engine: string, fallback: string): string {
  return engine === "codex" ? "gpt-5.5" : fallback;
}

// The canonical routine catalog (name, default schedule, owning module) lives in
// @/lib/routines so the by-repo config endpoint can share it. See that file.

// Derive modules array from the set of enabled module routines
function modulesFromRoutines(routines: RoutineState[]): string[] {
  const mods = new Set<string>();
  for (const r of routines) {
    const def = ALL_ROUTINES.find((d) => d.name === r.name);
    if (def?.module && r.enabled) mods.add(def.module);
  }
  return Array.from(mods);
}

interface RoutineConfig {
  name: string;
  cron: string | null;
  model: string | null;
  engine: string | null;
  enabled: boolean;
  permissionMode: string | null;
}

interface RoutineState {
  name: string;
  cron: string;
  model: string;
  engine: string;
  enabled: boolean;
  permissionMode: string | null;
}

// Build the initial merged routine state:
// - Start from ALL_ROUTINES as the canonical list
// - Override with any existing DB RoutineConfig rows
// - For module routines with no DB row: enabled = module is in the modules[] array
function buildInitialRoutines(configs: RoutineConfig[], modules: string[]): RoutineState[] {
  const configMap = new Map(configs.map((c) => [c.name, c]));
  return ALL_ROUTINES.map((def) => {
    const existing = configMap.get(def.name);
    if (existing) {
      return {
        name: def.name,
        cron: existing.cron ?? def.defaultCron,
        model: existing.model ?? def.defaultModel,
        engine: existing.engine ?? "claude",
        enabled: existing.enabled,
        permissionMode: existing.permissionMode,
      };
    }
    // No DB row yet — derive enabled from the modules array for module routines;
    // core routines default to enabled.
    const enabledDefault = def.module ? modules.includes(def.module) : true;
    return {
      name: def.name,
      cron: def.defaultCron,
      model: def.defaultModel,
      engine: "claude",
      enabled: enabledDefault,
      permissionMode: null,
    };
  });
}

interface RoutineConfigFormProps {
  projectId: string;
  routineConfigs: RoutineConfig[];
  modules: string[];
}

export function RoutineConfigForm({ projectId, routineConfigs, modules }: RoutineConfigFormProps) {
  const router = useRouter();

  const [routines, setRoutines] = useState<RoutineState[]>(
    buildInitialRoutines(routineConfigs, modules)
  );

  const [status, setStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState("");

  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const savedTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const save = async (toSave: RoutineState[]) => {
    setStatus("saving");
    setErrorMsg("");
    try {
      const res = await fetch(`/api/projects/${projectId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          modules: modulesFromRoutines(toSave),
          routines: toSave.map((r) => ({
            name: r.name,
            cron: r.cron || null,
            model: r.model,
            engine: r.engine,
            enabled: r.enabled,
            permissionMode: r.permissionMode,
          })),
        }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error ?? "Save failed");
      }
      setStatus("saved");
      router.refresh();
      if (savedTimer.current) clearTimeout(savedTimer.current);
      savedTimer.current = setTimeout(() => setStatus("idle"), 2000);
    } catch (e) {
      setStatus("error");
      setErrorMsg(e instanceof Error ? e.message : "Save failed");
    }
  };

  // Debounced auto-save: applies the change to state and persists it shortly
  // after, so typing in the cron field doesn't fire a request per keystroke.
  const scheduleSave = (next: RoutineState[]) => {
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => save(next), 600);
  };

  const updateRoutine = (routineName: string, field: keyof RoutineState, value: string | boolean | null) => {
    setRoutines((prev) => {
      const next = prev.map((r) => (r.name === routineName ? { ...r, [field]: value } : r));
      scheduleSave(next);
      return next;
    });
  };

  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-lg font-semibold" style={{ color: "var(--text)" }}>
        Routines
      </h2>
      <RoutineTable rows={routines} onChange={updateRoutine} />

      <div className="flex items-center gap-3 mt-1 h-5 text-sm">
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

function RoutineTable({
  rows,
  onChange,
}: {
  rows: RoutineState[];
  onChange: (name: string, field: keyof RoutineState, value: string | boolean | null) => void;
}) {
  return (
    <div className="rounded-lg overflow-hidden" style={{ border: "1px solid var(--border)" }}>
        <table className="w-full text-sm border-collapse">
          <thead>
            <tr style={{ background: "var(--surface)", borderBottom: "1px solid var(--border)" }}>
              {["Routine", "Enabled", "Engine", "Model", "Cron"].map((col) => (
                <th
                  key={col}
                  className="py-2 px-3 text-xs font-medium uppercase tracking-wider text-left"
                  style={{ color: "var(--muted)" }}
                >
                  {col}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => {
              const def = ALL_ROUTINES.find((d) => d.name === r.name);
              return (
                <tr
                  key={r.name}
                  style={{
                    borderBottom: "1px solid var(--border)",
                    opacity: r.enabled ? 1 : 0.45,
                  }}
                >
                  <td className="py-2 px-3" style={{ color: "var(--text)" }}>
                    <span className="font-mono font-semibold">{r.name}</span>
                    {r.engine === "codex" && def?.claudeOnly && (
                      <span
                        className="ml-1.5 cursor-help"
                        title="This routine's command uses a Claude-only skill — it runs under Codex but with degraded quality."
                      >
                        ⚠️
                      </span>
                    )}
                    {def?.label && (
                      <span className="block text-xs mt-0.5" style={{ color: "var(--muted)" }}>
                        {def.label}
                      </span>
                    )}
                  </td>
                  <td className="py-2 px-3">
                    <input
                      type="checkbox"
                      checked={r.enabled}
                      onChange={(e) => onChange(r.name, "enabled", e.target.checked)}
                      className="cursor-pointer"
                      style={{ accentColor: "var(--accent)" }}
                    />
                  </td>
                  <td className="py-2 px-3">
                    <select
                      value={r.engine}
                      onChange={(e) => {
                        const newEngine = e.target.value;
                        onChange(r.name, "engine", newEngine);
                        // Reset the model if it isn't valid for the new engine.
                        const allowed = MODELS_BY_ENGINE[newEngine] ?? MODELS_BY_ENGINE.claude;
                        if (!allowed.includes(r.model)) {
                          onChange(r.name, "model", defaultModelFor(newEngine, def?.defaultModel ?? "sonnet"));
                        }
                      }}
                      className="text-xs font-mono px-2 py-0.5 rounded cursor-pointer"
                      style={{
                        background: "var(--surface)",
                        border: "1px solid var(--border)",
                        color: "var(--text)",
                        outline: "none",
                      }}
                    >
                      <option value="claude">claude</option>
                      <option value="codex">codex</option>
                    </select>
                  </td>
                  <td className="py-2 px-3">
                    <select
                      value={r.model}
                      onChange={(e) => onChange(r.name, "model", e.target.value)}
                      className="text-xs font-mono px-2 py-0.5 rounded cursor-pointer"
                      style={{
                        background: "var(--surface)",
                        border: "1px solid var(--border)",
                        color: "var(--text)",
                        outline: "none",
                      }}
                    >
                      {(MODELS_BY_ENGINE[r.engine] ?? MODELS_BY_ENGINE.claude).map((m) => (
                        <option key={m} value={m}>{m}</option>
                      ))}
                    </select>
                  </td>
                  <td className="py-2 px-3">
                    <input
                      type="text"
                      value={r.cron}
                      onChange={(e) => onChange(r.name, "cron", e.target.value)}
                      placeholder="0 * * * *"
                      className="text-xs font-mono px-2 py-0.5 rounded"
                      style={{
                        background: "var(--surface)",
                        border: "1px solid var(--border)",
                        color: "var(--text)",
                        outline: "none",
                        width: 130,
                      }}
                    />
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
    </div>
  );
}
