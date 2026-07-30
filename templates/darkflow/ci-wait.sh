#!/usr/bin/env bash
# ci-wait.sh — wait for the GitHub Actions run(s) of the current HEAD commit and
# report the verdict synchronously, so a session that pushed knows whether CI is
# green before it finishes.
#
# Exit codes:
#   0  green (or nothing to check — no gh, no repo, no workflow on this push)
#   1  red — at least one run for HEAD failed
#   2  no run appeared within the timeout (treat as "no CI here", not as failure)
#
# Env: CI_WAIT_TIMEOUT (seconds to wait for a run to register, default 600)
set -uo pipefail

timeout=${CI_WAIT_TIMEOUT:-600}

command -v gh >/dev/null 2>&1 || { echo "ci-wait: gh CLI not found — skipping CI check"; exit 2; }
sha=$(git rev-parse HEAD 2>/dev/null) || { echo "ci-wait: not a git repo — skipping CI check"; exit 2; }

# Only runs this push actually caused count as the verdict. Dependabot
# (`event: dynamic`), schedules and other bot workflows share the branch head SHA
# and would otherwise report a red that has nothing to do with the commit.
runs_for_head() {
  gh run list --limit 30 --json databaseId,headSha,event,conclusion -q "
    [ .[]
      | select(.headSha == \"$sha\")
      | select(.event as \$e | [\"push\",\"pull_request\",\"workflow_dispatch\",\"merge_group\"] | index(\$e))
      | select(.conclusion != \"skipped\" and .conclusion != \"cancelled\")
    ] | .[].databaseId" 2>/dev/null
}

# A run is registered a few seconds after the push — poll until one shows up.
deadline=$(( SECONDS + timeout ))
ids=""
while :; do
  ids=$(runs_for_head)
  [[ -n "$ids" ]] && break
  if (( SECONDS >= deadline )); then
    echo "ci-wait: no workflow run for ${sha:0:7} after ${timeout}s — nothing to verify"
    exit 2
  fi
  sleep 5
done

# ponytail: a second workflow on the same push registers a beat later than the
# first — re-list once so a sibling job can't sneak past as a false green.
sleep 5
ids=$(runs_for_head)

failed=0
for id in $ids; do
  url=$(gh run view "$id" --json url -q .url 2>/dev/null)
  echo "ci-wait: watching run $id ($url)"
  if gh run watch "$id" --exit-status --interval 10 >/dev/null 2>&1; then
    echo "ci-wait: GREEN — $url"
  else
    failed=1
    echo "ci-wait: RED — $url"
    gh run view "$id" --log-failed 2>/dev/null | tail -n 40
  fi
done

exit "$failed"
