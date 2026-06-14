// Canonical Dark Flow routine catalog — the single source of truth for which
// routines exist. Imported by the settings UI (RoutineConfigForm) AND by the
// /api/projects/by-repo endpoint that generates each project's routines.yml.
//
// IMPORTANT: when a routine is removed from Dark Flow, delete it here. The
// by-repo endpoint filters project RoutineConfig rows against KNOWN_ROUTINE_NAMES
// so that orphaned DB rows (left over from a removed routine) are never emitted
// into routines.yml. Without that filter a removed routine keeps shipping a
// `name: enabled: true` block whose command file no longer exists, which bricks
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
  { name: "security-audit",      defaultCron: "0 3 * * 0",   defaultModel: "opus",   module: null,               label: "Full security review (weekly)", claudeOnly: true },
  { name: "vulnerability-check", defaultCron: "0 6 * * *",   defaultModel: "sonnet", module: null,               label: "Dependabot + code scanning (daily)" },
  { name: "build-optimization",  defaultCron: "0 4 * * 0",   defaultModel: "opus",   module: null,               label: "Build + deploy pipeline audit (weekly)" },
  { name: "uptime-check",        defaultCron: "0 */4 * * *", defaultModel: "sonnet", module: null,               label: "DNS + HTTP + page-load check → critical issue if down (every 4h)" },
  // Optional modules
  { name: "analytics-review",         defaultCron: "0 8 * * *",   defaultModel: "sonnet", module: "analytics",        label: "PostHog + commits → issues (daily)" },
  { name: "observability-check",      defaultCron: "30 8 * * *",  defaultModel: "sonnet", module: "observability",    label: "Errors / latency → issues (daily)" },
  { name: "gsc-check",                defaultCron: "0 8 * * 1",   defaultModel: "sonnet", module: "gsc",              label: "Search Console + SEO audit (weekly Mon)" },
  { name: "ads-review",               defaultCron: "0 9 * * 1",   defaultModel: "sonnet", module: "ads",              label: "Paid ads performance (weekly Mon)" },
  { name: "coolify-check-deployment", defaultCron: "0 9 * * *",   defaultModel: "sonnet", module: "coolify",          label: "Deployment status (daily)" },
  { name: "claude-md-update",         defaultCron: "0 9 * * 1-5", defaultModel: "sonnet", module: "claude-update",    label: "Regenerate CLAUDE.md (weekdays)" },
  { name: "architecture-review",      defaultCron: "0 2 * * 0",   defaultModel: "opus",   module: "arch-review",      label: "Architectural analysis (weekly)", claudeOnly: true },
  { name: "code-health",              defaultCron: "0 7 * * 0",   defaultModel: "sonnet", module: "fallow",           label: "Fallow code-health audit (weekly)" },
  { name: "mailbox-check",            defaultCron: "0 10 * * *",  defaultModel: "sonnet", module: "mailbox",          label: "IMAP inbox → issues (daily)" },
  { name: "docs-audit",               defaultCron: "0 5 * * 0",   defaultModel: "opus",   module: "docs-audit",       label: "Docs ↔ code drift (weekly)" },
  { name: "product-overview",         defaultCron: "0 7 * * 1",   defaultModel: "opus",   module: "product-overview", label: "Product state digest (weekly Mon)" },
  { name: "design-audit",             defaultCron: "0 10 * * 6",  defaultModel: "opus",   module: "impeccable",       label: "Design quality audit (weekly Sat)", claudeOnly: true },
  { name: "design-critique",          defaultCron: "0 11 * * 6",  defaultModel: "opus",   module: "impeccable",       label: "Scored design review (weekly Sat)", claudeOnly: true },
  { name: "design-harden",            defaultCron: "0 10 1 * *",  defaultModel: "opus",   module: "impeccable",       label: "Production-readiness check (monthly)", claudeOnly: true },
];

// Set of every routine name Dark Flow still ships. Used to drop orphaned
// RoutineConfig rows for routines that have since been removed.
export const KNOWN_ROUTINE_NAMES = new Set(ALL_ROUTINES.map((r) => r.name));
