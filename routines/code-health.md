# Code Health

Weekly codebase-intelligence audit powered by **[fallow](https://github.com/fallow-rs/fallow)** — finds unused code, duplication, circular dependencies, complexity hotspots, and dependency hygiene problems, then creates `status:proposed` GitHub issues for the high-confidence ones.

fallow is a deterministic Rust-native static analyzer for **TypeScript/JavaScript only**. It does the heavy analysis; the routine triages its findings (filtering false positives — public APIs, framework entry points, dynamic refs) and files concrete issues. This is the cheap, deterministic complement to `architecture-review` (which is LLM-driven structural judgment): they are wired not to overlap — fallow owns dead code / dupes / deps / complexity, `architecture-review` owns coupling and design.

This is a **proposal-only** routine — it never applies changes itself (implementation goes through the normal approve → `fix-issues` path).

---

## Prerequisites

Install the fallow agent skill once (the Dark Flow installer does this automatically if you select the Code health module):

```bash
tmp=$(mktemp -d)
git clone https://github.com/fallow-rs/fallow-skills.git "$tmp/fallow-skills"
mkdir -p ~/.claude/skills
cp -R "$tmp/fallow-skills/fallow/skills/fallow" ~/.claude/skills/fallow
```

The skill teaches the agent which fallow commands/flags to run, the JSON output shape, and the gotchas (what looks dead but isn't). The fallow CLI itself runs via `npx fallow` — no separate global install required.

---

## Instructions

```
/darkflow:code-health
```

The command reads `.darkflow` for the output language — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 7 * * 0` (weekly Sun 7:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (recommended — fallow does the analysis deterministically; the model only triages JSON → issues) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `~/.darkflow/darkflow-run.sh code-health` |

---

## Required integrations

- **`gh` CLI** authenticated — for creating GitHub issues
- **fallow agent skill** installed (see Prerequisites above)
- **`npx`** available (Node.js) — to run `npx fallow audit --json`

---

## What gets created

Issues with labels: `status:proposed`, `source:code-health`, `priority:high` / `medium` (low-confidence or minor findings are noted in the snapshot, not filed)

A dated snapshot at `docs/insights/code-health/YYYY-MM-DD.md` and a metrics file at `.darkflow.d/state/metrics/code-health.json`.

---

## Schedule relative to other weekly routines

```
Sun 2:00  Architecture review
Sun 3:00  Security code audit
Sun 4:00  Build optimization
Sun 5:00  Docs audit
Sun 7:00  Code health            ← this routine
```

Runs in the Sunday audit cluster with gaps so routines don't overlap (6:00 is taken by the daily vulnerability-check).

---

## Notes

- **TypeScript/JavaScript only.** On non-TS/JS projects the routine writes a "skipped" snapshot and files nothing — don't enable the module on Python/Go/Rust repos.
- Use **Sonnet** — fallow's output is deterministic, so the model only needs to triage and judge, not analyze the whole codebase. Bump to Opus only if false-positive filtering on a large/dynamic codebase proves unreliable.
- **Judgment matters.** fallow is context-blind: it flags public API surface, framework entry points (`app/**`, `route.ts`), and dynamically-referenced symbols as "dead". The command filters these before filing — never blindly trust `auto_fixable`.
- Findings already tracked in open GitHub issues are skipped to avoid duplicates; deliberately-skipped false positives are recorded in the snapshot so the next audit doesn't re-litigate them.
- The skill is version-matched to fallow, so CLI changes ship with the skill — no need to maintain command syntax in this repo.
