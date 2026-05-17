#!/usr/bin/env bash
# Dark Flow installer
# Usage: bash install.sh [--name "Project Name"] [--no-labels] [--no-claude]
# Or pipe: bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/master/install.sh)

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

DARKFLOW_REPO="https://raw.githubusercontent.com/alifanov/darkflow/main"
TARGET_DIR="${PWD}"
PROJECT_NAME=""
SKIP_LABELS=false
SKIP_CLAUDE_SNIPPET=false
FORCE=false

# ── Colours ───────────────────────────────────────────────────────────────────

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

info()    { echo -e "${CYAN}▸ $*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✗ $*${RESET}" >&2; exit 1; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)        PROJECT_NAME="$2"; shift 2 ;;
    --no-labels)   SKIP_LABELS=true; shift ;;
    --no-claude)   SKIP_CLAUDE_SNIPPET=true; shift ;;
    --force)       FORCE=true; shift ;;
    --target)      TARGET_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: install.sh [--name \"Project Name\"] [--no-labels] [--no-claude] [--force] [--target DIR]"
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
  # Try to infer from directory or package.json
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    inferred=$(node -p "require('./package.json').name" 2>/dev/null || true)
    [[ -n "$inferred" ]] && PROJECT_NAME="$inferred"
  fi
  if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME="$(basename "$TARGET_DIR")"
  fi
  read -rp "Project name [${PROJECT_NAME}]: " input
  [[ -n "$input" ]] && PROJECT_NAME="$input"
fi

header "Installing Dark Flow for \"${PROJECT_NAME}\""

# ── Helpers ───────────────────────────────────────────────────────────────────

# Fetch file from remote or copy from local
fetch_file() {
  local rel_path="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ "$USE_LOCAL" == true ]]; then
    cp "$SOURCE_DIR/$rel_path" "$dest"
  else
    curl -fsSL "${DARKFLOW_REPO}/templates/${rel_path}" -o "$dest"
  fi
}

# Create file only if it doesn't exist (or --force)
safe_fetch() {
  local rel_path="$1"
  local dest="$2"
  if [[ -f "$dest" && "$FORCE" != true ]]; then
    warn "Skipping (exists): $dest  — use --force to overwrite"
  else
    fetch_file "$rel_path" "$dest"
    success "Created: $dest"
  fi
}

# Replace {{PROJECT_NAME}} in a file
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

dirs=(
  "docs/product"
  "docs/spec/flows"
  "docs/spec/screens"
  "docs/design/assets"
  "docs/insights/analytics"
  "docs/insights/search-console"
  "docs/insights/ads"
  "docs/insights/qualitative"
  "docs/decisions"
  ".github/ISSUE_TEMPLATE"
)
for d in "${dirs[@]}"; do
  if [[ ! -d "$d" ]]; then
    mkdir -p "$d"
    # keep empty dirs in git
    touch "$d/.gitkeep"
    success "mkdir $d"
  else
    info "Exists: $d"
  fi
done

# ── Copy template files ───────────────────────────────────────────────────────

safe_fetch "docs/README.md"              "docs/README.md"
safe_fetch "docs/agent-workflow.md"      "docs/agent-workflow.md"
safe_fetch "docs/github-issues.md"       "docs/github-issues.md"
safe_fetch "docs/decisions/TEMPLATE.md"  "docs/decisions/TEMPLATE.md"
safe_fetch ".github/ISSUE_TEMPLATE/recommendation.yml" ".github/ISSUE_TEMPLATE/recommendation.yml"

# Inject project name into the docs README
inject_name "docs/README.md"

# ── GitHub labels ─────────────────────────────────────────────────────────────

if [[ "$SKIP_LABELS" == false ]]; then
  header "2/3  Setting up GitHub labels"
  if ! command -v gh &>/dev/null; then
    warn "gh not found — skipping label setup. Install: https://cli.github.com/"
  elif ! gh auth status &>/dev/null 2>&1; then
    warn "gh not authenticated — run 'gh auth login' then re-run: bash install.sh --no-claude"
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
    # Create minimal CLAUDE.md
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
echo "  2. Fill in docs/spec/   — user flows, screens, data model"
echo "  3. Fill in docs/design/ — tokens, components, voice and tone"
echo "  4. Commit: git add docs/ .github/ISSUE_TEMPLATE/ CLAUDE.md && git commit -m 'chore: install dark-flow workflow'"
echo "  5. Start a Claude Code session and ask it to check the approved queue"
echo ""
