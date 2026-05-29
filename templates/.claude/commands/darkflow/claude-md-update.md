Scan the current codebase state and regenerate CLAUDE.md to keep it accurate.

## Step 1 — Read project config

Read `.darkflow` in the project root. Extract:
- `branch=` → main branch name for push (default: main)

If `.darkflow` is missing or has no `<!-- darkflow:start -->` marker in `CLAUDE.md`, skip the run without committing — leave no comment.

## Step 2 — Check if update is needed

Run:
```bash
git log --oneline $(git log --all --oneline -- CLAUDE.md | head -1 | cut -d' ' -f1)..HEAD -- . 2>/dev/null | head -5
```

If the output is empty (no commits since the last CLAUDE.md update), skip the run without committing — leave no comment.

## Step 3 — Audit the codebase

Read the current CLAUDE.md. Then scan the project to find what has changed or is missing. Focus on:

**Commands** — are all build/dev/test/lint commands correct and present?
- Check `package.json` scripts, `Makefile`, shell scripts in the root
- Flag stale commands that no longer exist

**Architecture** — does the directory structure reflect current reality?
- Check top-level dirs and key subdirs
- Note any new modules or removed ones

**Environment** — are all required env vars documented?
- Grep for `process.env.`, `os.environ`, `.env.example`

**Key files** — are entry points, config files, and important scripts mentioned?

**Gotchas** — scan for non-obvious patterns worth capturing:
- Custom tooling (wrappers, aliases, non-standard bins)
- Deployment quirks
- Database or migration notes
- Framework-specific constraints

## Step 4 — Update CLAUDE.md

Rules:
- Keep everything between `<!-- darkflow:start -->` and `<!-- darkflow:end -->` exactly as-is — do not touch it
- Only update the project-specific sections outside those markers
- Be concise: one line per concept, no verbose explanations, no obvious info
- Keep CLAUDE.md under 300 lines — summarise, don't enumerate
- All documented commands must be copy-paste ready

## Step 5 — Commit and push

Only if something actually changed:
```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md to reflect current codebase state"
git push origin <branch>
```
