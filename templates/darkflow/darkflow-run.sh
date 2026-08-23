#!/usr/bin/env bash
# Dark Flow global routine dispatcher
# Lives at ~/.darkflow/darkflow-run.sh — ONE worker services every registered
# project. With no arguments it loops, discovering projects from the web UI
# (/api/projects) and dispatching each one's due routines. The single-project
# subcommands operate on the Dark Flow project containing the current directory.
#
# Usage:
#   darkflow-run.sh              # global loop: discover all projects, dispatch due routines (default)
#   darkflow-run.sh <name>       # manual: run one routine in the cwd's project immediately
#   darkflow-run.sh --sync       # push the cwd project's issues + metadata to the web UI
#   darkflow-run.sh --list       # show the cwd project's routine status table
#   darkflow-run.sh --dry-run    # show what would run for the cwd project, don't run it
#   darkflow-run.sh --self-test  # run internal cron-matcher tests

set -euo pipefail

# ── Global paths ──────────────────────────────────────────────────────────────
# These never change: the worker, its config, slots and the user-scope command
# files are all machine-global now (one worker for every project).

SELF_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
DARKFLOW_REPO="https://raw.githubusercontent.com/alifanov/darkflow/main"
GLOBAL_SLOTS_DIR="${TMPDIR:-/tmp}/darkflow-slots"
GLOBAL_DIR="${HOME}/.darkflow"
GLOBAL_CFG="${GLOBAL_DIR}/config"          # webapp_url=, version=
GLOBAL_LOG="${GLOBAL_DIR}/worker.log"
USER_CMD_DIR="${HOME}/.claude/commands/darkflow"   # slash commands live in user scope
DF_BIN="${GLOBAL_DIR}/df"                          # task CLI — talks to /api/tasks/*

# Every routine the worker starts runs unattended. A routine that behaves
# differently with a human present (asking instead of deciding) reads this
# instead of probing for AskUserQuestion and catching the failure.
export DARKFLOW_HEADLESS=1

# ── Engine credentials ────────────────────────────────────────────────────────
# launchd does NOT source ~/.zshrc, so the interactive login token the user's
# terminal `claude` relies on (CLAUDE_CODE_OAUTH_TOKEN and friends) is invisible
# to the worker — every routine that reaches the engine fails with
# "Not logged in · Please run /login". Source ~/.darkflow/env (git-ignored,
# outside any repo) so those credentials reach `claude`/`codex` here too.
if [[ -f "${GLOBAL_DIR}/env" ]]; then
  set -a; source "${GLOBAL_DIR}/env"; set +a
fi

# ── Per-project paths ─────────────────────────────────────────────────────────
# (Re)computed by set_project() for each project the global worker services.
# LOG points at the global log until a project is selected so orchestration
# messages emitted between projects still land somewhere.
PROJECT_ROOT=""
DARKFLOW_D=""
STATE_DIR=""
LOCK_DIR=""
LOG="$GLOBAL_LOG"
METRICS_DIR=""
PROJECT_CFG_JSON=""

# Temp files registered here are removed by the EXIT trap even on signals.
_CLEANUP_FILES=()
# Throwaway git worktrees registered here are removed by the EXIT trap too, so a
# crashed/killed run never leaks a checkout dir.
_CLEANUP_WORKTREES=()

# Accumulated routine log entries for this dispatch cycle (JSON lines)
PENDING_LOGS=()

# Cached log prefix "[vX.Y.Z] [ProjectName]" — built lazily on first log() call
_LOG_PREFIX=""
_LOG_PREFIX_READY=false

mkdir -p "$GLOBAL_DIR" 2>/dev/null || true

# Point every per-project path var at <abs_path> and reset per-project caches.
# Called once per project per dispatch tick, and once for the cwd-scoped manual
# subcommands. cd's into the project so gh/git invocations resolve the right repo.
set_project() {
  PROJECT_ROOT="$1"
  DARKFLOW_D="${PROJECT_ROOT}/.darkflow.d"          # per-project runtime dir (state, metrics, logs, mailbox)
  STATE_DIR="${DARKFLOW_D}/state"
  LOCK_DIR="${STATE_DIR}/.lock"
  LOG="${DARKFLOW_D}/darkflow-run.log"
  METRICS_DIR="${STATE_DIR}/metrics"
  PROJECT_CFG_JSON="${STATE_DIR}/config.json"        # config + schedule fetched from the Web UI
  _LOG_PREFIX=""
  _LOG_PREFIX_READY=false
  _REPO_URL_CACHE=""
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  cd "$PROJECT_ROOT" 2>/dev/null || return 1
  fetch_project_config || return 1   # not registered / server down → caller skips this project
  return 0
}

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

# Parse a UTC ISO-8601 timestamp (as GitHub's API returns) into an epoch. Echoes
# 0 when it can't parse — callers treat that as "unknown, don't act on it".
# ponytail: python3 is already a hard dependency, and BSD/GNU `date` disagree on
# every flag needed to do this in shell.
iso_to_epoch() {
  python3 -c 'import datetime,sys
try: print(int(datetime.datetime.strptime(sys.argv[1].strip(), "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc).timestamp()))
except Exception: print(0)' "$1" 2>/dev/null || echo 0
}

# The inverse: epoch → UTC ISO-8601, directly comparable to GitHub's timestamps.
# NB: not epoch_fmt() — that formats in LOCAL time, so stamping its output with a
# "Z" suffix would silently shift the value by the machine's UTC offset.
epoch_to_iso() {
  python3 -c 'import datetime,sys
print(datetime.datetime.fromtimestamp(int(sys.argv[1]), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$1" 2>/dev/null || echo "1970-01-01T00:00:00Z"
}

# ── Logging ───────────────────────────────────────────────────────────────────

log() {
  _init_log_prefix
  local line="[$(date '+%Y-%m-%d %H:%M:%S')]${_LOG_PREFIX} $*"
  echo "$line" >> "$LOG" 2>/dev/null || true
  echo "$line"
}

rotate_log() {
  if [[ -f "$LOG" ]] && [[ "$(wc -c < "$LOG")" -gt 1048576 ]]; then
    tail -c 524288 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
  fi
}

# Global logger — used by the orchestration loop for messages that aren't tied to
# any one project (project discovery, worker start/stop, self-update).
glog() {
  local line="[$(date '+%Y-%m-%d %H:%M:%S')] [global] $*"
  echo "$line" >> "$GLOBAL_LOG" 2>/dev/null || true
  echo "$line"
}

# ── Project config reader ─────────────────────────────────────────────────────
# Reads settings from the per-project config JSON fetched from the Web UI (the DB
# is the source of truth). `webapp_url` and `version` are machine-global and come
# from ~/.darkflow/config; secrets like gh_token are no longer stored per project.
# The legacy snake_case keys are kept so call sites don't change.
darkflow_val() {
  local key="$1" default="${2:-}" val jqexpr
  case "$key" in
    webapp_url|version)
      val=$(global_val "$key" ""); [[ -n "$val" ]] && { echo "$val"; return; }; echo "$default"; return ;;
    gh_token)
      echo "$default"; return ;;
  esac
  [[ -f "$PROJECT_CFG_JSON" ]] || { echo "$default"; return; }
  case "$key" in
    name)               jqexpr='.name' ;;
    slug)               jqexpr='.slug' ;;
    domain|site_url)    jqexpr='.domain' ;;
    branch)             jqexpr='.branch' ;;
    language)           jqexpr='.language' ;;
    merge_strategy)     jqexpr='.mergeStrategy' ;;
    min_priority)       jqexpr='.minPriority' ;;
    max_concurrent)     jqexpr='.maxConcurrent' ;;
    obs_tool)           jqexpr='.obsTool' ;;
    obs_url)            jqexpr='.obsUrl' ;;
    modules)            jqexpr='(.modules // []) | join(",")' ;;
    worktree)           jqexpr='.worktree' ;;
    *)                  echo "$default"; return ;;
  esac
  val=$(jq -r "${jqexpr} // empty" "$PROJECT_CFG_JSON" 2>/dev/null)
  if [[ -n "$val" && "$val" != "null" ]]; then echo "$val"; else echo "$default"; fi
}

# ── ~/.darkflow/config reader (global worker settings) ────────────────────────

global_val() {
  local key="$1" default="${2:-}" val
  if [[ -f "$GLOBAL_CFG" ]]; then
    val=$(grep -E "^${key}=" "$GLOBAL_CFG" 2>/dev/null | head -1 | cut -d= -f2-)
    if [[ -n "$val" ]]; then echo "$val"; return; fi
  fi
  echo "$default"
}

# ── Per-project config fetch (Web UI = source of truth) ───────────────────────
# Pulls the project's full settings + merged routine schedule from
# /api/projects/by-repo into $PROJECT_CFG_JSON, which darkflow_val() and the
# routine helpers read. Returns non-zero when the project isn't registered or the
# server is unreachable, so callers skip it instead of dispatching blind.
fetch_project_config() {
  local webapp_url repo_url encoded resp
  webapp_url=$(global_val "webapp_url" "")
  [[ -n "$webapp_url" ]] || return 1
  command -v curl &>/dev/null || return 1
  command -v jq   &>/dev/null || return 1
  repo_url=$(_get_repo_url_cached)
  [[ -n "$repo_url" ]] || return 1
  encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$repo_url" 2>/dev/null \
    || printf '%s' "$repo_url" | sed 's|:|%3A|g; s|/|%2F|g')
  resp=$(curl -fsS -m 10 "${webapp_url}/api/projects/by-repo?repoUrl=${encoded}" 2>/dev/null) || return 1
  [[ "${resp:0:1}" == "{" ]] || return 1
  jq -e '.id' >/dev/null 2>&1 <<< "$resp" || return 1   # 404 → {"error":…} has no .id
  printf '%s' "$resp" > "$PROJECT_CFG_JSON" 2>/dev/null || return 1
  return 0
}

# Lazily builds the log prefix "[vX.Y.Z] [ProjectName]" and caches it.
# Called on every log() invocation; only reads .darkflow on the first call.
_init_log_prefix() {
  $_LOG_PREFIX_READY && return 0
  _LOG_PREFIX_READY=true
  local ver name
  ver=$(darkflow_val "version" "")
  name=$(darkflow_val "name" "$(basename "$PROJECT_ROOT")")
  _LOG_PREFIX=""
  [[ -n "$ver" ]]  && _LOG_PREFIX=" [v${ver}]"
  [[ -n "$name" ]] && _LOG_PREFIX+=" [${name}]"
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
  local name="$1" ep="$2" tmp
  mkdir -p "$STATE_DIR"
  tmp=$(mktemp "${STATE_DIR}/.state_tmp.XXXXXX")
  echo "$ep" > "$tmp"
  mv "$tmp" "${STATE_DIR}/${name}.last"
}

# ── Routine schedule helpers (read from the fetched config JSON) ──────────────
# The Web UI already merged the global default catalog with per-project overrides,
# so each entry in .routines[] carries its resolved cron/model/engine/enabled.

routine_names() {
  [[ -f "$PROJECT_CFG_JSON" ]] || return 0
  jq -r '.routines[]?.name' "$PROJECT_CFG_JSON" 2>/dev/null
}

# routine_val <name> <jsonField> [default]
# NB: don't use jq's `//` here — it treats `false` as empty, which would turn a
# disabled routine (enabled:false) back into the "true" default. Filter null only.
routine_val() {
  local name="$1" field="$2" default="${3:-}" val
  [[ -f "$PROJECT_CFG_JSON" ]] || { echo "$default"; return; }
  val=$(jq -r --arg n "$name" --arg f "$field" \
    '.routines[]? | select(.name==$n) | .[$f] | select(. != null)' "$PROJECT_CFG_JSON" 2>/dev/null)
  if [[ -n "$val" ]]; then echo "$val"; else echo "$default"; fi
}

routine_exists() {
  local name="$1"
  [[ -f "$PROJECT_CFG_JSON" ]] || return 1
  jq -e --arg n "$name" '.routines[]? | select(.name==$n)' "$PROJECT_CFG_JSON" >/dev/null 2>&1
}

# ── Preflight ─────────────────────────────────────────────────────────────────

# Machine-global tool checks — run once at startup, independent of any project.
preflight_tools() {
  local ok=true
  if ! command -v claude &>/dev/null; then
    echo "darkflow-run: claude not found." >&2
    echo "  Install Claude Code: https://claude.ai/code" >&2
    ok=false
  fi
  if ! command -v python3 &>/dev/null; then
    echo "darkflow-run: python3 not found." >&2
    echo "  macOS:  brew install python3" >&2
    echo "  Linux:  apt install python3 / dnf install python3" >&2
    ok=false
  fi
  if ! command -v jq &>/dev/null; then
    echo "darkflow-run: jq not found." >&2
    echo "  macOS:  brew install jq" >&2
    echo "  Linux:  apt install jq / dnf install jq" >&2
    ok=false
  fi
  [[ "$ok" == true ]]
}

# Per-project checks for the cwd-scoped subcommands (--list/--dry-run/<name>).
# Assumes preflight_tools already ran. set_project() must have run first.
preflight() {
  local ok=true
  if [[ ! -f "$PROJECT_CFG_JSON" ]]; then
    echo "darkflow-run: no config for this project — register it in the Web UI and make sure the server is reachable." >&2
    return 1
  fi
  # Warn when an enabled routine has no command file, but DON'T fail the whole
  # dispatcher over it — this is the expected state right after Dark Flow removes
  # a routine upstream; the orphan simply gets skipped at dispatch time. Also
  # require the codex CLI when any enabled routine runs on the codex engine.
  local _cmd_dir="${USER_CMD_DIR}" _rname _enabled _uses_codex=false _cengine
  while IFS= read -r _rname; do
    _enabled=$(routine_val "$_rname" enabled "true")
    [[ "$_enabled" == "false" ]] && continue
    # ci-watch and housekeeping run entirely inside this script — they have no
    # command file by design, so don't warn about the one they don't need.
    [[ "$_rname" == "ci-watch" || "$_rname" == "housekeeping" ]] && continue
    if [[ ! -f "${_cmd_dir}/${_rname}.md" ]]; then
      echo "darkflow-run: routine '${_rname}' has no command file (~/.claude/commands/darkflow/${_rname}.md) — skipping it." >&2
    fi
    _cengine=$(routine_val "$_rname" engine "claude")
    [[ "$_cengine" == "codex" ]] && _uses_codex=true
  done < <(routine_names)
  if [[ "$_uses_codex" == true ]] && ! command -v codex &>/dev/null; then
    echo "darkflow-run: codex not found, but a routine is set to engine: codex." >&2
    echo "  Install Codex CLI (npm i -g @openai/codex) and authenticate it, or switch the routine back to claude." >&2
    ok=false
  fi
  [[ "$ok" == true ]]
}

# ── Lock ──────────────────────────────────────────────────────────────────────

# ── Per-project lock: ONE session per project (A10) ───────────────────────────
# The global semaphore below caps how many agent sessions run on the machine.
# This lock is the other half: it caps them at one *per project*, and it is taken
# BEFORE the global slot, by every entry point — the watch loop's dispatch
# subshell, `--dry-run`, and a manual `darkflow-run.sh <routine>` alike.
#
# It has to be per project because worktrees are forbidden: every routine of a
# project works in the same checkout. Two at once would race for `index.lock` and,
# once routines started committing what they write, sweep each other's edits into
# a commit. A busy project simply skips the tick.
#
# No exemptions for the cheap routines. ci-watch and the uptime probe cost nothing
# to run, but they still write into that one checkout, and they run every 4–24h —
# they rarely collide with anything anyway, so the exemption would buy nothing and
# cost the guarantee.
#
# mkdir is the atomic primitive here (not `set -o noclobber`): it is one syscall
# and it behaves on network filesystems, where O_EXCL does not.
#
# Try to take the dispatch lock. Returns 0 on success, 1 on contention.
# Reclaims the lock if the recorded owner PID is no longer alive (stale lock
# from a SIGKILLed / OOM-killed / power-loss dispatch that never ran its trap).
try_acquire_lock() {
  mkdir -p "$STATE_DIR"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$$" > "$LOCK_DIR/pid"
    return 0
  fi

  local owner_pid=""
  [[ -f "$LOCK_DIR/pid" ]] && owner_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")

  if [[ -n "$owner_pid" ]] && kill -0 "$owner_pid" 2>/dev/null; then
    return 1
  fi

  log "LOCK   reclaiming stale lock (owner PID ${owner_pid:-unknown} not running)"
  rm -rf "$LOCK_DIR"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$$" > "$LOCK_DIR/pid"
    return 0
  fi
  return 1
}

release_lock() {
  rm -rf "$LOCK_DIR" 2>/dev/null || true
}

# ── Global concurrency semaphore ──────────────────────────────────────────────
# Limits simultaneous claude processes across all projects on this machine.
# Slots live in /tmp/darkflow-slots/; each slot file contains "PID:project-path".
# Stale slots (dead PID) are reclaimed automatically.

_acquired_slot=""  # slot index held by this process (empty = none)

semaphore_acquire() {
  local max_slots i slot_file owner_pid
  max_slots=$(darkflow_val "max_concurrent" "3")
  mkdir -p "$GLOBAL_SLOTS_DIR"

  for (( i = 0; i < max_slots; i++ )); do
    slot_file="${GLOBAL_SLOTS_DIR}/slot-${i}.lock"
    if [[ ! -f "$slot_file" ]]; then
      if ( set -o noclobber; echo "$$:${PROJECT_ROOT}" > "$slot_file" ) 2>/dev/null; then
        _acquired_slot="$i"
        return 0
      fi
    fi
    # Slot exists — reclaim if owner PID is dead
    owner_pid=$(cut -d: -f1 "$slot_file" 2>/dev/null || echo "")
    if [[ -n "$owner_pid" ]] && ! kill -0 "$owner_pid" 2>/dev/null; then
      rm -f "$slot_file"
      if ( set -o noclobber; echo "$$:${PROJECT_ROOT}" > "$slot_file" ) 2>/dev/null; then
        log "SEMA   reclaimed stale slot ${i} (dead PID ${owner_pid})"
        _acquired_slot="$i"
        return 0
      fi
    fi
  done
  return 1  # all slots busy
}

semaphore_release() {
  if [[ -n "$_acquired_slot" ]]; then
    rm -f "${GLOBAL_SLOTS_DIR}/slot-${_acquired_slot}.lock" 2>/dev/null || true
    _acquired_slot=""
  fi
}

_do_exit_cleanup() {
  [[ ${#_CLEANUP_FILES[@]} -gt 0 ]] && rm -f "${_CLEANUP_FILES[@]}" 2>/dev/null || true
  local _wt
  for _wt in "${_CLEANUP_WORKTREES[@]}"; do
    [[ -n "$_wt" ]] || continue
    git -C "$PROJECT_ROOT" worktree remove --force "$_wt" 2>/dev/null || rm -rf "$_wt"
  done
  release_lock
  stop_heartbeat_loop
}

acquire_lock() {
  if ! try_acquire_lock; then
    # A busy project skips the tick — that is the point. But a person who typed
    # `darkflow-run.sh <routine>` and got a silent exit 0 has no way to tell
    # "already running" from "did nothing", so say which PID owns it.
    local owner_pid=""
    [[ -f "$LOCK_DIR/pid" ]] && owner_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
    echo "darkflow-run: another run is already active for this project (PID ${owner_pid:-unknown}) — one session per project" >&2
    exit 0
  fi
  trap '_do_exit_cleanup' EXIT
}

# ── Process group isolation ───────────────────────────────────────────────────
# Run a command in a new process group so any background processes it spawns
# (dev servers, watchers, etc.) can be killed after the command exits.
# Prints output to stdout; sets caller's _pgid_ret to the new PGID.
_pgid_ret=""

run_in_pgid() {
  local _tmpout _bgpid _watchdog _rc=0
  _tmpout=$(mktemp)
  _CLEANUP_FILES+=("$_tmpout")
  _pgid_ret=""

  if ! command -v python3 &>/dev/null; then
    echo "darkflow-run: python3 not found — required for process group isolation" >&2
    return 1
  fi

  # Pre-flight: the python wrapper execvp's "$1" and would otherwise emit an
  # opaque FileNotFoundError traceback if the engine binary (claude/codex) is
  # missing from PATH. Fail loud and clear instead.
  if ! command -v "$1" &>/dev/null; then
    echo "darkflow-run: command not found on PATH: '$1' — is the engine CLI installed?" >&2
    return 127
  fi

  python3 -c 'import os,sys; os.setpgrp(); os.execvp(sys.argv[1], sys.argv[1:])' "$@" > "$_tmpout" 2>&1 &
  _bgpid=$!
  _pgid_ret=$_bgpid

  # Watchdog: kill the subprocess if it runs longer than 2 hours
  (sleep 7200 && kill -TERM "$_bgpid" 2>/dev/null || true) &
  _watchdog=$!

  wait "$_bgpid" 2>/dev/null || _rc=$?

  kill "$_watchdog" 2>/dev/null || true
  wait "$_watchdog" 2>/dev/null || true

  # Kill any survivors in the process group (stray dev servers, file watchers, etc.)
  if [[ -n "$_pgid_ret" ]] && pgrep -g "$_pgid_ret" &>/dev/null 2>/dev/null; then
    log "CLEANUP stray processes in PGID ${_pgid_ret} (dev servers, watchers) — terminating"
    kill -TERM -"$_pgid_ret" 2>/dev/null || true
    sleep 1
    kill -KILL -"$_pgid_ret" 2>/dev/null || true
  fi

  cat "$_tmpout"
  rm -f "$_tmpout"
  _CLEANUP_FILES=("${_CLEANUP_FILES[@]/$_tmpout}")
  return $_rc
}

# ── Routine execution ─────────────────────────────────────────────────────────

# ── CI watch (mechanical — never launches an agent) ───────────────────────────
# The producer of `source:ci` tasks that `fix-ci-issue` consumes. Two probes:
#
#   A. GitHub Actions — the newest run per workflow on the base branch either
#      concluded `failure`, or is STILL queued/in_progress past CI_STUCK_MIN
#      minutes (that's a dead self-hosted runner: the job is never red and never
#      green, so nothing else would ever notice).
#   B. Local checks — lint + test in the project root, but only when HEAD moved
#      since the last green run, so an idle repo costs nothing. This covers the
#      repos that have no GitHub workflows at all.
#
# Both file ONE deduped task per branch and close it again when everything goes
# green. Deciding "CI is red" and writing a task is pure bookkeeping, so this is
# plain bash: no LLM, no concurrency slot, no tokens. `fix-ci-issue` does the
# actual fixing.
#
# ponytail: this replaces the darkflow-ci-gate GitHub workflow, which needed a
# self-hosted runner to run the checks and — running inside GitHub Actions —
# could not reach the local task store, so it filed GitHub Issues nobody read.
CI_STUCK_MIN=45
# Ignore red runs older than this. A workflow that failed once and has not run
# since is history, not a signal: nothing will re-run it, so it can never go
# green and the task it files can never be closed. Real case that forced this:
# naturalwrite's only workflow on `dev` was a CodeQL run that failed on
# 2026-06-02 and never ran again — ci-watch reported the repo red forever.
CI_STALE_DAYS=7
_CI_SUMMARY=""

# Echo the number of the open source:ci task with this exact title, or nothing.
ci_open_task() {
  local title="$1"
  "$DF_BIN" task list --source ci --state open 2>/dev/null \
    | jq -r --arg t "$title" '[.[] | select(.title == $t)] | .[0].number // empty' 2>/dev/null
}

ci_watch() {
  _CI_SUMMARY=""
  [[ -x "$DF_BIN" ]] || { _CI_SUMMARY="df CLI missing - cannot file ci tasks"; return 0; }
  command -v jq &>/dev/null || { _CI_SUMMARY="jq missing - cannot file ci tasks"; return 0; }

  local branch title failed="" report=""
  branch=$(darkflow_val "branch" "main")
  title="CI failure on ${branch}"

  # ── A. GitHub Actions on the base branch ────────────────────────────────────
  local repo
  repo=$(_get_repo_url_cached)
  repo="${repo#https://github.com/}"
  if [[ -n "$repo" ]] && command -v gh &>/dev/null; then
    local runs latest
    runs=$(gh run list -R "$repo" -b "$branch" -L 40 \
             --json name,conclusion,status,createdAt,url,databaseId,event 2>/dev/null || echo "")
    if [[ -n "$runs" && "$runs" != "[]" ]]; then
      # Newest run per workflow name — an old red run whose workflow has since
      # gone green must not keep the task open.
      #
      # `event == "dynamic"` runs are Dependabot's own update jobs. They land on
      # the base branch, they routinely fail (private registry, peer conflict),
      # and each one carries a UNIQUE name ("npm_and_yarn in /. for next -
      # Update #149…") so they defeat the group_by dedup and would flood the
      # task with a dozen phantom "failing workflows" that can never go green.
      # Dependency updates are `vulnerability-check`'s job, not CI's.
      latest=$(jq -c '[.[] | select(.event != "dynamic")] | [group_by(.name)[] | sort_by(.createdAt) | last]' <<<"$runs" 2>/dev/null || echo "[]")

      # Only FRESH failures count (see CI_STALE_DAYS). GitHub's timestamps are
      # UTC ISO-8601, so a plain string compare is a correct date compare here.
      local stale_before
      stale_before=$(epoch_to_iso "$(( $(now_epoch) - CI_STALE_DAYS * 86400 ))")

      local id wf url created
      while IFS=$'\t' read -r id wf url created; do
        [[ -n "$id" ]] || continue
        failed="${failed:+$failed, }${wf}"
        report="${report}"$'\n\n'"### workflow \`${wf}\` — failed ${created}"$'\n'"${url}"$'\n'"\`\`\`"$'\n'"$(gh run view "$id" -R "$repo" --log-failed 2>/dev/null | tail -n 40)"$'\n'"\`\`\`"
      done < <(jq -r --arg cut "$stale_before" \
                 '.[] | select(.conclusion == "failure" and .createdAt > $cut)
                      | [.databaseId, .name, .url, .createdAt] | @tsv' <<<"$latest" 2>/dev/null)

      # Stuck runs: no conclusion yet and started more than CI_STUCK_MIN ago.
      local age_cut created
      age_cut=$(( $(now_epoch) - CI_STUCK_MIN * 60 ))
      while IFS=$'\t' read -r created wf url; do
        [[ -n "$created" ]] || continue
        local started
        started=$(iso_to_epoch "$created")
        (( started > 0 && started < age_cut )) || continue
        failed="${failed:+$failed, }${wf} (stuck)"
        report="${report}"$'\n\n'"### workflow \`${wf}\` — stuck since ${created}"$'\n'"${url}"$'\n'"Queued/running for over ${CI_STUCK_MIN} minutes. Usually the self-hosted runner is offline, so the job is neither red nor green. Check the runner, or move the workflow to \`runs-on: ubuntu-latest\`."
      done < <(jq -r '.[] | select(.conclusion == null or .conclusion == "") | [.createdAt, .name, .url] | @tsv' <<<"$latest" 2>/dev/null)
    fi
  fi

  # ── B. Local lint on a new HEAD ─────────────────────────────────────────────
  # The HEAD marker is written only when the local checks pass, so a red repo
  # keeps being re-checked (and the task keeps being justified) until it's fixed.
  #
  # LINT ONLY — deliberately NOT the test suite. Lint is hermetic: static
  # analysis over the working tree, same verdict wherever it runs. A test suite
  # is not, and running one from a launchd-spawned daemon proved it: `pnpm test`
  # failed on 7 of 8 projects on the first real tick while passing interactively
  # in the same checkout, because vitest could not resolve its optional native
  # binding (`@rolldown/binding-darwin-arm64`) in the worker's environment.
  # Suites also want a database, env vars and generated clients that a
  # background daemon has no business providing. Every one of those failures is
  # an environment report, not a code report, and each filed a phantom
  # high-priority task. Tests belong where the environment is declared: the
  # project's own CI workflow (probe A watches it) and `fix-issues`, which runs
  # them in the foreground before it pushes.
  # ponytail: if a repo genuinely needs local tests here, give it a CI workflow.
  local sha_file="${STATE_DIR}/ci-watch.sha" head_sha prev_sha local_ran=false local_red=false
  head_sha=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo "")
  prev_sha=$(cat "$sha_file" 2>/dev/null || echo "")
  if [[ -n "$head_sha" && "$head_sha" != "$prev_sha" ]]; then
    local out
    # node_modules must already be there — installing deps is not this routine's
    # job, and a missing one would otherwise look like a code failure.
    if [[ -f "${PROJECT_ROOT}/package.json" && -d "${PROJECT_ROOT}/node_modules" ]] \
       && command -v pnpm &>/dev/null \
       && jq -e '.scripts.lint // empty' "${PROJECT_ROOT}/package.json" >/dev/null 2>&1; then
      local_ran=true
      if ! out=$( cd "$PROJECT_ROOT" && CI=1 pnpm lint 2>&1 ); then
        local_red=true
        failed="${failed:+$failed, }local lint"
        report="${report}"$'\n\n'"### local \`pnpm lint\` on \`${head_sha:0:8}\`"$'\n'"\`\`\`"$'\n'"$(tail -n 40 <<<"$out")"$'\n'"\`\`\`"
      fi
    fi
    if [[ -f "${PROJECT_ROOT}/pyproject.toml" || -f "${PROJECT_ROOT}/requirements.txt" ]] && command -v ruff &>/dev/null; then
      local_ran=true
      if ! out=$( cd "$PROJECT_ROOT" && ruff check . 2>&1 ); then
        local_red=true
        failed="${failed:+$failed, }local ruff"
        report="${report}"$'\n\n'"### local \`ruff check .\` on \`${head_sha:0:8}\`"$'\n'"\`\`\`"$'\n'"$(tail -n 40 <<<"$out")"$'\n'"\`\`\`"
      fi
    fi
    [[ "$local_red" == true ]] || echo "$head_sha" > "$sha_file"
  fi

  # ── File / update / close the task ──────────────────────────────────────────
  if [[ -n "$failed" ]]; then
    local n body
    body="Automated CI watch found failing checks: **${failed}**

- Branch: \`${branch}\`
- Commit: \`${head_sha:0:8}\`
${report}

---
_Filed by the \`ci-watch\` routine (local worker, no agent). \`fix-ci-issue\` picks this up — up to 3 retries, then a human._"
    n=$(ci_open_task "$title")
    if [[ -n "$n" ]]; then
      "$DF_BIN" task comment "$n" --body "Still failing: ${failed}" >/dev/null 2>&1 || true
      _CI_SUMMARY="ci red (${failed}) - task #${n} already open, commented"
    else
      "$DF_BIN" task create --title "$title" --body "$body" \
        --priority high --source ci --status approved >/dev/null 2>&1 || true
      _CI_SUMMARY="ci red (${failed}) - filed a new ci task"
    fi
    return 0
  fi

  # Green — close the branch's open CI task if there is one. Safe even when the
  # local half was skipped: `failed` is empty only when nothing we looked at was
  # red, and a still-red local check never writes the HEAD marker.
  local n
  n=$(ci_open_task "$title")
  if [[ -n "$n" ]]; then
    "$DF_BIN" task close "$n" >/dev/null 2>&1 || true
    _CI_SUMMARY="ci green again - closed task #${n}"
  elif [[ "$local_ran" == true ]]; then
    _CI_SUMMARY="ci ok - workflows green, local checks pass"
  else
    _CI_SUMMARY="ci ok - no failing or stuck workflow runs"
  fi
}

# ── Uptime cheap pre-flight ───────────────────────────────────────────────────
# A plain curl probe is enough to confirm a healthy site, so the (Sonnet) agent
# is only worth launching when the site is actually down/broken or the probe is
# inconclusive. uptime_preflight() returns 0 when the site is verifiably healthy
# (or merely slow/degraded) and has already written the metrics file here —
# the caller then SKIPS the agent. It returns 1 to escalate to the agent: site is
# down (agent files the critical issue) or the check can't decide (no site_url,
# no curl, DNS failure, …). Sets _UPTIME_SUMMARY / _UPTIME_ESCALATE_REASON.
_UPTIME_SUMMARY=""
_UPTIME_ESCALATE_REASON=""

# A green probe writes the widget's metrics file and nothing else — no doc, no
# repo change. A clean run leaves no trace; only a failure escalates to the agent.
uptime_write_metrics() {
  local url="$1" http_code="$2" latency_ms="$3" status="$4"

  mkdir -p "$METRICS_DIR"
  cat > "${METRICS_DIR}/uptime.json" <<EOF
{
  "url": "${url}",
  "httpCode": ${http_code},
  "latencyMs": ${latency_ms},
  "status": "${status}"
}
EOF
}

uptime_preflight() {
  _UPTIME_SUMMARY=""
  _UPTIME_ESCALATE_REASON=""

  command -v curl &>/dev/null || { _UPTIME_ESCALATE_REASON="curl not available"; return 1; }

  local url; url=$(darkflow_val "site_url" "")
  [[ -z "$url" ]] && { _UPTIME_ESCALATE_REASON="no site_url configured — agent will auto-discover"; return 1; }

  local host_only
  host_only=$(printf '%s' "$url" | sed -E 's#^https?://##; s#/.*$##; s#:.*$##')
  if ! { getent hosts "$host_only" || nslookup "$host_only" || host "$host_only"; } >/dev/null 2>&1; then
    _UPTIME_ESCALATE_REASON="DNS does not resolve for ${host_only}"
    return 1
  fi

  local body_file; body_file=$(mktemp)
  _CLEANUP_FILES+=("$body_file")
  local curl_w="" curl_rc=0
  curl_w=$(curl -sS -A "darkflow-uptime/1.0" -L --max-time 25 -o "$body_file" \
    -w 'http_code=%{http_code} time_total=%{time_total}' "$url" 2>/dev/null) || curl_rc=$?

  local rc=1   # default: escalate to the agent
  if [[ "$curl_rc" != "0" ]]; then
    _UPTIME_ESCALATE_REASON="curl failed (rc=${curl_rc}: connection/TLS/timeout)"
  else
    local http_code time_total
    http_code=$(sed -E 's/.*http_code=([0-9]+).*/\1/' <<< "$curl_w"); http_code=${http_code:-0}
    time_total=$(sed -E 's/.*time_total=([0-9.]+).*/\1/' <<< "$curl_w"); time_total=${time_total:-0}
    if [[ ! "$http_code" =~ ^(2|3)[0-9][0-9]$ ]]; then
      _UPTIME_ESCALATE_REASON="HTTP ${http_code}"
    else
      local body_size; body_size=$(wc -c < "$body_file" 2>/dev/null | tr -d ' '); body_size=${body_size:-0}
      if (( body_size < 200 )); then
        _UPTIME_ESCALATE_REASON="empty/short body (${body_size} bytes)"
      elif grep -qiE 'Bad Gateway|Gateway Time-?out|Service Unavailable|no (available )?server( available)?|Application error|This site can.?t be reached|Welcome to nginx' "$body_file"; then
        _UPTIME_ESCALATE_REASON="error marker in body"
      else
        local status="ok" latency_ms latency_s
        latency_ms=$(awk "BEGIN{printf \"%d\", ${time_total}*1000}")
        latency_s=$(awk "BEGIN{printf \"%.1f\", ${time_total}}")
        awk "BEGIN{exit !(${time_total} > 10)}" && status="degraded"
        uptime_write_metrics "$url" "$http_code" "$latency_ms" "$status"
        if [[ "$status" == "degraded" ]]; then
          _UPTIME_SUMMARY="uptime degraded — HTTP ${http_code}, slow ${latency_s}s"
        else
          _UPTIME_SUMMARY="uptime ok — HTTP ${http_code}, ${latency_s}s"
        fi
        rc=0
      fi
    fi
  fi

  rm -f "$body_file"
  _CLEANUP_FILES=("${_CLEANUP_FILES[@]/$body_file}")
  return $rc
}

# ── Mailbox cheap pre-flight ──────────────────────────────────────────────────
# The mailbox-check agent only has work when there is incoming mail to triage OR
# approved reply tasks to send. Both are cheap to count without an LLM: a
# read-only IMAP UNSEEN search (`fetch.py --count`) and a `df task list`.
# Returns 0 (caller SKIPS the agent) only when both are zero or the mailbox is
# not configured. Returns 1 to escalate: mail waiting, replies pending, or the
# probe can't decide (IMAP error, missing python3). Sets _MAILBOX_SUMMARY /
# _MAILBOX_ESCALATE_REASON, and _MAILBOX_CONFIG_ERROR when the routine is enabled
# but unconfigured (a misconfiguration the caller logs as an error).
_MAILBOX_SUMMARY=""
_MAILBOX_ESCALATE_REASON=""
_MAILBOX_CONFIG_ERROR=false

# Files a single needs-human task telling the human to configure (or disable)
# the mailbox routine. Deduped: never opens a second one while the first is open.
# Best-effort — silently degrades to just a summary when df/jq are unavailable.
# Sets _MAILBOX_SUMMARY.
mailbox_file_config_issue() {
  if [[ ! -x "$DF_BIN" ]] || ! command -v jq &>/dev/null; then
    _MAILBOX_SUMMARY="mailbox routine enabled but not configured (MAILBOX_* missing) — df/jq unavailable to file a needs-human task"
    return 0
  fi

  local existing
  existing=$("$DF_BIN" task list --state open --needs-human --source mailbox 2>/dev/null \
               | jq '[.[] | select(.title == "Configure mailbox integration (MAILBOX_* in .env)")] | length' 2>/dev/null || echo "")
  if [[ "$existing" =~ ^[1-9][0-9]*$ ]]; then
    _MAILBOX_SUMMARY="mailbox routine enabled but not configured — needs-human task already open"
    return 0
  fi

  local num
  num=$("$DF_BIN" task create \
    --title "Configure mailbox integration (MAILBOX_* in .env)" \
    --source mailbox --priority high --needs-human \
    --body "$(cat <<'BODY'
## Problem

The `mailbox-check` routine is scheduled and running, but `MAILBOX_IMAP_HOST` is
empty in `.env` — so it can neither read incoming mail nor send replies.
Every scheduled run is currently a no-op.

## Plan

- [ ] 1. Add the mailbox credentials to `.env` (git-ignored) in the project root:

      MAILBOX_IMAP_HOST=imap.example.com
      MAILBOX_IMAP_PORT=993
      MAILBOX_IMAP_USER=you@example.com
      MAILBOX_IMAP_PASSWORD=...
      MAILBOX_SMTP_HOST=smtp.example.com
      MAILBOX_SMTP_PORT=465
      MAILBOX_SMTP_USER=you@example.com
      MAILBOX_SMTP_PASSWORD=...

- [ ] 2. Or, if you don't want the mailbox integration at all, skip step 1 and toggle
      `mailbox-check` off in the Web UI (Settings → Routine schedule).

## Acceptance criteria

- [ ] `grep MAILBOX_IMAP_HOST .env` returns a non-empty value **or** `mailbox-check` is off in the Web UI
- [ ] The next `mailbox-check` run log no longer says "not configured"
BODY
)" 2>/dev/null) || num=""

  if [[ "$num" =~ ^[0-9]+$ ]]; then
    _MAILBOX_SUMMARY="mailbox routine enabled but not configured — filed needs-human task #${num}"
  else
    _MAILBOX_SUMMARY="mailbox routine enabled but not configured — failed to file needs-human task"
  fi
}

mailbox_preflight() {
  _MAILBOX_SUMMARY=""
  _MAILBOX_ESCALATE_REASON=""
  _MAILBOX_CONFIG_ERROR=false

  # 1. Approved reply tasks waiting to be sent (cheap; needs no IMAP).
  if [[ -x "$DF_BIN" ]] && command -v jq &>/dev/null; then
    local reply_count
    reply_count=$("$DF_BIN" task list --status approved --source mailbox --action reply --state open 2>/dev/null \
                    | jq 'length' 2>/dev/null || echo "")
    if [[ "$reply_count" =~ ^[1-9][0-9]*$ ]]; then
      _MAILBOX_ESCALATE_REASON="${reply_count} approved reply(ies) to send"
      return 1
    fi
  fi

  # 2. Probe the inbox in a subshell so sourced MAILBOX_* creds never leak into
  #    the dispatcher's environment or other routines.
  local probe
  probe=$(
    set +e
    set -a
    # Creds live in the project's main .env; .env.darkflow is a legacy fallback,
    # sourced first so .env wins when both define a key.
    [[ -f "${PROJECT_ROOT}/.env.darkflow" ]] && . "${PROJECT_ROOT}/.env.darkflow" 2>/dev/null
    [[ -f "${PROJECT_ROOT}/.env" ]] && . "${PROJECT_ROOT}/.env" 2>/dev/null
    set +a
    if [[ -z "${MAILBOX_IMAP_HOST:-}" ]]; then echo "UNCONFIGURED"; exit 0; fi
    command -v python3 >/dev/null 2>&1 || { echo "NOPY"; exit 0; }
    _fetch_py="${GLOBAL_DIR}/mailbox/fetch.py"
    [[ -f "$_fetch_py" ]] || _fetch_py="${PROJECT_ROOT}/.darkflow.d/mailbox/fetch.py"
    out=$(python3 "$_fetch_py" --count 2>/dev/null)
    if [[ "$out" =~ ^[0-9]+$ ]]; then echo "COUNT:${out}"; else echo "ERR"; fi
  )

  case "$probe" in
    UNCONFIGURED)
      # Routine is enabled but has no credentials — a misconfiguration the human
      # must fix. File a deduped needs-human issue and flag it as an error so the
      # caller logs it loudly. Still skip the agent (it can do nothing here).
      _MAILBOX_CONFIG_ERROR=true
      mailbox_file_config_issue
      return 0
      ;;
    NOPY)
      _MAILBOX_ESCALATE_REASON="python3 unavailable — cannot probe inbox"
      return 1
      ;;
    ERR)
      _MAILBOX_ESCALATE_REASON="IMAP unseen-count failed (server/credentials)"
      return 1
      ;;
    COUNT:0)
      _MAILBOX_SUMMARY="no new mail, no replies pending"
      return 0
      ;;
    COUNT:*)
      _MAILBOX_ESCALATE_REASON="${probe#COUNT:} new message(s) in inbox"
      return 1
      ;;
    *)
      _MAILBOX_ESCALATE_REASON="inconclusive mailbox probe"
      return 1
      ;;
  esac
}

# Mirror the untracked build inputs a fresh worktree lacks — `node_modules` dirs
# and `.env` files — from the project root into the worktree via symlinks, at the
# same relative paths. Symlinks (not copies) so builds resolve deps and routines
# read env vars without duplicating anything on disk. Covers monorepos (root +
# nested app/package dirs); node_modules and .git are pruned so we don't descend
# into them. ponytail: maxdepth 4 covers apps/*/  packages/*/; deepen if a project nests further.
link_worktree_inputs() {
  local src="$1" dst="$2" p rel
  while IFS= read -r p; do
    rel="${p#"$src"/}"
    mkdir -p "$dst/$(dirname "$rel")" 2>/dev/null || true
    [[ -e "$dst/$rel" ]] || ln -s "$p" "$dst/$rel" 2>/dev/null || true
  done < <(find "$src" -maxdepth 4 -name node_modules -type d -prune -print 2>/dev/null || true)
  while IFS= read -r p; do
    rel="${p#"$src"/}"
    mkdir -p "$dst/$(dirname "$rel")" 2>/dev/null || true
    [[ -e "$dst/$rel" ]] || ln -s "$p" "$dst/$rel" 2>/dev/null || true
  done < <(find "$src" -maxdepth 4 \( -name .git -o -name node_modules \) -prune -o -type f \( -name '.env' -o -name '.env.local' \) -print 2>/dev/null || true)
}

run_routine() {
  local name="$1" model="$2" permission_mode="$3" engine="${4:-claude}"
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

  # Both queue consumers can answer "nothing to do" from one `df task list`
  # call. Without this, an agent boots on every tick just to report an empty
  # queue — measured at ~$0.34 a run, and `fix-ci-issue` ticks every 15 min.
  if [[ "$name" == "fix-issues" || "$name" == "fix-ci-issue" ]] && [[ -x "$DF_BIN" ]]; then
    # Revive anything stuck in-progress before checking the queue, so a task
    # stranded by a crashed previous run is immediately eligible again.
    revive_stuck_issues
    # Count approved tasks this routine should act on. status is a single value,
    # so "approved" already excludes needs-human — no re-filter needed here.
    # The one exclusion left is action:reply — those are mailbox-owned
    # (mailbox-check sends the reply), not a code task for us.
    # fix-ci-issue only ever picks up source:ci, so it narrows server-side.
    local -a queue_args=(task list --status approved --state open)
    [[ "$name" == "fix-ci-issue" ]] && queue_args+=(--source ci)
    local approved_count
    approved_count=$("$DF_BIN" "${queue_args[@]}" 2>/dev/null \
                       | jq '[.[] | select(.action != "reply" and (.scheduledFor == null or .scheduledFor <= (now | todate)))] | length' 2>/dev/null || echo "")
    if [[ "$approved_count" == "0" || -z "$approved_count" ]]; then
      log "SKIP   ${name} — no actionable approved tasks"
      local skip_now skip_ts
      skip_now=$(now_epoch)
      write_state "$name" "$(( skip_now - skip_now % 60 ))"
      skip_ts=$(date -u +%FT%TZ)
      PENDING_LOGS+=("{\"routine\":\"${name}\",\"summary\":\"skipped ${name} — no approved tasks\",\"timestamp\":\"${skip_ts}\"}")
      return 0
    fi
  fi

  # CI watch is fully mechanical — it polls GitHub Actions, runs the local checks
  # and files the `source:ci` task itself. There is no agent and no command file,
  # so it never takes a concurrency slot and never costs a token.
  if [[ "$name" == "ci-watch" ]]; then
    ci_watch
    local cw_now; cw_now=$(now_epoch)
    write_state "$name" "$(( cw_now - cw_now % 60 ))"
    local cw_ts; cw_ts=$(date -u +%FT%TZ)
    PENDING_LOGS+=("{\"routine\":\"${name}\",\"summary\":\"${_CI_SUMMARY} (no agent run)\",\"timestamp\":\"${cw_ts}\"}")
    log "DONE   ${name} — ${_CI_SUMMARY} (no agent run)"
    return 0
  fi

  # Housekeeping is the same shape: pure bookkeeping, no reasoning, so it runs in
  # the worker at zero token cost instead of as an agent routine (H).
  if [[ "$name" == "housekeeping" ]]; then
    housekeeping
    local hk_now; hk_now=$(now_epoch)
    write_state "$name" "$(( hk_now - hk_now % 60 ))"
    local hk_ts; hk_ts=$(date -u +%FT%TZ)
    PENDING_LOGS+=("{\"routine\":\"${name}\",\"summary\":\"${_HK_SUMMARY} (no agent run)\",\"timestamp\":\"${hk_ts}\"}")
    log "DONE   ${name} — ${_HK_SUMMARY} (no agent run)"
    return 0
  fi

  # Uptime cheap pre-flight: a curl probe confirms a healthy site without paying
  # for an agent run. Only escalate to the (Sonnet) agent when the site is down/
  # broken or the probe can't decide — that's when its diagnosis + auto-approved
  # critical issue is actually needed. Runs before semaphore_acquire so a healthy
  # skip never consumes a concurrency slot.
  if [[ "$name" == "uptime-check" ]]; then
    if uptime_preflight; then
      local up_now; up_now=$(now_epoch)
      write_state "$name" "$(( up_now - up_now % 60 ))"
      local up_ts; up_ts=$(date -u +%FT%TZ)
      PENDING_LOGS+=("{\"routine\":\"${name}\",\"summary\":\"${_UPTIME_SUMMARY} (cheap probe, no agent run)\",\"timestamp\":\"${up_ts}\"}")
      log "SKIP   ${name} — ${_UPTIME_SUMMARY} (cheap probe, no agent run)"
      return 0
    fi
    log "ESCALATE ${name} — ${_UPTIME_ESCALATE_REASON}; launching agent for diagnosis"
  fi

  # Mailbox cheap pre-flight: skip the agent when there's no incoming mail and no
  # approved replies to send. Runs before semaphore_acquire so an idle skip never
  # consumes a concurrency slot.
  if [[ "$name" == "mailbox-check" ]]; then
    if mailbox_preflight; then
      local mb_now; mb_now=$(now_epoch)
      write_state "$name" "$(( mb_now - mb_now % 60 ))"
      local mb_ts; mb_ts=$(date -u +%FT%TZ)
      PENDING_LOGS+=("{\"routine\":\"${name}\",\"summary\":\"${_MAILBOX_SUMMARY} (cheap probe, no agent run)\",\"timestamp\":\"${mb_ts}\"}")
      if $_MAILBOX_CONFIG_ERROR; then
        log "ERROR  ${name} — ${_MAILBOX_SUMMARY}"
      else
        log "SKIP   ${name} — ${_MAILBOX_SUMMARY} (cheap probe, no agent run)"
      fi
      return 0
    fi
    log "ESCALATE ${name} — ${_MAILBOX_ESCALATE_REASON}; launching agent"
  fi

  if ! semaphore_acquire; then
    local _max_slots; _max_slots=$(darkflow_val "max_concurrent" "3")
    log "DEFER  ${name} — all ${_max_slots} global slots busy, will retry next cycle"
    return 0
  fi

  log "START  ${name} (engine=${engine}, model=${model}, perm=${permission_mode})"

  # Refresh config from the Web UI right before invoking the agent so darkflow_val()
  # reads below see the freshest values. Silently keeps the cached JSON if the
  # server is offline.
  fetch_project_config 2>/dev/null || true

  send_heartbeat "running" "$name"
  start_heartbeat_loop "$name"

  local agent_output _stream_file
  local _cost_json="" _tokens_json=""   # JSON fragments for PENDING_LOGS (empty = omit)
  # Persist the engine + model used for this run so the web UI can break spend
  # down by command. We prefix the model name with the engine ("claude" or
  # "codex") so the analytics page distinguishes e.g. claude:sonnet from
  # codex:gpt-5 instead of collapsing same-named models or showing "unknown".
  local _model_json=""
  [[ -n "$model" ]] && _model_json=",\"model\":\"${engine}:${model}\""
  _stream_file=$(mktemp)
  _CLEANUP_FILES+=("$_stream_file")

  # Optional worktree isolation: run the engine in a throwaway `git worktree` so
  # parallel routines on the same project don't fight over the working tree. A
  # worktree checks out tracked files only, so we symlink the untracked build
  # inputs (node_modules, .env) back in. Opt-in per project via config
  # `worktree: true`; default keeps the historical in-place behavior. The dir is
  # torn down right after the run below, and the EXIT trap is a backstop on crash.
  local _run_dir="$PROJECT_ROOT"
  if [[ "$(darkflow_val worktree false)" == true ]]; then
    local _wt; _wt=$(mktemp -d "${TMPDIR:-/tmp}/df-wt-${name}-XXXXXX")
    if git -C "$PROJECT_ROOT" worktree add --detach "$_wt" HEAD >/dev/null 2>&1; then
      _CLEANUP_WORKTREES+=("$_wt")
      link_worktree_inputs "$PROJECT_ROOT" "$_wt"
      _run_dir="$_wt"
      log "WORKTREE ${name} — isolated run in ${_wt}"
    else
      rmdir "$_wt" 2>/dev/null || true
      log "WARN   ${name} — worktree add failed, running in project root"
    fi
  fi

  if [[ "$engine" == "codex" ]]; then
    # Codex has no /darkflow:<name> slash command, so feed the routine's command
    # markdown directly as the prompt (same file Claude resolves the command
    # from). Codex has no per-tool permission allowlist — map every permission
    # mode to autonomous, no-prompt execution. `codex exec` is already
    # non-interactive (the old `--ask-for-approval never` flag was removed from
    # the exec subcommand in newer Codex CLIs). Darkflow routines push to git and
    # call gh, which the workspace-write sandbox blocks (no network), so we run
    # with the externally-sandboxed bypass — equivalent to Claude's bypassPermissions.
    # Codex's stdout is already human-readable, so we store it verbatim.
    local _cmd_file="${USER_CMD_DIR}/${name}.md"
    if [[ -f "$_cmd_file" ]]; then
      ( cd "$_run_dir" && run_in_pgid codex exec --model "${model}" \
          --dangerously-bypass-approvals-and-sandbox \
          "$(cat "$_cmd_file")" ) > "$_stream_file" || exit_code=$?
    else
      log "ERROR  ${name} — engine=codex but command file missing: ${_cmd_file}"
      exit_code=1
    fi
    agent_output=$(cat "$_stream_file") || agent_output=""
  else
    # --output-format json returns a single result object carrying the final
    # assistant text (.result) plus usage metrics (.total_cost_usd, .usage.*).
    # We persist cost + total tokens per run so the web UI can show which
    # routine consumes the most of the account's limits.
    ( cd "$_run_dir" && run_in_pgid claude -p "/darkflow:${name}" --model "${model}" "${perm_args[@]}" \
        --output-format json ) > "$_stream_file" || exit_code=$?
    local _raw; _raw=$(cat "$_stream_file") || _raw=""
    if jq -e . >/dev/null 2>&1 <<< "$_raw"; then
      agent_output=$(jq -r '.result // ""' <<< "$_raw")
      local _cost _tokens
      _cost=$(jq -r '.total_cost_usd // empty' <<< "$_raw")
      _tokens=$(jq -r '[.usage.input_tokens, .usage.output_tokens, .usage.cache_creation_input_tokens, .usage.cache_read_input_tokens] | map(select(. != null)) | add // empty' <<< "$_raw")
      [[ -n "$_cost" ]]   && _cost_json=",\"costUsd\":${_cost}"
      [[ -n "$_tokens" ]] && _tokens_json=",\"totalTokens\":${_tokens}"
    else
      # Non-JSON stdout (crash/partial) — keep raw text, leave metrics empty.
      agent_output="$_raw"
    fi
  fi
  rm -f "$_stream_file"
  _CLEANUP_FILES=("${_CLEANUP_FILES[@]/$_stream_file}")
  semaphore_release

  # Tear down the throwaway worktree now that the run is done. Symlinked
  # node_modules/.env point at the real project files; `worktree remove` unlinks
  # them without touching the targets. The EXIT trap still covers a crash above.
  if [[ "$_run_dir" != "$PROJECT_ROOT" ]]; then
    git -C "$PROJECT_ROOT" worktree remove --force "$_run_dir" 2>/dev/null || rm -rf "$_run_dir"
    _CLEANUP_WORKTREES=("${_CLEANUP_WORKTREES[@]/$_run_dir}")
  fi

  stop_heartbeat_loop
  send_heartbeat "idle"

  now=$(now_epoch)
  write_state "$name" "$(( now - now % 60 ))"

  local status_str="ok"
  [[ "$exit_code" != "0" ]] && status_str="exit:${exit_code}"
  log "DONE   ${name} (${status_str})"

  # A crashed fix-issues run leaves its issue stuck in status:in-progress with no
  # PR. Recover it now instead of waiting the full 1h auto-revive window.
  if [[ "$name" == "fix-issues" && "$exit_code" != "0" ]]; then
    recover_crashed_fix_issues
  fi
  local ts; ts=$(date -u +%FT%TZ)
  local output_json
  output_json=$(jq -Rsa '.' <<< "$agent_output")
  PENDING_LOGS+=("{\"routine\":\"${name}\",\"summary\":\"ran ${name} — ${status_str}\",\"output\":${output_json}${_model_json}${_cost_json}${_tokens_json},\"timestamp\":\"${ts}\"}")

  return $exit_code
}

# ── Auto-revive stuck in-progress tasks ───────────────────────────────────────
# If a task has been in status "in-progress" for >1h (per updatedAt), treat it
# as crashed/stalled and set it back to "approved" so the next fix-issues run
# picks it up again.

STUCK_IN_PROGRESS_THRESHOLD=3600

revive_stuck_issues() {
  [[ -x "$DF_BIN" ]] || return 0
  command -v jq &>/dev/null || return 0

  local stuck_json now_secs threshold_iso
  stuck_json=$("$DF_BIN" task list --status in-progress --state open 2>/dev/null) || return 0
  [[ -z "$stuck_json" || "$stuck_json" == "[]" ]] && return 0

  now_secs=$(now_epoch)
  threshold_iso=$(epoch_fmt $(( now_secs - STUCK_IN_PROGRESS_THRESHOLD )) "%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || return 0

  local stuck
  stuck=$(echo "$stuck_json" | jq -r --arg cutoff "$threshold_iso" '.[] | select(.updatedAt < $cutoff) | .number' 2>/dev/null) || return 0
  [[ -z "$stuck" ]] && return 0

  local num
  while IFS= read -r num; do
    [[ -z "$num" ]] && continue
    if "$DF_BIN" task set-status "$num" approved >/dev/null 2>&1; then
      log "REVIVE #${num} stuck >1h in-progress → approved"
    else
      log "REVIVE #${num} failed to revive"
    fi
  done <<< "$stuck"
}

# ── Recover a task stranded by a crashed fix-issues run ───────────────────────
# When a fix-issues agent dies mid-run (e.g. the Claude API drops the socket),
# it has usually already set status "in-progress" and posted a "starting work"
# comment, but never landed the fix. The 1h auto-revive (revive_stuck_issues)
# eventually rescues it, but that's an hour of the task looking "in progress"
# with nothing happening. This runs immediately after a non-zero fix-issues exit
# and reverts every open in-progress task back to approved. fix-issues is
# single-instance, so a crash strands exactly the task it was holding.
recover_crashed_fix_issues() {
  [[ -x "$DF_BIN" ]] || return 0
  command -v jq &>/dev/null || return 0

  local in_prog
  in_prog=$("$DF_BIN" task list --status in-progress --state open 2>/dev/null | jq -r '.[].number' 2>/dev/null) || return 0
  [[ -z "$in_prog" ]] && return 0

  local num
  while IFS= read -r num; do
    [[ -z "$num" ]] && continue
    if "$DF_BIN" task set-status "$num" approved >/dev/null 2>&1; then
      log "RECOVER #${num} fix-issues crashed before landing → back to approved"
    fi
  done <<< "$in_prog"
}

# ── Housekeeping (H) ──────────────────────────────────────────────────────────
# One daily bookkeeping pass, in bash, no agent and no tokens — the same shape as
# ci-watch. Nothing here needs reasoning: it is three mechanical repairs that
# would otherwise need two agent routines.
#
#   stuck tasks   in-progress and untouched for >4h  → comment + back to approved
#   stuck HEAD    checkout left on a feature branch  → back to the base branch
#   worktrees     prune stale ones, delete merged branches
#
# The "is the checkout dirty?" test deliberately IGNORES docs/logs/ and
# docs/state/. Under the `pr` strategy audits commit nothing (A7) — their files
# sit there waiting for the next PR. Without the exemption the whole pass would be
# dead on arrival: a project with no open tasks opens no PR for weeks, so the log
# stays uncommitted, so the checkout always looks dirty, so nothing is ever
# recovered — exactly when recovery is needed.

HOUSEKEEPING_STUCK_THRESHOLD=14400   # 4h

# Anything uncommitted that is NOT an audit's pending output. Prints the paths.
#
# --untracked-files=all is load-bearing: the default collapses an untracked
# directory to "docs/", which never matches the docs/logs/ exemption below, so a
# brand-new daily log would read as unexpected work and block every repair.
_hk_unexpected_changes() {
  git status --porcelain --untracked-files=all 2>/dev/null \
    | sed 's/^...//; s/^.* -> //; s/^"//; s/"$//' \
    | grep -v -E '^docs/(logs|state)/' || true
}

housekeeping() {
  _HK_SUMMARY=""
  local -a done_items=()

  # ── 1. Stuck tasks ──────────────────────────────────────────────────────────
  if [[ -x "$DF_BIN" ]] && command -v jq &>/dev/null; then
    local stuck_json cutoff stuck num n=0
    stuck_json=$("$DF_BIN" task list --status in-progress --state open 2>/dev/null || echo "[]")
    if [[ -n "$stuck_json" && "$stuck_json" != "[]" ]]; then
      cutoff=$(epoch_fmt $(( $(now_epoch) - HOUSEKEEPING_STUCK_THRESHOLD )) "%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
      if [[ -n "$cutoff" ]]; then
        stuck=$(echo "$stuck_json" | jq -r --arg c "$cutoff" '.[] | select(.updatedAt < $c) | .number' 2>/dev/null || echo "")
        while IFS= read -r num; do
          [[ -z "$num" ]] && continue
          "$DF_BIN" task comment "$num" --body \
            "Housekeeping: in-progress for over 4h with no activity — the session that took it is gone. Back to approved." >/dev/null 2>&1
          if "$DF_BIN" task set-status "$num" approved >/dev/null 2>&1; then
            log "HOUSE  #${num} stuck >4h → approved"
            n=$(( n + 1 ))
          fi
        done <<< "$stuck"
      fi
    fi
    [[ $n -gt 0 ]] && done_items+=("${n} stuck task(s) revived")
  fi

  git rev-parse --git-dir &>/dev/null || {
    _HK_SUMMARY="${done_items[*]:-nothing to do} (not a git repo — skipped checkout jobs)"
    return 0
  }

  # ── 2. Stuck HEAD ───────────────────────────────────────────────────────────
  # fix-issues is supposed to switch back when it finishes, so HEAD sitting on a
  # feature branch means a session was killed. Every A7 write after that lands on
  # the wrong branch, so this is the repair that makes the rest of them safe.
  local base cur
  base=$(darkflow_val "branch" "main")
  cur=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ -n "$cur" && "$cur" != "$base" && "$cur" != "HEAD" ]]; then
    local dirty; dirty=$(_hk_unexpected_changes)
    if [[ -n "$dirty" ]]; then
      log "HOUSE  HEAD on '${cur}' with uncommitted work — left alone:"
      log "HOUSE    $(echo "$dirty" | tr '\n' ' ')"
      done_items+=("HEAD on '${cur}' left alone (uncommitted work)")
    elif git checkout "$base" >/dev/null 2>&1; then
      log "HOUSE  HEAD was on '${cur}' → back to ${base}"
      done_items+=("HEAD recovered from '${cur}'")
    else
      log "HOUSE  could not switch from '${cur}' to ${base}"
    fi
  fi

  # ── 3. Worktrees and merged branches ────────────────────────────────────────
  git worktree prune 2>/dev/null || true
  local br merged=0
  while IFS= read -r br; do
    br="${br#"${br%%[![:space:]]*}"}"
    [[ -z "$br" || "$br" == "$base" || "$br" == "$cur" ]] && continue
    if git branch -d "$br" >/dev/null 2>&1; then
      log "HOUSE  deleted merged branch ${br}"
      merged=$(( merged + 1 ))
    fi
  done < <(git branch --merged "$base" --format '%(refname:short)' 2>/dev/null || true)
  [[ $merged -gt 0 ]] && done_items+=("${merged} merged branch(es) deleted")

  # ── 4. Report anything else left uncommitted, and leave it alone ────────────
  local leftover; leftover=$(_hk_unexpected_changes)
  if [[ -n "$leftover" ]]; then
    log "HOUSE  uncommitted changes outside docs/logs and docs/state — leaving them:"
    log "HOUSE    $(echo "$leftover" | tr '\n' ' ')"
    done_items+=("uncommitted work reported, untouched")
  fi

  if [[ ${#done_items[@]} -eq 0 ]]; then
    _HK_SUMMARY="nothing to clean up"
  else
    # "${arr[*]}" joins on IFS's FIRST character only, so a two-character
    # separator has to be built by hand.
    printf -v _HK_SUMMARY '%s; ' "${done_items[@]}"
    _HK_SUMMARY="${_HK_SUMMARY%; }"
  fi
  return 0
}

# ── Webapp sync ───────────────────────────────────────────────────────────────
# Called after any routine actually ran. POSTs project metadata (analytics,
# security/architecture rollups, logs, routine schedule, commits, alerts) to the
# Dark Flow webapp API (/api/ingest) using the webapp_url from ~/.darkflow/config.
# Tasks themselves are NOT part of this payload — routines write them directly
# via `df` (see /api/tasks/*), so there is nothing to mirror or reconcile here.

sync_webapp() {
  local webapp_url
  webapp_url=$(global_val "webapp_url" "")
  if [[ -z "$webapp_url" ]]; then
    log "WEBAPP skipped (webapp_url not set in ~/.darkflow/config)"
    PENDING_LOGS=()
    return 0
  fi

  if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
    log "WEBAPP skipped (jq or curl missing)"
    PENDING_LOGS=()
    return 0
  fi

  local repo_url now_iso
  repo_url=$(_get_repo_url_cached)
  if [[ -z "$repo_url" ]]; then
    log "WEBAPP skipped (could not determine repo URL)"
    PENDING_LOGS=()
    return 0
  fi

  now_iso=$(date -u +%FT%TZ)

  # Read project metadata from the fetched config JSON
  local proj_name proj_domain proj_branch proj_lang proj_merge proj_modules proj_version
  proj_name=$(darkflow_val "name" "$(basename "$PROJECT_ROOT")")
  proj_domain=$(darkflow_val "domain" "")
  proj_branch=$(darkflow_val "branch" "main")
  proj_lang=$(darkflow_val "language" "English")
  proj_merge=$(darkflow_val "merge_strategy" "pr")
  proj_modules=$(darkflow_val "modules" "")
  proj_version=$(darkflow_val "version" "")

  # Build modules JSON array (comma-separated string → JSON array)
  local modules_json
  modules_json=$(echo "$proj_modules" | jq -Rc 'split(",") | map(select(length > 0))')

  # Build optional sections from metrics files
  local analytics_json="null" security_json="null" architecture_json="null"
  [[ -f "${METRICS_DIR}/analytics.json" ]]     && analytics_json=$(cat "${METRICS_DIR}/analytics.json")
  [[ -f "${METRICS_DIR}/security.json" ]]      && security_json=$(cat "${METRICS_DIR}/security.json")
  [[ -f "${METRICS_DIR}/architecture.json" ]]  && architecture_json=$(cat "${METRICS_DIR}/architecture.json")

  # Read attention items from .darkflow.d/attention.json (written by routines/scripts)
  local alerts_json="[]"
  if [[ -f "${DARKFLOW_D}/attention.json" ]]; then
    alerts_json=$(jq -c '.' "${DARKFLOW_D}/attention.json" 2>/dev/null || echo "[]")
  fi

  # Build logs JSON array from accumulated PENDING_LOGS
  local logs_json="[]"
  if [[ "${#PENDING_LOGS[@]}" -gt 0 ]]; then
    logs_json=$(printf '%s\n' "${PENDING_LOGS[@]}" | jq -sc '.')
  fi

  # Routine snapshot: pass the fetched schedule straight through (the Web UI is the
  # source of truth; ingest only seeds RoutineConfig when a project has none yet).
  local routines_json="[]"
  if [[ -f "$PROJECT_CFG_JSON" ]]; then
    routines_json=$(jq -c '.routines // []' "$PROJECT_CFG_JSON" 2>/dev/null || echo "[]")
  fi

  # Last 50 commits via git log; tab-separated to dodge quoting issues in messages.
  local commits_json="[]"
  if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
    local commit_base="${repo_url%.git}"
    commits_json=$(git log -n 50 --pretty=format:'%H%x09%cI%x09%an%x09%ae%x09%s' 2>/dev/null \
      | jq -Rsc --arg base "$commit_base" '
          split("\n") | map(select(length > 0))
          | map(split("\t") | {
              sha:         .[0],
              committedAt: .[1],
              author:      .[2],
              email:       .[3],
              message:     .[4],
              url:         ($base + "/commit/" + .[0])
            })
        ' 2>/dev/null) || commits_json="[]"
    [[ -z "$commits_json" ]] && commits_json="[]"
  fi

  # Assemble payload. The log/commit arrays can be sizeable, so they go into a
  # temp file read by jq via --slurpfile — passing them as --argjson argv could
  # overflow ARG_MAX ("jq: Argument list too long") and silently drop the sync.
  # Only the small scalar fields stay on the command line. Each *_json var is
  # already valid JSON, so concatenating them builds the context object without
  # another jq invocation.
  local tmp_ctx
  tmp_ctx=$(mktemp "${TMPDIR:-/tmp}/darkflow-ctx.XXXXXX") || {
    log "WEBAPP skipped (mktemp failed)"; PENDING_LOGS=(); return 0; }
  {
    printf '{"modules":%s'      "$modules_json"
    printf ',"analytics":%s'    "$analytics_json"
    printf ',"security":%s'     "$security_json"
    printf ',"architecture":%s' "$architecture_json"
    printf ',"logs":%s'         "$logs_json"
    printf ',"routines":%s'     "$routines_json"
    printf ',"commits":%s'      "$commits_json"
    printf ',"alerts":%s}'      "$alerts_json"
  } > "$tmp_ctx"

  local payload
  payload=$(jq -n \
    --arg repoUrl    "$repo_url" \
    --arg name       "$proj_name" \
    --arg localPath  "$PROJECT_ROOT" \
    --arg domain     "$proj_domain" \
    --arg branch     "$proj_branch" \
    --arg language   "$proj_lang" \
    --arg merge      "$proj_merge" \
    --arg version    "$proj_version" \
    --slurpfile ctx "$tmp_ctx" \
    '($ctx[0]) as $c | {
      repoUrl:          $repoUrl,
      name:             $name,
      localPath:        $localPath,
      domain:           $domain,
      branch:           $branch,
      language:         $language,
      mergeStrategy:    $merge,
      modules:          $c.modules,
      darkflowVersion:  $version,
      logs:             $c.logs,
      routines:         $c.routines,
      commits:          $c.commits,
      alerts:           $c.alerts
    }
    | if $c.analytics    != null then . + {analytics: $c.analytics}       else . end
    | if $c.security     != null then . + {security: $c.security}         else . end
    | if $c.architecture != null then . + {architecture: $c.architecture} else . end
    ')
  local jq_rc=$?
  rm -f "$tmp_ctx"
  if (( jq_rc != 0 )) || [[ -z "$payload" ]]; then
    log "WEBAPP skipped (payload build error)"; PENDING_LOGS=(); return 0
  fi

  # POST the body via stdin (--data-binary @-) so a large payload can't overflow
  # ARG_MAX on the curl command line either.
  local http_code
  http_code=$(printf '%s' "$payload" | curl -fsS -o /dev/null -w "%{http_code}" \
    -X POST "${webapp_url}/api/ingest" \
    -H "Content-Type: application/json" \
    --data-binary @- 2>/dev/null) || true

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
# The watch loop sends "idle" every 30 s even when no routine runs.

_REPO_URL_CACHE=""

# Normalize any git remote spelling to the canonical https URL with no .git suffix
# and no embedded credentials — the exact form `gh repo view --json url` returns,
# which is what projects are registered under in the Web UI.
_normalize_repo_url() {
  local u="$1"
  u="${u%.git}"                       # strip trailing .git
  if [[ "$u" == git@*:* ]]; then      # git@host:owner/repo → https://host/owner/repo
    local host="${u#git@}"; host="${host%%:*}"
    u="https://${host}/${u#*:}"
  elif [[ "$u" == ssh://* ]]; then    # ssh://git@host/owner/repo → https://host/owner/repo
    u="${u#ssh://}"; u="https://${u#git@}"
  fi
  u="${u/https:\/\/*@/https:\/\/}"    # strip https://user:tok@ credentials
  printf '%s' "$u"
}

# Resolve the repo URL from the local git remote (zero API cost) and fall back to
# `gh repo view` (GraphQL) only when there's no usable remote. This keeps the
# worker resolving repos even when the GraphQL rate limit is exhausted — otherwise
# every project gets skipped and the worker goes dark.
_get_repo_url_cached() {
  if [[ -z "$_REPO_URL_CACHE" ]]; then
    local remote
    remote=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ -n "$remote" ]]; then
      _REPO_URL_CACHE=$(_normalize_repo_url "$remote")
    else
      _REPO_URL_CACHE=$(gh repo view --json url -q .url 2>/dev/null || echo "")
    fi
  fi
  echo "$_REPO_URL_CACHE"
}

send_heartbeat() {
  local status="$1" routine="${2:-}"
  local webapp_url
  webapp_url=$(global_val "webapp_url" "")
  [[ -z "$webapp_url" ]] && return 0
  ! command -v curl &>/dev/null && return 0

  local repo_url
  repo_url=$(_get_repo_url_cached)
  [[ -z "$repo_url" ]] && return 0

  local proj_name proj_hb_version routine_field="null" config_field="null"
  proj_name=$(darkflow_val "name" "$(basename "$PROJECT_ROOT")")
  proj_hb_version=$(darkflow_val "version" "")
  [[ -n "$routine" ]] && routine_field="\"${routine}\""

  # The worker now reads config straight from the Web UI every tick, so whenever a
  # fresh config JSON exists the project is, by definition, up to date as of now.
  [[ -f "$PROJECT_CFG_JSON" ]] && config_field="\"$(date -u +%FT%TZ)\""

  curl -fsS -o /dev/null -m 5 \
    -X POST "${webapp_url}/api/worker/heartbeat" \
    -H "Content-Type: application/json" \
    -d "{\"repoUrl\":\"${repo_url}\",\"status\":\"${status}\",\"routine\":${routine_field},\"name\":\"${proj_name}\",\"darkflowVersion\":\"${proj_hb_version}\",\"configSyncedAt\":${config_field}}" \
    2>/dev/null || true
}

HEARTBEAT_PID=""

start_heartbeat_loop() {
  local routine="$1"
  (
    # Ignore INT so Ctrl-C during a dispatch doesn't kill the heartbeat;
    # TERM stays catchable so stop_heartbeat_loop can reap it cleanly.
    trap '' INT
    while true; do
      sleep 30
      send_heartbeat "running" "$routine"
    done
  ) &
  HEARTBEAT_PID=$!
}

stop_heartbeat_loop() {
  if [[ -n "${HEARTBEAT_PID:-}" ]]; then
    kill -TERM "$HEARTBEAT_PID" 2>/dev/null || true
    # Belt-and-suspenders: if it's wedged, SIGKILL can't be trapped/ignored.
    kill -KILL "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
    HEARTBEAT_PID=""
  fi
}

# Self-update is intentionally NOT automatic. With a single global worker there is
# only one artifact to update, so updates are done explicitly — either by running
# the installer (`install.sh --self-update`) or the `/darkflow:self-update` slash
# command. This keeps the unattended worker from ever fetching and executing an
# installer on its own (the riskiest path) and removes a whole class of CDN-lag
# failure modes.

# ── Project discovery ─────────────────────────────────────────────────────────
# The global worker learns which projects to service — and where they live on
# disk — from the web UI. Each project the user has given a Local path is
# returned by GET /api/projects. Prints one absolute path per line.

fetch_projects() {
  local webapp_url resp
  webapp_url=$(global_val "webapp_url" "")
  [[ -z "$webapp_url" ]] && return 0
  command -v curl &>/dev/null || return 0
  command -v jq   &>/dev/null || return 0
  resp=$(curl -fsS -m 10 "${webapp_url}/api/projects" 2>/dev/null) || return 0
  [[ "${resp:0:1}" == "[" ]] || return 0
  jq -r '.[].localPath | select(. != null and . != "")' <<< "$resp" 2>/dev/null || true
}

# The cwd-scoped subcommands operate on the git repo containing the current dir.
detect_project_from_cwd() {
  local top
  top=$(git rev-parse --show-toplevel 2>/dev/null) && [[ -n "$top" ]] && { echo "$top"; return 0; }
  return 1
}

# Resolves the cwd's project and enters it, or aborts with guidance. set_project
# fetches the project's config from the Web UI — failure means it isn't a git repo
# or isn't registered there.
require_cwd_project() {
  local p
  if ! p=$(detect_project_from_cwd); then
    echo "darkflow-run: not inside a git repository (${PWD})." >&2
    echo "  cd into a registered project, or run the global worker with no arguments." >&2
    exit 1
  fi
  set_project "$p" || {
    echo "darkflow-run: '${p}' is not registered in the Web UI (or the server is unreachable)." >&2
    echo "  Add it in the Dark Flow dashboard, then retry." >&2
    exit 1
  }
}

# ── Mode: list ────────────────────────────────────────────────────────────────

mode_list() {
  local name cron enabled last_run last_str proj_active
  proj_active=$(jq -r '.active | select(. != null)' "$PROJECT_CFG_JSON" 2>/dev/null)
  [[ "$proj_active" == "false" ]] && echo "PROJECT: paused (Settings → Routines → \"Routines active\" is off)"
  printf "%-25s %-20s %-9s %s\n" "ROUTINE" "CRON" "ENABLED" "LAST RUN"
  printf "%-25s %-20s %-9s %s\n" "-------" "----" "-------" "--------"
  while IFS= read -r name; do
    cron=$(routine_val "$name" cron "")
    enabled=$(routine_val "$name" enabled "true")
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
  local now name cron enabled model permission_mode engine last_run floor prev

  now=$(now_epoch)

  rotate_log

  # Project-level master switch (Settings → Routines → "Routines active"). Read
  # with a null-only filter, NOT the `// empty` path `darkflow_val()` uses —
  # jq's `//` treats `false` as empty too, which would silently re-enable a
  # switched-off project. Same trap the `enabled` per-routine field avoids
  # below via `select(. != null)`.
  local proj_active
  proj_active=$(jq -r '.active | select(. != null)' "$PROJECT_CFG_JSON" 2>/dev/null)
  if [[ "$proj_active" == "false" ]]; then
    log "DISPATCH skipped — project routines are switched off (Settings → Routines)"
    return 0
  fi

  local any_due=false
  while IFS= read -r name; do
    cron=$(routine_val "$name" cron "")
    enabled=$(routine_val "$name" enabled "true")

    if [[ "$enabled" != "true" || -z "$cron" ]]; then
      continue
    fi

    # Skip routines Dark Flow no longer ships (no command file). preflight already
    # warned; running them would only fail. They clear on the next config refresh.
    # ci-watch and housekeeping are exempt: pure bash in-process, no command file.
    if [[ "$name" != "ci-watch" && "$name" != "housekeeping" && ! -f "${USER_CMD_DIR}/${name}.md" ]]; then
      continue
    fi

    model=$(routine_val "$name" model "sonnet")
    permission_mode=$(routine_val "$name" permissionMode "bypassPermissions")
    engine=$(routine_val "$name" engine "claude")

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
      echo "  [due] ${name}  cron='${cron}'  engine=${engine}  model=${model}"
    else
      run_routine "$name" "$model" "$permission_mode" "$engine" || true
    fi

  done < <(routine_names)

  if [[ "$dry_run" == true && "$any_due" == false ]]; then
    echo "  No routines are due at this time."
  fi
}

# ── Mode: manual ──────────────────────────────────────────────────────────────

mode_manual() {
  local name="$1"
  local model permission_mode engine

  if ! routine_exists "$name"; then
    echo "darkflow-run: unknown routine '${name}'" >&2
    echo "Known routines: $(routine_names | tr '\n' ' ')" >&2
    exit 1
  fi

  # ci-watch and housekeeping are exempt: pure bash in-process, no command file.
  if [[ "$name" != "ci-watch" && "$name" != "housekeeping" && ! -f "${USER_CMD_DIR}/${name}.md" ]]; then
    echo "darkflow-run: routine '${name}' has no command file: ~/.claude/commands/darkflow/${name}.md" >&2
    echo "  Dark Flow may have removed it, or it's disabled for this project in the Web UI." >&2
    exit 1
  fi

  model=$(routine_val "$name" model "sonnet")
  permission_mode=$(routine_val "$name" permissionMode "bypassPermissions")
  engine=$(routine_val "$name" engine "claude")

  log "MANUAL ${name}"
  run_routine "$name" "$model" "$permission_mode" "$engine"
  sync_webapp
}

# ── Mode: watch ───────────────────────────────────────────────────────────────

# Global orchestration loop: one worker, every project. Each tick discovers the
# registered projects from the web UI and runs a dispatch pass for each. The
# global concurrency semaphore (/tmp/darkflow-slots) still caps how many agent
# sessions run at once across all projects, so iterating serially here never
# over-subscribes the machine.
mode_watch() {
  # One tick forks two processes per registered project, so the cost scales with
  # the project count, not with the work actually due. At 19 projects a 30s tick
  # meant ~38 short-lived shells every half minute for a schedule whose finest
  # granularity is hourly. 120s keeps dispatch latency far below any routine's
  # period while cutting that churn 4x.
  local interval=${DARKFLOW_WATCH_INTERVAL:-120}
  local tick=0

  glog "Dark Flow global worker started (tick every ${interval}s, ${SELF_PATH}). Ctrl-C to stop."
  trap 'echo ""; glog "WATCH stopped (signal)"; stop_heartbeat_loop; exit 0' INT TERM

  while true; do
    (( tick++ )) || true

    local projects; projects=$(fetch_projects)
    if [[ -z "$projects" ]]; then
      glog "WATCH tick ${tick} — no projects registered (set each project's Local path in the web UI)"
    else
      local pcount; pcount=$(printf '%s\n' "$projects" | grep -c . || true)
      glog "WATCH tick ${tick} — ${pcount} project(s)"
      local path
      while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        if [[ ! -d "$path" ]]; then
          glog "SKIP ${path} — directory not found (moved or deleted)"
          continue
        fi
        # Dispatch each project in its OWN subshell so projects run in PARALLEL.
        # The fork gives the child private copies of PROJECT_ROOT/LOG/PENDING_LOGS,
        # so the loop's next set_project can't clobber a still-running child.
        # Cross-project isolation already holds: per-project lock dir, separate
        # git repos/cwd. The global
        # /tmp/darkflow-slots semaphore still caps total agent sessions on the
        # machine. We do NOT wait on these children: the per-project lock makes a
        # re-dispatch of a busy project fail fast next tick, so the count of live
        # children is bounded by the number of projects.
        (
          # set_project enters the repo and fetches its config from the Web UI;
          # failure means the dir isn't a registered git repo or the server is down.
          set_project "$path" || { glog "SKIP ${path} — not a registered project or config fetch failed"; exit 0; }
          send_heartbeat "idle"
          if try_acquire_lock; then
            mode_dispatch false || log "WATCH  dispatch error (tick ${tick})"
            # This subshell owns its PENDING_LOGS (fork) and dies at exit, so it
            # must flush its OWN logs now — the old every-10th-tick batching only
            # worked while PENDING_LOGS lived in one long-running process. Sync
            # whenever a routine produced logs; keep a periodic full metadata/issue
            # refresh on top (~5 min).
            if [[ ${#PENDING_LOGS[@]} -gt 0 ]] || (( tick % 10 == 1 )); then
              sync_webapp
            fi
            release_lock
          else
            local owner_pid=""
            [[ -f "$LOCK_DIR/pid" ]] && owner_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
            log "WATCH  skipped (another dispatch is running, PID ${owner_pid:-unknown})"
          fi
        ) &
      done <<< "$projects"
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

  # ── ci-watch triage ─────────────────────────────────────────────────────────
  # Offline checks on the two pieces of ci_watch that are easy to get wrong: the
  # timestamp parser, and the jq that reduces `gh run list` to "what is broken".
  echo "Running ci-watch self-tests..."

  if [[ "$(iso_to_epoch "2026-07-28T11:11:00Z")" == "1785237060" ]]; then
    echo "  PASS  iso_to_epoch"
  else
    echo "  FAIL  iso_to_epoch: got $(iso_to_epoch "2026-07-28T11:11:00Z")"
    (( failures++ )) || true
  fi

  if [[ "$(iso_to_epoch "not-a-date")" == "0" ]]; then
    echo "  PASS  iso_to_epoch rejects garbage"
  else
    echo "  FAIL  iso_to_epoch should return 0 for unparseable input"
    (( failures++ )) || true
  fi

  # Fixture: one workflow that went red then green (must NOT be reported), one
  # that is still red, one stuck in queued, and a uniquely-named Dependabot
  # `dynamic` run that must be filtered out entirely.
  local fixture='[
    {"name":"Build","conclusion":"failure","status":"completed","createdAt":"2026-07-28T10:00:00Z","url":"u1","databaseId":1,"event":"push"},
    {"name":"Build","conclusion":"success","status":"completed","createdAt":"2026-07-28T12:00:00Z","url":"u2","databaseId":2,"event":"push"},
    {"name":"Tests","conclusion":"failure","status":"completed","createdAt":"2026-07-28T12:00:00Z","url":"u3","databaseId":3,"event":"push"},
    {"name":"Gate","conclusion":null,"status":"queued","createdAt":"2026-07-28T12:00:00Z","url":"u4","databaseId":4,"event":"push"},
    {"name":"npm_and_yarn in /. for next - Update #1","conclusion":"failure","status":"completed","createdAt":"2026-07-28T13:00:00Z","url":"u5","databaseId":5,"event":"dynamic"}
  ]'
  local _latest _red _pending
  _latest=$(jq -c '[.[] | select(.event != "dynamic")] | [group_by(.name)[] | sort_by(.createdAt) | last]' <<<"$fixture")
  _red=$(jq -r '[.[] | select(.conclusion == "failure") | .name] | join(",")' <<<"$_latest")
  _pending=$(jq -r '[.[] | select(.conclusion == null or .conclusion == "") | .name] | join(",")' <<<"$_latest")

  if [[ "$_red" == "Tests" ]]; then
    echo "  PASS  triage: only the still-red workflow is reported"
  else
    echo "  FAIL  triage red: expected 'Tests', got '${_red}'"
    (( failures++ )) || true
  fi

  if [[ "$_pending" == "Gate" ]]; then
    echo "  PASS  triage: queued workflow flagged as stuck candidate"
  else
    echo "  FAIL  triage stuck: expected 'Gate', got '${_pending}'"
    (( failures++ )) || true
  fi

  if [[ "$_red" != *"npm_and_yarn"* ]]; then
    echo "  PASS  triage: Dependabot 'dynamic' runs filtered out"
  else
    echo "  FAIL  triage: Dependabot run leaked into the red set"
    (( failures++ )) || true
  fi

  # epoch_to_iso must round-trip through iso_to_epoch, and must NOT drift by the
  # machine's UTC offset the way epoch_fmt would.
  local _iso _back
  _iso=$(epoch_to_iso 1785237060)
  _back=$(iso_to_epoch "$_iso")
  if [[ "$_iso" == "2026-07-28T11:11:00Z" && "$_back" == "1785237060" ]]; then
    echo "  PASS  epoch_to_iso is UTC and round-trips"
  else
    echo "  FAIL  epoch_to_iso: got ${_iso} → ${_back} (want 2026-07-28T11:11:00Z → 1785237060)"
    (( failures++ )) || true
  fi

  # Stale-failure filter: a red run older than CI_STALE_DAYS must be ignored,
  # because nothing will re-run it and the task it files could never be closed.
  local _stale_fixture _cut _fresh_red
  _stale_fixture='[
    {"name":"CodeQL","conclusion":"failure","createdAt":"2026-06-02T07:28:00Z","databaseId":1,"url":"u1"},
    {"name":"Tests","conclusion":"failure","createdAt":"2026-07-28T12:00:00Z","databaseId":2,"url":"u2"}
  ]'
  _cut=$(epoch_to_iso "$(( $(iso_to_epoch "2026-07-29T12:00:00Z") - CI_STALE_DAYS * 86400 ))")
  _fresh_red=$(jq -r --arg cut "$_cut" \
    '[.[] | select(.conclusion == "failure" and .createdAt > $cut) | .name] | join(",")' <<<"$_stale_fixture")
  if [[ "$_fresh_red" == "Tests" ]]; then
    echo "  PASS  triage: two-month-old red run ignored as stale"
  else
    echo "  FAIL  triage stale: expected 'Tests', got '${_fresh_red}'"
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
  if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
    echo "darkflow-run: --sync requires jq and curl" >&2
    exit 1
  fi
  log "SYNC   manual web UI sync"
  send_heartbeat "idle"
  sync_webapp
  echo "Synced project metadata to the web UI."
}

# ── Main ──────────────────────────────────────────────────────────────────────

case "${1:-}" in
  --list)
    preflight_tools || exit 1
    require_cwd_project
    preflight || exit 1
    mode_list
    ;;
  --dry-run)
    preflight_tools || exit 1
    require_cwd_project
    preflight || exit 1
    acquire_lock
    mode_dispatch true
    ;;
  --self-test)
    mode_self_test
    ;;
  --sync)
    require_cwd_project
    mode_sync
    ;;
  "")
    # Default: global continuous loop over every registered project.
    preflight_tools || exit 1
    mode_watch
    ;;
  -*)
    echo "Usage: darkflow-run.sh [<routine-name> | --sync | --list | --dry-run | --self-test]" >&2
    exit 1
    ;;
  *)
    preflight_tools || exit 1
    require_cwd_project
    preflight || exit 1
    acquire_lock
    mode_manual "$1"
    ;;
esac
