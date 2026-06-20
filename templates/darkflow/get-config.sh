#!/usr/bin/env bash
# get-config.sh — fetch the current project's settings from the Dark Flow Web UI
# (the DB is the source of truth) into <project>/.darkflow.d/state/config.json.
#
# Installed globally at ~/.darkflow/get-config.sh. The interactive slash commands
# call it in their "Step 1 — Read project config"; the global worker fetches the
# same JSON itself. Safe to run anywhere: silently no-ops (keeping any cached JSON)
# if the server is offline or the project isn't registered.
#
# Identity is via repoUrl (the DB unique key); webapp_url comes from ~/.darkflow/config.

set -euo pipefail

GLOBAL_CFG="${HOME}/.darkflow/config"

command -v curl &>/dev/null || exit 0
command -v jq   &>/dev/null || exit 0
command -v gh   &>/dev/null || exit 0

# Project root = the git toplevel of the current directory.
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$PROJECT_ROOT" ]] || exit 0

webapp_url=$(grep -E '^webapp_url=' "$GLOBAL_CFG" 2>/dev/null | head -1 | cut -d= -f2-)
[[ -n "$webapp_url" ]] || exit 0

repo_url=$(gh repo view --json url -q .url 2>/dev/null || true)
[[ -n "$repo_url" ]] || exit 0

encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$repo_url" 2>/dev/null \
  || printf '%s' "$repo_url" | sed 's|:|%3A|g; s|/|%2F|g')

resp=$(curl -fsS --max-time 5 "${webapp_url}/api/projects/by-repo?repoUrl=${encoded}" 2>/dev/null) || exit 0
[[ "${resp:0:1}" == "{" ]] || exit 0
jq -e '.id' >/dev/null 2>&1 <<< "$resp" || exit 0   # 404 → no .id; keep the cache

mkdir -p "${PROJECT_ROOT}/.darkflow.d/state" 2>/dev/null || true
printf '%s' "$resp" > "${PROJECT_ROOT}/.darkflow.d/state/config.json"
