"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

const ALL_MODULES = [
  { id: "analytics", label: "Analytics" },
  { id: "observability", label: "Observability" },
  { id: "gsc", label: "Google Search Console" },
  { id: "ads", label: "Paid Ads" },
  { id: "coolify", label: "Coolify" },
  { id: "claude-update", label: "Claude MD auto-update" },
  { id: "arch-review", label: "Architecture Review" },
  { id: "mailbox", label: "Mailbox" },
  { id: "docs-audit", label: "Docs Audit" },
  { id: "product-overview", label: "Product Overview" },
  { id: "impeccable", label: "Impeccable (design audits)" },
];

interface RoutineConfig {
  name: string;
  cron: string | null;
  model: string | null;
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

export function ProjectSettingsForm({ projectId, initialValues, routineConfigs }: ProjectSettingsFormProps) {
  const router = useRouter();

  // Scalar settings
  const [name, setName] = useState(initialValues.name);
  const [slug, setSlug] = useState(initialValues.slug ?? "");
  const [branch, setBranch] = useState(initialValues.branch);
  const [language, setLanguage] = useState(initialValues.language);
  const [mergeStrategy, setMergeStrategy] = useState(initialValues.mergeStrategy);
  const [modules, setModules] = useState<string[]>(initialValues.modules);
  const [maxConcurrent, setMaxConcurrent] = useState(String(initialValues.maxConcurrent));
  const [posthogProjectId, setPosthogProjectId] = useState(initialValues.posthogProjectId ?? "");
  const [obsTool, setObsTool] = useState(initialValues.obsTool ?? "");
  const [obsUrl, setObsUrl] = useState(initialValues.obsUrl ?? "");

  // Routine configs
  const [routines, setRoutines] = useState<RoutineConfig[]>(
    routineConfigs.map((r) => ({ ...r }))
  );

  const [status, setStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState("");

  const toggleModule = (id: string) => {
    setModules((prev) =>
      prev.includes(id) ? prev.filter((m) => m !== id) : [...prev, id]
    );
  };

  const updateRoutine = (name: string, field: keyof RoutineConfig, value: string | boolean | null) => {
    setRoutines((prev) =>
      prev.map((r) => (r.name === name ? { ...r, [field]: value } : r))
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
          modules,
          maxConcurrent: parseInt(maxConcurrent, 10) || 3,
          posthogProjectId: posthogProjectId || null,
          obsTool: obsTool || null,
          obsUrl: obsUrl || null,
          routines,
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
        <InputField label="Observability tool" value={obsTool} onChange={setObsTool} placeholder="SigNoz / Datadog / Grafana" />
        <InputField label="Observability URL" value={obsUrl} onChange={setObsUrl} placeholder="https://..." />
      </section>

      {/* Modules */}
      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold uppercase tracking-wider" style={{ color: "var(--muted)" }}>
          Modules
        </h3>
        <div className="flex flex-col gap-2">
          {ALL_MODULES.map((mod) => {
            const active = modules.includes(mod.id);
            return (
              <label key={mod.id} className="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={active}
                  onChange={() => toggleModule(mod.id)}
                  className="cursor-pointer"
                  style={{ accentColor: "var(--accent)" }}
                />
                <span
                  className="text-sm font-mono"
                  style={{ color: active ? "var(--text)" : "var(--muted)" }}
                >
                  {mod.id}
                </span>
                <span className="text-xs" style={{ color: "var(--muted)" }}>
                  {mod.label}
                </span>
              </label>
            );
          })}
        </div>
      </section>

      {/* Routines */}
      {routines.length > 0 && (
        <section className="flex flex-col gap-3">
          <h3 className="text-sm font-semibold uppercase tracking-wider" style={{ color: "var(--muted)" }}>
            Routine schedule
          </h3>
          <div
            className="rounded-lg overflow-hidden"
            style={{ border: "1px solid var(--border)" }}
          >
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
                {routines.map((r) => (
                  <tr key={r.name} style={{ borderBottom: "1px solid var(--border)" }}>
                    <td className="py-2 px-3 font-mono font-semibold" style={{ color: "var(--text)" }}>
                      {r.name}
                    </td>
                    <td className="py-2 px-3">
                      <input
                        type="checkbox"
                        checked={r.enabled}
                        onChange={(e) => updateRoutine(r.name, "enabled", e.target.checked)}
                        className="cursor-pointer"
                        style={{ accentColor: "var(--accent)" }}
                      />
                    </td>
                    <td className="py-2 px-3">
                      <select
                        value={r.model ?? "sonnet"}
                        onChange={(e) => updateRoutine(r.name, "model", e.target.value)}
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
                        value={r.cron ?? ""}
                        onChange={(e) => updateRoutine(r.name, "cron", e.target.value || null)}
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
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

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
