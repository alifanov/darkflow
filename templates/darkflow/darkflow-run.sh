#!/usr/bin/env bash
# Dark Flow routine dispatcher
# Lives at .darkflow.d/darkflow-run.sh — run from anywhere in the project.
#
# Usage:
#   bash .darkflow.d/darkflow-run.sh              # loop every 60s — checks for due routines (default)
#   bash .darkflow.d/darkflow-run.sh --once       # single dispatch and exit (for system scheduler)
#   bash .darkflow.d/darkflow-run.sh <name>       # manual: run one routine immediately
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
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
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

  if claude -p "/darkflow:${name}" --model "${model}" "${perm_args[@]}"; then
    exit_code=0
  else
    exit_code=$?
  fi

  now=$(now_epoch)
  write_state "$name" "$(( now - now % 60 ))"
  return $exit_code
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

  log "DISPATCH start (dry_run=${dry_run})"
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

    log "DUE    ${name} (scheduled=$(epoch_fmt "$prev"), last=$([ "$last_run" = 0 ] && echo never || epoch_fmt "$last_run"))"
    any_due=true

    if [[ "$dry_run" == true ]]; then
      echo "  [due] ${name}  cron='${cron}'  model=${model}"
    else
      run_routine "$name" "$model" "$permission_mode" || true
    fi

  done < <(routine_names)

  log "DISPATCH end"

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
}

# ── Mode: watch ───────────────────────────────────────────────────────────────

mode_watch() {
  local interval=60
  local tick=0

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dark Flow started (tick every ${interval}s). Ctrl-C to stop."
  trap 'echo ""; log "WATCH  stopped (signal)"; exit 0' INT TERM

  while true; do
    (( tick++ )) || true
    log "WATCH  tick ${tick}"

    mkdir -p "$STATE_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      mode_dispatch false
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
    ;;
  --self-test)
    mode_self_test
    ;;
  "")
    # Default: continuous loop, check every minute
    preflight || exit 1
    mode_watch 60
    ;;
  -*)
    echo "Usage: darkflow-run.sh [<routine-name> | --once | --list | --dry-run | --self-test]" >&2
    exit 1
    ;;
  *)
    preflight || exit 1
    acquire_lock
    mode_manual "$1"
    ;;
esac
