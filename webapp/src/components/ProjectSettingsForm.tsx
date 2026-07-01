"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

// Slider index → priority word. Left = most important (critical), right = least (low).
const PRIORITY_LEVELS = ["critical", "high", "medium", "low"];

const LANGUAGES = [
  "English",
  "Russian",
  "Spanish",
  "German",
  "French",
  "Portuguese",
  "Italian",
  "Dutch",
  "Polish",
  "Ukrainian",
  "Turkish",
  "Chinese",
  "Japanese",
  "Korean",
];

interface ProjectSettingsFormProps {
  projectId: string;
  initialValues: {
    name: string;
    active: boolean;
    slug: string | null;
    domain: string | null;
    localPath: string | null;
    branch: string;
    language: string;
    mergeStrategy: string;
    minPriority: string;
    maxConcurrent: number;
    posthogProjectId: string | null;
    obsTool: string | null;
    obsUrl: string | null;
    settingsUpdatedAt: Date | null;
  };
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

export function ProjectSettingsForm({ projectId, initialValues }: ProjectSettingsFormProps) {
  const router = useRouter();

  const [name, setName] = useState(initialValues.name);
  const [active, setActive] = useState(initialValues.active);
  const [slug, setSlug] = useState(initialValues.slug ?? "");
  const [domain, setDomain] = useState(initialValues.domain ?? "");
  const [localPath, setLocalPath] = useState(initialValues.localPath ?? "");
  const [branch, setBranch] = useState(initialValues.branch);
  const [language, setLanguage] = useState(initialValues.language);
  const [mergeStrategy, setMergeStrategy] = useState(initialValues.mergeStrategy);
  const [minPriority, setMinPriority] = useState(
    PRIORITY_LEVELS.includes(initialValues.minPriority) ? initialValues.minPriority : "medium",
  );
  const [maxConcurrent, setMaxConcurrent] = useState(String(initialValues.maxConcurrent));
  const [posthogProjectId, setPosthogProjectId] = useState(initialValues.posthogProjectId ?? "");
  const [obsTool, setObsTool] = useState(initialValues.obsTool ?? "");
  const [obsUrl, setObsUrl] = useState(initialValues.obsUrl ?? "");

  const [status, setStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState("");

  const save = async () => {
    setStatus("saving");
    setErrorMsg("");
    try {
      const res = await fetch(`/api/projects/${projectId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name,
          active,
          slug: slug || null,
          domain: domain || null,
          localPath: localPath || null,
          branch,
          language,
          mergeStrategy,
          minPriority,
          maxConcurrent: parseInt(maxConcurrent, 10) || 3,
          posthogProjectId: posthogProjectId || null,
          obsTool: obsTool || null,
          obsUrl: obsUrl || null,
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

        <div className="flex flex-col gap-1">
          <label className="flex items-center gap-2 text-sm cursor-pointer" style={{ color: "var(--text)" }}>
            <input
              type="checkbox"
              checked={active}
              onChange={(e) => setActive(e.target.checked)}
              className="cursor-pointer"
              style={{ accentColor: "var(--accent)" }}
            />
            Routines active
          </label>
          <span className="text-xs" style={{ color: "var(--muted)" }}>
            Off pauses every routine for this project, regardless of the per-routine toggles on the Routines tab.
          </span>
        </div>

        <InputField label="Slug" value={slug} onChange={setSlug} placeholder="my-app" hint="Lowercase, dash-separated identifier" />
        <InputField label="Domain" value={domain} onChange={setDomain} placeholder="app.example.com" hint="Production domain where the project is deployed" />
        <InputField label="Local path" value={localPath} onChange={setLocalPath} placeholder="/Users/you/code/my-app" hint="Absolute path to this project's checkout on the host — used by the “Fix in cmux” button" />
        <InputField label="Main branch" value={branch} onChange={setBranch} placeholder="main" />

        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium uppercase tracking-wider" style={{ color: "var(--muted)" }}>
            Communication language
          </label>
          <select
            value={language}
            onChange={(e) => setLanguage(e.target.value)}
            className="text-sm px-3 py-1.5 rounded cursor-pointer"
            style={{
              background: "var(--surface)",
              border: "1px solid var(--border)",
              color: "var(--text)",
              outline: "none",
              width: "100%",
            }}
          >
            {(LANGUAGES.includes(language) ? LANGUAGES : [language, ...LANGUAGES]).map((l) => (
              <option key={l} value={l}>{l}</option>
            ))}
          </select>
          <span className="text-xs" style={{ color: "var(--muted)" }}>
            For issues, comments, commits &amp; chat only — the product itself always stays in English
          </span>
        </div>

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

        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium uppercase tracking-wider" style={{ color: "var(--muted)" }}>
            Minimum issue priority
          </label>
          <input
            type="range"
            min={0}
            max={3}
            step={1}
            value={PRIORITY_LEVELS.indexOf(minPriority)}
            onChange={(e) => setMinPriority(PRIORITY_LEVELS[parseInt(e.target.value, 10)] ?? "medium")}
            className="cursor-pointer"
            style={{ accentColor: "var(--accent)", width: "100%", maxWidth: 320 }}
          />
          <div className="flex justify-between text-[11px] font-medium" style={{ width: "100%", maxWidth: 320 }}>
            {PRIORITY_LEVELS.map((p) => (
              <span
                key={p}
                className="capitalize"
                style={{ color: p === minPriority ? "var(--accent)" : "var(--muted)" }}
              >
                {p}
              </span>
            ))}
          </div>
          <span className="text-xs" style={{ color: "var(--muted)" }}>
            Routines won&apos;t file issues below this level — lower-priority findings go to the run
            snapshot instead. Existing lower-priority issues are highlighted in the Issues list.
          </span>
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
