#!/usr/bin/env bash
# Dark Flow installer
#
# Interactive:   bash install.sh
# All modules:   bash install.sh --all
# Pick modules:  bash install.sh --with-analytics --with-gsc --with-coolify
# One-liner:     bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh)
# Silent:        bash install.sh --yes  (core only, no prompts)

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

DARKFLOW_REPO="https://raw.githubusercontent.com/alifanov/darkflow/main"
TARGET_DIR="${PWD}"
PROJECT_NAME=""
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
    --no-labels)          SKIP_LABELS=true; shift ;;
    --no-claude)          SKIP_CLAUDE_SNIPPET=true; shift ;;
    --force)              FORCE=true; shift ;;
    --target)             TARGET_DIR="$2"; shift 2 ;;
    --all)                NON_INTERACTIVE=true
                          MOD_ANALYTICS=true MOD_OBSERVABILITY=true MOD_GSC=true
                          MOD_ADS=true MOD_COOLIFY=true MOD_CLAUDE_UPDATE=true
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
    -y|--yes)             NON_INTERACTIVE=true; shift ;;
    -h|--help)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --name NAME           Project name (default: directory name)"
      echo "  --all                 Enable all optional modules non-interactively"
      echo "  -y, --yes             Accept defaults non-interactively (no optional modules)"
      echo "  --with-analytics      Include analytics module (PostHog/Mixpanel)"
      echo "  --with-observability  Include observability module (SigNoz/Datadog)"
      echo "  --with-gsc            Include Google Search Console module"
      echo "  --with-ads            Include paid ads module (Google Ads/Meta)"
      echo "  --with-coolify        Include Coolify deployment monitoring"
      echo "  --with-claude-update  Include auto CLAUDE.md regeneration routine"
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
   [[ -z "$MOD_ANALYTICS$MOD_OBSERVABILITY$MOD_GSC$MOD_ADS$MOD_COOLIFY$MOD_CLAUDE_UPDATE" ]]; then
  echo ""
  echo -e "${BOLD}Optional modules${RESET} — select what applies to your project:"
  echo ""
fi

ask_module MOD_ANALYTICS     "Analytics"       "(PostHog, Mixpanel, Amplitude…) — daily review routine + insights/analytics/"
ask_module MOD_OBSERVABILITY  "Observability"   "(SigNoz, Datadog, Grafana…) — daily error/latency monitoring routine"
ask_module MOD_GSC            "Search Console"  "(Google Search Console) — weekly GSC check routine + insights/search-console/"
ask_module MOD_ADS            "Paid Ads"        "(Google Ads, Meta…) — insights/ads/ folder"              false
ask_module MOD_COOLIFY        "Coolify"         "deployment log monitoring — daily logs check routine"
ask_module MOD_CLAUDE_UPDATE  "CLAUDE.md update" "weekday routine that re-generates CLAUDE.md from codebase" false

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

# ── Create directory structure ────────────────────────────────────────────────

header "1/3  Creating docs/ structure"

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
safe_fetch ".github/ISSUE_TEMPLATE/recommendation.yml" ".github/ISSUE_TEMPLATE/recommendation.yml"

inject_name "docs/README.md"

# ── GitHub labels ─────────────────────────────────────────────────────────────

if [[ "$SKIP_LABELS" == false ]]; then
  header "2/3  Setting up GitHub labels"
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

# ── CLAUDE.md snippet ─────────────────────────────────────────────────────────

if [[ "$SKIP_CLAUDE_SNIPPET" == false ]]; then
  header "3/3  CLAUDE.md"

  SNIPPET='## Docs & Agent Workflow

@docs/agent-workflow.md
@docs/github-issues.md

**Before each session** — check the approved task queue:
```bash
gh issue list --label "status:approved" --state open --json number,title,labels,body --limit 20
```'

  if [[ -f "CLAUDE.md" ]]; then
    if grep -q "agent-workflow.md" CLAUDE.md; then
      info "CLAUDE.md already references agent-workflow.md — nothing to add"
    else
      warn "CLAUDE.md exists but does not reference workflow docs."
      echo ""
      echo -e "${BOLD}Add this to your CLAUDE.md:${RESET}"
      echo ""
      echo "$SNIPPET"
      echo ""
    fi
  else
    cat > CLAUDE.md << EOF
# CLAUDE.md

$SNIPPET
EOF
    success "Created CLAUDE.md"
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
echo "  4. Commit: git add docs/ .github/ISSUE_TEMPLATE/ CLAUDE.md && git commit -m 'chore: install dark-flow workflow'"
echo ""

# Show only the routines relevant to chosen modules
HAS_ROUTINES=false
for m in "$MOD_ANALYTICS" "$MOD_OBSERVABILITY" "$MOD_GSC" "$MOD_COOLIFY" "$MOD_CLAUDE_UPDATE"; do
  [[ "$m" == true ]] && HAS_ROUTINES=true && break
done

echo -e "${BOLD}Set up Claude Code Routines${RESET} (Claude Code → Routines → New routine)"
echo "  Full prompts: https://github.com/alifanov/darkflow/blob/main/routines/README.md"
echo ""
echo -e "  ${BOLD}Core routines (always recommended):${RESET}"
echo "  Fix issues       Hourly          Picks up status:approved → PR → merge"
echo ""

if [[ "$HAS_ROUTINES" == true ]]; then
  echo -e "  ${BOLD}Routines for your selected modules:${RESET}"
  [[ "$MOD_ANALYTICS"    == true ]] && echo "  Analytics review     Daily 8:00      PostHog/analytics + commits → GitHub issues"
  [[ "$MOD_OBSERVABILITY" == true ]] && echo "  Observability check  Daily 8:30      SigNoz/errors/slow URLs → GitHub issues"
  [[ "$MOD_GSC"          == true ]] && echo "  GSC check            Weekly Mon 8:00  Google Search Console → GitHub issues"
  [[ "$MOD_COOLIFY"      == true ]] && echo "  Coolify logs         Daily 9:00      Deployment logs → fix errors → verify"
  [[ "$MOD_CLAUDE_UPDATE" == true ]] && echo "  CLAUDE.md update     Weekdays 9:00   Re-generates CLAUDE.md from codebase"
  echo ""
fi

echo -e "  ${DIM}⚠ Set 'Always allowed: Act without asking' on every routine.${RESET}"
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
echo ""
