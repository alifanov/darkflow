#!/usr/bin/env bash
# Dark Flow installer
#
# Interactive:   bash install.sh
# All modules:   bash install.sh --all
# Pick modules:  bash install.sh --with-analytics --with-gsc --with-coolify
# Set language:  bash install.sh --lang Russian
# One-liner:     bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh)
# Silent:        bash install.sh --yes  (core only, no prompts)

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

DARKFLOW_REPO="https://raw.githubusercontent.com/alifanov/darkflow/main"
TARGET_DIR="${PWD}"
PROJECT_NAME=""
LANGUAGE=""           # Language for agent outputs and GitHub issues (default: English)
MAIN_BRANCH=""        # Main branch name (default: main)
MERGE_STRATEGY=""     # "pr" = create PR then merge | "direct" = commit directly to main
SKIP_LABELS=false
SKIP_CLAUDE_SNIPPET=false
FORCE=false
NON_INTERACTIVE=false

# Optional modules (set via flags or interactive prompts)
MOD_ANALYTICS=""      # PostHog, Mixpanel, etc.
MOD_OBSERVABILITY=""  # SigNoz, Datadog, etc.
MOD_GSC=""            # Google Search Console
MOD_ADS=""            # Google Ads, Meta Ads, etc.
MOD_COOLIFY=""        # Coolify deployment monitoring
MOD_CLAUDE_UPDATE=""  # Auto-regenerate CLAUDE.md
MOD_ARCH_REVIEW=""    # Architecture review skill (improve-codebase-architecture)
SETUP_SCHEDULER=""    # Install system scheduler (launchd/cron) for the dispatcher

# Integration credentials (collected interactively or via flags)
OBS_TOOL=""           # Observability tool name (SigNoz / Datadog / Grafana / Other)
OBS_URL=""            # Observability tool base URL
OBS_API_KEY=""        # Observability API key

# ── Colours ───────────────────────────────────────────────────────────────────

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
DIM="\033[2m"
RESET="\033[0m"

info()    { echo -e "${CYAN}▸ $*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
dim()     { echo -e "${DIM}  $*${RESET}"; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)               PROJECT_NAME="$2"; shift 2 ;;
    --lang)               LANGUAGE="$2"; shift 2 ;;
    --no-labels)          SKIP_LABELS=true; shift ;;
    --no-claude)          SKIP_CLAUDE_SNIPPET=true; shift ;;
    --force)              FORCE=true; shift ;;
    --target)             TARGET_DIR="$2"; shift 2 ;;
    --all)                NON_INTERACTIVE=true
                          MOD_ANALYTICS=true MOD_OBSERVABILITY=true MOD_GSC=true
                          MOD_ADS=true MOD_COOLIFY=true MOD_CLAUDE_UPDATE=true
                          MOD_ARCH_REVIEW=true SETUP_SCHEDULER=true
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
    --with-scheduler)     SETUP_SCHEDULER=true; shift ;;
    --no-scheduler)       SETUP_SCHEDULER=false; shift ;;
    --obs-tool)           OBS_TOOL="$2"; shift 2 ;;
    --obs-url)            OBS_URL="$2"; shift 2 ;;
    --obs-api-key)        OBS_API_KEY="$2"; shift 2 ;;
    --branch)             MAIN_BRANCH="$2"; shift 2 ;;
    --merge-pr)           MERGE_STRATEGY="pr"; shift ;;
    --merge-direct)       MERGE_STRATEGY="direct"; shift ;;
    -y|--yes)             NON_INTERACTIVE=true; shift ;;
    -h|--help)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --name NAME           Project name (default: directory name)"
      echo "  --lang LANGUAGE       Language for agent outputs and issues (default: English)"
      echo "                        Examples: --lang Russian  --lang Spanish  --lang \"Brazilian Portuguese\""
      echo "  --all                 Enable all optional modules non-interactively"
      echo "  -y, --yes             Accept defaults non-interactively (no optional modules)"
      echo "  --with-analytics      Include analytics module (PostHog/Mixpanel)"
      echo "  --with-observability  Include observability module (SigNoz/Datadog)"
      echo "  --with-gsc            Include Google Search Console module"
      echo "  --with-ads            Include paid ads module (Google Ads/Meta)"
      echo "  --with-coolify        Include Coolify deployment monitoring"
      echo "  --with-claude-update  Include auto CLAUDE.md regeneration routine"
      echo "  --with-arch-review    Install improve-codebase-architecture skill + weekly routine"
      echo "  --with-scheduler      Install system scheduler (launchd on macOS / cron on Linux)"
      echo "  --no-scheduler        Skip system scheduler setup"
      echo "  --branch NAME         Main branch name (default: main)"
      echo "  --merge-pr            Fix issues via pull requests (default)"
      echo "  --merge-direct        Fix issues by committing directly to main branch"
      echo "  --no-labels           Skip GitHub label setup"
      echo "  --no-claude           Skip CLAUDE.md creation"
      echo "  --force               Overwrite existing files"
      echo "  --target DIR          Install into DIR instead of current directory"
      exit 0
      ;;
    *) warn "Unknown argument: $1"; shift ;;
  esac
done

# ── Resolve source (local clone or remote) ────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/templates/docs/agent-workflow.md" ]]; then
  USE_LOCAL=true
  SOURCE_DIR="$SCRIPT_DIR/templates"
  info "Using local templates from $SCRIPT_DIR"
else
  USE_LOCAL=false
  info "Fetching templates from GitHub..."
fi

# ── Project name ──────────────────────────────────────────────────────────────

if [[ -z "$PROJECT_NAME" ]]; then
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    inferred=$(node -p "require('./package.json').name" 2>/dev/null || true)
    [[ -n "$inferred" ]] && PROJECT_NAME="$inferred"
  fi
  [[ -z "$PROJECT_NAME" ]] && PROJECT_NAME="$(basename "$TARGET_DIR")"

  if [[ "$NON_INTERACTIVE" == false ]]; then
    read -rp "Project name [${PROJECT_NAME}]: " input
    [[ -n "$input" ]] && PROJECT_NAME="$input"
  fi
fi

header "Installing Dark Flow for \"${PROJECT_NAME}\""

# ── Language selection ────────────────────────────────────────────────────────

if [[ -z "$LANGUAGE" ]]; then
  if [[ "$NON_INTERACTIVE" == true ]] || [[ ! -t 0 ]]; then
    LANGUAGE="English"
  else
    echo ""
    echo -e "${BOLD}Language${RESET} — used in GitHub issues, agent outputs, and CLAUDE.md"
    echo ""
    echo "  1) English (default)"
    echo "  2) Russian"
    echo "  3) Spanish"
    echo "  4) German"
    echo "  5) Other"
    echo ""
    read -rp "  Choice [1]: " lang_choice
    case "${lang_choice:-1}" in
      1|"")    LANGUAGE="English" ;;
      2)       LANGUAGE="Russian" ;;
      3)       LANGUAGE="Spanish" ;;
      4)       LANGUAGE="German" ;;
      5)       read -rp "  Language name: " LANGUAGE
               [[ -z "$LANGUAGE" ]] && LANGUAGE="English" ;;
      *)       LANGUAGE="$lang_choice" ;;  # allow typing a name directly
    esac
    echo ""
  fi
fi

info "Language: ${LANGUAGE}"

# ── Branch & merge strategy ───────────────────────────────────────────────────

if [[ -z "$MAIN_BRANCH" ]]; then
  if [[ "$NON_INTERACTIVE" == true ]] || [[ ! -t 0 ]]; then
    # Auto-detect from git, fall back to "main"
    MAIN_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    [[ "$MAIN_BRANCH" == "HEAD" ]] && MAIN_BRANCH="main"
  else
    detected=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    [[ "$detected" == "HEAD" ]] && detected="main"
    echo ""
    read -rp "Main branch name [${detected}]: " branch_input
    MAIN_BRANCH="${branch_input:-$detected}"
  fi
fi

if [[ -z "$MERGE_STRATEGY" ]]; then
  if [[ "$NON_INTERACTIVE" == true ]] || [[ ! -t 0 ]]; then
    MERGE_STRATEGY="pr"
  else
    echo ""
    echo -e "${BOLD}Fix Issues merge strategy${RESET} — how should the agent close approved issues?"
    echo ""
    echo "  1) Pull request — agent opens a PR, then merges it (default, safer, auditable)"
    echo "  2) Direct commit — agent commits and pushes directly to ${MAIN_BRANCH} (faster)"
    echo ""
    read -rp "  Choice [1]: " merge_choice
    case "${merge_choice:-1}" in
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

  # Already set via flag — skip prompt
  [[ -n "${!var}" ]] && return

  # No TTY or explicitly non-interactive — use default (false = skip)
  if [[ "$NON_INTERACTIVE" == true ]] || [[ ! -t 0 ]]; then
    eval "$var=false"
    return
  fi

  local default_label
  [[ "$default" == true ]] && default_label="Y/n" || default_label="y/N"

  echo -e "  ${BOLD}${label}${RESET} ${DIM}${hint}${RESET}"
  read -rp "  Include? [${default_label}]: " yn
  case "${yn:-$default}" in
    [Yy1tT]*|true) eval "$var=true" ;;
    *)              eval "$var=false" ;;
  esac
  echo ""
}

if [[ "$NON_INTERACTIVE" == false ]] && \
   [[ -z "$MOD_ANALYTICS$MOD_OBSERVABILITY$MOD_GSC$MOD_ADS$MOD_COOLIFY$MOD_CLAUDE_UPDATE$MOD_ARCH_REVIEW" ]]; then
  echo ""
  echo -e "${BOLD}Optional modules${RESET} — select what applies to your project:"
  echo ""
fi

ask_module MOD_ANALYTICS     "Analytics"         "(PostHog, Mixpanel, Amplitude…) — daily review routine + insights/analytics/"
ask_module MOD_OBSERVABILITY  "Observability"     "(SigNoz, Datadog, Grafana…) — daily error/latency monitoring routine"
ask_module MOD_GSC            "Search Console"    "(Google Search Console) — weekly GSC check routine + insights/search-console/"
ask_module MOD_ADS            "Paid Ads"          "(Google Ads, Meta…) — insights/ads/ folder"              false
ask_module MOD_COOLIFY        "Coolify"           "deployment log monitoring — daily logs check routine"
ask_module MOD_CLAUDE_UPDATE  "CLAUDE.md update"  "weekday routine that re-generates CLAUDE.md from codebase" false
ask_module MOD_ARCH_REVIEW    "Architecture review" "installs improve-codebase-architecture skill + weekly routine (Matt Pocock)" false

# ── Integrations ──────────────────────────────────────────────────────────────

if [[ "$MOD_OBSERVABILITY" == true ]] && [[ -z "$OBS_URL" ]] && \
   [[ "$NON_INTERACTIVE" == false ]] && [[ -t 0 ]]; then
  echo ""
  echo -e "${BOLD}Observability integration${RESET}"
  echo ""
  read -rp "  Connect your observability tool now? [Y/n]: " want_obs
  case "${want_obs:-Y}" in
    [Yy]*|"")
      echo ""
      echo "  Tool:"
      echo "    1) SigNoz"
      echo "    2) Datadog"
      echo "    3) Grafana"
      echo "    4) Other"
      read -rp "  Choice [1]: " obs_choice
      case "${obs_choice:-1}" in
        1|"") OBS_TOOL="SigNoz" ;;
        2)    OBS_TOOL="Datadog" ;;
        3)    OBS_TOOL="Grafana" ;;
        4)    read -rp "  Tool name: " OBS_TOOL; [[ -z "$OBS_TOOL" ]] && OBS_TOOL="Observability" ;;
        *)    OBS_TOOL="$obs_choice" ;;
      esac
      echo ""
      read -rp "  ${OBS_TOOL} URL (e.g. https://signoz.example.com): " OBS_URL
      read -rsp "  ${OBS_TOOL} API key: " OBS_API_KEY; echo ""
      echo ""
      ;;
    *)
      info "Skipping observability integration setup"
      ;;
  esac
fi

# ── Scheduler prompt ──────────────────────────────────────────────────────────

detect_os() {
  case "$(uname)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "other" ;;
  esac
}

DETECTED_OS=$(detect_os)

if [[ -z "$SETUP_SCHEDULER" ]]; then
  if [[ "$NON_INTERACTIVE" == true ]] || [[ ! -t 0 ]]; then
    SETUP_SCHEDULER=false
  elif [[ "$DETECTED_OS" == "other" ]]; then
    warn "Unsupported OS for automatic scheduler setup — skipping"
    SETUP_SCHEDULER=false
  else
    echo ""
    echo -e "${BOLD}Routine scheduler${RESET} — run routines automatically without keeping a terminal open"
    echo ""
    echo "  Installs a single ${DETECTED_OS == macos && echo 'launchd job' || echo 'crontab entry'} that fires the dispatcher every 15 min."
    echo "  The dispatcher reads .darkflow.d/routines.yml and runs any due routine via claude -p."
    echo ""
    read -rp "  Set up system scheduler? [Y/n]: " sched_yn
    case "${sched_yn:-Y}" in
      [Yy]*|"") SETUP_SCHEDULER=true ;;
      *)         SETUP_SCHEDULER=false ;;
    esac
    echo ""
  fi
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

fetch_file() {
  local rel_path="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ "$USE_LOCAL" == true ]]; then
    cp "$SOURCE_DIR/$rel_path" "$dest"
  else
    curl -fsSL "${DARKFLOW_REPO}/templates/${rel_path}" -o "$dest"
  fi
}

safe_fetch() {
  local rel_path="$1" dest="$2"
  if [[ -f "$dest" && "$FORCE" != true ]]; then
    warn "Skipping (exists): $dest  — use --force to overwrite"
  else
    fetch_file "$rel_path" "$dest"
    success "Created: $dest"
  fi
}

make_dir() {
  local d="$1"
  if [[ ! -d "$d" ]]; then
    mkdir -p "$d"
    touch "$d/.gitkeep"
    success "mkdir $d"
  else
    info "Exists: $d"
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

project_slug() {
  echo "${PROJECT_NAME}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//'
}

# ── Create directory structure ────────────────────────────────────────────────

header "1/5  Creating docs/ structure"

cd "$TARGET_DIR"

# Core dirs — always
make_dir "docs/product"
make_dir "docs/spec/flows"
make_dir "docs/spec/screens"
make_dir "docs/design/assets"
make_dir "docs/insights/qualitative"
make_dir "docs/decisions"
make_dir ".github/ISSUE_TEMPLATE"

# Optional dirs
[[ "$MOD_ANALYTICS"    == true ]] && make_dir "docs/insights/analytics"
[[ "$MOD_GSC"          == true ]] && make_dir "docs/insights/search-console"
[[ "$MOD_ADS"          == true ]] && make_dir "docs/insights/ads"

# ── Copy template files ───────────────────────────────────────────────────────

safe_fetch "docs/README.md"              "docs/README.md"
safe_fetch "docs/agent-workflow.md"      "docs/agent-workflow.md"
safe_fetch "docs/github-issues.md"       "docs/github-issues.md"
safe_fetch "docs/decisions/TEMPLATE.md"  "docs/decisions/TEMPLATE.md"
safe_fetch "docs/overview.html"          "docs/overview.html"
safe_fetch ".github/ISSUE_TEMPLATE/recommendation.yml" ".github/ISSUE_TEMPLATE/recommendation.yml"

inject_name "docs/README.md"
inject_name "docs/overview.html"

# ── Write .darkflow config ────────────────────────────────────────────────────

DARKFLOW_VERSION=$(curl -fsSL "${DARKFLOW_REPO}/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "1.0.0")
[[ "$USE_LOCAL" == true ]] && DARKFLOW_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "1.0.0")

{
  echo "# Dark Flow project config — do not edit manually, use update.sh to upgrade"
  echo "version=${DARKFLOW_VERSION}"
  echo "installed=$(date -u +%Y-%m-%d)"
  echo "language=${LANGUAGE}"
  echo "branch=${MAIN_BRANCH}"
  echo "merge_strategy=${MERGE_STRATEGY}"
  # modules
  local_mods=""
  [[ "$MOD_ANALYTICS"     == true ]] && local_mods="${local_mods}analytics,"
  [[ "$MOD_OBSERVABILITY" == true ]] && local_mods="${local_mods}observability,"
  [[ "$MOD_GSC"           == true ]] && local_mods="${local_mods}gsc,"
  [[ "$MOD_ADS"           == true ]] && local_mods="${local_mods}ads,"
  [[ "$MOD_COOLIFY"       == true ]] && local_mods="${local_mods}coolify,"
  [[ "$MOD_CLAUDE_UPDATE" == true ]] && local_mods="${local_mods}claude-update,"
  [[ "$MOD_ARCH_REVIEW"   == true ]] && local_mods="${local_mods}arch-review,"
  echo "modules=${local_mods%,}"
  [[ -n "$OBS_TOOL" ]] && echo "obs_tool=${OBS_TOOL}"
  [[ -n "$OBS_URL"  ]] && echo "obs_url=${OBS_URL}"
  echo "slug=$(project_slug)"
} > .darkflow

success "Created .darkflow config (version ${DARKFLOW_VERSION})"
# .darkflow is safe to commit — credentials go into .env.darkflow (see below)

# ── Write integration credentials ─────────────────────────────────────────────

if [[ -n "$OBS_URL" ]] || [[ -n "$OBS_API_KEY" ]]; then
  CREDS_FILE=".env.darkflow"
  {
    echo "# Dark Flow — integration credentials"
    echo "# Add these to your project .env (do NOT commit .env.darkflow if it contains real keys)"
    echo ""
    [[ -n "$OBS_TOOL"    ]] && echo "# ${OBS_TOOL}"
    [[ -n "$OBS_URL"     ]] && echo "OBSERVABILITY_URL=${OBS_URL}"
    [[ -n "$OBS_API_KEY" ]] && echo "OBSERVABILITY_API_KEY=${OBS_API_KEY}"
  } > "$CREDS_FILE"

  # Append to .gitignore so keys aren't committed
  if ! grep -q ".env.darkflow" .gitignore 2>/dev/null; then
    echo ".env.darkflow" >> .gitignore
    success "Added .env.darkflow to .gitignore"
  fi

  success "Credentials saved to .env.darkflow (git-ignored)"
  info "Copy them to your main .env and configure your observability MCP accordingly"
fi

# Ensure .darkflow.d/ runtime files are git-ignored
for gi_entry in ".darkflow.d/state/" ".darkflow.d/*.log"; do
  if ! grep -qF "$gi_entry" .gitignore 2>/dev/null; then
    echo "$gi_entry" >> .gitignore
    success "Added ${gi_entry} to .gitignore"
  fi
done

# ── GitHub labels ─────────────────────────────────────────────────────────────

if [[ "$SKIP_LABELS" == false ]]; then
  header "2/5  Setting up GitHub labels"
  if ! command -v gh &>/dev/null; then
    warn "gh not found — skipping label setup. Install: https://cli.github.com/"
  elif ! gh auth status &>/dev/null 2>&1; then
    warn "gh not authenticated — run 'gh auth login' then re-run with --no-claude"
  else
    if [[ "$USE_LOCAL" == true ]]; then
      bash "$SCRIPT_DIR/setup-labels.sh"
    else
      bash <(curl -fsSL "${DARKFLOW_REPO}/setup-labels.sh")
    fi
  fi
else
  info "Skipping labels (--no-labels)"
fi

# ── CLAUDE.md ─────────────────────────────────────────────────────────────────

generate_claude_md_section() {
  # Outputs the Dark Flow section for CLAUDE.md to stdout (between markers)
  # KEEP IN SYNC with the new_section block in update.sh — they must produce identical output
  cat << 'HEREDOC'
<!-- darkflow:start -->
## Documentation & Agent Workflow

@docs/agent-workflow.md
@docs/github-issues.md

HEREDOC

  echo "**Language:** ${LANGUAGE} — use this language for GitHub issues, comments, commit messages, and all agent-facing text."
  echo "**Main branch:** \`${MAIN_BRANCH}\`"
  if [[ "$MERGE_STRATEGY" == "direct" ]]; then
    echo "**Fix Issues strategy:** commit and push directly to \`${MAIN_BRANCH}\` — no pull requests."
  else
    echo "**Fix Issues strategy:** open a pull request, then merge into \`${MAIN_BRANCH}\` with \`Closes #N\`."
  fi
  echo ""

  cat << 'HEREDOC'
### Before each session

Check approved task queue:
```bash
gh issue list --label "status:approved" --state open --json number,title,labels,body --limit 20
```
If there are approved issues with `area:*` matching the current context — pick them first.
Before starting: set `status:in-progress`, leave a comment with the branch name.

### When to read docs

HEREDOC

  echo "- **Any UI/UX task** → \`docs/design/voice-and-tone.md\` + \`docs/design/tokens.md\` + \`docs/design/patterns.md\` + \`docs/design/components.md\`"
  echo "- **Changing a user flow** → \`docs/spec/flows/\`"
  echo "- **Product / marketing decisions** → \`docs/product/positioning.md\` + \`docs/product/audience.md\` + \`docs/product/pricing.md\`"
  [[ "$MOD_ANALYTICS" == true ]] && echo "- **Working with analytics events** → \`docs/product/metrics.md\` (not guessing event names)"
  [[ "$MOD_ANALYTICS" == true ]] && echo "- **Context on what's working now** → last 2–3 files from \`docs/insights/analytics/\`"
  [[ "$MOD_GSC"       == true ]] && echo "- **SEO decisions** → last 2–3 files from \`docs/insights/search-console/\`"
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
  [[ "$MOD_ADS"       == true ]] && echo "- **After checking ads** → write snapshot to \`docs/insights/ads/YYYY-MM-DD.md\`"

  # Routines section — only if any optional module selected
  local has_routines=false
  for m in "$MOD_ANALYTICS" "$MOD_OBSERVABILITY" "$MOD_GSC" "$MOD_COOLIFY" "$MOD_CLAUDE_UPDATE"; do
    [[ "$m" == true ]] && has_routines=true && break
  done

  echo ""
  echo "### Active Routines"
  echo ""
  echo "Scheduled Claude Code agents that run this workflow automatically:"
  echo ""
  echo "- **Fix issues** (Hourly) — picks up \`status:approved\` issues → PR → merge to main"
  [[ "$MOD_ANALYTICS"     == true ]] && echo "- **Analytics review** (Daily 8:00) — PostHog + recent commits → GitHub issues"
  if [[ "$MOD_OBSERVABILITY" == true ]]; then
    local obs_label="${OBS_TOOL:-Observability tool}"
    echo "- **Observability check** (Daily 8:30) — ${obs_label}: errors / slow queries / latency → GitHub issues"
  fi
  [[ "$MOD_GSC"           == true ]] && echo "- **GSC check** (Weekly Mon 8:00) — Google Search Console → GitHub issues"
  [[ "$MOD_COOLIFY"       == true ]] && echo "- **Coolify logs** (Daily 9:00) — deployment monitoring → fix errors"
  [[ "$MOD_CLAUDE_UPDATE" == true ]] && echo "- **CLAUDE.md update** (Weekdays 9:00) — re-generates this file from codebase"
  [[ "$MOD_ARCH_REVIEW"   == true ]] && echo "- **Architecture review** (Weekly Sun 2:00) — \`/improve-codebase-architecture\` → GitHub issues"
  echo ""
  echo "Schedule: \`.darkflow.d/routines.yml\`  |  Dispatcher: \`bash .darkflow.d/darkflow-run.sh\`"
  echo "Run any routine manually: \`bash .darkflow.d/darkflow-run.sh <name>\`"
  echo "List status: \`bash .darkflow.d/darkflow-run.sh --list\`"
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
  [[ "$MOD_GSC"           == true ]] && echo "- \`/darkflow:gsc-check\` — Google Search Console → GitHub issues"
  [[ "$MOD_COOLIFY"       == true ]] && echo "- \`/darkflow:coolify-logs\` — deployment log monitoring"
  [[ "$MOD_COOLIFY"       == true ]] && echo "- \`/darkflow:deployment-failure\` — diagnose and fix a failed deployment"
  [[ "$MOD_CLAUDE_UPDATE" == true ]] && echo "- \`/darkflow:claude-md-update\` — regenerate CLAUDE.md from codebase"
  [[ "$MOD_ARCH_REVIEW"   == true ]] && echo "- \`/darkflow:architecture-review\` — architectural analysis → GitHub issues"
  echo "- \`/darkflow:security-audit\` — full security review (static + runtime) → GitHub issues"
  echo ""
  echo "<!-- darkflow:end -->"
}

if [[ "$SKIP_CLAUDE_SNIPPET" == false ]]; then
  header "3/5  CLAUDE.md"

  if [[ -f "CLAUDE.md" ]]; then
    if grep -q "agent-workflow.md" CLAUDE.md; then
      info "CLAUDE.md already references agent-workflow.md — skipping (use --force to regenerate)"
    else
      warn "CLAUDE.md exists but does not reference workflow docs."
      echo ""
      echo -e "${BOLD}Add this section to your CLAUDE.md:${RESET}"
      echo "──────────────────────────────────────────"
      generate_claude_md_section
      echo "──────────────────────────────────────────"
    fi
  else
    {
      echo "# CLAUDE.md"
      echo ""
      generate_claude_md_section
    } > CLAUDE.md
    success "Created CLAUDE.md"
  fi
fi

# ── Claude Code command ───────────────────────────────────────────────────────

header "4/5  Claude Code commands"

make_dir ".claude/commands"
make_dir ".claude/commands/darkflow"

safe_fetch ".claude/commands/darkflow.md"                               ".claude/commands/darkflow.md"
safe_fetch ".claude/commands/darkflow/add-issue.md"                    ".claude/commands/darkflow/add-issue.md"
safe_fetch ".claude/commands/darkflow/install.md"                      ".claude/commands/darkflow/install.md"
safe_fetch ".claude/commands/darkflow/update.md"                       ".claude/commands/darkflow/update.md"
safe_fetch ".claude/commands/darkflow/fix-issues.md"                   ".claude/commands/darkflow/fix-issues.md"
safe_fetch ".claude/commands/darkflow/analytics-review.md"             ".claude/commands/darkflow/analytics-review.md"
safe_fetch ".claude/commands/darkflow/observability-check.md"          ".claude/commands/darkflow/observability-check.md"
safe_fetch ".claude/commands/darkflow/gsc-check.md"                    ".claude/commands/darkflow/gsc-check.md"
safe_fetch ".claude/commands/darkflow/coolify-logs.md"                 ".claude/commands/darkflow/coolify-logs.md"
safe_fetch ".claude/commands/darkflow/deployment-failure.md"           ".claude/commands/darkflow/deployment-failure.md"
safe_fetch ".claude/commands/darkflow/claude-md-update.md"             ".claude/commands/darkflow/claude-md-update.md"
safe_fetch ".claude/commands/darkflow/security-audit.md"               ".claude/commands/darkflow/security-audit.md"
safe_fetch ".claude/commands/darkflow/architecture-review.md"          ".claude/commands/darkflow/architecture-review.md"

success "Installed /darkflow commands — /darkflow, /darkflow:add-issue, /darkflow:fix-issues, /darkflow:analytics-review, and 6 more"

# ── Routine dispatcher (.darkflow.d/) ─────────────────────────────────────────

header "5/6  Routine dispatcher"

SLUG=$(project_slug)

make_dir ".darkflow.d"
make_dir ".darkflow.d/state"

# Copy dispatcher script
if [[ "$USE_LOCAL" == true ]]; then
  cp "$SOURCE_DIR/darkflow/darkflow-run.sh" ".darkflow.d/darkflow-run.sh"
else
  curl -fsSL "${DARKFLOW_REPO}/templates/darkflow/darkflow-run.sh?t=$(date +%s)" -o ".darkflow.d/darkflow-run.sh"
fi
chmod +x ".darkflow.d/darkflow-run.sh"
success "Installed .darkflow.d/darkflow-run.sh"

# Copy install-scheduler helper
if [[ "$USE_LOCAL" == true ]]; then
  cp "$SOURCE_DIR/darkflow/install-scheduler.sh" ".darkflow.d/install-scheduler.sh"
else
  curl -fsSL "${DARKFLOW_REPO}/templates/darkflow/install-scheduler.sh?t=$(date +%s)" -o ".darkflow.d/install-scheduler.sh"
fi
chmod +x ".darkflow.d/install-scheduler.sh"
success "Installed .darkflow.d/install-scheduler.sh"

# Copy uninstall helper
if [[ "$USE_LOCAL" == true ]]; then
  cp "$SOURCE_DIR/darkflow/uninstall-scheduler.sh" ".darkflow.d/uninstall-scheduler.sh"
else
  curl -fsSL "${DARKFLOW_REPO}/templates/darkflow/uninstall-scheduler.sh?t=$(date +%s)" -o ".darkflow.d/uninstall-scheduler.sh"
fi
chmod +x ".darkflow.d/uninstall-scheduler.sh"
success "Installed .darkflow.d/uninstall-scheduler.sh"

# Generate filtered routines.yml
if [[ ! -f ".darkflow.d/routines.yml" || "$FORCE" == true ]]; then
  {
    cat << 'YAML_HEADER'
# Dark Flow routine schedule — generated by install.sh. Safe to edit after installation.
# Run a routine manually:  bash .darkflow.d/darkflow-run.sh <name>
# List routines and status: bash .darkflow.d/darkflow-run.sh --list
# Cron times are in the machine's local timezone.
#
# permission_mode options:
#   bypassPermissions — act without asking (equivalent to "Always allowed" in the Claude Code UI)
#   acceptEdits       — allow file edits but still prompt for shell commands
defaults:
  model: sonnet
  permission_mode: bypassPermissions

routines:
  fix-issues:
    cron: "0 * * * *"
    model: sonnet
    enabled: true
YAML_HEADER

    if [[ "$MOD_ANALYTICS" == true ]]; then
      cat << 'YAML_SECTION'

  analytics-review:
    cron: "0 8 * * *"
    model: sonnet
    enabled: true
YAML_SECTION
    fi

    if [[ "$MOD_OBSERVABILITY" == true ]]; then
      cat << 'YAML_SECTION'

  observability-check:
    cron: "30 8 * * *"
    model: sonnet
    enabled: true
YAML_SECTION
    fi

    if [[ "$MOD_GSC" == true ]]; then
      cat << 'YAML_SECTION'

  gsc-check:
    cron: "0 8 * * 1"
    model: sonnet
    enabled: true
YAML_SECTION
    fi

    if [[ "$MOD_COOLIFY" == true ]]; then
      cat << 'YAML_SECTION'

  coolify-logs:
    cron: "0 9 * * *"
    model: sonnet
    enabled: true
YAML_SECTION
    fi

    if [[ "$MOD_CLAUDE_UPDATE" == true ]]; then
      cat << 'YAML_SECTION'

  claude-md-update:
    cron: "0 9 * * 1-5"
    model: sonnet
    enabled: true
YAML_SECTION
    fi

    if [[ "$MOD_ARCH_REVIEW" == true ]]; then
      cat << 'YAML_SECTION'

  architecture-review:
    cron: "0 2 * * 0"
    model: opus
    enabled: true
YAML_SECTION
    fi

    cat << 'YAML_SECTION'

  security-audit:
    cron: "0 3 * * 0"
    model: opus
    enabled: true
YAML_SECTION

    if [[ "$MOD_COOLIFY" == true ]]; then
      cat << 'YAML_SECTION'

  deployment-failure:
    cron: ""
    model: sonnet
    enabled: false
YAML_SECTION
    fi

    echo ""
  } > ".darkflow.d/routines.yml"
  success "Created .darkflow.d/routines.yml"
else
  info "Exists: .darkflow.d/routines.yml — skipping (use --force to overwrite)"
fi

# Optionally install system scheduler
if [[ "$SETUP_SCHEDULER" == true ]]; then
  PROJECT_ABS="$(cd "$TARGET_DIR" && pwd)"
  if [[ "$DETECTED_OS" == "macos" ]]; then
    PLIST_PATH="$HOME/Library/LaunchAgents/com.darkflow.${SLUG}.plist"
    cat > "$PLIST_PATH" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.darkflow.${SLUG}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${PROJECT_ABS}/.darkflow.d/darkflow-run.sh</string>
  </array>
  <key>WorkingDirectory</key><string>${PROJECT_ABS}</string>
  <key>StartInterval</key><integer>900</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>${PROJECT_ABS}/.darkflow.d/launchd.out.log</string>
  <key>StandardErrorPath</key><string>${PROJECT_ABS}/.darkflow.d/launchd.err.log</string>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
</dict></plist>
PLIST_EOF
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load "$PLIST_PATH"
    success "Installed launchd job: com.darkflow.${SLUG} (every 15 min)"
    info "Logs: ${PROJECT_ABS}/.darkflow.d/launchd.{out,err}.log"

  elif [[ "$DETECTED_OS" == "linux" ]]; then
    CRON_LINE="*/15 * * * * cd ${PROJECT_ABS} && /bin/bash .darkflow.d/darkflow-run.sh >> .darkflow.d/cron.log 2>&1  # darkflow:${SLUG}"
    (crontab -l 2>/dev/null | grep -v "# darkflow:${SLUG}"; echo "$CRON_LINE") | crontab -
    success "Added crontab entry for darkflow:${SLUG} (every 15 min)"
  fi

  # Warn if dependencies missing
  if ! command -v yq &>/dev/null; then
    warn "yq not found — dispatcher needs it to parse routines.yml"
    warn "  macOS: brew install yq  |  Linux: https://github.com/mikefarah/yq#install"
  fi
  if ! command -v claude &>/dev/null; then
    warn "claude CLI not found — dispatcher needs it to run routines"
    warn "  Install Claude Code: https://claude.ai/code"
  fi

else
  info "Scheduler not installed."
  if [[ "$DETECTED_OS" != "other" ]]; then
    info "To install later: bash .darkflow.d/install-scheduler.sh"
  fi
fi

# ── Architecture review skill ─────────────────────────────────────────────────

if [[ "$MOD_ARCH_REVIEW" == true ]]; then
  header "6/6  Architecture review skill"

  if ! command -v npx &>/dev/null; then
    warn "npx not found — skipping skill install. Run manually:"
    warn "  npx skills add https://github.com/mattpocock/skills --skill improve-codebase-architecture"
  else
    info "Installing improve-codebase-architecture skill..."
    if npx skills add https://github.com/mattpocock/skills --skill improve-codebase-architecture 2>&1; then
      success "Skill installed — use /improve-codebase-architecture inside Claude Code"
    else
      warn "Skill install failed. Run manually:"
      warn "  npx skills add https://github.com/mattpocock/skills --skill improve-codebase-architecture"
    fi
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}Dark Flow installed in ${TARGET_DIR}${RESET}"
echo ""
echo "Next steps:"
echo "  1. Fill in docs/product/ — what are you building and for whom"
echo "  2. Fill in docs/spec/    — user flows, screens, data model"
echo "  3. Fill in docs/design/  — tokens, components, voice and tone"
echo "  4. Commit: git add docs/ .github/ISSUE_TEMPLATE/ CLAUDE.md .darkflow .darkflow.d/ && git commit -m 'chore: install dark-flow workflow'"
echo "  5. Open docs/overview.html in a browser — it updates daily via the analytics-review routine"
echo ""

echo -e "${BOLD}Routine dispatcher${RESET} — .darkflow.d/routines.yml + darkflow-run.sh"
echo ""
echo -e "  ${BOLD}Core routines (always active):${RESET}"
if [[ "$MERGE_STRATEGY" == "direct" ]]; then
  echo "  fix-issues       0 * * * *      Picks up status:approved → commit → push to ${MAIN_BRANCH}"
else
  echo "  fix-issues       0 * * * *      Picks up status:approved → PR → merge into ${MAIN_BRANCH}"
fi
echo "  security-audit   0 3 * * 0      Full security review → GitHub issues"
echo ""

if [[ "$MOD_ANALYTICS" == true ]] || [[ "$MOD_OBSERVABILITY" == true ]] || \
   [[ "$MOD_GSC" == true ]] || [[ "$MOD_COOLIFY" == true ]] || \
   [[ "$MOD_CLAUDE_UPDATE" == true ]] || [[ "$MOD_ARCH_REVIEW" == true ]]; then
  echo -e "  ${BOLD}Routines for your selected modules:${RESET}"
  [[ "$MOD_ANALYTICS"     == true ]] && echo "  analytics-review     0 8 * * *      PostHog + commits → GitHub issues"
  [[ "$MOD_OBSERVABILITY" == true ]] && echo "  observability-check  30 8 * * *     Errors / latency → GitHub issues"
  [[ "$MOD_GSC"           == true ]] && echo "  gsc-check            0 8 * * 1      Google Search Console → GitHub issues"
  [[ "$MOD_COOLIFY"       == true ]] && echo "  coolify-logs         0 9 * * *      Deployment monitoring → fix errors"
  [[ "$MOD_CLAUDE_UPDATE" == true ]] && echo "  claude-md-update     0 9 * * 1-5    Re-generates CLAUDE.md from codebase"
  [[ "$MOD_ARCH_REVIEW"   == true ]] && echo "  architecture-review  0 2 * * 0      Architectural analysis → GitHub issues"
  echo ""
fi

echo -e "  Run manually:   ${DIM}bash .darkflow.d/darkflow-run.sh <name>${RESET}"
echo -e "  Show status:    ${DIM}bash .darkflow.d/darkflow-run.sh --list${RESET}"
echo -e "  Dry run:        ${DIM}bash .darkflow.d/darkflow-run.sh --dry-run${RESET}"
if [[ "$SETUP_SCHEDULER" == true ]]; then
  echo -e "  Scheduler:      ${GREEN}active (every 15 min)${RESET}"
  echo -e "  Uninstall:      ${DIM}bash .darkflow.d/uninstall-scheduler.sh${RESET}"
else
  echo -e "  Scheduler:      ${DIM}not installed — run: bash .darkflow.d/install-scheduler.sh${RESET}"
fi
echo ""

# Summary of what was installed
echo -e "${DIM}Installed modules:${RESET}"
echo -e "  ${GREEN}✓${RESET} Core workflow (docs/, labels, CLAUDE.md, GitHub issue template)"
[[ "$MOD_ANALYTICS"     == true ]] && echo -e "  ${GREEN}✓${RESET} Analytics        (docs/insights/analytics/)"
[[ "$MOD_GSC"           == true ]] && echo -e "  ${GREEN}✓${RESET} Search Console   (docs/insights/search-console/)"
[[ "$MOD_ADS"           == true ]] && echo -e "  ${GREEN}✓${RESET} Ads              (docs/insights/ads/)"
[[ "$MOD_OBSERVABILITY" == true ]] && echo -e "  ${GREEN}✓${RESET} Observability    (routine only)"
[[ "$MOD_COOLIFY"       == true ]] && echo -e "  ${GREEN}✓${RESET} Coolify          (routine only)"
[[ "$MOD_CLAUDE_UPDATE" == true ]] && echo -e "  ${GREEN}✓${RESET} CLAUDE.md update (routine only)"
[[ "$MOD_ARCH_REVIEW"   == true ]] && echo -e "  ${GREEN}✓${RESET} Architecture review (skill installed + routine)"
echo ""
