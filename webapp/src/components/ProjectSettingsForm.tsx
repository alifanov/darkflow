"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

// Every routine with its default schedule and the module it belongs to (null = core, always-on)
const ALL_ROUTINES: {
  name: string;
  defaultCron: string;
  defaultModel: string;
  module: string | null;  // null = core (fix-issues, security-audit, etc.)
  label: string;          // human-readable description
}[] = [
  // Core — always-on, no optional module
  { name: "fix-issues",          defaultCron: "0 * * * *",   defaultModel: "sonnet", module: null,               label: "Pick up approved issues → fix → merge" },
  { name: "security-audit",      defaultCron: "0 3 * * 0",   defaultModel: "opus",   module: null,               label: "Full security review (weekly)" },
  { name: "vulnerability-check", defaultCron: "0 6 * * *",   defaultModel: "sonnet", module: null,               label: "Dependabot + code scanning (daily)" },
  { name: "build-optimization",  defaultCron: "0 4 * * 0",   defaultModel: "opus",   module: null,               label: "Build + deploy pipeline audit (weekly)" },
  // Optional modules
  { name: "analytics-review",         defaultCron: "0 8 * * *",   defaultModel: "sonnet", module: "analytics",        label: "PostHog + commits → issues (daily)" },
  { name: "observability-check",      defaultCron: "30 8 * * *",  defaultModel: "sonnet", module: "observability",    label: "Errors / latency → issues (daily)" },
  { name: "gsc-check",                defaultCron: "0 8 * * 1",   defaultModel: "sonnet", module: "gsc",              label: "Google Search Console (weekly Mon)" },
  { name: "ads-review",               defaultCron: "0 9 * * 1",   defaultModel: "sonnet", module: "ads",              label: "Paid ads performance (weekly Mon)" },
  { name: "coolify-check-deployment", defaultCron: "0 9 * * *",   defaultModel: "sonnet", module: "coolify",          label: "Deployment status (daily)" },
  { name: "coolify-check-logs",       defaultCron: "30 9 * * *",  defaultModel: "sonnet", module: "coolify",          label: "Runtime logs (daily)" },
  { name: "claude-md-update",         defaultCron: "0 9 * * 1-5", defaultModel: "sonnet", module: "claude-update",    label: "Regenerate CLAUDE.md (weekdays)" },
  { name: "architecture-review",      defaultCron: "0 2 * * 0",   defaultModel: "opus",   module: "arch-review",      label: "Architectural analysis (weekly)" },
  { name: "mailbox-check",            defaultCron: "0 10 * * *",  defaultModel: "sonnet", module: "mailbox",          label: "IMAP inbox → issues (daily)" },
  { name: "docs-audit",               defaultCron: "0 5 * * 0",   defaultModel: "opus",   module: "docs-audit",       label: "Docs ↔ code drift (weekly)" },
  { name: "product-overview",         defaultCron: "0 7 * * 1",   defaultModel: "opus",   module: "product-overview", label: "Product state digest (weekly Mon)" },
  { name: "design-audit",             defaultCron: "0 10 * * 6",  defaultModel: "opus",   module: "impeccable",       label: "Design quality audit (weekly Sat)" },
  { name: "design-critique",          defaultCron: "0 11 * * 6",  defaultModel: "opus",   module: "impeccable",       label: "Scored design review (weekly Sat)" },
  { name: "design-harden",            defaultCron: "0 10 1 * *",  defaultModel: "opus",   module: "impeccable",       label: "Production-readiness check (monthly)" },
];

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
  enabled: boolean;
  permissionMode: string | null;
}

interface RoutineState {
  name: string;
  cron: string;
  model: string;
  enabled: boolean;
  permissionMode: string | null;
}

interface ProjectSettingsFormProps {
  projectId: string;
  initialValues: {
    name: string;
    slug: string | null;
    branch: string;
    language: string;
    mergeStrategy: string;
    modules: string[];
    maxConcurrent: number;
    posthogProjectId: string | null;
    obsTool: string | null;
    obsUrl: string | null;
    settingsUpdatedAt: Date | null;
  };
  routineConfigs: RoutineConfig[];
}

function InputField({
  label,
  value,
  onChange,
  placeholder,
  hint,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  hint?: string;
}) {
  return (
    <div className="flex flex-col gap-1">
      <label className="text-xs font-medium uppercase tracking-wider" style={{ color: "var(--muted)" }}>
        {label}
      </label>
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="text-sm px-3 py-1.5 rounded font-mono"
        style={{
          background: "var(--surface)",
          border: "1px solid var(--border)",
          color: "var(--text)",
          outline: "none",
          width: "100%",
        }}
      />
      {hint && (
        <span className="text-xs" style={{ color: "var(--muted)" }}>{hint}</span>
      )}
    </div>
  );
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
      enabled: enabledDefault,
      permissionMode: null,
    };
  });
}

export function ProjectSettingsForm({ projectId, initialValues, routineConfigs }: ProjectSettingsFormProps) {
  const router = useRouter();

  const [name, setName] = useState(initialValues.name);
  const [slug, setSlug] = useState(initialValues.slug ?? "");
  const [branch, setBranch] = useState(initialValues.branch);
  const [language, setLanguage] = useState(initialValues.language);
  const [mergeStrategy, setMergeStrategy] = useState(initialValues.mergeStrategy);
  const [maxConcurrent, setMaxConcurrent] = useState(String(initialValues.maxConcurrent));
  const [posthogProjectId, setPosthogProjectId] = useState(initialValues.posthogProjectId ?? "");
  const [obsTool, setObsTool] = useState(initialValues.obsTool ?? "");
  const [obsUrl, setObsUrl] = useState(initialValues.obsUrl ?? "");

  const [routines, setRoutines] = useState<RoutineState[]>(
    buildInitialRoutines(routineConfigs, initialValues.modules)
  );

  const [status, setStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState("");

  const updateRoutine = (routineName: string, field: keyof RoutineState, value: string | boolean | null) => {
    setRoutines((prev) =>
      prev.map((r) => (r.name === routineName ? { ...r, [field]: value } : r))
    );
  };

  const save = async () => {
    setStatus("saving");
    setErrorMsg("");
    try {
      const res = await fetch(`/api/projects/${projectId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name,
          slug: slug || null,
          branch,
          language,
          mergeStrategy,
          modules: modulesFromRoutines(routines),
          maxConcurrent: parseInt(maxConcurrent, 10) || 3,
          posthogProjectId: posthogProjectId || null,
          obsTool: obsTool || null,
          obsUrl: obsUrl || null,
          routines: routines.map((r) => ({
            name: r.name,
            cron: r.cron || null,
            model: r.model,
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
      setTimeout(() => setStatus("idle"), 3000);
    } catch (e) {
      setStatus("error");
      setErrorMsg(e instanceof Error ? e.message : "Save failed");
    }
  };

  return (
    <div className="flex flex-col gap-8 max-w-2xl">
      {/* Project basics */}
      <section className="flex flex-col gap-4">
        <h3 className="text-sm font-semibold uppercase tracking-wider" style={{ color: "var(--muted)" }}>
          Project
        </h3>
        <InputField label="Name" value={name} onChange={setName} placeholder="My App" />
        <InputField label="Slug" value={slug} onChange={setSlug} placeholder="my-app" hint="Lowercase, dash-separated identifier" />
        <InputField label="Main branch" value={branch} onChange={setBranch} placeholder="main" />
        <InputField label="Language" value={language} onChange={setLanguage} placeholder="English" hint="Used for issue text and agent output" />

        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium uppercase tracking-wider" style={{ color: "var(--muted)" }}>
            Merge strategy
          </label>
          <select
            value={mergeStrategy}
            onChange={(e) => setMergeStrategy(e.target.value)}
            className="text-sm px-3 py-1.5 rounded cursor-pointer"
            style={{
              background: "var(--surface)",
              border: "1px solid var(--border)",
              color: "var(--text)",
              outline: "none",
              width: "100%",
            }}
          >
            <option value="pr">Pull request (PR)</option>
            <option value="direct">Direct push to branch</option>
          </select>
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium uppercase tracking-wider" style={{ color: "var(--muted)" }}>
            Max concurrent routines
          </label>
          <input
            type="number"
            min={1}
            max={10}
            value={maxConcurrent}
            onChange={(e) => setMaxConcurrent(e.target.value)}
            className="text-sm px-3 py-1.5 rounded font-mono"
            style={{
              background: "var(--surface)",
              border: "1px solid var(--border)",
              color: "var(--text)",
              outline: "none",
              width: 80,
            }}
          />
        </div>
      </section>

      {/* Integrations */}
      <section className="flex flex-col gap-4">
        <h3 className="text-sm font-semibold uppercase tracking-wider" style={{ color: "var(--muted)" }}>
          Integrations
        </h3>
        <InputField label="PostHog project ID" value={posthogProjectId} onChange={setPosthogProjectId} placeholder="phc_..." />

        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium uppercase tracking-wider" style={{ color: "var(--muted)" }}>
            Observability tool
          </label>
          <select
            value={obsTool}
            onChange={(e) => setObsTool(e.target.value)}
            className="text-sm px-3 py-1.5 rounded cursor-pointer"
            style={{
              background: "var(--surface)",
              border: "1px solid var(--border)",
              color: obsTool ? "var(--text)" : "var(--muted)",
              outline: "none",
              width: "100%",
            }}
          >
            <option value="">— none —</option>
            <option value="SigNoz">SigNoz</option>
            <option value="Datadog">Datadog</option>
            <option value="Grafana">Grafana</option>
          </select>
        </div>

        <InputField label="Observability URL" value={obsUrl} onChange={setObsUrl} placeholder="https://..." />
      </section>

      {/* Routines — single unified section replaces both "Modules" and "Routine schedule" */}
      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold uppercase tracking-wider" style={{ color: "var(--muted)" }}>
          Routines
        </h3>
        <RoutineTable rows={routines} onChange={updateRoutine} />
      </section>

      {/* Save */}
      <div className="flex items-center gap-3">
        <button
          onClick={save}
          disabled={status === "saving"}
          className="text-sm px-4 py-2 rounded cursor-pointer font-medium"
          style={{
            background: "var(--accent)",
            color: "#fff",
            border: "none",
            opacity: status === "saving" ? 0.6 : 1,
          }}
        >
          {status === "saving" ? "Saving…" : "Save settings"}
        </button>
        {status === "saved" && (
          <span className="text-sm" style={{ color: "var(--green)" }}>Saved ✓</span>
        )}
        {status === "error" && (
          <span className="text-sm" style={{ color: "var(--red)" }}>{errorMsg || "Failed to save"}</span>
        )}
        {initialValues.settingsUpdatedAt && status === "idle" && (
          <span className="text-xs" style={{ color: "var(--muted)" }}>
            Last saved {new Date(initialValues.settingsUpdatedAt).toLocaleString()}
          </span>
        )}
      </div>
    </div>
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
              {["Routine", "Enabled", "Model", "Cron"].map((col) => (
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
                      <option value="sonnet">sonnet</option>
                      <option value="opus">opus</option>
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
