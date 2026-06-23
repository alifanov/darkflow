Update Dark Flow to the latest version.

## Step 1 — Run the installer

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh) --force --yes
```

The installer is fully non-interactive: `--yes` skips all prompts, `--force` overwrites locally-modified templates. It refreshes the global worker (`~/.darkflow/darkflow-run.sh`), the user-scope slash commands (`~/.claude/commands/darkflow/`), this project's `.darkflow.d/` files, and the version in `.darkflow.d/state/config.json`.

> Updates are manual by design — the global worker never fetches or runs an installer on its own. To update just the worker + commands without touching a project, run `bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh) --self-update --yes`.

## Step 1b — Ask the user to restart the global worker

A running worker holds the **old** script in memory, so the update has no effect until the worker is restarted. **Do NOT restart it yourself.** The worker's `claude`/`codex` engine authenticates from the user's interactive shell (keychain / env credentials a Claude Code session does not have); a worker you launch inherits your credential-less environment and every routine fails with `Not logged in · Please run /login`.

Check whether a worker is running and tell the user what to do:

```bash
pgrep -f /.darkflow/darkflow-run.sh >/dev/null && echo "worker running — needs restart" || echo "worker not running"
```

If it is running, print this and ask the user to run it **in their own terminal** (where `claude -p "ok"` works) — do not run it for them, not in the background, not even if asked to "just restart it":

```bash
pkill -f /.darkflow/darkflow-run.sh
sleep 1
nohup /usr/local/bin/bash ~/.darkflow/darkflow-run.sh >/dev/null 2>> ~/.darkflow/worker.err.log &
```

If no worker was running, just note that the user should start it themselves when ready. (You may stop/kill the worker on request — that needs no credentials — but never start or restart it.)

## Step 2 — Ensure `.darkflow.d/state/config.json` is in `.gitignore`

Check if `.darkflow.d/state/config.json` is already ignored. If not, add it:

```bash
grep -qxF '.darkflow' .gitignore 2>/dev/null || echo '.darkflow' >> .gitignore
```

## Step 3 — Detect PostHog project ID (if missing)

<!-- Note: the detection logic below (name-match → write ID) is mirrored in analytics-review.md Step 1. Keep both in sync when modifying. -->

Read `.darkflow.d/state/config.json`. Extract `language` (default: English) for all user-facing output. If `posthogProjectId` is missing or empty, and the PostHog MCP is available:

1. List all available PostHog projects.
2. Find the one whose name best matches `name` from `.darkflow.d/state/config.json` (case-insensitive, partial match).
3. Write the ID to `.darkflow.d/state/config.json`:

```bash
# macOS
grep -q "^posthog_project_id=" .darkflow \
  && sed -i '' "s/^posthog_project_id=.*/posthog_project_id=<ID>/" .darkflow \
  || echo "posthog_project_id=<ID>" >> .darkflow
# Linux
grep -q "^posthog_project_id=" .darkflow \
  && sed -i "s/^posthog_project_id=.*/posthog_project_id=<ID>/" .darkflow \
  || echo "posthog_project_id=<ID>" >> .darkflow
```

If PostHog MCP is not available or no match found — skip silently.

## Step 4 — Verify

After the installer exits, confirm the update succeeded:

```bash
grep '^version=' .darkflow
```

Compare the installed version against the latest release:

```bash
curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/VERSION
```

## Step 5 — Commit and push the update

After a successful update, commit and push any changes left by the installer:

```bash
git add -A
git diff --cached --quiet || git commit -m "chore: update Dark Flow to vX.Y.Z"
git push
```

Replace `vX.Y.Z` with the actual installed version. If there were no changes (already up to date), skip the commit step.

## Step 6 — Report

Print a single summary line in `language`:
- On success: `Dark Flow updated to vX.Y.Z`
- If already up to date: `Dark Flow already up to date (vX.Y.Z)`
- On failure: print the error output and exit non-zero
