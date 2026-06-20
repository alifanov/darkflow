#!/usr/bin/env bash
# Dark Flow — installer, updater, and verifier.
# One command for all scenarios: fresh install, update, and repair.
#
# New project:       bash install.sh
# Existing project:  bash install.sh  (auto-detects installed version)
# One-liner:         curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh -o /tmp/darkflow-install.sh && bash /tmp/darkflow-install.sh
# All modules:       bash install.sh --all
# Silent/CI:         bash install.sh --yes
# Preview changes:   bash install.sh --dry-run
# Re-apply all:      bash install.sh --force

set -euo pipefail

DARKFLOW_REPO="https://raw.githubusercontent.com/alifanov/darkflow/main"
TARGET_DIR="${PWD}"
PROJECT_NAME=""
LANGUAGE=""
MAIN_BRANCH=""
MERGE_STRATEGY=""
SKIP_LABELS=false
SKIP_CLAUDE_SNIPPET=false
FORCE=false
DRY_RUN=false
NON_INTERACTIVE=false
SELF_UPDATE=false
WEBAPP_URL_SET=false

MOD_ANALYTICS=""
MOD_OBSERVABILITY=""
MOD_GSC=""
MOD_ADS=""
MOD_COOLIFY=""
MOD_CLAUDE_UPDATE=""
MOD_ARCH_REVIEW=""
MOD_MAILBOX=""
MOD_DOCS_AUDIT=""
MOD_PRODUCT_OVERVIEW=""
MOD_IMPECCABLE=""
MOD_FALLOW=""
MOD_CI_GATE=""

OBS_TOOL=""
OBS_URL=""
OBS_API_KEY=""
POSTHOG_PROJECT_ID=""
MAILBOX_IMAP_HOST=""
MAILBOX_IMAP_PORT=""
MAILBOX_IMAP_USER=""
MAILBOX_IMAP_PASSWORD=""
MAILBOX_SMTP_HOST=""
MAILBOX_SMTP_PORT=""
MAILBOX_SMTP_USER=""
MAILBOX_SMTP_PASSWORD=""
WEBAPP_URL="http://localhost:5555"

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
DIM="\033[2m"
RED="\033[0;31m"
RESET="\033[0m"

info()    { echo -e "${CYAN}▸ $*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
skip()    { echo -e "${DIM}  skip: $*${RESET}"; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }
changed() { echo -e "${YELLOW}↻ $*${RESET}"; }
dim()     { echo -e "${DIM}  $*${RESET}"; }

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)               PROJECT_NAME="$2"; shift 2 ;;
    --lang)               LANGUAGE="$2"; shift 2 ;;
    --no-labels)          SKIP_LABELS=true; shift ;;
    --no-claude)          SKIP_CLAUDE_SNIPPET=true; shift ;;
    --force)              FORCE=true; shift ;;
    --dry-run)            DRY_RUN=true; shift ;;
    --target)             TARGET_DIR="$2"; shift 2 ;;
    --all)                NON_INTERACTIVE=true
                          MOD_ANALYTICS=true; MOD_OBSERVABILITY=true; MOD_GSC=true
                          MOD_ADS=true; MOD_COOLIFY=true; MOD_CLAUDE_UPDATE=true
                          MOD_ARCH_REVIEW=true; MOD_MAILBOX=true
                          MOD_DOCS_AUDIT=true; MOD_PRODUCT_OVERVIEW=true
                          MOD_IMPECCABLE=true; MOD_FALLOW=true; MOD_CI_GATE=true
                          shift ;;
    --with-analytics)     MOD_ANALYTICS=true; shift ;;
    --with-observability) MOD_OBSERVABILITY=true; shift ;;
    --with-gsc)           MOD_GSC=true; shift ;;
    --with-ads)           MOD_ADS=true; shift ;;
    --with-coolify)       MOD_COOLIFY=true; shift ;;
    --with-claude-update) MOD_CLAUDE_UPDATE=true; shift ;;
    --no-analytics)       MOD_ANALYTICS=false; shift ;;
    --no-observability)   MOD_OBSERVABILITY=false; shift ;;
    --no-gsc)             MOD_GSC=false; shift ;;
    --no-ads)             MOD_ADS=false; shift ;;
    --no-coolify)         MOD_COOLIFY=false; shift ;;
    --no-claude-update)   MOD_CLAUDE_UPDATE=false; shift ;;
    --with-arch-review)   MOD_ARCH_REVIEW=true; shift ;;
    --no-arch-review)     MOD_ARCH_REVIEW=false; shift ;;
    --with-mailbox)       MOD_MAILBOX=true; shift ;;
    --no-mailbox)         MOD_MAILBOX=false; shift ;;
    --with-docs-audit)       MOD_DOCS_AUDIT=true; shift ;;
    --no-docs-audit)         MOD_DOCS_AUDIT=false; shift ;;
    --with-product-overview) MOD_PRODUCT_OVERVIEW=true; shift ;;
    --no-product-overview)   MOD_PRODUCT_OVERVIEW=false; shift ;;
    --with-impeccable)       MOD_IMPECCABLE=true; shift ;;
    --no-impeccable)         MOD_IMPECCABLE=false; shift ;;
    --with-fallow)           MOD_FALLOW=true; shift ;;
    --no-fallow)             MOD_FALLOW=false; shift ;;
    --with-ci-gate)          MOD_CI_GATE=true; shift ;;
    --no-ci-gate)            MOD_CI_GATE=false; shift ;;
    --obs-tool)           OBS_TOOL="$2"; shift 2 ;;
    --obs-url)            OBS_URL="$2"; shift 2 ;;
    --obs-api-key)        OBS_API_KEY="$2"; shift 2 ;;
    --posthog-project-id) POSTHOG_PROJECT_ID="$2"; shift 2 ;;
    --webapp-url)         WEBAPP_URL="$2"; WEBAPP_URL_SET=true; shift 2 ;;
    --self-update)        SELF_UPDATE=true; NON_INTERACTIVE=true; shift ;;
    --branch)             MAIN_BRANCH="$2"; shift 2 ;;
    --merge-pr)           MERGE_STRATEGY="pr"; shift ;;
    --merge-direct)       MERGE_STRATEGY="direct"; shift ;;
    -y|--yes)             NON_INTERACTIVE=true; shift ;;
    -h|--help)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Works on both new and existing Dark Flow projects. Automatically detects"
      echo "whether to perform a fresh install or an update based on the installed version."
      echo ""
      echo "Options:"
      echo "  --name NAME           Project name (default: directory name)"
      echo "  --lang LANGUAGE       Communication language for issues/comments/chat; product stays English (default: English)"
      echo "  --all                 Enable all optional modules non-interactively"
      echo "  -y, --yes             Accept defaults non-interactively (no optional modules)"
      echo "  --dry-run             Show what would change without applying anything"
      echo "  --force               Overwrite locally-modified files; skip version check"
      echo "  --with-analytics      Include analytics module (PostHog/Mixpanel)"
      echo "  --with-observability  Include observability module (SigNoz/Datadog)"
      echo "  --with-gsc            Include Google Search Console module"
      echo "  --with-ads            Include paid ads module (Google Ads/Meta)"
      echo "  --with-coolify        Include Coolify deployment monitoring"
      echo "  --with-claude-update  Include auto CLAUDE.md regeneration routine"
      echo "  --with-arch-review    Install improve-codebase-architecture skill + weekly routine"
      echo "  --with-docs-audit     Weekly docs <-> code drift check routine"
      echo "  --with-product-overview  Weekly product overview digest routine"
      echo "  --with-impeccable     Weekly design quality routines (audit + critique + monthly harden)"
      echo "  --with-fallow         Weekly code-health audit via fallow (TS/JS only) + skill"
      echo "  --with-ci-gate        GitHub Actions workflow: failing lint/test auto-files an issue"
      echo "  --branch NAME         Main branch name (default: main)"
      echo "  --merge-pr            Fix issues via pull requests (default)"
      echo "  --merge-direct        Fix issues by committing directly to main branch"
      echo "  --no-labels           Skip GitHub label setup"
      echo "  --no-claude           Skip CLAUDE.md creation"
      echo "  --target DIR          Install into DIR instead of current directory"
      echo "  --self-update         Refresh only the global worker + user-scope commands (no project work)"
      exit 0
      ;;
    *) warn "Unknown argument: $1"; shift ;;
  esac
done

# ── Resolve source (local repo clone vs remote) ───────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/templates/docs/agent-workflow.md" ]]; then
  USE_LOCAL=true
  SOURCE_DIR="$SCRIPT_DIR/templates"
else
  USE_LOCAL=false
  SOURCE_DIR=""
fi

cd "$TARGET_DIR"

# ── Core helpers ──────────────────────────────────────────────────────────────

fetch_raw() {
  local path="$1"
  if [[ "$USE_LOCAL" == true ]]; then
    cat "$SCRIPT_DIR/$path" 2>/dev/null || true
  else
    curl -fsSL "${DARKFLOW_REPO}/${path}?t=$(date +%s)" 2>/dev/null || true
  fi
}

read_config() {
  local key="$1" default="${2:-}"
  local v
  v=$(grep "^${key}=" .darkflow 2>/dev/null | head -1 | cut -d= -f2- || true)
  [[ -n "$v" ]] && echo "$v" || echo "$default"
}

detect_os() {
  case "$(uname)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "other" ;;
  esac
}
DETECTED_OS=$(detect_os)

project_slug() {
  echo "${PROJECT_NAME}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//'
}

# ── Global worker bootstrap (one worker for every project) ────────────────────
# Dark Flow now runs a single host-side worker (~/.darkflow/darkflow-run.sh) that
# services every project, plus user-scope slash commands so they exist in all
# projects automatically. These artifacts are machine-global, not per-project.

GLOBAL_DIR="$HOME/.darkflow"
USER_CMD_DIR="$HOME/.claude/commands/darkflow"

# The worker requires a modern bash (the script uses bash 4+ syntax). macOS ships
# /bin/bash 3.2, which can't even parse it, so the launchd agent must run under the
# same bash that runs this installer (typically Homebrew's bash 5 on PATH).
BASH_BIN="$(command -v bash 2>/dev/null || echo /bin/bash)"

# Every slash command Dark Flow ships, installed once into user scope as a
# superset — routines.yml still gates which actually run per project, and an
# unused slash command is harmless.
ALL_DF_COMMANDS=(
  add-issue install self-update fix-issues analytics-review observability-check
  gsc-check ads-review coolify-check-deployment claude-md-update security-audit
  vulnerability-check architecture-review update-config docs-audit product-overview
  build-optimization csp-setup uptime-check grill design-audit design-critique
  design-harden mailbox-check code-health fix-ci-issue
)

# Fetch a template (local clone or remote) to dest, always overwriting.
gb_fetch() {
  local rel="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ "$USE_LOCAL" == true ]]; then
    cp "$SOURCE_DIR/$rel" "$dest"
  else
    curl -fsSL "${DARKFLOW_REPO}/templates/${rel}?t=$(date +%s)" -o "$dest"
  fi
}

install_global_worker() {
  [[ "$DRY_RUN" == true ]] && { info "Would install global worker at ${GLOBAL_DIR}/darkflow-run.sh"; return; }
  mkdir -p "$GLOBAL_DIR"
  gb_fetch "darkflow/darkflow-run.sh" "${GLOBAL_DIR}/darkflow-run.sh"
  chmod +x "${GLOBAL_DIR}/darkflow-run.sh"
  success "Installed global worker at ${GLOBAL_DIR}/darkflow-run.sh"
}

install_user_commands() {
  [[ "$DRY_RUN" == true ]] && { info "Would install slash commands into ${USER_CMD_DIR}/"; return; }
  mkdir -p "$USER_CMD_DIR"
  gb_fetch ".claude/commands/darkflow.md" "$HOME/.claude/commands/darkflow.md" \
    || warn "Could not fetch root command (darkflow.md)"
  local c
  for c in "${ALL_DF_COMMANDS[@]}"; do
    gb_fetch ".claude/commands/darkflow/${c}.md" "${USER_CMD_DIR}/${c}.md" \
      || warn "Could not fetch command: ${c}"
  done
  success "Installed ${#ALL_DF_COMMANDS[@]} slash commands into ${USER_CMD_DIR}/"
}

# Write ~/.darkflow/config (webapp_url + version). Preserves a custom webapp_url
# across updates — only --webapp-url overrides it.
write_global_config() {
  [[ "$DRY_RUN" == true ]] && return
  mkdir -p "$GLOBAL_DIR"
  local cfg="${GLOBAL_DIR}/config" existing_url url
  existing_url=$(grep "^webapp_url=" "$cfg" 2>/dev/null | head -1 | cut -d= -f2- || true)
  if [[ "$WEBAPP_URL_SET" == true ]]; then
    url="$WEBAPP_URL"
  elif [[ -n "$existing_url" ]]; then
    url="$existing_url"
  else
    url="$WEBAPP_URL"
  fi
  {
    echo "# Dark Flow global worker config — managed by install.sh"
    echo "webapp_url=${url}"
    echo "version=${LATEST_VERSION}"
  } > "$cfg"
}

# Dark Flow does NOT auto-start the worker — the operator starts it manually for
# full control. Remove any launchd agent left by an earlier install so nothing
# auto-runs, then print how to start it.
worker_start_help() {
  [[ "$DRY_RUN" == true ]] && { info "Would print manual worker start instructions"; return; }
  if [[ "$DETECTED_OS" == "macos" ]]; then
    local plist="$HOME/Library/LaunchAgents/com.darkflow.worker.plist"
    if [[ -f "$plist" ]]; then
      launchctl unload "$plist" 2>/dev/null || true
      rm -f "$plist"
      info "Removed the auto-start launchd agent — the worker is manual now."
    fi
  fi
  info "Start the global worker yourself (services every project, runs until stopped):"
  dim  "  nohup ${BASH_BIN} ${GLOBAL_DIR}/darkflow-run.sh >/dev/null 2>> ${GLOBAL_DIR}/worker.err.log &"
  dim  "Stop it with:  pkill -f ${GLOBAL_DIR}/darkflow-run.sh"
}

# Remove the now-obsolete per-project worker + command copies. Only runs inside a
# project (skipped during --self-update, which has no project context).
cleanup_legacy_project_files() {
  [[ "$DRY_RUN" == true || "$SELF_UPDATE" == true ]] && return
  if [[ -f ".darkflow.d/darkflow-run.sh" ]]; then
    rm -f ".darkflow.d/darkflow-run.sh"
    success "Removed legacy per-project worker (.darkflow.d/darkflow-run.sh) — now global"
  fi
  if [[ -d ".claude/commands/darkflow" ]]; then
    rm -rf ".claude/commands/darkflow"
    success "Removed per-project commands (.claude/commands/darkflow/) — now in ~/.claude/commands/darkflow/"
  fi
  [[ -f ".claude/commands/darkflow.md" ]] && rm -f ".claude/commands/darkflow.md"
  return 0
}

global_bootstrap() {
  header "Global worker (one worker for all projects)"
  install_global_worker
  install_user_commands
  write_global_config
  worker_start_help
  cleanup_legacy_project_files
}

# ── Global-only self-update (manual: `install.sh --self-update`) ──────────────
# Refreshes just the global worker + user-scope commands, then exits — no project
# scaffolding, labels, or sync. cwd is irrelevant here.
if [[ "$SELF_UPDATE" == true ]]; then
  LATEST_VERSION=$(fetch_raw "VERSION" | tr -d '[:space:]')
  [[ -z "$LATEST_VERSION" ]] && LATEST_VERSION="0.0.0"
  global_bootstrap
  echo ""
  success "Dark Flow global worker refreshed to v${LATEST_VERSION}"
  exit 0
fi

# ── Mode detection ────────────────────────────────────────────────────────────

MODE=fresh
INSTALLED_VERSION=""
LATEST_VERSION=""

if [[ -f ".darkflow" ]]; then
  INSTALLED_VERSION=$(read_config version "0.0.0")
  LATEST_VERSION=$(fetch_raw "VERSION" | tr -d '[:space:]')
  [[ -z "$LATEST_VERSION" ]] && LATEST_VERSION="$INSTALLED_VERSION"

  if [[ "$INSTALLED_VERSION" == "$LATEST_VERSION" && "$FORCE" != true ]]; then
    MODE=verify
  else
    MODE=update
  fi
else
  LATEST_VERSION=$(fetch_raw "VERSION" | tr -d '[:space:]')
  [[ -z "$LATEST_VERSION" ]] && LATEST_VERSION="0.0.0"
fi

# ── Verify mode: already up to date — quick exit ─────────────────────────────

if [[ "$MODE" == "verify" ]]; then
  echo ""
  success "Dark Flow already up to date (${INSTALLED_VERSION})"
  dim "Run with --force to re-apply all templates."
  echo ""
  _webapp_url=$(read_config webapp_url "")
  if [[ -n "$_webapp_url" && -x "${GLOBAL_DIR}/darkflow-run.sh" ]]; then
    bash "${GLOBAL_DIR}/darkflow-run.sh" --sync >/dev/null 2>&1 && \
      success "Synced project to web UI (${_webapp_url})" || true
  fi
  exit 0
fi

# ── Read existing config (update mode only) ───────────────────────────────────

MODULES=""
if [[ "$MODE" == "update" ]]; then
  [[ -z "$LANGUAGE"       ]] && LANGUAGE=$(read_config language "")
  [[ -z "$MAIN_BRANCH"    ]] && MAIN_BRANCH=$(read_config branch "")
  [[ -z "$MERGE_STRATEGY" ]] && MERGE_STRATEGY=$(read_config merge_strategy "")
  MODULES=$(read_config modules "")
  [[ -z "$OBS_TOOL"           ]] && OBS_TOOL=$(read_config obs_tool "")
  [[ -z "$OBS_URL"            ]] && OBS_URL=$(read_config obs_url "")
  [[ -z "$POSTHOG_PROJECT_ID" ]] && POSTHOG_PROJECT_ID=$(read_config posthog_project_id "")
  [[ -z "$PROJECT_NAME" ]] && PROJECT_NAME=$(read_config name "")
  WEBAPP_URL=$(read_config webapp_url "$WEBAPP_URL")
  # Populate MOD_* from .darkflow (command-line flags take precedence)
  [[ "$MODULES" == *"analytics"*     && -z "$MOD_ANALYTICS"     ]] && MOD_ANALYTICS=true
  [[ "$MODULES" == *"observability"* && -z "$MOD_OBSERVABILITY" ]] && MOD_OBSERVABILITY=true
  [[ "$MODULES" == *"gsc"*           && -z "$MOD_GSC"           ]] && MOD_GSC=true
  [[ "$MODULES" == *"ads"*           && -z "$MOD_ADS"           ]] && MOD_ADS=true
  [[ "$MODULES" == *"coolify"*       && -z "$MOD_COOLIFY"       ]] && MOD_COOLIFY=true
  [[ "$MODULES" == *"claude-update"* && -z "$MOD_CLAUDE_UPDATE" ]] && MOD_CLAUDE_UPDATE=true
  [[ "$MODULES" == *"arch-review"*   && -z "$MOD_ARCH_REVIEW"   ]] && MOD_ARCH_REVIEW=true
  [[ "$MODULES" == *"mailbox"*       && -z "$MOD_MAILBOX"       ]] && MOD_MAILBOX=true
  [[ "$MODULES" == *"docs-audit"*       && -z "$MOD_DOCS_AUDIT"      ]] && MOD_DOCS_AUDIT=true
  [[ "$MODULES" == *"product-overview"* && -z "$MOD_PRODUCT_OVERVIEW" ]] && MOD_PRODUCT_OVERVIEW=true
  [[ "$MODULES" == *"impeccable"*       && -z "$MOD_IMPECCABLE"       ]] && MOD_IMPECCABLE=true
  [[ "$MODULES" == *"fallow"*           && -z "$MOD_FALLOW"           ]] && MOD_FALLOW=true
  [[ "$MODULES" == *"ci-gate"*          && -z "$MOD_CI_GATE"          ]] && MOD_CI_GATE=true
fi

# ── Mode header ───────────────────────────────────────────────────────────────

if [[ "$MODE" == "fresh" ]]; then
  echo ""
  [[ "$USE_LOCAL" == true ]] && info "Using local templates from $SCRIPT_DIR" || info "Fetching templates from GitHub..."
else
  header "Dark Flow update"
  echo -e "  Installed: ${BOLD}${INSTALLED_VERSION}${RESET}"
  echo -e "  Latest:    ${BOLD}${LATEST_VERSION}${RESET}"
  echo -e "  Project:   ${TARGET_DIR}"
  [[ "$DRY_RUN" == true ]] && echo -e "\n${YELLOW}DRY RUN — no changes will be applied${RESET}"
  echo ""
  # Show changelog entries since installed version
  CHANGELOG=$(fetch_raw "CHANGELOG.md")
  if [[ -n "$CHANGELOG" ]]; then
    echo -e "${BOLD}Changes since ${INSTALLED_VERSION}:${RESET}"
    awk "/## \[${LATEST_VERSION}\]/,/## \[${INSTALLED_VERSION}\]/" <<< "$CHANGELOG" \
      | grep -v "## \[${INSTALLED_VERSION}\]" \
      | head -40 \
      || true
    echo ""
  fi
fi

# ── Project name ──────────────────────────────────────────────────────────────

if [[ -z "$PROJECT_NAME" ]]; then
  if [[ -f "package.json" ]]; then
    inferred=$(node -p "require('./package.json').name" 2>/dev/null || true)
    [[ -n "$inferred" ]] && PROJECT_NAME="$inferred"
  fi
  [[ -z "$PROJECT_NAME" ]] && PROJECT_NAME="$(basename "$TARGET_DIR")"

  if [[ "$NON_INTERACTIVE" == false && -t 0 ]]; then
    read -rp "Project name [${PROJECT_NAME}]: " _input
    [[ -n "$_input" ]] && PROJECT_NAME="$_input"
  fi
fi

[[ "$MODE" == "fresh" ]] && header "Installing Dark Flow for \"${PROJECT_NAME}\""

# ── Language ──────────────────────────────────────────────────────────────────

if [[ -z "$LANGUAGE" ]]; then
  if [[ "$NON_INTERACTIVE" == true || ! -t 0 ]]; then
    LANGUAGE="English"
  else
    echo ""
    echo -e "${BOLD}Communication language${RESET} — for GitHub issues, comments, commits, and chat. The product itself always stays in English."
    echo ""
    echo "  1) English (default)"
    echo "  2) Russian"
    echo "  3) Spanish"
    echo "  4) German"
    echo "  5) Other"
    echo ""
    read -rp "  Choice [1]: " _lang_choice
    case "${_lang_choice:-1}" in
      1|"")    LANGUAGE="English" ;;
      2)       LANGUAGE="Russian" ;;
      3)       LANGUAGE="Spanish" ;;
      4)       LANGUAGE="German" ;;
      5)       read -rp "  Language name: " LANGUAGE
               [[ -z "$LANGUAGE" ]] && LANGUAGE="English" ;;
      *)       LANGUAGE="${_lang_choice}" ;;
    esac
    echo ""
  fi
fi

info "Language: ${LANGUAGE}"

# ── Branch & merge strategy ───────────────────────────────────────────────────

if [[ -z "$MAIN_BRANCH" ]]; then
  if [[ "$NON_INTERACTIVE" == true || ! -t 0 ]]; then
    MAIN_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    [[ "$MAIN_BRANCH" == "HEAD" ]] && MAIN_BRANCH="main"
  else
    _detected=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    [[ "$_detected" == "HEAD" ]] && _detected="main"
    echo ""
    read -rp "Main branch name [${_detected}]: " _branch_input
    MAIN_BRANCH="${_branch_input:-$_detected}"
  fi
fi

if [[ -z "$MERGE_STRATEGY" ]]; then
  if [[ "$NON_INTERACTIVE" == true || ! -t 0 ]]; then
    MERGE_STRATEGY="pr"
  else
    echo ""
    echo -e "${BOLD}Fix Issues merge strategy${RESET}"
    echo ""
    echo "  1) Pull request — agent opens a PR, then merges it (default, safer, auditable)"
    echo "  2) Direct commit — agent commits and pushes directly to ${MAIN_BRANCH} (faster)"
    echo ""
    read -rp "  Choice [1]: " _merge_choice
    case "${_merge_choice:-1}" in
      2) MERGE_STRATEGY="direct" ;;
      *) MERGE_STRATEGY="pr" ;;
    esac
    echo ""
  fi
fi

info "Branch: ${MAIN_BRANCH} | Merge: ${MERGE_STRATEGY}"

# ── Module selection ──────────────────────────────────────────────────────────

ask_module() {
  local var="$1" label="$2" hint="$3" default="${4:-true}"
  # Skip if already set via flag or read from .darkflow
  [[ -n "${!var}" ]] && return
  if [[ "$NON_INTERACTIVE" == true || ! -t 0 ]]; then
    eval "$var=false"
    return
  fi
  local default_label
  [[ "$default" == true ]] && default_label="Y/n" || default_label="y/N"
  echo -e "  ${BOLD}${label}${RESET} ${DIM}${hint}${RESET}"
  read -rp "  Include? [${default_label}]: " _yn
  case "${_yn:-$default}" in
    [Yy1tT]*|true) eval "$var=true" ;;
    *)              eval "$var=false" ;;
  esac
  echo ""
}

if [[ "$NON_INTERACTIVE" == false && -t 0 ]] && \
   [[ -z "$MOD_ANALYTICS$MOD_OBSERVABILITY$MOD_GSC$MOD_ADS$MOD_COOLIFY$MOD_CLAUDE_UPDATE$MOD_ARCH_REVIEW" ]]; then
  echo ""
  echo -e "${BOLD}Optional modules${RESET}${DIM} — select what applies to your project:${RESET}"
  echo ""
fi

ask_module MOD_ANALYTICS     "Analytics"           "(PostHog, Mixpanel, Amplitude…) — daily review routine + insights/analytics/"
ask_module MOD_OBSERVABILITY  "Observability"       "(SigNoz, Datadog, Grafana…) — daily error/latency monitoring routine"
ask_module MOD_GSC            "Search Console"      "(Google Search Console) — weekly GSC check + technical/on-page SEO audit routine + insights/search-console/ + insights/seo-audit/"
ask_module MOD_ADS            "Paid Ads"            "(Google Ads, Meta…) — insights/ads/ folder"              false
ask_module MOD_COOLIFY        "Coolify"             "deployment status check — one daily routine"
ask_module MOD_CLAUDE_UPDATE  "CLAUDE.md update"    "weekday routine that re-generates CLAUDE.md from codebase" false
ask_module MOD_ARCH_REVIEW    "Architecture review" "installs improve-codebase-architecture skill + weekly routine" false
ask_module MOD_DOCS_AUDIT     "Docs audit"          "weekly docs <-> code drift check -> GitHub issues" false
ask_module MOD_PRODUCT_OVERVIEW "Product overview"  "weekly product digest: state + changes + bugs + hypotheses" false
ask_module MOD_IMPECCABLE     "Design quality"      "weekly design audit + critique (impeccable skill) + monthly harden" false
ask_module MOD_FALLOW         "Code health"         "weekly fallow audit (dead code, dupes, cycles, complexity) — TS/JS only" false
ask_module MOD_MAILBOX        "Mailbox"             "(IMAP+SMTP) — hourly inbox check → GitHub issues + automated replies" false
ask_module MOD_CI_GATE        "CI gate"             "GitHub Actions: failing lint/test auto-files an issue for the fix-issues worker" false

# ── Observability integration ─────────────────────────────────────────────────

if [[ "$MOD_OBSERVABILITY" == true && -z "$OBS_URL" && \
      "$NON_INTERACTIVE" == false && -t 0 ]]; then
  echo ""
  echo -e "${BOLD}Observability integration${RESET}"
  echo ""
  read -rp "  Connect your observability tool now? [Y/n]: " _want_obs
  case "${_want_obs:-Y}" in
    [Yy]*|"")
      echo ""
      echo "  1) SigNoz  2) Datadog  3) Grafana  4) Other"
      read -rp "  Choice [1]: " _obs_choice
      case "${_obs_choice:-1}" in
        1|"") OBS_TOOL="SigNoz" ;;
        2)    OBS_TOOL="Datadog" ;;
        3)    OBS_TOOL="Grafana" ;;
        4)    read -rp "  Tool name: " OBS_TOOL; [[ -z "$OBS_TOOL" ]] && OBS_TOOL="Observability" ;;
        *)    OBS_TOOL="$_obs_choice" ;;
      esac
      echo ""
      read -rp "  ${OBS_TOOL} URL: " OBS_URL
      read -rsp "  ${OBS_TOOL} API key: " OBS_API_KEY; echo ""
      echo ""
      ;;
    *) info "Skipping observability integration setup" ;;
  esac
fi

# ── PostHog integration ───────────────────────────────────────────────────────

if [[ "$MOD_ANALYTICS" == true && -z "$POSTHOG_PROJECT_ID" && \
      "$NON_INTERACTIVE" == false && -t 0 ]]; then
  echo ""
  echo -e "${BOLD}PostHog integration${RESET}"
  echo ""
  echo "  Storing the PostHog project ID prevents analytics routines from"
  echo "  accidentally querying the wrong project when multiple projects"
  echo "  share the same PostHog MCP instance."
  echo ""
  read -rp "  PostHog project ID (find it in PostHog → Project Settings → ID): " POSTHOG_PROJECT_ID
  echo ""
fi

# ── Mailbox integration ───────────────────────────────────────────────────────

if [[ "$MOD_MAILBOX" == true && -z "$MAILBOX_IMAP_HOST" && \
      "$NON_INTERACTIVE" == false && -t 0 ]]; then
  echo ""
  echo -e "${BOLD}Mailbox integration${RESET}"
  echo ""
  read -rp "  Configure IMAP/SMTP now? [Y/n]: " _want_mailbox
  case "${_want_mailbox:-Y}" in
    [Yy]*|"")
      echo ""
      echo -e "  ${DIM}IMAP (incoming mail)${RESET}"
      read -rp "  IMAP host: " MAILBOX_IMAP_HOST
      read -rp "  IMAP port [993]: " MAILBOX_IMAP_PORT
      [[ -z "$MAILBOX_IMAP_PORT" ]] && MAILBOX_IMAP_PORT="993"
      read -rp "  IMAP username: " MAILBOX_IMAP_USER
      read -rsp "  IMAP password: " MAILBOX_IMAP_PASSWORD; echo ""
      echo ""
      echo -e "  ${DIM}SMTP (outgoing mail — for sending replies)${RESET}"
      read -rp "  SMTP host [${MAILBOX_IMAP_HOST}]: " MAILBOX_SMTP_HOST
      [[ -z "$MAILBOX_SMTP_HOST" ]] && MAILBOX_SMTP_HOST="$MAILBOX_IMAP_HOST"
      read -rp "  SMTP port [587]: " MAILBOX_SMTP_PORT
      [[ -z "$MAILBOX_SMTP_PORT" ]] && MAILBOX_SMTP_PORT="587"
      read -rp "  SMTP username [${MAILBOX_IMAP_USER}]: " MAILBOX_SMTP_USER
      [[ -z "$MAILBOX_SMTP_USER" ]] && MAILBOX_SMTP_USER="$MAILBOX_IMAP_USER"
      read -rsp "  SMTP password (leave blank to reuse IMAP password): " MAILBOX_SMTP_PASSWORD; echo ""
      [[ -z "$MAILBOX_SMTP_PASSWORD" ]] && MAILBOX_SMTP_PASSWORD="$MAILBOX_IMAP_PASSWORD"
      echo ""
      ;;
    *) info "Skipping mailbox integration setup" ;;
  esac
fi

# ── Derived vars ──────────────────────────────────────────────────────────────

SLUG=$(project_slug)
if [[ "$MODE" == "update" ]]; then
  _existing_slug=$(read_config slug "")
  [[ -n "$_existing_slug" ]] && SLUG="$_existing_slug"
fi

# ── File / template helpers ───────────────────────────────────────────────────

fetch_file() {
  local rel_path="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ "$USE_LOCAL" == true ]]; then
    cp "$SOURCE_DIR/$rel_path" "$dest"
  else
    curl -fsSL "${DARKFLOW_REPO}/templates/${rel_path}?t=$(date +%s)" -o "$dest"
  fi
}

# Add if missing. If exists: skip when identical, warn+diff if locally modified,
# overwrite silently with --force.
smart_update_template() {
  local rel_path="$1" dest="$2" is_exec="${3:-}" always_update="${4:-}"

  if [[ ! -f "$dest" ]]; then
    if [[ "$DRY_RUN" == false ]]; then
      fetch_file "$rel_path" "$dest"
      [[ "$is_exec" == "true" ]] && chmod +x "$dest"
      success "Added: $dest"
    else
      info "Would add: $dest"
    fi
    return
  fi

  local latest current
  if [[ "$USE_LOCAL" == true ]]; then
    latest=$(cat "$SOURCE_DIR/$rel_path" 2>/dev/null || echo "")
  else
    latest=$(curl -fsSL "${DARKFLOW_REPO}/templates/${rel_path}?t=$(date +%s)" 2>/dev/null || echo "")
  fi
  if [[ -z "$latest" ]]; then
    warn "Skipped update for $dest (could not fetch upstream — network error or file missing)"
    return
  fi
  current=$(cat "$dest")

  if [[ "$current" == "$latest" ]]; then
    skip "$dest (unchanged)"
  elif [[ "$FORCE" == true || "$always_update" == "true" ]]; then
    if [[ "$DRY_RUN" == false ]]; then
      echo "$latest" > "$dest"
      [[ "$is_exec" == "true" ]] && chmod +x "$dest"
      if [[ "$always_update" == "true" ]]; then
        changed "Updated (infrastructure): $dest"
      else
        changed "Updated (--force): $dest"
      fi
    else
      info "Would update: $dest"
    fi
  else
    warn "Locally modified: $dest"
    dim "New upstream version available. Use --force to overwrite."
    diff <(echo "$current") <(echo "$latest") | head -20 | sed 's/^/  /' || true
  fi
}

make_dir() {
  local d="$1"
  if [[ ! -d "$d" ]]; then
    if [[ "$DRY_RUN" == false ]]; then
      mkdir -p "$d"
      touch "$d/.gitkeep"
      success "mkdir $d"
    else
      info "Would create: $d/"
    fi
  fi
}

inject_name() {
  local file="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" "$file"
  else
    sed -i "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" "$file"
  fi
}

inject_makefile_block() {
  local block_file="$1" target="Makefile"
  if [[ "$DRY_RUN" == true ]]; then
    if [[ ! -f "$target" ]]; then
      info "Would create Makefile with Dark Flow targets"
    elif grep -q "# darkflow:start" "$target"; then
      info "Would update Dark Flow block in Makefile"
    else
      info "Would append Dark Flow block to existing Makefile"
    fi
    return
  fi
  if [[ ! -f "$target" ]]; then
    cp "$block_file" "$target"
    success "Created Makefile with Dark Flow targets (run: make df-help)"
  elif grep -q "# darkflow:start" "$target"; then
    awk -v bf="$block_file" '
      /# darkflow:start/ { while ((getline l < bf) > 0) print l; close(bf); skip=1; next }
      skip && /# darkflow:end/ { skip=0; next }
      skip { next }
      { print }
    ' "$target" > "$target.tmp" && mv "$target.tmp" "$target"
    success "Updated Dark Flow block in Makefile"
  else
    printf '\n' >> "$target"
    cat "$block_file" >> "$target"
    success "Appended Dark Flow block to existing Makefile"
  fi
}

sync_makefile() {
  local _mkfile_tmp
  _mkfile_tmp=$(mktemp)
  if [[ "$USE_LOCAL" == true ]]; then
    cp "$SOURCE_DIR/Makefile.darkflow" "$_mkfile_tmp" 2>/dev/null || true
  else
    curl -fsSL "${DARKFLOW_REPO}/templates/Makefile.darkflow?t=$(date +%s)" \
      -o "$_mkfile_tmp" 2>/dev/null || true
  fi
  [[ -s "$_mkfile_tmp" ]] && inject_makefile_block "$_mkfile_tmp"
  rm -f "$_mkfile_tmp"
}

# ── GitHub labels ─────────────────────────────────────────────────────────────

setup_labels() {
  if [[ "$SKIP_LABELS" == true ]]; then
    info "Skipping labels (--no-labels)"
    return
  fi
  if ! command -v gh &>/dev/null; then
    warn "gh not found — skipping label setup. Install: https://cli.github.com/"
    return
  fi
  if ! gh auth status &>/dev/null 2>&1; then
    warn "gh not authenticated — run 'gh auth login' then re-run with --no-labels"
    return
  fi
  if [[ "$DRY_RUN" == true ]]; then
    info "Would set up GitHub labels (additive, safe)"
    return
  fi

  _do_label() {
    local name="$1" color="$2" desc="$3"
    if gh label create "$name" --color "$color" --description "$desc" 2>/dev/null; then
      success "label: $name"
    else
      gh label edit "$name" --color "$color" --description "$desc" 2>/dev/null && \
        changed "label: $name" || true
    fi
  }

  info "Setting up GitHub labels..."
  _do_label "status:proposed"        "fbca04" "Created by agent, awaiting human decision"
  _do_label "status:approved"        "0e8a16" "Human approved — agent may pick up"
  _do_label "status:rejected"        "b60205" "Won't do — do not recreate without new data"
  _do_label "status:in-progress"     "1d76db" "Agent started; comment has branch/PR link"
  _do_label "source:posthog"         "5319e7" "From insights/analytics/* (PostHog/HogQL)"
  _do_label "source:gsc"             "5319e7" "From insights/search-console/* (GSC)"
  _do_label "source:seo"             "5319e7" "From technical/on-page SEO audit (gsc-check)"
  _do_label "source:ads"             "5319e7" "From insights/ads/* (Google Ads)"
  _do_label "source:signoz"          "5319e7" "From SigNoz observability"
  _do_label "source:security-review" "5319e7" "From security audit"
  _do_label "source:user-feedback"   "5319e7" "From insights/qualitative/*"
  _do_label "source:manual"          "5319e7" "Hypothesis without data source"
  _do_label "source:mailbox"         "5319e7" "From inbox email — incoming customer requests"
  _do_label "source:build"           "5319e7" "From build/deploy optimization audit"
  _do_label "source:uptime"          "5319e7" "From uptime / site health check"
  _do_label "source:design"          "5319e7" "From design quality routines (impeccable:audit/critique/harden)"
  _do_label "source:code-health"     "5319e7" "From fallow code-health audit (dead code, dupes, cycles, complexity)"
  _do_label "source:ci"              "5319e7" "From CI gate — failing lint/test in GitHub Actions"
  _do_label "source:docs"            "5319e7" "From docs-audit doc/code drift findings"
  _do_label "source:infra"           "5319e7" "From Coolify / deployment health checks"
  _do_label "source:vulnerability-report" "5319e7" "From GitHub Dependabot / Code Scanning / Secret Scanning"
  _do_label "ci-retry"               "e99695" "CI auto-fix in progress — fix-ci-issue retries up to 3x before escalating to needs-human"
  _do_label "action:reply"           "0052cc" "Approved mailbox issue — agent will send email reply"
  _do_label "action:fix"             "0052cc" "Approved mailbox issue — agent will make a code change"
  _do_label "needs-human"            "8b5cf6" "Agent blocked — requires human action (credentials, config, external service)"
  _do_label "priority:critical"      "b60205" "Breaks revenue or disables a feature right now"
  _do_label "priority:high"          "d93f0b" "This week"
  _do_label "priority:medium"        "fbca04" "This month"
  _do_label "priority:low"           "cccccc" "Someday / nice-to-have (issues are NOT auto-created)"
}

# ── CLAUDE.md ─────────────────────────────────────────────────────────────────

# Generates the standalone Dark Flow instructions file (.darkflow.d/claude.md).
# CLAUDE.md itself is never rewritten — only a single @-include line is added to it.
generate_darkflow_md() {
  cat << 'HEREDOC'
## Documentation & Agent Workflow

@docs/agent-workflow.md
@docs/github-issues.md
@docs/auto-approve.md

HEREDOC

  echo "**Communication language:** ${LANGUAGE} — use it ONLY for human-facing text you write *about* the work: GitHub issues, comments, commit messages, PR descriptions, and console/chat output."
  echo "**Product language:** English — everything shipped *inside* the product is always written in English, regardless of the communication language: source code, identifiers, code comments, UI copy, user-facing strings, logs, and in-product docs. Setting the communication language to anything other than English never changes this."
  echo "**Main branch:** \`${MAIN_BRANCH}\`"
  if [[ "$MERGE_STRATEGY" == "direct" ]]; then
    echo "**Fix Issues strategy:** commit and push directly to \`${MAIN_BRANCH}\` — no pull requests."
  else
    echo "**Fix Issues strategy:** open a pull request, then merge into \`${MAIN_BRANCH}\` with \`Closes #N\`."
  fi
  echo "**Workspace rule:** never create a git worktree (\`git worktree add\`) — always work in the project root on \`${MAIN_BRANCH}\`. If the PR strategy needs a feature branch, create it in place with \`git checkout -b\` based off \`${MAIN_BRANCH}\`."
  echo ""

  cat << 'HEREDOC'
### Before each session

Check approved task queue:
```bash
gh issue list --label "status:approved" --state open --json number,title,labels,body --limit 20
```
If there are approved issues matching the current context — pick them first.
Before starting: set `status:in-progress`, leave a comment with the branch name.

### When to read docs

HEREDOC

  echo "- **Any UI/UX task** → \`docs/design/voice-and-tone.md\` + \`docs/design/tokens.md\` + \`docs/design/patterns.md\` + \`docs/design/components.md\`"
  echo "- **Changing a user flow** → \`docs/spec/flows/\`"
  echo "- **Product / marketing decisions** → \`docs/product/positioning.md\` + \`docs/product/audience.md\` + \`docs/product/pricing.md\`"
  [[ "$MOD_ANALYTICS" == true ]] && echo "- **Working with analytics events** → \`docs/product/metrics.md\` (not guessing event names)"
  [[ "$MOD_ANALYTICS" == true ]] && echo "- **Context on what's working now** → last 2–3 files from \`docs/insights/analytics/\`"
  [[ "$MOD_GSC"       == true ]] && echo "- **SEO decisions** → last 2–3 files from \`docs/insights/search-console/\` and \`docs/insights/seo-audit/\`"
  [[ "$MOD_ADS"       == true ]] && echo "- **Ads campaigns** → last 2–3 files from \`docs/insights/ads/\`"
  echo "- **Before architectural changes** → \`docs/decisions/\` (check for existing ADRs)"

  echo ""
  echo "### When to write docs"
  echo ""
  echo "- **Changed a user flow** → update \`docs/spec/flows/*.md\`"
  echo "- **Added / removed a screen** → update \`docs/spec/screens/inventory.md\`"
  echo "- **Changed data model** → update \`docs/spec/data-model.md\`"
  echo "- **Changed pricing / billing** → update \`docs/product/pricing.md\`"
  echo "- **Added UI component or pattern** → update \`docs/design/components.md\` / \`docs/design/patterns.md\`"
  echo "- **Made an architectural decision** → add ADR to \`docs/decisions/\` (context → decision → how to verify)"
  [[ "$MOD_ANALYTICS" == true ]] && echo "- **After analyzing analytics** → write snapshot to \`docs/insights/analytics/YYYY-MM-DD.md\`"
  [[ "$MOD_GSC"       == true ]] && echo "- **After checking GSC** → write snapshot to \`docs/insights/search-console/YYYY-MM-DD.md\`"
  [[ "$MOD_GSC"       == true ]] && echo "- **After the SEO audit** → write snapshot to \`docs/insights/seo-audit/YYYY-MM-DD.md\`"
  [[ "$MOD_ADS"       == true ]] && echo "- **After checking ads** → write snapshot to \`docs/insights/ads/YYYY-MM-DD.md\`"

  echo ""
  echo "### Active Routines"
  echo ""
  echo "Scheduled Claude Code agents that run this workflow automatically:"
  echo ""
  echo "- **Fix issues** (Hourly) — picks up \`status:approved\` issues → PR → merge to ${MAIN_BRANCH}"
  [[ "$MOD_ANALYTICS"     == true ]] && echo "- **Analytics review** (Daily 8:00) — PostHog + recent commits → GitHub issues"
  if [[ "$MOD_OBSERVABILITY" == true ]]; then
    local _obs_label="${OBS_TOOL:-Observability tool}"
    echo "- **Observability check** (Daily 8:30) — ${_obs_label}: errors / slow queries / latency → GitHub issues"
  fi
  [[ "$MOD_GSC"           == true ]] && echo "- **GSC check** (Weekly Mon 8:00) — Google Search Console + technical/on-page SEO audit → GitHub issues"
  [[ "$MOD_ADS"           == true ]] && echo "- **Ads review** (Weekly Mon 8:00) — paid ads performance → GitHub issues"
  [[ "$MOD_COOLIFY"       == true ]] && echo "- **Coolify check deployment** (Daily 9:00) — deploy status → critical issue on failure"
  [[ "$MOD_CLAUDE_UPDATE" == true ]] && echo "- **CLAUDE.md update** (Weekdays 9:00) — re-generates this file from codebase"
  [[ "$MOD_ARCH_REVIEW"   == true ]] && echo "- **Architecture review** (Weekly Sun 2:00) — \`/improve-codebase-architecture\` → GitHub issues"
  [[ "$MOD_MAILBOX"       == true ]] && echo "- **Mailbox check** (Hourly) — IMAP inbox → GitHub issues with \`action:reply\` / \`action:fix\` choice; approved replies sent via SMTP"
  echo "- **Build optimization** (Weekly Sun 4:00) — build + deploy pipeline analysis → GitHub issues"
  echo "- **Uptime check** (Every 4h) — DNS + HTTP + page-load check; site down → auto-approved critical issue"
  [[ "$MOD_DOCS_AUDIT"    == true ]] && echo "- **Docs audit** (Weekly Sun 5:00) — docs ↔ code drift → GitHub issues"
  [[ "$MOD_FALLOW"        == true ]] && echo "- **Code health** (Weekly Sun 7:00) — \`/darkflow:code-health\` fallow audit (dead code, dupes, cycles, complexity) → GitHub issues"
  [[ "$MOD_IMPECCABLE" == true ]] && echo "- **Design audit** (Weekly Sat 10:00) — \`/impeccable:audit\` five-dimension quality check → GitHub issues"
  [[ "$MOD_IMPECCABLE" == true ]] && echo "- **Design critique** (Weekly Sat 11:00) — \`/impeccable:critique\` scored review + persona tests → GitHub issues"
  [[ "$MOD_IMPECCABLE" == true ]] && echo "- **Design harden** (Monthly 1st 10:00) — \`/impeccable:harden\` edge cases, i18n, error states → GitHub issues"
  [[ "$MOD_CI_GATE"    == true ]] && echo "- **CI gate** (GitHub Actions, on push) — failing lint/test → auto-filed \`source:ci\` issue"
  [[ "$MOD_CI_GATE"    == true ]] && echo "- **Fix CI issue** (Every 15 min) — \`/darkflow:fix-ci-issue\` picks up a \`source:ci\` issue, pushes a fix; retries up to 3x, then escalates to \`needs-human\`"
  echo ""
  echo "Schedule: \`.darkflow.d/routines.yml\`  |  Worker: one global \`~/.darkflow/darkflow-run.sh\` services every project"
  echo "Run any routine manually (from this project dir): \`~/.darkflow/darkflow-run.sh <name>\`"
  echo "List status (from this project dir): \`~/.darkflow/darkflow-run.sh --list\`"
  echo ""
  echo "### Dark Flow commands"
  echo ""
  echo "Use \`/darkflow\` inside Claude Code to check workflow health and review the approved queue."
  echo ""
  echo "Workflow commands: \`/darkflow:add-issue\`, \`/darkflow:update\`, \`/darkflow:install\`."
  echo ""
  echo "Routine commands (run any routine interactively or use as the routine prompt):"
  echo "- \`/darkflow:fix-issues\` — pick up one approved issue and close it"
  [[ "$MOD_ANALYTICS"     == true ]] && echo "- \`/darkflow:analytics-review\` — PostHog + commits → GitHub issues"
  [[ "$MOD_OBSERVABILITY" == true ]] && echo "- \`/darkflow:observability-check\` — errors / slow queries / latency → GitHub issues"
  [[ "$MOD_GSC"           == true ]] && echo "- \`/darkflow:gsc-check\` — Google Search Console + technical/on-page SEO audit → GitHub issues"
  [[ "$MOD_ADS"           == true ]] && echo "- \`/darkflow:ads-review\` — paid ads performance → GitHub issues"
  [[ "$MOD_COOLIFY"       == true ]] && echo "- \`/darkflow:coolify-check-deployment\` — deployment status check"
  [[ "$MOD_CLAUDE_UPDATE" == true ]] && echo "- \`/darkflow:claude-md-update\` — regenerate CLAUDE.md from codebase"
  [[ "$MOD_DOCS_AUDIT"        == true ]] && echo "- \`/darkflow:docs-audit\` — docs <-> code drift check → GitHub issues"
  [[ "$MOD_PRODUCT_OVERVIEW"  == true ]] && echo "- \`/darkflow:product-overview\` — product overview digest"
  [[ "$MOD_ARCH_REVIEW"   == true ]] && echo "- \`/darkflow:architecture-review\` — architectural analysis → GitHub issues"
  [[ "$MOD_MAILBOX"       == true ]] && echo "- \`/darkflow:mailbox-check\` — read new mail and send approved replies via SMTP"
  [[ "$MOD_CI_GATE"       == true ]] && echo "- \`/darkflow:fix-ci-issue\` — pick up a \`source:ci\` issue and push a fix (retries up to 3x, then needs-human)"
  echo "- \`/darkflow:security-audit\` — full security review (static + runtime) → GitHub issues"
  echo "- \`/darkflow:build-optimization\` — build + deploy optimization analysis → GitHub issues"
  echo "- \`/darkflow:csp-setup\` — wire CSP violation reporting → PostHog or internal endpoint (one-time setup)"
  echo "- \`/darkflow:uptime-check\` — DNS + HTTP + page-load check; site down → auto-approved critical issue"
  [[ "$MOD_FALLOW"        == true ]] && echo "- \`/darkflow:code-health\` — fallow audit (dead code, dupes, cycles, complexity) → GitHub issues"
  [[ "$MOD_IMPECCABLE" == true ]] && echo "- \`/darkflow:design-audit\` — five-dimension design quality check → GitHub issues"
  [[ "$MOD_IMPECCABLE" == true ]] && echo "- \`/darkflow:design-critique\` — scored design review with persona tests → GitHub issues"
  [[ "$MOD_IMPECCABLE" == true ]] && echo "- \`/darkflow:design-harden\` — production-readiness review (edge cases, i18n, error states) → GitHub issues"
  echo ""
  echo "Interactive commands (planning/design, human-in-the-loop — no issues or snapshots):"
  echo "- \`/darkflow:grill\` — pressure-test a plan against the domain model; updates glossary + ADRs inline"
}

# Writes .darkflow.d/claude.md with full Dark Flow instructions, then ensures
# CLAUDE.md has a single @-include line pointing to it. CLAUDE.md content is
# never rewritten — only the one reference line is appended if absent.
sync_claude_md() {
  if [[ "$SKIP_CLAUDE_SNIPPET" == true ]]; then
    info "Skipping Dark Flow docs (--no-claude)"
    return
  fi
  if [[ "$DRY_RUN" == true ]]; then
    info "Would write .darkflow.d/claude.md and add @-include to CLAUDE.md"
    return
  fi

  generate_darkflow_md > ".darkflow.d/claude.md"
  success "Updated .darkflow.d/claude.md"

  if [[ ! -f "CLAUDE.md" ]]; then
    { echo "# CLAUDE.md"; echo ""; echo "@.darkflow.d/claude.md"; } > CLAUDE.md
    success "Created CLAUDE.md with Dark Flow reference"
  elif ! grep -qF "@.darkflow.d/claude.md" CLAUDE.md; then
    echo "" >> CLAUDE.md
    echo "@.darkflow.d/claude.md" >> CLAUDE.md
    success "Added @.darkflow.d/claude.md reference to CLAUDE.md"
  else
    skip "CLAUDE.md already references .darkflow.d/claude.md"
  fi
}

# ── Checklist verification (embedded from check.sh) ──────────────────────────

run_checklist() {
  local _fix_mode=false
  [[ "${1:-}" == "--fix" ]] && _fix_mode=true

  if ! command -v yq >/dev/null 2>&1; then
    warn "yq not installed — skipping verification. Install: brew install yq"
    return 0
  fi

  local _checklist=""
  if [[ "$USE_LOCAL" == true && -f "$SCRIPT_DIR/checklist.yml" ]]; then
    _checklist="$SCRIPT_DIR/checklist.yml"
  else
    _checklist=$(mktemp)
    if ! curl -fsSL "${DARKFLOW_REPO}/checklist.yml?t=$(date +%s)" -o "$_checklist" 2>/dev/null; then
      warn "Could not fetch checklist.yml — skipping verification"
      return 0
    fi
  fi

  local _items_count
  _items_count=$(yq '.items | length' "$_checklist")

  # Use indexed arrays keyed by item index to avoid associative array issues
  local _missing_ids=()

  _q() { local _out; _out=$(yq -r "$1" "$_checklist" 2>/dev/null || echo ""); [[ "$_out" == "null" ]] && _out=""; echo "$_out"; }

  _module_active() {
    local _m="$1"
    # Check MODULES string (from .darkflow) and individual MOD_* vars
    [[ ",${MODULES}," == *",${_m},"* ]] && return 0
    case "$_m" in
      analytics)     [[ "$MOD_ANALYTICS"     == true ]] ;;
      observability) [[ "$MOD_OBSERVABILITY" == true ]] ;;
      gsc)           [[ "$MOD_GSC"           == true ]] ;;
      ads)           [[ "$MOD_ADS"           == true ]] ;;
      coolify)       [[ "$MOD_COOLIFY"       == true ]] ;;
      claude-update) [[ "$MOD_CLAUDE_UPDATE" == true ]] ;;
      arch-review)   [[ "$MOD_ARCH_REVIEW"   == true ]] ;;
      mailbox)          [[ "$MOD_MAILBOX"          == true ]] ;;
      docs-audit)       [[ "$MOD_DOCS_AUDIT"       == true ]] ;;
      product-overview) [[ "$MOD_PRODUCT_OVERVIEW" == true ]] ;;
      impeccable)    [[ "$MOD_IMPECCABLE"    == true ]] ;;
      fallow)        [[ "$MOD_FALLOW"        == true ]] ;;
      ci-gate)       [[ "$MOD_CI_GATE"       == true ]] ;;
      *) return 1 ;;
    esac
  }

  # Collect field arrays (bash 3-compatible via parallel indexed arrays)
  declare -a _itype _ipath _itemplate _iexec _imarker _ikey _idefault \
             _icheck _ifix _iwhen _igroup _idesc _iroutine _icron _imodel _iengine _ienabled _iid

  local _i
  for (( _i = 0; _i < _items_count; _i++ )); do
    _iid[$_i]=$(_q ".items[$_i].id")
    _itype[$_i]=$(_q ".items[$_i].type")
    _ipath[$_i]=$(_q ".items[$_i].path")
    _itemplate[$_i]=$(_q ".items[$_i].template")
    _iexec[$_i]=$(_q ".items[$_i].executable")
    _imarker[$_i]=$(_q ".items[$_i].marker_start")
    _ikey[$_i]=$(_q ".items[$_i].key")
    _idefault[$_i]=$(_q ".items[$_i].default")
    _icheck[$_i]=$(_q ".items[$_i].check")
    _ifix[$_i]=$(_q ".items[$_i].fix")
    _iwhen[$_i]=$(_q ".items[$_i].when")
    _igroup[$_i]=$(_q ".items[$_i].group")
    _idesc[$_i]=$(_q ".items[$_i].desc")
    _iroutine[$_i]=$(_q ".items[$_i].routine_key")
    _icron[$_i]=$(_q ".items[$_i].cron")
    _imodel[$_i]=$(_q ".items[$_i].model")
    _iengine[$_i]=$(_q ".items[$_i].engine")
    _ienabled[$_i]=$(_q ".items[$_i].enabled")

    local _when="${_iwhen[$_i]}"
    if [[ -n "$_when" ]]; then
      case "$_when" in
        module.*)      _module_active "${_when#module.}" || continue ;;
        platform.macos) [[ "$DETECTED_OS" == macos ]] || continue ;;
        platform.linux) [[ "$DETECTED_OS" == linux ]] || continue ;;
      esac
    fi

    local _type="${_itype[$_i]}" _path="${_ipath[$_i]}" _present=false
    case "$_type" in
      file)       [[ -f "$_path" ]] && _present=true ;;
      dir)        [[ -d "$_path" ]] && _present=true ;;
      marker)
        [[ -f "$_path" ]] && grep -qF "${_imarker[$_i]}" "$_path" && _present=true ;;
      config-key)
        [[ -f "$_path" ]] && grep -q "^${_ikey[$_i]}=" "$_path" && _present=true ;;
      command)
        local _expr="${_icheck[$_i]//\$\{SLUG\}/${SLUG}}"
        eval "$_expr" >/dev/null 2>&1 && _present=true || true ;;
      routine)
        if [[ -f "$_path" ]]; then
          local _pval
          _pval=$(yq ".routines[\"${_iroutine[$_i]}\"]" "$_path" 2>/dev/null || echo "null")
          [[ "$_pval" != "null" && -n "$_pval" ]] && _present=true
        fi ;;
    esac
    $_present || _missing_ids+=("$_i")
  done

  local _total=${#_missing_ids[@]}
  echo ""
  echo -e "${BOLD}Installation check${RESET} ${DIM}(${_items_count} checks, ${_total} missing)${RESET}"

  if [[ $_total -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed${RESET}"
    return 0
  fi

  echo ""
  for _idx in "${_missing_ids[@]}"; do
    echo -e "  ${RED}✗${RESET} ${_ipath[$_idx]:-${_icheck[$_idx]}}  ${DIM}— ${_idesc[$_idx]}${RESET}"
  done
  echo ""

  if [[ "$_fix_mode" != true ]]; then
    warn "Run install.sh --force to repair missing items."
    return 1
  fi

  local _fixed=0 _skipped=0

  _chk_copy_template() {
    local _idx="$1"
    local _rel="${_itemplate[$_idx]:-${_ipath[$_idx]}}"
    local _dest="${_ipath[$_idx]}"
    mkdir -p "$(dirname "$_dest")"
    if [[ "$USE_LOCAL" == true && -f "$SOURCE_DIR/$_rel" ]]; then
      cp "$SOURCE_DIR/$_rel" "$_dest"
    else
      curl -fsSL "${DARKFLOW_REPO}/templates/${_rel}?t=$(date +%s)" -o "$_dest"
    fi
    [[ "${_iexec[$_idx]}" == "true" ]] && chmod +x "$_dest"
    success "  Restored: $_dest"
  }

  _chk_mkdir() {
    local _d="${_ipath[$1]}"
    mkdir -p "$_d"
    [[ ! -e "$_d/.gitkeep" ]] && touch "$_d/.gitkeep"
    success "  Created: $_d/"
  }

  _chk_append_config() {
    local _idx="$1" _key="${_ikey[$1]}" _def="${_idefault[$1]}" _file="${_ipath[$1]}"
    if [[ -z "$_def" ]]; then
      warn "  ${_key} missing in ${_file} — re-run install.sh"
      return 1
    fi
    echo "${_key}=${_def}" >> "$_file"
    success "  Added ${_key}=${_def} to ${_file}"
  }

  _chk_add_routine() {
    local _idx="$1"
    local _file="${_ipath[$_idx]}" _key="${_iroutine[$_idx]}"
    local _cron="${_icron[$_idx]}" _model="${_imodel[$_idx]:-sonnet}" _enabled="${_ienabled[$_idx]:-true}"
    local _engine="${_iengine[$_idx]:-claude}"
    if [[ ! -f "$_file" ]]; then
      warn "  $_file missing — re-run install.sh"
      return 1
    fi
    yq -i ".routines[\"${_key}\"] = {\"cron\": \"${_cron}\", \"model\": \"${_model}\", \"engine\": \"${_engine}\", \"enabled\": ${_enabled}}" "$_file"
    success "  Added routine ${_key} to ${_file}"
  }

  _chk_install_arch_skill() {
    if ! command -v npx >/dev/null 2>&1; then
      warn "  npx not found — install Node.js first"; return 1
    fi
    npx skills add https://github.com/mattpocock/skills --skill improve-codebase-architecture
  }

  _chk_regenerate_marker() {
    local _path="${_ipath[$1]}"
    case "$_path" in
      Makefile) sync_makefile ;;
      *) warn "  Unknown marker path: $_path"; return 1 ;;
    esac
  }

  _chk_add_darkflow_ref() {
    if [[ ! -f "CLAUDE.md" ]]; then
      { echo "# CLAUDE.md"; echo ""; echo "@.darkflow.d/claude.md"; } > CLAUDE.md
      success "  Created CLAUDE.md with Dark Flow reference"
    else
      echo "" >> CLAUDE.md
      echo "@.darkflow.d/claude.md" >> CLAUDE.md
      success "  Added @.darkflow.d/claude.md reference to CLAUDE.md"
    fi
  }

  for _idx in "${_missing_ids[@]}"; do
    local _handler="${_ifix[$_idx]}"
    if [[ -z "$_handler" ]]; then
      warn "  No fix handler for ${_iid[$_idx]:-item $_idx}"
      _skipped=$(( _skipped + 1 ))
      continue
    fi
    case "$_handler" in
      copy-template)      _chk_copy_template "$_idx"   && _fixed=$((_fixed+1)) || _skipped=$((_skipped+1)) ;;
      mkdir)              _chk_mkdir "$_idx"            && _fixed=$((_fixed+1)) || _skipped=$((_skipped+1)) ;;
      append-config)      _chk_append_config "$_idx"   && _fixed=$((_fixed+1)) || _skipped=$((_skipped+1)) ;;
      install-arch-skill) _chk_install_arch_skill      && _fixed=$((_fixed+1)) || _skipped=$((_skipped+1)) ;;
      add-routine)        _chk_add_routine "$_idx"     && _fixed=$((_fixed+1)) || _skipped=$((_skipped+1)) ;;
      regenerate-marker)  _chk_regenerate_marker "$_idx"  && _fixed=$((_fixed+1)) || _skipped=$((_skipped+1)) ;;
      add-darkflow-ref)   _chk_add_darkflow_ref          && _fixed=$((_fixed+1)) || _skipped=$((_skipped+1)) ;;
      *)
        warn "  Unknown handler '${_handler}' for ${_iid[$_idx]:-item $_idx}"
        _skipped=$(( _skipped + 1 )) ;;
    esac
  done

  echo ""
  echo -e "${BOLD}Verification done${RESET} — fixed ${GREEN}${_fixed}${RESET}, skipped ${YELLOW}${_skipped}${RESET} of ${_total}"
  [[ $_skipped -eq 0 ]] && return 0 || return 1
}

# ── Web UI sync ───────────────────────────────────────────────────────────────

# Registers this project (incl. its localPath) and pushes GitHub issues to the
# web UI via the global worker's --sync (run from the project dir, which the
# worker resolves from cwd). localPath is what lets the global worker discover it.
web_sync() {
  local _url
  _url=$(read_config webapp_url "$WEBAPP_URL")
  if [[ -n "$_url" && -x "${GLOBAL_DIR}/darkflow-run.sh" ]]; then
    if bash "${GLOBAL_DIR}/darkflow-run.sh" --sync >/dev/null 2>&1; then
      success "Registered project + synced GitHub issues to web UI (${_url})"
    else
      info "Web UI sync skipped — run 'make df-sync' to retry"
    fi
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# Stages
# ══════════════════════════════════════════════════════════════════════════════

# ── 1. Directory structure ────────────────────────────────────────────────────

header "1/4  Docs structure"

make_dir "docs/product"
make_dir "docs/spec/flows"
make_dir "docs/spec/screens"
make_dir "docs/design/assets"
make_dir "docs/insights/qualitative"
make_dir "docs/decisions"
make_dir ".github/ISSUE_TEMPLATE"
make_dir ".darkflow.d"
make_dir ".darkflow.d/state"

[[ "$MOD_ANALYTICS" == true ]] && make_dir "docs/insights/analytics"
[[ "$MOD_GSC"       == true ]] && make_dir "docs/insights/search-console"
[[ "$MOD_GSC"       == true ]] && make_dir "docs/insights/seo-audit"
[[ "$MOD_ADS"       == true ]] && make_dir "docs/insights/ads"

# ── 2. Template files ─────────────────────────────────────────────────────────

header "2/4  Template files"

smart_update_template "docs/README.md"             "docs/README.md"
smart_update_template "docs/agent-workflow.md"     "docs/agent-workflow.md"
smart_update_template "docs/github-issues.md"      "docs/github-issues.md"
smart_update_template "docs/auto-approve.md"       "docs/auto-approve.md"
smart_update_template "docs/decisions/TEMPLATE.md" "docs/decisions/TEMPLATE.md"
smart_update_template ".github/ISSUE_TEMPLATE/recommendation.yml" \
                      ".github/ISSUE_TEMPLATE/recommendation.yml"

[[ "$DRY_RUN" == false && -f "docs/README.md" ]] && inject_name "docs/README.md"

# Slash commands + the worker itself are installed once into user/home scope by
# global_bootstrap (below) — not copied per project anymore. The project keeps
# only its own operational files: get-config.sh, mailbox scripts, ci-gate workflow.
smart_update_template "darkflow/get-config.sh"          ".darkflow.d/get-config.sh"          "true"

if [[ "$MOD_MAILBOX" == true ]]; then
  smart_update_template "darkflow/mailbox/fetch.py" ".darkflow.d/mailbox/fetch.py" "true"
  smart_update_template "darkflow/mailbox/send.py"  ".darkflow.d/mailbox/send.py"  "true"
fi

if [[ "$MOD_CI_GATE" == true ]]; then
  make_dir ".github/workflows"
  smart_update_template ".github/workflows/darkflow-ci-gate.yml" ".github/workflows/darkflow-ci-gate.yml"
fi

# Install / refresh the single global worker + all user-scope slash commands, and
# clean up any legacy per-project worker/command copies left by older installs.
global_bootstrap

# ── 3. Config (.darkflow) ─────────────────────────────────────────────────────

header "3/4  Config"

if [[ "$DRY_RUN" == false ]]; then
  if [[ "$MODE" == "fresh" ]]; then
    _local_mods=""
    [[ "$MOD_ANALYTICS"     == true ]] && _local_mods="${_local_mods}analytics,"
    [[ "$MOD_OBSERVABILITY" == true ]] && _local_mods="${_local_mods}observability,"
    [[ "$MOD_GSC"           == true ]] && _local_mods="${_local_mods}gsc,"
    [[ "$MOD_ADS"           == true ]] && _local_mods="${_local_mods}ads,"
    [[ "$MOD_COOLIFY"       == true ]] && _local_mods="${_local_mods}coolify,"
    [[ "$MOD_CLAUDE_UPDATE" == true ]] && _local_mods="${_local_mods}claude-update,"
    [[ "$MOD_ARCH_REVIEW"   == true ]] && _local_mods="${_local_mods}arch-review,"
    [[ "$MOD_MAILBOX"       == true ]] && _local_mods="${_local_mods}mailbox,"
    [[ "$MOD_DOCS_AUDIT"        == true ]] && _local_mods="${_local_mods}docs-audit,"
    [[ "$MOD_PRODUCT_OVERVIEW"  == true ]] && _local_mods="${_local_mods}product-overview,"
    [[ "$MOD_IMPECCABLE"        == true ]] && _local_mods="${_local_mods}impeccable,"
    [[ "$MOD_FALLOW"            == true ]] && _local_mods="${_local_mods}fallow,"
    [[ "$MOD_CI_GATE"           == true ]] && _local_mods="${_local_mods}ci-gate,"
    {
      echo "# Dark Flow project config — managed by install.sh"
      echo "version=${LATEST_VERSION}"
      echo "installed=$(date -u +%Y-%m-%d)"
      echo "language=${LANGUAGE}"
      echo "branch=${MAIN_BRANCH}"
      echo "merge_strategy=${MERGE_STRATEGY}"
      echo "modules=${_local_mods%,}"
      [[ -n "$OBS_TOOL"           ]] && echo "obs_tool=${OBS_TOOL}"
      [[ -n "$OBS_URL"            ]] && echo "obs_url=${OBS_URL}"
      [[ -n "$POSTHOG_PROJECT_ID" ]] && echo "posthog_project_id=${POSTHOG_PROJECT_ID}"
      echo "slug=${SLUG}"
      echo "name=${PROJECT_NAME}"
      echo "webapp_url=${WEBAPP_URL}"
      echo "max_concurrent=3"
    } > .darkflow
    success "Created .darkflow (v${LATEST_VERSION})"
  else
    # Update version/date; append any missing keys
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "s/^version=.*/version=${LATEST_VERSION}/" .darkflow
      sed -i '' "s/^installed=.*/installed=$(date -u +%Y-%m-%d)/" .darkflow
    else
      sed -i "s/^version=.*/version=${LATEST_VERSION}/" .darkflow
      sed -i "s/^installed=.*/installed=$(date -u +%Y-%m-%d)/" .darkflow
    fi
    grep -q "^version="    .darkflow || echo "version=${LATEST_VERSION}" >> .darkflow
    grep -q "^slug="       .darkflow || echo "slug=${SLUG}"            >> .darkflow
    grep -q "^name="       .darkflow || echo "name=${PROJECT_NAME}"    >> .darkflow
    grep -q "^webapp_url=" .darkflow || echo "webapp_url=${WEBAPP_URL}" >> .darkflow
    [[ -n "$POSTHOG_PROJECT_ID" ]] && { grep -q "^posthog_project_id=" .darkflow && \
      { [[ "$(uname)" == "Darwin" ]] && sed -i '' "s/^posthog_project_id=.*/posthog_project_id=${POSTHOG_PROJECT_ID}/" .darkflow || \
        sed -i "s/^posthog_project_id=.*/posthog_project_id=${POSTHOG_PROJECT_ID}/" .darkflow; } || \
      echo "posthog_project_id=${POSTHOG_PROJECT_ID}" >> .darkflow; }
    success "Updated .darkflow to v${LATEST_VERSION}"
  fi

  # Integration credentials — always live in the project's main .env. We append
  # only the keys that aren't already there, so re-runs never clobber values the
  # user edited by hand.
  if [[ -n "$OBS_URL" || -n "$OBS_API_KEY" || -n "$MAILBOX_IMAP_HOST" ]]; then
    touch .env
    _env_new=""
    _env_add() { # _env_add KEY VALUE [COMMENT]
      local k="$1" v="$2" c="${3:-}"
      [[ -z "$v" ]] && return
      grep -q "^${k}=" .env 2>/dev/null && return  # keep existing value
      [[ -n "$c" ]] && _env_new+="${c}"$'\n'
      _env_new+="${k}=${v}"$'\n'
    }
    if [[ -n "$OBS_URL" || -n "$OBS_API_KEY" ]]; then
      _env_add OBSERVABILITY_URL "$OBS_URL" "# ${OBS_TOOL:-Observability}"
      _env_add OBSERVABILITY_API_KEY "$OBS_API_KEY"
    fi
    if [[ -n "$MAILBOX_IMAP_HOST" ]]; then
      _env_add MAILBOX_IMAP_HOST "$MAILBOX_IMAP_HOST" "# Mailbox — IMAP (incoming)"
      _env_add MAILBOX_IMAP_PORT "${MAILBOX_IMAP_PORT:-993}"
      _env_add MAILBOX_IMAP_USER "$MAILBOX_IMAP_USER"
      _env_add MAILBOX_IMAP_PASSWORD "$MAILBOX_IMAP_PASSWORD"
      _env_add MAILBOX_SMTP_HOST "$MAILBOX_SMTP_HOST" "# Mailbox — SMTP (outgoing replies)"
      _env_add MAILBOX_SMTP_PORT "${MAILBOX_SMTP_PORT:-587}"
      _env_add MAILBOX_SMTP_USER "$MAILBOX_SMTP_USER"
      _env_add MAILBOX_SMTP_PASSWORD "$MAILBOX_SMTP_PASSWORD"
    fi
    if [[ -n "$_env_new" ]]; then
      { echo ""; echo "# Dark Flow — integration credentials"; printf '%s' "$_env_new"; } >> .env
      success "Credentials appended to .env (git-ignored)"
    else
      success "Integration credentials already present in .env"
    fi
    grep -qxF ".env" .gitignore 2>/dev/null || echo ".env" >> .gitignore
  fi

  # .gitignore entries
  for _gi in ".darkflow.d/state/" ".darkflow.d/mailbox/state/" ".darkflow.d/*.log"; do
    grep -qF "$_gi" .gitignore 2>/dev/null || { echo "$_gi" >> .gitignore; success "Added ${_gi} to .gitignore"; }
  done
fi

# ── 4. routines.yml ───────────────────────────────────────────────────────────

if [[ ! -f ".darkflow.d/routines.yml" || "$FORCE" == true ]]; then
  if [[ "$DRY_RUN" == false ]]; then
    {
      cat << 'YAML'
# Dark Flow routine schedule — generated by install.sh. Safe to edit after installation.
# A single global worker (~/.darkflow/darkflow-run.sh) reads this for every project.
# Run a routine manually (from this project dir):   ~/.darkflow/darkflow-run.sh <name>
# List routines and status (from this project dir): ~/.darkflow/darkflow-run.sh --list
defaults:
  model: sonnet
  engine: claude
  permission_mode: bypassPermissions

routines:
  fix-issues:
    cron: "0 * * * *"
    model: sonnet
    engine: claude
    enabled: true
YAML

      [[ "$MOD_ANALYTICS" == true ]] && cat << 'YAML'

  analytics-review:
    cron: "0 8 * * *"
    model: sonnet
    engine: claude
    enabled: true
YAML

      [[ "$MOD_OBSERVABILITY" == true ]] && cat << 'YAML'

  observability-check:
    cron: "30 8 * * *"
    model: sonnet
    engine: claude
    enabled: true
YAML

      [[ "$MOD_GSC" == true ]] && cat << 'YAML'

  gsc-check:
    cron: "0 8 * * 1"
    model: sonnet
    engine: claude
    enabled: true
YAML

      [[ "$MOD_ADS" == true ]] && cat << 'YAML'

  ads-review:
    cron: "0 8 * * 1"
    model: sonnet
    engine: claude
    enabled: true
YAML

      [[ "$MOD_COOLIFY" == true ]] && cat << 'YAML'

  coolify-check-deployment:
    cron: "0 9 * * *"
    model: sonnet
    engine: claude
    enabled: true
YAML

      [[ "$MOD_CLAUDE_UPDATE" == true ]] && cat << 'YAML'

  claude-md-update:
    cron: "0 9 * * 1-5"
    model: sonnet
    engine: claude
    enabled: true
YAML

      [[ "$MOD_ARCH_REVIEW" == true ]] && cat << 'YAML'

  architecture-review:
    cron: "0 2 * * 0"
    model: opus
    engine: claude
    enabled: true
YAML

      [[ "$MOD_FALLOW" == true ]] && cat << 'YAML'

  code-health:
    cron: "0 7 * * 0"
    model: sonnet
    engine: claude
    enabled: true
YAML

      [[ "$MOD_DOCS_AUDIT" == true ]] && cat << 'YAML'

  docs-audit:
    cron: "0 5 * * 0"
    model: opus
    engine: claude
    enabled: true
YAML

      [[ "$MOD_PRODUCT_OVERVIEW" == true ]] && cat << 'YAML'

  product-overview:
    cron: "0 7 * * 1"
    model: opus
    engine: claude
    enabled: true
YAML

      [[ "$MOD_IMPECCABLE" == true ]] && cat << 'YAML'

  design-audit:
    cron: "0 10 * * 6"
    model: opus
    engine: claude
    enabled: true

  design-critique:
    cron: "0 11 * * 6"
    model: opus
    engine: claude
    enabled: true

  design-harden:
    cron: "0 10 1 * *"
    model: opus
    engine: claude
    enabled: true
YAML

      [[ "$MOD_MAILBOX" == true ]] && cat << 'YAML'

  mailbox-check:
    cron: "0 * * * *"
    model: sonnet
    engine: claude
    enabled: true
YAML

      [[ "$MOD_CI_GATE" == true ]] && cat << 'YAML'

  fix-ci-issue:
    cron: "*/15 * * * *"
    model: sonnet
    engine: claude
    enabled: true
YAML

      cat << 'YAML'

  security-audit:
    cron: "0 3 * * 0"
    model: opus
    engine: claude
    enabled: true

  build-optimization:
    cron: "0 4 * * 0"
    model: opus
    engine: claude
    enabled: true

  uptime-check:
    cron: "0 */4 * * *"
    model: sonnet
    engine: claude
    enabled: true

  vulnerability-check:
    cron: "0 6 * * *"
    model: sonnet
    engine: claude
    enabled: true
YAML

      echo ""
    } > ".darkflow.d/routines.yml"

    # Stagger routine minutes per-project so independent projects don't all
    # dispatch on the same minute (e.g. every fix-issues at :00) and saturate
    # the global concurrency semaphore. Offset is deterministic from the slug,
    # so the same project always lands on the same minute; relative spacing
    # between a project's own routines is preserved.
    _cron_offset=$(( $(printf '%s' "$SLUG" | cksum | cut -d' ' -f1) % 60 ))
    _stagger_tmp=$(mktemp)
    awk -v off="$_cron_offset" '
      /^[[:space:]]+cron:[[:space:]]*"/ && match($0, /"[^"]*"/) {
        q = substr($0, RSTART + 1, RLENGTH - 2)
        n = split(q, f, " ")
        if (f[1] ~ /^[0-9]+$/) {
          f[1] = (f[1] + off) % 60
          nq = f[1]; for (i = 2; i <= n; i++) nq = nq " " f[i]
          sub(/"[^"]*"/, "\"" nq "\"", $0)
        }
      }
      { print }
    ' ".darkflow.d/routines.yml" > "$_stagger_tmp" && mv "$_stagger_tmp" ".darkflow.d/routines.yml"

    success "Created .darkflow.d/routines.yml (minute offset +${_cron_offset})"
  else
    info "Would create: .darkflow.d/routines.yml"
  fi
else
  skip ".darkflow.d/routines.yml (project-specific — edit manually)"
fi

# ── 5. GitHub labels, CLAUDE.md, Makefile ────────────────────────────────────

header "4/4  Labels, CLAUDE.md, Makefile"
setup_labels
sync_claude_md
sync_makefile

# ── Legacy per-project scheduler cleanup ──────────────────────────────────────
# Dark Flow used to run one dispatcher per project (started by a per-slug launchd
# job or crontab line). The single global worker (com.darkflow.worker) replaces
# them, so remove any per-project scheduler left over from older installs.

if [[ "$DRY_RUN" == false ]]; then
  if [[ "$DETECTED_OS" == "macos" ]]; then
    _plist="$HOME/Library/LaunchAgents/com.darkflow.${SLUG}.plist"
    if [[ -f "$_plist" ]]; then
      launchctl unload "$_plist" 2>/dev/null || true
      rm -f "$_plist"
      success "Removed legacy per-project launchd job: com.darkflow.${SLUG}"
    fi
  elif [[ "$DETECTED_OS" == "linux" ]]; then
    if crontab -l 2>/dev/null | grep -q "# darkflow:${SLUG}"; then
      (crontab -l 2>/dev/null | grep -v "# darkflow:${SLUG}") | crontab -
      success "Removed legacy per-project crontab entry: darkflow:${SLUG}"
    fi
  fi
  # Drop the obsolete `scheduler` module marker from .darkflow if present.
  if [[ "$MODULES" == *"scheduler"* && -f .darkflow ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "s/,scheduler//g; s/scheduler,//g; s/^modules=scheduler$/modules=/" .darkflow
    else
      sed -i "s/,scheduler//g; s/scheduler,//g; s/^modules=scheduler$/modules=/" .darkflow
    fi
  fi
fi

# ── Architecture review skill ─────────────────────────────────────────────────

if [[ "$MOD_ARCH_REVIEW" == true && "$DRY_RUN" == false ]]; then
  if ! command -v npx &>/dev/null; then
    warn "npx not found — install Node.js to use the architecture review skill"
  else
    info "Installing improve-codebase-architecture skill..."
    npx skills add https://github.com/mattpocock/skills --skill improve-codebase-architecture 2>&1 \
      && success "Skill installed — use /improve-codebase-architecture in Claude Code" \
      || warn "Skill install failed. Run manually: npx skills add https://github.com/mattpocock/skills --skill improve-codebase-architecture"
  fi
fi

# ── Code health (fallow) skill ────────────────────────────────────────────────

if [[ "$MOD_FALLOW" == true && "$DRY_RUN" == false ]]; then
  if ! command -v git &>/dev/null; then
    warn "git not found — cannot install the fallow skill"
  elif [[ -d "$HOME/.claude/skills/fallow" ]]; then
    info "fallow skill already installed — skipping"
  else
    info "Installing fallow skill..."
    _fallow_tmp="$(mktemp -d)"
    if git clone --depth 1 https://github.com/fallow-rs/fallow-skills.git "$_fallow_tmp/fallow-skills" >/dev/null 2>&1; then
      mkdir -p "$HOME/.claude/skills"
      cp -R "$_fallow_tmp/fallow-skills/fallow/skills/fallow" "$HOME/.claude/skills/fallow" \
        && success "fallow skill installed — code-health routine will use it" \
        || warn "fallow skill copy failed. Install manually: see routines/code-health.md"
    else
      warn "fallow skill clone failed. Install manually: see routines/code-health.md"
    fi
    rm -rf "$_fallow_tmp"
  fi
fi

# ── Verification ──────────────────────────────────────────────────────────────

header "Verification"
run_checklist --fix || true

# ── Web UI sync ───────────────────────────────────────────────────────────────

web_sync

# ── Done ──────────────────────────────────════════════════════════════════════

echo ""
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}Dry run complete — no changes were applied. Remove --dry-run to apply.${RESET}"
elif [[ "$MODE" == "fresh" ]]; then
  echo -e "${GREEN}${BOLD}Dark Flow installed (v${LATEST_VERSION}) in ${TARGET_DIR}${RESET}"
  echo ""
  echo "Next steps:"
  echo "  1. Fill in docs/product/ — what are you building and for whom"
  echo "  2. Fill in docs/spec/    — user flows, screens, data model"
  echo "  3. Fill in docs/design/  — tokens, components, voice and tone"
  echo "  4. Commit: git add docs/ .github/ISSUE_TEMPLATE/ CLAUDE.md .darkflow .darkflow.d/ && git commit -m 'chore: install dark-flow'"
  echo "  5. Open ${WEBAPP_URL} in a browser — projects and issues sync automatically"
else
  echo -e "${GREEN}${BOLD}Dark Flow updated to v${LATEST_VERSION}${RESET}"
  echo ""
  echo "Commit the changes:"
  echo "  git add .darkflow .darkflow.d/ docs/ CLAUDE.md Makefile"
  echo "  git commit -m 'chore: update dark-flow to ${LATEST_VERSION}'"
fi

echo ""
echo -e "${BOLD}Routines${RESET}"
echo ""
if [[ "$MERGE_STRATEGY" == "direct" ]]; then
  echo "  fix-issues           0 * * * *      Picks up status:approved → commit → push to ${MAIN_BRANCH}"
else
  echo "  fix-issues           0 * * * *      Picks up status:approved → PR → merge into ${MAIN_BRANCH}"
fi
echo "  security-audit       0 3 * * 0      Full security review → GitHub issues"
echo "  build-optimization   0 4 * * 0      Build + deploy pipeline analysis → GitHub issues"
echo "  uptime-check         0 */4 * * *    DNS + HTTP + page-load check → critical issue if site down"
echo "  vulnerability-check  0 6 * * *      GitHub Dependabot + code scanning → GitHub issues"
[[ "$MOD_ANALYTICS"     == true ]] && echo "  analytics-review     0 8 * * *      PostHog + commits → GitHub issues"
[[ "$MOD_OBSERVABILITY" == true ]] && echo "  observability-check  30 8 * * *     Errors / latency → GitHub issues"
[[ "$MOD_GSC"           == true ]] && echo "  gsc-check            0 8 * * 1      Google Search Console + SEO audit → GitHub issues"
[[ "$MOD_ADS"           == true ]] && echo "  ads-review           0 8 * * 1      Paid ads performance → GitHub issues"
[[ "$MOD_COOLIFY"       == true ]] && echo "  coolify-check-deploy 0 9 * * *      Deployment status → critical issue on failure"
[[ "$MOD_CLAUDE_UPDATE" == true ]] && echo "  claude-md-update     0 9 * * 1-5    Re-generates CLAUDE.md from codebase"
[[ "$MOD_DOCS_AUDIT"        == true ]] && echo "  docs-audit           0 5 * * 0      Docs <-> code drift → GitHub issues"
[[ "$MOD_PRODUCT_OVERVIEW"  == true ]] && echo "  product-overview     0 7 * * 1      Product overview digest"
[[ "$MOD_ARCH_REVIEW"   == true ]] && echo "  architecture-review  0 2 * * 0      Architectural analysis → GitHub issues"
[[ "$MOD_FALLOW"        == true ]] && echo "  code-health          0 7 * * 0      fallow audit (dead code, dupes, cycles) → GitHub issues"
[[ "$MOD_IMPECCABLE"    == true ]] && echo "  design-audit         0 10 * * 6     Design quality check (impeccable:audit) → GitHub issues"
[[ "$MOD_IMPECCABLE"    == true ]] && echo "  design-critique      0 11 * * 6     Scored design review (impeccable:critique) → GitHub issues"
[[ "$MOD_IMPECCABLE"    == true ]] && echo "  design-harden        0 10 1 * *     Production-readiness review (impeccable:harden) → GitHub issues"
[[ "$MOD_CI_GATE"       == true ]] && echo "  fix-ci-issue         */15 * * * *   Picks up source:ci issue → push fix; retries up to 3x, then needs-human"
echo ""
echo -e "  ${DIM}Minutes shown are baselines; this project's actual cron minute is offset by"
echo -e "  +$(( $(printf '%s' "$SLUG" | cksum | cut -d' ' -f1) % 60 )) so independent projects don't all dispatch on the same minute. See routines.yml.${RESET}"
echo ""
echo -e "  ${DIM}One global worker (~/.darkflow/darkflow-run.sh) services every project."
echo -e "  Start it yourself (no auto-start), then it runs until you stop it:${RESET}"
echo -e "  Start worker:  ${DIM}nohup ${BASH_BIN} ~/.darkflow/darkflow-run.sh >/dev/null 2>> ~/.darkflow/worker.err.log &${RESET}"
echo -e "  Stop worker:   ${DIM}pkill -f ~/.darkflow/darkflow-run.sh${RESET}"
echo ""
echo -e "  Run one routine:  ${DIM}~/.darkflow/darkflow-run.sh <name>   (from this project dir)${RESET}"
echo -e "  Show status:      ${DIM}~/.darkflow/darkflow-run.sh --list   (from this project dir)${RESET}"
echo -e "  Dry run:          ${DIM}~/.darkflow/darkflow-run.sh --dry-run (from this project dir)${RESET}"
echo ""
