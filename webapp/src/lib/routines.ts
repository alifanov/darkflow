// Canonical Dark Flow routine catalog — the single source of truth for which
// routines exist. Imported by the settings UI (RoutineConfigForm) AND by the
// /api/projects/by-repo endpoint that serves each project's effective schedule.
//
// IMPORTANT: when a routine is removed from Dark Flow, delete it here. The
// by-repo endpoint filters project RoutineConfig rows against KNOWN_ROUTINE_NAMES
// so that orphaned DB rows (left over from a removed routine) are never served
// to the worker. Without that filter a removed routine keeps shipping an
// `enabled: true` entry whose command file no longer exists, which bricks
// the worker's preflight check on every existing install.

export interface RoutineDef {
  name: string;
  defaultCron: string;
  defaultModel: string;
  module: string | null; // null = core (fix-issues, security-audit, etc.)
  label: string; // human-readable description
  claudeOnly?: boolean; // command body depends on a Claude-only skill
}

export const ALL_ROUTINES: RoutineDef[] = [
  // Core — always-on, no optional module
  { name: "fix-issues",          defaultCron: "0 * * * *",   defaultModel: "sonnet", module: null,               label: "Pick up approved issues → fix → merge" },
  // Absorbed vulnerability-check (C1): the Dependabot / code-scanning pull is now
  // the first step of the weekly review. Cost: an advisory can sit up to 7 days.
  { name: "security-audit",      defaultCron: "0 3 * * 0",   defaultModel: "opus",   module: null,               label: "Full security review + Dependabot / code scanning (weekly)", claudeOnly: true },
  { name: "build-optimization",  defaultCron: "0 4 * * 0",   defaultModel: "opus",   module: null,               label: "Build + deploy pipeline audit (weekly)" },
  { name: "uptime-check",        defaultCron: "0 */4 * * *", defaultModel: "sonnet", module: null,               label: "DNS + HTTP + page-load check → critical issue if down (every 4h)" },
  { name: "web-vitals",          defaultCron: "0 6 * * 1",   defaultModel: "sonnet", module: null,               label: "Core Web Vitals via local Lighthouse → issue if a metric is poor (weekly Mon)" },
  // Core, and deliberately NOT behind the ci-gate module: ci-watch is pure bash
  // with no agent and no external setup beyond `gh`, so there is nothing to opt
  // into. The module used to gate the self-hosted CI runner, which is gone.
  { name: "ci-watch",            defaultCron: "*/30 * * * *", defaultModel: "sonnet", module: null,              label: "Red / stuck CI + local lint & test → source:ci task (every 30 min, no agent)" },
  // Same shape as ci-watch: pure bookkeeping, so it runs in the worker in bash
  // rather than as two agent routines (H). Stuck tasks, stuck HEAD, worktrees.
  { name: "housekeeping",        defaultCron: "0 5 * * *",    defaultModel: "sonnet", module: null,              label: "Stuck tasks + stuck HEAD + worktree/branch cleanup (daily, no agent)" },
  // Optional modules
  { name: "fix-ci-issue",             defaultCron: "*/15 * * * *", defaultModel: "sonnet", module: "ci-gate",         label: "Pick up source:ci failures → fix → retry up to 3× (every 15 min)" },
  { name: "analytics-review",         defaultCron: "0 8 * * *",   defaultModel: "sonnet", module: "analytics",        label: "OpenPanel + commits → issues (daily)" },
  { name: "observability-check",      defaultCron: "30 8 * * *",  defaultModel: "sonnet", module: "observability",    label: "Errors / latency → issues (daily)" },
  // Renamed from `gsc-check` in 4.35.0 — the routine always was a full SEO audit
  // with GSC as its data half; the old name hid that. Module key stays `gsc`: it is
  // internal, and renaming it would invalidate every stored module list.
  { name: "seo-check",                defaultCron: "0 8 * * 1",   defaultModel: "sonnet", module: "gsc",              label: "SEO audit + Search Console (weekly Mon)" },
  { name: "ads-review",               defaultCron: "0 9 * * 1",   defaultModel: "sonnet", module: "ads",              label: "Paid ads performance (weekly Mon)" },
  { name: "coolify-check-deployment", defaultCron: "0 9 * * *",   defaultModel: "sonnet", module: "coolify",          label: "Deployment status (daily)" },
  // Absorbed code-health (C2): the fallow step is optional inside the review — it
  // only covers TS/JS, the rest of the analysis does not.
  { name: "architecture-review",      defaultCron: "0 2 * * 0",   defaultModel: "opus",   module: "arch-review",      label: "Architecture + code-health audit (weekly)", claudeOnly: true },
  { name: "mailbox-check",            defaultCron: "0 10 * * *",  defaultModel: "sonnet", module: "mailbox",          label: "IMAP inbox → issues (daily)" },
  { name: "docs-audit",               defaultCron: "0 5 * * 0",   defaultModel: "opus",   module: "docs-audit",       label: "Docs ↔ code drift (weekly)" },
  // Three design commands merged into two (C4): visual quality vs. real flows.
  { name: "check-design",             defaultCron: "0 10 * * 6",  defaultModel: "opus",   module: "impeccable",       label: "Visual design quality audit (weekly Sat)", claudeOnly: true },
  { name: "check-ux",                 defaultCron: "0 11 * * 6",  defaultModel: "opus",   module: "impeccable",       label: "Walk key flows in a real browser, mobile + desktop (weekly Sat)", claudeOnly: true },
];

// Deliberately NOT here: `checklist-review`. It is a manual command, run by hand
// from a project (`/darkflow:checklist-review [group]`), never on a schedule.
// The catalog is only for scheduled routines — a name listed here gets a cron, a
// model and a worker dispatch. Adding it would put a weekly agent run on every
// project that enables the module, which is not what it is for.

// Set of every routine name Dark Flow still ships. RoutineConfig rows whose name
// is absent from it are orphans — a schedule that outlived its command (A9) — and
// get deleted on the next /api/ingest sync.
export const KNOWN_ROUTINE_NAMES = new Set(ALL_ROUTINES.map((r) => r.name));
