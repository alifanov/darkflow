#!/usr/bin/env bash
# One-time import: pulls this project's open GitHub issues into Dark Flow's own
# task store via the df CLI's API (/api/tasks). Run once, from inside the
# project's git repo, after the project has been migrated off GitHub Issues.
# Safe to re-run — dedupes against already-imported tasks by title.
set -euo pipefail

command -v gh   &>/dev/null || { echo "import-github-issues: gh is required" >&2; exit 1; }
command -v jq   &>/dev/null || { echo "import-github-issues: jq is required" >&2; exit 1; }
command -v curl &>/dev/null || { echo "import-github-issues: curl is required" >&2; exit 1; }

DF_BIN="${HOME}/.darkflow/df"
[[ -x "$DF_BIN" ]] || { echo "import-github-issues: ${DF_BIN} not found — run the Dark Flow installer first" >&2; exit 1; }

GLOBAL_CFG="${HOME}/.darkflow/config"
WEBAPP_URL=$(grep -E '^webapp_url=' "$GLOBAL_CFG" 2>/dev/null | head -1 | cut -d= -f2-)
[[ -n "$WEBAPP_URL" ]] || { echo "import-github-issues: webapp_url not set in ${GLOBAL_CFG}" >&2; exit 1; }

_normalize_repo_url() {
  local u="$1"
  u="${u%.git}"
  if [[ "$u" == git@*:* ]]; then
    local host="${u#git@}"; host="${host%%:*}"
    u="https://${host}/${u#*:}"
  elif [[ "$u" == ssh://* ]]; then
    u="${u#ssh://}"; u="https://${u#git@}"
  fi
  u="${u/https:\/\/*@/https:\/\/}"
  printf '%s' "$u"
}

REPO_URL=$(_normalize_repo_url "$(git remote get-url origin 2>/dev/null || echo "")")
[[ -n "$REPO_URL" ]] || { echo "import-github-issues: no git remote 'origin'" >&2; exit 1; }
REPO_Q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$REPO_URL")

echo "Importing open GitHub issues for ${REPO_URL} into ${WEBAPP_URL} ..."

existing_titles=$(curl -fsS "${WEBAPP_URL}/api/tasks?repoUrl=${REPO_Q}&state=all" | jq -r '.[].title')

issues=$(gh issue list --state open --json number,title,body,labels,url,comments,createdAt --limit 500)
count=$(echo "$issues" | jq 'length')
echo "Found ${count} open GitHub issue(s)."

imported=0
skipped=0
while IFS= read -r issue; do
  title=$(echo "$issue" | jq -r '.title')
  gh_number=$(echo "$issue" | jq -r '.number')

  if grep -qxF "$title" <<< "$existing_titles"; then
    echo "  #${gh_number} \"${title}\" — already imported, skipping"
    ((skipped++)) || true
    continue
  fi

  body=$(echo "$issue" | jq -r '.body // ""')
  created_at=$(echo "$issue" | jq -r '.createdAt')
  comments=$(echo "$issue" | jq -c '[.comments[] | {author: (.author.login // "unknown"), body, createdAt}]')

  labels=$(echo "$issue" | jq -r '.labels[].name')
  status=$(grep -oE '^status:.*' <<< "$labels" | head -1 | cut -d: -f2- || true)
  [[ "$status" == "blocked" ]] && status=""
  # Old GitHub label taxonomy had more values than the current status enum
  # (proposed/approved/in-progress/closed) — fold anything else into closed.
  case "$status" in
    proposed|approved|in-progress|"") ;;
    *) status="closed" ;;
  esac
  priority_raw=$(grep -oE '^priority:.*' <<< "$labels" | head -1 | cut -d: -f2- || true)
  case "$priority_raw" in
    p0) priority="critical" ;; p1) priority="high" ;; p2) priority="medium" ;; p3) priority="low" ;;
    critical|high|medium|low) priority="$priority_raw" ;;
    *) priority="medium" ;;
  esac
  source=$(grep -oE '^source:.*' <<< "$labels" | head -1 | cut -d: -f2- || true)
  action=$(grep -oE '^action:.*' <<< "$labels" | head -1 | cut -d: -f2- || true)
  needs_human="false"
  { grep -qx "needs-human" <<< "$labels" || [[ "$status" == "blocked" ]]; } && needs_human="true"
  [[ -z "$status" ]] && status="proposed"

  payload=$(jq -n \
    --arg repoUrl "$REPO_URL" --arg title "$title" --arg body "$body" \
    --arg status "$status" --arg priority "$priority" --arg source "${source:-manual}" \
    --arg action "$action" --arg createdAt "$created_at" --argjson needsHuman "$needs_human" \
    --argjson comments "$comments" '
    {repoUrl:$repoUrl, title:$title, body:$body, status:$status, priority:$priority,
     source:$source, needsHuman:$needsHuman, createdAt:$createdAt}
    + (if $action != "" then {action:$action} else {} end)
    + (if ($comments | length) > 0 then {comments:$comments} else {} end)')

  resp=$(curl -fsS -X POST "${WEBAPP_URL}/api/tasks" -H "Content-Type: application/json" -d "$payload")
  new_number=$(echo "$resp" | jq -r '.number // empty')
  if [[ -n "$new_number" ]]; then
    echo "  #${gh_number} \"${title}\" → imported as task #${new_number}"
    ((imported++)) || true
  else
    echo "  #${gh_number} \"${title}\" → FAILED: $(echo "$resp" | jq -c .)"
  fi
done < <(echo "$issues" | jq -c '.[]')

echo ""
echo "Done. Imported ${imported}, skipped ${skipped} (already present)."
echo "GitHub issues were NOT modified or closed — close them manually once you've verified the import."
