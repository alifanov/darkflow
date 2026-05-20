#!/usr/bin/env bash
# Dark Flow updater
#
# Usage (inside a project that has Dark Flow installed):
#   bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/update.sh)
#
# Or via /darkflow:update in Claude Code.

set -euo pipefail

DARKFLOW_REPO="https://raw.githubusercontent.com/alifanov/darkflow/main"
TARGET_DIR="${PWD}"
DRY_RUN=false
FORCE=false

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --force)   FORCE=true; shift ;;
    --target)  TARGET_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: update.sh [--dry-run] [--force] [--target DIR]"
      echo ""
      echo "  --dry-run   Show what would change without applying anything"
      echo "  --force     Overwrite template files even if locally modified"
      exit 0 ;;
    *) warn "Unknown argument: $1"; shift ;;
  esac
done

cd "$TARGET_DIR"

# ── Resolve source ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/templates/docs/agent-workflow.md" ]]; then
  USE_LOCAL=true
  SOURCE_DIR="$SCRIPT_DIR/templates"
else
  USE_LOCAL=false
fi

fetch_raw() {
  local path="$1"
  if [[ "$USE_LOCAL" == true ]]; then
    cat "$SCRIPT_DIR/$path" 2>/dev/null || true
  else
    curl -fsSL "${DARKFLOW_REPO}/${path}?t=$(date +%s)" 2>/dev/null || true
  fi
}

# ── Read installed config ─────────────────────────────────────────────────────

if [[ ! -f ".darkflow" ]]; then
  echo -e "${RED}✗ .darkflow config not found.${RESET}"
  echo "  This project doesn't appear to have Dark Flow installed."
  echo "  Run the installer first:"
  echo "    bash <(curl -fsSL ${DARKFLOW_REPO}/install.sh)"
  exit 1
fi

read_config() {
  local key="$1" default="${2:-}"
  grep "^${key}=" .darkflow 2>/dev/null | cut -d= -f2- || echo "$default"
}

INSTALLED_VERSION=$(read_config version "0.0.0")
LANGUAGE=$(read_config language "English")
MAIN_BRANCH=$(read_config branch "main")
MERGE_STRATEGY=$(read_config merge_strategy "pr")
MODULES=$(read_config modules "")
OBS_TOOL=$(read_config obs_tool "")
SLUG=$(read_config slug "")
[[ -z "$SLUG" ]] && SLUG=$(basename "$TARGET_DIR" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

MOD_ANALYTICS=false;    MOD_OBSERVABILITY=false; MOD_GSC=false
MOD_ADS=false;          MOD_COOLIFY=false;        MOD_CLAUDE_UPDATE=false
MOD_ARCH_REVIEW=false

[[ "$MODULES" == *"analytics"*   ]] && MOD_ANALYTICS=true
[[ "$MODULES" == *"observability"* ]] && MOD_OBSERVABILITY=true
[[ "$MODULES" == *"gsc"*         ]] && MOD_GSC=true
[[ "$MODULES" == *"ads"*         ]] && MOD_ADS=true
[[ "$MODULES" == *"coolify"*     ]] && MOD_COOLIFY=true
[[ "$MODULES" == *"claude-update"* ]] && MOD_CLAUDE_UPDATE=true
[[ "$MODULES" == *"arch-review"* ]] && MOD_ARCH_REVIEW=true

# ── Fetch latest version ──────────────────────────────────────────────────────

LATEST_VERSION=$(fetch_raw "VERSION" | tr -d '[:space:]')
[[ -z "$LATEST_VERSION" ]] && LATEST_VERSION="$INSTALLED_VERSION"

header "Dark Flow update"
echo -e "  Installed: ${BOLD}${INSTALLED_VERSION}${RESET}"
echo -e "  Latest:    ${BOLD}${LATEST_VERSION}${RESET}"
echo -e "  Project:   ${TARGET_DIR}"
echo ""

if [[ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]] && [[ "$FORCE" != true ]]; then
  success "Already up to date (${LATEST_VERSION})"
  echo ""
  echo -e "${DIM}Run with --force to re-apply all templates regardless.${RESET}"
  exit 0
fi

# Show changelog entries since installed version
CHANGELOG=$(fetch_raw "CHANGELOG.md")
if [[ -n "$CHANGELOG" ]]; then
  echo -e "${BOLD}Changes since ${INSTALLED_VERSION}:${RESET}"
  # Print sections between installed version and latest
  awk "/## \[${LATEST_VERSION}\]/,/## \[${INSTALLED_VERSION}\]/" <<< "$CHANGELOG" \
    | grep -v "## \[${INSTALLED_VERSION}\]" \
    | head -40 \
    || true
  echo ""
fi

[[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}DRY RUN — no changes will be applied${RESET}\n"

# ── Helper: smart file update ─────────────────────────────────────────────────

# Update a template file only if it hasn't been locally modified
# "not modified" = file content matches the template in the darkflow repo
smart_update_template() {
  local rel_path="$1"   # path relative to templates/
  local dest="$2"       # destination path in project

  if [[ ! -f "$dest" ]]; then
    if [[ "$DRY_RUN" == false ]]; then
      mkdir -p "$(dirname "$dest")"
      if [[ "$USE_LOCAL" == true ]]; then
        cp "$SOURCE_DIR/$rel_path" "$dest"
      else
        curl -fsSL "${DARKFLOW_REPO}/templates/${rel_path}" -o "$dest"
      fi
      success "Added: $dest"
    else
      info "Would add: $dest"
    fi
    return
  fi

  # Fetch latest template content
  local latest
  if [[ "$USE_LOCAL" == true ]]; then
    latest=$(cat "$SOURCE_DIR/$rel_path" 2>/dev/null || echo "")
  else
    latest=$(curl -fsSL "${DARKFLOW_REPO}/templates/${rel_path}" 2>/dev/null || echo "")
  fi

  local current
  current=$(cat "$dest")

  if [[ "$current" == "$latest" ]]; then
    skip "$dest (unchanged)"
  elif [[ "$FORCE" == true ]]; then
    if [[ "$DRY_RUN" == false ]]; then
      echo "$latest" > "$dest"
      changed "Updated (--force): $dest"
    else
      info "Would update (--force): $dest"
    fi
  else
    warn "Locally modified: $dest"
    echo -e "  ${DIM}New upstream version available. Review diff and update manually, or run with --force.${RESET}"
    # Show a short diff summary
    diff <(echo "$current") <(echo "$latest") | head -20 | sed 's/^/  /' || true
  fi
}

# ── 1. Labels ─────────────────────────────────────────────────────────────────

header "1/4  GitHub labels"

if ! command -v gh &>/dev/null; then
  warn "gh not found — skipping label update"
elif ! gh auth status &>/dev/null 2>&1; then
  warn "gh not authenticated — skipping label update"
elif [[ "$DRY_RUN" == true ]]; then
  info "Would re-run setup-labels.sh (additive, safe)"
else
  if [[ "$USE_LOCAL" == true ]]; then
    bash "$SCRIPT_DIR/setup-labels.sh"
  else
    bash <(curl -fsSL "${DARKFLOW_REPO}/setup-labels.sh")
  fi
fi

# ── 2. Template files ─────────────────────────────────────────────────────────

header "2/4  Template files"

smart_update_template "docs/agent-workflow.md"     "docs/agent-workflow.md"
smart_update_template "docs/github-issues.md"      "docs/github-issues.md"
smart_update_template "docs/decisions/TEMPLATE.md" "docs/decisions/TEMPLATE.md"
smart_update_template ".github/ISSUE_TEMPLATE/recommendation.yml" \
                      ".github/ISSUE_TEMPLATE/recommendation.yml"
smart_update_template ".claude/commands/darkflow.md"                         ".claude/commands/darkflow.md"
smart_update_template ".claude/commands/darkflow/add-issue.md"               ".claude/commands/darkflow/add-issue.md"
smart_update_template ".claude/commands/darkflow/install.md"                 ".claude/commands/darkflow/install.md"
smart_update_template ".claude/commands/darkflow/update.md"                  ".claude/commands/darkflow/update.md"
smart_update_template ".claude/commands/darkflow/fix-issues.md"              ".claude/commands/darkflow/fix-issues.md"
smart_update_template ".claude/commands/darkflow/analytics-review.md"        ".claude/commands/darkflow/analytics-review.md"
smart_update_template ".claude/commands/darkflow/observability-check.md"     ".claude/commands/darkflow/observability-check.md"
smart_update_template ".claude/commands/darkflow/gsc-check.md"               ".claude/commands/darkflow/gsc-check.md"
smart_update_template ".claude/commands/darkflow/coolify-logs.md"            ".claude/commands/darkflow/coolify-logs.md"
smart_update_template ".claude/commands/darkflow/deployment-failure.md"      ".claude/commands/darkflow/deployment-failure.md"
smart_update_template ".claude/commands/darkflow/claude-md-update.md"        ".claude/commands/darkflow/claude-md-update.md"
smart_update_template ".claude/commands/darkflow/security-audit.md"          ".claude/commands/darkflow/security-audit.md"
smart_update_template ".claude/commands/darkflow/architecture-review.md"     ".claude/commands/darkflow/architecture-review.md"

# Dispatcher script — always update to latest
mkdir -p ".darkflow.d/state"
smart_update_template "darkflow/darkflow-run.sh"           ".darkflow.d/darkflow-run.sh"
[[ -f ".darkflow.d/darkflow-run.sh" ]] && chmod +x ".darkflow.d/darkflow-run.sh"
smart_update_template "darkflow/install-scheduler.sh"      ".darkflow.d/install-scheduler.sh"
[[ -f ".darkflow.d/install-scheduler.sh" ]] && chmod +x ".darkflow.d/install-scheduler.sh"
smart_update_template "darkflow/uninstall-scheduler.sh"    ".darkflow.d/uninstall-scheduler.sh"
[[ -f ".darkflow.d/uninstall-scheduler.sh" ]] && chmod +x ".darkflow.d/uninstall-scheduler.sh"

# routines.yml is project-specific (filtered by modules) — don't overwrite, just add if missing
if [[ ! -f ".darkflow.d/routines.yml" ]]; then
  info "Creating missing .darkflow.d/routines.yml (run install.sh to regenerate with module filtering)"
  if [[ "$USE_LOCAL" == true ]]; then
    cp "$SOURCE_DIR/darkflow/routines.yml" ".darkflow.d/routines.yml"
  else
    curl -fsSL "${DARKFLOW_REPO}/templates/darkflow/routines.yml?t=$(date +%s)" -o ".darkflow.d/routines.yml"
  fi
  success "Added: .darkflow.d/routines.yml"
else
  skip ".darkflow.d/routines.yml (project-specific — edit manually)"
fi

# Ensure .darkflow.d runtime files are git-ignored
for gi_entry in ".darkflow.d/state/" ".darkflow.d/*.log"; do
  if ! grep -qF "$gi_entry" .gitignore 2>/dev/null; then
    [[ "$DRY_RUN" == false ]] && echo "$gi_entry" >> .gitignore
    success "Added ${gi_entry} to .gitignore"
  fi
done

# ── 3. CLAUDE.md — update only the Dark Flow section ────────────────────────

header "3/4  CLAUDE.md"

if [[ ! -f "CLAUDE.md" ]]; then
  warn "CLAUDE.md not found — skipping"
elif ! grep -q "darkflow:start" CLAUDE.md; then
  warn "CLAUDE.md has no <!-- darkflow:start --> marker"
  echo -e "  ${DIM}The Dark Flow section was probably added before v1.0.0 markers were introduced.${RESET}"
  echo -e "  ${DIM}Add the markers manually around the Dark Flow section, then re-run update.${RESET}"
else
  # Regenerate the section between markers
  # Build the new section inline — KEEP IN SYNC with generate_claude_md_section() in install.sh
  new_section="<!-- darkflow:start -->
## Documentation & Agent Workflow

@docs/agent-workflow.md
@docs/github-issues.md

**Language:** ${LANGUAGE} — use this language for GitHub issues, comments, commit messages, and all agent-facing text.
**Main branch:** \`${MAIN_BRANCH}\`"

  if [[ "$MERGE_STRATEGY" == "direct" ]]; then
    new_section="${new_section}
**Fix Issues strategy:** commit and push directly to \`${MAIN_BRANCH}\` — no pull requests."
  else
    new_section="${new_section}
**Fix Issues strategy:** open a pull request, then merge into \`${MAIN_BRANCH}\` with \`Closes #N\`."
  fi

  new_section="${new_section}

### Before each session

Check approved task queue:
\`\`\`bash
gh issue list --label \"status:approved\" --state open --json number,title,labels,body --limit 20
\`\`\`
If there are approved issues with \`area:*\` matching the current context — pick them first.
Before starting: set \`status:in-progress\`, leave a comment with the branch name.

### When to read docs

- **Any UI/UX task** → \`docs/design/voice-and-tone.md\` + \`docs/design/tokens.md\` + \`docs/design/patterns.md\` + \`docs/design/components.md\`
- **Changing a user flow** → \`docs/spec/flows/\`
- **Product / marketing decisions** → \`docs/product/positioning.md\` + \`docs/product/audience.md\` + \`docs/product/pricing.md\`"

  [[ "$MOD_ANALYTICS" == true ]] && new_section="${new_section}
- **Working with analytics events** → \`docs/product/metrics.md\` (not guessing event names)
- **Context on what's working now** → last 2–3 files from \`docs/insights/analytics/\`"
  [[ "$MOD_GSC"       == true ]] && new_section="${new_section}
- **SEO decisions** → last 2–3 files from \`docs/insights/search-console/\`"
  [[ "$MOD_ADS"       == true ]] && new_section="${new_section}
- **Ads campaigns** → last 2–3 files from \`docs/insights/ads/\`"

  new_section="${new_section}
- **Before architectural changes** → \`docs/decisions/\` (check for existing ADRs)

### When to write docs

- **Changed a user flow** → update \`docs/spec/flows/*.md\`
- **Added / removed a screen** → update \`docs/spec/screens/inventory.md\`
- **Changed data model** → update \`docs/spec/data-model.md\`
- **Changed pricing / billing** → update \`docs/product/pricing.md\`
- **Added UI component or pattern** → update \`docs/design/components.md\` / \`docs/design/patterns.md\`
- **Made an architectural decision** → add ADR to \`docs/decisions/\` (context → decision → how to verify)"

  [[ "$MOD_ANALYTICS" == true ]] && new_section="${new_section}
- **After analyzing analytics** → write snapshot to \`docs/insights/analytics/YYYY-MM-DD.md\`"
  [[ "$MOD_GSC"       == true ]] && new_section="${new_section}
- **After checking GSC** → write snapshot to \`docs/insights/search-console/YYYY-MM-DD.md\`"
  [[ "$MOD_ADS"       == true ]] && new_section="${new_section}
- **After checking ads** → write snapshot to \`docs/insights/ads/YYYY-MM-DD.md\`"

  new_section="${new_section}

### Active Routines

Scheduled Claude Code agents that run this workflow automatically:

- **Fix issues** (Hourly) — picks up \`status:approved\` issues → PR → merge to ${MAIN_BRANCH}"

  [[ "$MOD_ANALYTICS"     == true ]] && new_section="${new_section}
- **Analytics review** (Daily 8:00) — ${OBS_TOOL:-analytics} + recent commits → GitHub issues"
  [[ "$MOD_OBSERVABILITY" == true ]] && { obs_label="${OBS_TOOL:-Observability tool}"; new_section="${new_section}
- **Observability check** (Daily 8:30) — ${obs_label}: errors / slow queries / latency → GitHub issues"; }
  [[ "$MOD_GSC"           == true ]] && new_section="${new_section}
- **GSC check** (Weekly Mon 8:00) — Google Search Console → GitHub issues"
  [[ "$MOD_COOLIFY"       == true ]] && new_section="${new_section}
- **Coolify logs** (Daily 9:00) — deployment monitoring → fix errors"
  [[ "$MOD_CLAUDE_UPDATE" == true ]] && new_section="${new_section}
- **CLAUDE.md update** (Weekdays 9:00) — re-generates this file from codebase"
  [[ "$MOD_ARCH_REVIEW"   == true ]] && new_section="${new_section}
- **Architecture review** (Weekly Sun 2:00) — \`/improve-codebase-architecture\` → GitHub issues"

  new_section="${new_section}

Schedule: \`.darkflow.d/routines.yml\`  |  Dispatcher: \`bash .darkflow.d/darkflow-run.sh\`
Run any routine manually: \`bash .darkflow.d/darkflow-run.sh <name>\`
List status: \`bash .darkflow.d/darkflow-run.sh --list\`

### Dark Flow commands

Use \`/darkflow\` inside Claude Code to check workflow health and review the approved queue.

Workflow commands: \`/darkflow:add-issue\`, \`/darkflow:update\`, \`/darkflow:install\`.

Routine commands (run any routine interactively or use as the routine prompt):
- \`/darkflow:fix-issues\` — pick up one approved issue and close it
- \`/darkflow:analytics-review\` — PostHog + commits → GitHub issues
- \`/darkflow:observability-check\` — errors / slow queries / latency → GitHub issues
- \`/darkflow:gsc-check\` — Google Search Console → GitHub issues
- \`/darkflow:coolify-logs\` — deployment log monitoring
- \`/darkflow:deployment-failure\` — diagnose and fix a failed deployment
- \`/darkflow:claude-md-update\` — regenerate CLAUDE.md from codebase
- \`/darkflow:architecture-review\` — architectural analysis → GitHub issues
- \`/darkflow:security-audit\` — full security review (static + runtime) → GitHub issues

<!-- darkflow:end -->"

  if [[ "$DRY_RUN" == false ]]; then
    # Replace between markers using awk
    awk -v new="$new_section" '
      /<!-- darkflow:start -->/ { printing=1; print new; next }
      /<!-- darkflow:end -->/   { printing=0; next }
      !printing
    ' CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
    success "Updated Dark Flow section in CLAUDE.md"
  else
    info "Would update Dark Flow section in CLAUDE.md"
  fi
fi

# ── 4. Update .darkflow config version ───────────────────────────────────────

header "4/4  Config"

if [[ "$DRY_RUN" == false ]]; then
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/^version=.*/version=${LATEST_VERSION}/" .darkflow
    sed -i '' "s/^installed=.*/installed=$(date -u +%Y-%m-%d)/" .darkflow
  else
    sed -i "s/^version=.*/version=${LATEST_VERSION}/" .darkflow
    sed -i "s/^installed=.*/installed=$(date -u +%Y-%m-%d)/" .darkflow
  fi
  success "Updated .darkflow to version ${LATEST_VERSION}"
fi

# ── New routines announcement ─────────────────────────────────────────────────

NEW_ROUTINES=$(fetch_raw "CHANGELOG.md" | awk "/## \[${LATEST_VERSION}\]/,/## \[${INSTALLED_VERSION}\]/" \
  | grep "New routine" | sed 's/.*`\(.*\)`.*/\1/' || true)

if [[ -n "$NEW_ROUTINES" ]]; then
  echo ""
  echo -e "${BOLD}New routines available in this version:${RESET}"
  while IFS= read -r r; do
    echo "  + ${r} — https://github.com/alifanov/darkflow/blob/main/routines/${r}.md"
  done <<< "$NEW_ROUTINES"
  echo ""
  echo -e "${DIM}Add their entries to .darkflow.d/routines.yml (see https://github.com/alifanov/darkflow/blob/main/routines/)${RESET}"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}Dry run complete — no changes were applied.${RESET}"
  echo "Remove --dry-run to apply."
else
  echo -e "${GREEN}${BOLD}Dark Flow updated to ${LATEST_VERSION}${RESET}"
  echo ""
  echo "Commit the changes:"
  echo "  git add .darkflow .darkflow.d/darkflow-run.sh .darkflow.d/install-scheduler.sh .darkflow.d/uninstall-scheduler.sh .darkflow.d/routines.yml"
  echo "  git add docs/agent-workflow.md docs/github-issues.md CLAUDE.md"
  echo "  git commit -m 'chore: update dark-flow to ${LATEST_VERSION}'"
  echo ""
  if [[ ! -f "$HOME/Library/LaunchAgents/com.darkflow.${SLUG}.plist" ]] && \
     ! crontab -l 2>/dev/null | grep -q "# darkflow:${SLUG}" 2>/dev/null; then
    echo -e "${DIM}No system scheduler detected. To install: re-run install.sh --with-scheduler${RESET}"
  fi
fi
echo ""
