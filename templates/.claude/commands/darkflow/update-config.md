---
description: Update Dark Flow project settings: language and/or main branch.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

## Usage

```
/darkflow:update-config            ← interactive (ask for new values)
/darkflow:update-config lang=Russian
/darkflow:update-config branch=develop
/darkflow:update-config lang=Russian branch=develop
```

## Step 1 — Read current settings

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` from the project root. Extract `language` and `branch` values. If the file is missing, abort with an error.

## Step 2 — Determine new values

Parse any `lang` and `branch` arguments passed to the command.

For any value **not** provided as an argument, ask the user interactively:
- **Language**: current value shown as default; accept free text (e.g. English, Russian, Spanish)
- **Main branch**: current value shown as default; accept free text (e.g. main, master, develop)

If the user presses Enter without input, keep the current value unchanged.

## Step 3 — Update the settings in the Web UI

`language` and `branch` live in the Web UI database; `.darkflow.d/state/config.json` is only a cache that `get-config.sh` overwrites. Ask the user to change the values in the Web UI, then refresh the cache:

```bash
bash ~/.darkflow/get-config.sh
```

## Step 4 — Update `.darkflow.d/claude.md`

Read `.darkflow.d/claude.md`. Update the main-branch line in-place:

```bash
# macOS
sed -i '' "s/^\*\*Main branch:\*\* .*/\*\*Main branch:\*\* \`<NEW_BRANCH>\`/" .darkflow.d/claude.md

# Linux
sed -i "s/^\*\*Main branch:\*\* .*/\*\*Main branch:\*\* \`<NEW_BRANCH>\`/" .darkflow.d/claude.md
```

Also update any line that reads `→ PR → merge to <old-branch>` or `push directly to \`<old-branch>\`` to use `<NEW_BRANCH>`.

## Step 5 — Commit and push

Stage and commit the changed files:

```bash
git add .darkflow.d/claude.md
git commit -m "chore: update darkflow config (lang=<NEW_LANG>, branch=<NEW_BRANCH>)"
git push
```

Only include values that actually changed in the commit message. Note: `.darkflow.d/state/config.json` is gitignored and must not be staged — only `.darkflow.d/claude.md` is tracked.

## Step 6 — Report

Print a summary of what changed:
```
Updated settings and .darkflow.d/claude.md:
  language: <OLD> → <NEW>
  branch:   <OLD> → <NEW>
```

If nothing changed, print: `No changes — config already up to date.`
