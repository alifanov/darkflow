#!/usr/bin/env bash
# Dark Flow routine dispatcher
# Lives at .darkflow.d/darkflow-run.sh — run from anywhere in the project.
#
# Usage:
#   bash .darkflow.d/darkflow-run.sh              # loop every 60s — checks for due routines (default)
#   bash .darkflow.d/darkflow-run.sh --once       # single dispatch and exit (for system scheduler)
#   bash .darkflow.d/darkflow-run.sh <name>       # manual: run one routine immediately
#   bash .darkflow.d/darkflow-run.sh --sync       # push issues + metadata to the web UI
#   bash .darkflow.d/darkflow-run.sh --list       # show routine status table
#   bash .darkflow.d/darkflow-run.sh --dry-run    # show what would run, don't run it
#   bash .darkflow.d/darkflow-run.sh --self-test  # run internal cron-matcher tests

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DARKFLOW_D="${PROJECT_ROOT}/.darkflow.d"
YAML="${DARKFLOW_D}/routines.yml"
STATE_DIR="${DARKFLOW_D}/state"
LOCK_DIR="${STATE_DIR}/.lock"
LOG="${DARKFLOW_D}/darkflow-run.log"
METRICS_DIR="${DARKFLOW_D}/state/metrics"
DARKFLOW_CFG="${PROJECT_ROOT}/.darkflow"

# Accumulated routine log entries for this dispatch cycle (JSON lines)
PENDING_LOGS=()

cd "$PROJECT_ROOT"

# ── OS detection ──────────────────────────────────────────────────────────────

OS="$(uname)"

# Decode epoch → "minute hour day month weekday" (weekday: 0=Sun)
epoch_decode() {
  if [[ "$OS" == "Darwin" ]]; then
    date -r "$1" "+%M %H %d %m %w"
  else
    date -d "@$1" "+%M %H %d %m %w"
  fi
}

# Format epoch for display
epoch_fmt() {
  local fmt="${2:-%Y-%m-%d %H:%M}"
  if [[ "$OS" == "Darwin" ]]; then
    date -r "$1" "+$fmt" 2>/dev/null || echo "$1"
  else
    date -d "@$1" "+$fmt" 2>/dev/null || echo "$1"
  fi
}

now_epoch() { date +%s; }

# ── Logging ───────────────────────────────────────────────────────────────────

log() {
  local line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$line" >> "$LOG" 2>/dev/null || true
  echo "$line"
}

rotate_log() {
  if [[ -f "$LOG" ]] && [[ "$(wc -c < "$LOG")" -gt 1048576 ]]; then
    tail -c 524288 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
  fi
}

# ── .darkflow config reader ───────────────────────────────────────────────────

darkflow_val() {
  local key="$1" default="${2:-}" val
  if [[ -f "$DARKFLOW_CFG" ]]; then
    val=$(grep -E "^${key}=" "$DARKFLOW_CFG" 2>/dev/null | head -1 | cut -d= -f2-)
    if [[ -n "$val" ]]; then echo "$val"; return; fi
  fi
  echo "$default"
}

# ── Cron field matching ────────────────────────────────────────────────────────
# Returns 0 if integer value matches cron field expression.
# Supports: *, n, a-b, a-b/n, */n, a,b,c and combinations.

cron_field_match() {
  local val_raw="$1" field="$2"
  local val
  val=$(( 10#$val_raw ))  # strip leading zeros

  local part lo hi step
  local IFS=','
  read -ra parts <<< "$field"
  for part in "${parts[@]}"; do
    step=1
    if [[ "$part" == *"/"* ]]; then
      step="${part##*/}"
      part="${part%%/*}"
    fi
    if [[ "$part" == "*" ]]; then
      lo=0; hi=99
    elif [[ "$part" == *"-"* ]]; then
      lo="${part%%-*}"; hi="${part##*-}"
    else
      lo="$part"; hi="$part"
    fi
    lo=$(( 10#$lo )); hi=$(( 10#$hi )); step=$(( 10#$step ))
    if (( val >= lo && val <= hi && (val - lo) % step == 0 )); then
      return 0
    fi
  done
  return 1
}

# Returns 0 if the cron expression matches at the given epoch.
# dom/dow: if both are restricted, either matching is sufficient (standard OR rule).
cron_due_at() {
  local ep="$1" c_min="$2" c_hr="$3" c_dom="$4" c_month="$5" c_dow="$6"
  local dm hm dd mo wd

  read -r dm hm dd mo wd <<< "$(epoch_decode "$ep")"
  [[ "$wd" == "7" ]] && wd="0"  # normalize Sunday

  cron_field_match "$dm" "$c_min"   || return 1
  cron_field_match "$hm" "$c_hr"    || return 1
  cron_field_match "$mo" "$c_month" || return 1

  local dom_star=false dow_star=false
  [[ "$c_dom" == "*" ]] && dom_star=true
  [[ "$c_dow" == "*" ]] && dow_star=true

  if $dom_star && $dow_star; then
    return 0
  elif $dom_star; then
    cron_field_match "$wd" "$c_dow" || return 1
  elif $dow_star; then
    cron_field_match "$dd" "$c_dom" || return 1
  else
    # Both restricted: OR semantics
    cron_field_match "$dd" "$c_dom" || cron_field_match "$wd" "$c_dow" || return 1
  fi
  return 0
}

# Finds the most recent epoch >= floor_epoch that matches the cron expression.
# Prints the epoch on stdout; prints 0 if none found.
#
# Optimisation: if minute and hour are plain integers, align to the most recent
# (min, hour) pair in LOCAL time, then step by 86400s (daily). This reduces date
# calls from thousands to single digits for typical weekly/daily crons.
prev_fire() {
  local c_min="$1" c_hr="$2" c_dom="$3" c_month="$4" c_dow="$5" floor_ep="$6"
  local now ep step m h cur_m cur_h diff _f1 _f2 _rest

  now=$(now_epoch)
  ep=$(( now - now % 60 ))  # start of current minute

  if [[ "$c_min" =~ ^[0-9]+$ ]] && [[ "$c_hr" =~ ^[0-9]+$ ]]; then
    # Both minute and hour are fixed: align using LOCAL time from epoch_decode.
    m=$(( 10#$c_min )); h=$(( 10#$c_hr ))
    # Decode current local minute
    read -r cur_m _rest <<< "$(epoch_decode "$ep")"
    cur_m=$(( 10#$cur_m ))
    diff=$(( (cur_m - m + 60) % 60 ))
    ep=$(( ep - diff * 60 ))
    # Re-decode after minute alignment to get local hour (boundary may have shifted)
    read -r _f1 cur_h _rest <<< "$(epoch_decode "$ep")"
    cur_h=$(( 10#$cur_h ))
    diff=$(( (cur_h - h + 24) % 24 ))
    ep=$(( ep - diff * 3600 ))
    step=86400

  elif [[ "$c_min" =~ ^[0-9]+$ ]]; then
    # Only minute is fixed: align using LOCAL time, step hourly.
    m=$(( 10#$c_min ))
    read -r cur_m _rest <<< "$(epoch_decode "$ep")"
    cur_m=$(( 10#$cur_m ))
    diff=$(( (cur_m - m + 60) % 60 ))
    ep=$(( ep - diff * 60 ))
    step=3600

  else
    step=60
  fi

  while (( ep >= floor_ep )); do
    if cron_due_at "$ep" "$c_min" "$c_hr" "$c_dom" "$c_month" "$c_dow"; then
      echo "$ep"
      return 0
    fi
    ep=$(( ep - step ))
  done

  echo 0
}

# ── State helpers ─────────────────────────────────────────────────────────────

read_state() {
  local f="${STATE_DIR}/${1}.last"
  [[ -f "$f" ]] && cat "$f" || echo 0
}

write_state() {
  local name="$1" ep="$2"
  mkdir -p "$STATE_DIR"
  echo "$ep" > "${STATE_DIR}/${name}.last"
}

# ── YAML helpers ──────────────────────────────────────────────────────────────

yaml_get() {
  local expr="$1" file="$2" default="${3:-}"
  local val
  val=$(yq "$expr" "$file" 2>/dev/null || true)
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "$default"
  else
    echo "$val"
  fi
}

routine_names() {
  yq '.routines | keys | .[]' "$YAML" 2>/dev/null
}

# ── Preflight ─────────────────────────────────────────────────────────────────

preflight() {
  local ok=true
  if ! command -v yq &>/dev/null; then
    echo "darkflow-run: yq not found." >&2
    echo "  macOS:  brew install yq" >&2
    echo "  Linux:  https://github.com/mikefarah/yq#install" >&2
    ok=false
  fi
  if ! command -v claude &>/dev/null; then
    echo "darkflow-run: claude not found." >&2
    echo "  Install Claude Code: https://claude.ai/code" >&2
    ok=false
  fi
  if [[ ! -f "$YAML" ]]; then
    echo "darkflow-run: ${YAML} not found. Run install.sh to reinstall Dark Flow." >&2
    ok=false
  fi
  [[ "$ok" == true ]]
}

# ── Lock ──────────────────────────────────────────────────────────────────────

acquire_lock() {
  mkdir -p "$STATE_DIR"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true; stop_heartbeat_loop' EXIT
}

# ── Routine execution ─────────────────────────────────────────────────────────

run_routine() {
  local name="$1" model="$2" permission_mode="$3"
  local now exit_code=0
  local -a perm_args

  case "$permission_mode" in
    bypassPermissions)
      perm_args=(--permission-mode bypassPermissions)
      ;;
    acceptEdits)
      perm_args=(--permission-mode acceptEdits)
      ;;
    *)
      perm_args=(--permission-mode "$permission_mode")
      ;;
  esac

  log "START  ${name} (model=${model}, perm=${permission_mode})"

  send_heartbeat "running" "$name"
  start_heartbeat_loop "$name"

  if claude -p "/darkflow:${name}" --model "${model}" "${perm_args[@]}"; then
    exit_code=0
  else
    exit_code=$?
  fi

  stop_heartbeat_loop
  send_heartbeat "idle"

  now=$(now_epoch)
  write_state "$name" "$(( now - now % 60 ))"

  local status_str="ok"
  [[ "$exit_code" != "0" ]] && status_str="exit:${exit_code}"
  local ts; ts=$(date -u +%FT%TZ)
  PENDING_LOGS+=("{\"routine\":\"${name}\",\"summary\":\"ran ${name} — ${status_str}\",\"timestamp\":\"${ts}\"}")

  return $exit_code
}

# ── Webapp sync ───────────────────────────────────────────────────────────────
# Called after any routine actually ran. POSTs issue data and project metadata
# to the Dark Flow webapp API (/api/ingest) using the webapp_url from .darkflow.

sync_webapp() {
  local webapp_url
  webapp_url=$(darkflow_val "webapp_url" "")
  if [[ -z "$webapp_url" ]]; then
    log "WEBAPP skipped (webapp_url not set in .darkflow)"
    PENDING_LOGS=()
    return 0
  fi

  if ! command -v gh &>/dev/null || ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
    log "WEBAPP skipped (gh, jq, or curl missing)"
    PENDING_LOGS=()
    return 0
  fi

  local repo_url issues now_iso
  repo_url=$(gh repo view --json url -q .url 2>/dev/null || echo "")
  if [[ -z "$repo_url" ]]; then
    log "WEBAPP skipped (could not determine repo URL)"
    PENDING_LOGS=()
    return 0
  fi

  issues=$(gh issue list --state all --json number,title,body,state,labels,url --limit 300 2>/dev/null) || {
    log "WEBAPP skipped (gh issue list failed)"
    PENDING_LOGS=()
    return 0
  }
  now_iso=$(date -u +%FT%TZ)

  # Parse each issue's labels into structured fields
  local issues_json
  issues_json=$(printf '%s\n' "$issues" | jq '
    def label_prefix(p): [.labels[].name | select(startswith(p)) | ltrimstr(p)][0] // null;
    map({
      number,
      title,
      body,
      state,
      url,
      status:   (label_prefix("status:")   // "none"),
      priority: label_prefix("priority:"),
      area:     label_prefix("area:"),
      source:   label_prefix("source:"),
      effort:   label_prefix("effort:")
    })
  ') || { log "WEBAPP skipped (jq parse error)"; PENDING_LOGS=(); return 0; }

  # Read project metadata from .darkflow
  local proj_name proj_branch proj_lang proj_merge proj_modules
  proj_name=$(darkflow_val "name" "$(basename "$PROJECT_ROOT")")
  proj_branch=$(darkflow_val "branch" "main")
  proj_lang=$(darkflow_val "language" "English")
  proj_merge=$(darkflow_val "merge_strategy" "pr")
  proj_modules=$(darkflow_val "modules" "")

  # Build modules JSON array (comma-separated string → JSON array)
  local modules_json
  modules_json=$(echo "$proj_modules" | jq -Rc 'split(",") | map(select(length > 0))')

  # Build optional sections from metrics files
  local analytics_json="null" security_json="null" architecture_json="null"
  [[ -f "${METRICS_DIR}/analytics.json" ]]     && analytics_json=$(cat "${METRICS_DIR}/analytics.json")
  [[ -f "${METRICS_DIR}/security.json" ]]      && security_json=$(cat "${METRICS_DIR}/security.json")
  [[ -f "${METRICS_DIR}/architecture.json" ]]  && architecture_json=$(cat "${METRICS_DIR}/architecture.json")

  # Build logs JSON array from accumulated PENDING_LOGS
  local logs_json="[]"
  if [[ "${#PENDING_LOGS[@]}" -gt 0 ]]; then
    logs_json=$(printf '%s\n' "${PENDING_LOGS[@]}" | jq -sc '.')
  fi

  # Assemble payload
  local payload
  payload=$(jq -n \
    --arg repoUrl    "$repo_url" \
    --arg name       "$proj_name" \
    --arg branch     "$proj_branch" \
    --arg language   "$proj_lang" \
    --arg merge      "$proj_merge" \
    --argjson modules    "$modules_json" \
    --argjson issues     "$issues_json" \
    --argjson analytics  "$analytics_json" \
    --argjson security   "$security_json" \
    --argjson architecture "$architecture_json" \
    --argjson logs       "$logs_json" \
    '{
      repoUrl:       $repoUrl,
      name:          $name,
      branch:        $branch,
      language:      $language,
      mergeStrategy: $merge,
      modules:       $modules,
      issues:        $issues,
      logs:          $logs
    }
    | if $analytics   != null then . + {analytics: $analytics}     else . end
    | if $security    != null then . + {security: $security}        else . end
    | if $architecture != null then . + {architecture: $architecture} else . end
    ') || { log "WEBAPP skipped (payload build error)"; PENDING_LOGS=(); return 0; }

  local http_code
  http_code=$(curl -fsS -o /dev/null -w "%{http_code}" \
    -X POST "${webapp_url}/api/ingest" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>/dev/null) || true

  if [[ "$http_code" =~ ^2 ]]; then
    log "WEBAPP synced (HTTP ${http_code})"
  else
    log "WEBAPP sync failed (HTTP ${http_code:-000})"
  fi

  PENDING_LOGS=()
}

# ── Worker heartbeat ──────────────────────────────────────────────────────────
# Sends lightweight status pings to /api/worker/heartbeat so the web UI shows
# which projects have an active worker and what routine is running.
# The watch loop sends "idle" every 60 s even when no routine runs.

_REPO_URL_CACHE=""

_get_repo_url_cached() {
  if [[ -z "$_REPO_URL_CACHE" ]]; then
    _REPO_URL_CACHE=$(gh repo view --json url -q .url 2>/dev/null || echo "")
  fi
  echo "$_REPO_URL_CACHE"
}

send_heartbeat() {
  local status="$1" routine="${2:-}"
  local webapp_url
  webapp_url=$(darkflow_val "webapp_url" "")
  [[ -z "$webapp_url" ]] && return 0
  ! command -v curl &>/dev/null && return 0
  ! command -v gh   &>/dev/null && return 0

  local repo_url
  repo_url=$(_get_repo_url_cached)
  [[ -z "$repo_url" ]] && return 0

  local proj_name routine_field="null"
  proj_name=$(darkflow_val "name" "$(basename "$PROJECT_ROOT")")
  [[ -n "$routine" ]] && routine_field="\"${routine}\""

  curl -fsS -o /dev/null -m 5 \
    -X POST "${webapp_url}/api/worker/heartbeat" \
    -H "Content-Type: application/json" \
    -d "{\"repoUrl\":\"${repo_url}\",\"status\":\"${status}\",\"routine\":${routine_field},\"name\":\"${proj_name}\"}" \
    2>/dev/null || true
}

HEARTBEAT_PID=""

start_heartbeat_loop() {
  local routine="$1"
  (
    trap '' INT TERM
    while true; do
      sleep 60
      send_heartbeat "running" "$routine"
    done
  ) &
  HEARTBEAT_PID=$!
}

stop_heartbeat_loop() {
  if [[ -n "${HEARTBEAT_PID:-}" ]]; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
    HEARTBEAT_PID=""
  fi
}

# ── Mode: list ────────────────────────────────────────────────────────────────

mode_list() {
  local name cron enabled last_run last_str
  printf "%-25s %-20s %-9s %s\n" "ROUTINE" "CRON" "ENABLED" "LAST RUN"
  printf "%-25s %-20s %-9s %s\n" "-------" "----" "-------" "--------"
  while IFS= read -r name; do
    cron=$(yaml_get ".routines[\"${name}\"].cron" "$YAML" "")
    enabled=$(yaml_get ".routines[\"${name}\"].enabled" "$YAML" "true")
    last_run=$(read_state "$name")
    if [[ "$last_run" == "0" ]]; then
      last_str="never"
    else
      last_str=$(epoch_fmt "$last_run")
    fi
    printf "%-25s %-20s %-9s %s\n" "$name" "${cron:-(none)}" "$enabled" "$last_str"
  done < <(routine_names)
}

# ── Mode: dispatch ────────────────────────────────────────────────────────────

mode_dispatch() {
  local dry_run="${1:-false}"
  local now name cron enabled model permission_mode last_run floor prev
  local default_model default_perm

  now=$(now_epoch)
  default_model=$(yaml_get '.defaults.model' "$YAML" "sonnet")
  default_perm=$(yaml_get '.defaults.permission_mode' "$YAML" "bypassPermissions")

  rotate_log

  local any_due=false
  while IFS= read -r name; do
    cron=$(yaml_get ".routines[\"${name}\"].cron" "$YAML" "")
    enabled=$(yaml_get ".routines[\"${name}\"].enabled" "$YAML" "true")

    if [[ "$enabled" != "true" || -z "$cron" ]]; then
      continue
    fi

    model=$(yaml_get ".routines[\"${name}\"].model" "$YAML" "$default_model")
    permission_mode=$(yaml_get ".routines[\"${name}\"].permission_mode" "$YAML" "$default_perm")

    # Parse 5 cron fields
    read -r c_min c_hr c_dom c_month c_dow <<< "$cron"

    last_run=$(read_state "$name")

    # Search floor: on first install (last_run=0) look back 25h; else from last_run
    if [[ "$last_run" == "0" ]]; then
      floor=$(( now - 90000 ))
    else
      floor=$last_run
    fi

    prev=$(prev_fire "$c_min" "$c_hr" "$c_dom" "$c_month" "$c_dow" "$floor")

    if [[ "$prev" == "0" || "$prev" -le "$last_run" ]]; then
      continue
    fi

    any_due=true

    if [[ "$dry_run" == true ]]; then
      echo "  [due] ${name}  cron='${cron}'  model=${model}"
    else
      run_routine "$name" "$model" "$permission_mode" || true
    fi

  done < <(routine_names)

  if [[ "$dry_run" == true && "$any_due" == false ]]; then
    echo "  No routines are due at this time."
  fi
}

# ── Mode: manual ──────────────────────────────────────────────────────────────

mode_manual() {
  local name="$1"
  local model permission_mode default_model default_perm

  if ! yq ".routines | has(\"${name}\")" "$YAML" 2>/dev/null | grep -q "true"; then
    echo "darkflow-run: unknown routine '${name}'" >&2
    echo "Known routines: $(routine_names | tr '\n' ' ')" >&2
    exit 1
  fi

  default_model=$(yaml_get '.defaults.model' "$YAML" "sonnet")
  default_perm=$(yaml_get '.defaults.permission_mode' "$YAML" "bypassPermissions")
  model=$(yaml_get ".routines[\"${name}\"].model" "$YAML" "$default_model")
  permission_mode=$(yaml_get ".routines[\"${name}\"].permission_mode" "$YAML" "$default_perm")

  log "MANUAL ${name}"
  run_routine "$name" "$model" "$permission_mode"
  sync_webapp
}

# ── Mode: watch ───────────────────────────────────────────────────────────────

mode_watch() {
  local interval=60
  local tick=0

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dark Flow started (tick every ${interval}s). Ctrl-C to stop."
  trap 'echo ""; log "WATCH  stopped (signal)"; stop_heartbeat_loop; exit 0' INT TERM

  while true; do
    (( tick++ )) || true
    log "WATCH  tick ${tick}"
    send_heartbeat "idle"

    mkdir -p "$STATE_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      mode_dispatch false || log "WATCH  dispatch error (tick ${tick})"
      # Full web UI sync (GitHub issues + metadata) every 5th tick (~5 min).
      # The heartbeat above keeps the worker-alive signal fresh every minute.
      if (( tick % 5 == 1 )); then
        sync_webapp
      fi
      rmdir "$LOCK_DIR" 2>/dev/null || true
    else
      log "WATCH  skipped tick ${tick} (another dispatch is running)"
    fi

    sleep "$interval" || true   # || true so SIGINT from Ctrl-C doesn't exit with error
  done
}

# ── Mode: self-test ───────────────────────────────────────────────────────────

mode_self_test() {
  local failures=0
  local now; now=$(now_epoch)
  echo "Running cron-matcher self-tests..."

  # field match: wildcard
  cron_field_match "5" "*" || { echo "FAIL wildcard"; (( failures++ )) || true; }
  echo "  PASS  wildcard match"

  # field match: exact
  cron_field_match "0" "0" || { echo "FAIL exact 0"; (( failures++ )) || true; }
  echo "  PASS  exact match"

  # field match: list
  cron_field_match "0" "1,2,0" || { echo "FAIL list"; (( failures++ )) || true; }
  echo "  PASS  list match"

  # field match: list — negative
  cron_field_match "3" "1,2,0" && { echo "FAIL list-neg (should not match)"; (( failures++ )) || true; } || echo "  PASS  list no-match"

  # field match: range
  cron_field_match "3" "1-5" || { echo "FAIL range"; (( failures++ )) || true; }
  echo "  PASS  range match"

  # field match: step
  cron_field_match "5" "1-9/2" || { echo "FAIL step"; (( failures++ )) || true; }
  echo "  PASS  step match"

  # field match: step — negative
  cron_field_match "4" "1-9/2" && { echo "FAIL step-neg (should not match)"; (( failures++ )) || true; } || echo "  PASS  step no-match"

  # prev_fire: hourly — result must be the top of the current hour
  local top_of_hour=$(( now - now % 3600 ))
  local result; result=$(prev_fire "0" "*" "*" "*" "*" "$(( now - 90000 ))")
  if [[ "$result" == "$top_of_hour" ]]; then
    echo "  PASS  hourly prev_fire → $(epoch_fmt "$result" "%H:%M")"
  else
    echo "  FAIL  hourly: expected $(epoch_fmt "$top_of_hour" "%H:%M"), got $(epoch_fmt "$result" "%H:%M" 2>/dev/null || echo "$result")"
    (( failures++ )) || true
  fi

  # prev_fire: empty cron should not be called (guard: 0 floor always fails)
  result=$(prev_fire "0" "0" "*" "*" "*" "$(( now + 3600 ))")
  if [[ "$result" == "0" ]]; then
    echo "  PASS  unreachable floor → 0"
  else
    echo "  FAIL  expected 0, got $result"
    (( failures++ )) || true
  fi

  if [[ "$failures" == "0" ]]; then
    echo "All self-tests passed."
  else
    echo "${failures} test(s) failed."
    exit 1
  fi
}

# ── Mode: sync ────────────────────────────────────────────────────────────────
# Pushes current GitHub issues and project metadata to the web UI without
# running any routine. Useful right after install to populate the dashboard.

mode_sync() {
  if ! command -v gh &>/dev/null || ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
    echo "darkflow-run: --sync requires gh, jq, and curl" >&2
    exit 1
  fi
  log "SYNC   manual web UI sync"
  send_heartbeat "idle"
  sync_webapp
  echo "Synced GitHub issues and project metadata to the web UI."
}

# ── Main ──────────────────────────────────────────────────────────────────────

mkdir -p "$STATE_DIR"

case "${1:-}" in
  --list)
    preflight || exit 1
    mode_list
    ;;
  --dry-run)
    preflight || exit 1
    acquire_lock
    mode_dispatch true
    ;;
  --once)
    preflight || exit 1
    acquire_lock
    mode_dispatch false
    sync_webapp
    ;;
  --self-test)
    mode_self_test
    ;;
  --sync)
    mode_sync
    ;;
  "")
    # Default: continuous loop, check every minute
    preflight || exit 1
    mode_watch 60
    ;;
  -*)
    echo "Usage: darkflow-run.sh [<routine-name> | --once | --sync | --list | --dry-run | --self-test]" >&2
    exit 1
    ;;
  *)
    preflight || exit 1
    acquire_lock
    mode_manual "$1"
    ;;
esac
