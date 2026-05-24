#!/usr/bin/env bash
# Dark Flow installation checker — verifies every artifact in checklist.yml exists.
#
# Usage (inside a project that has Dark Flow installed):
#   bash check.sh                # report only (exit 1 if missing)
#   bash check.sh --fix          # report + interactive auto-fix
#   bash check.sh --quiet        # only summary line
#
# Designed to be run automatically at the end of install.sh and update.sh.
# Can also be fetched standalone:
#   bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/check.sh) --fix

set -euo pipefail

DARKFLOW_REPO="https://raw.githubusercontent.com/alifanov/darkflow/main"
TARGET_DIR="${PWD}"
FIX=false
QUIET=false
ASSUME_YES=false
CHECKLIST_OVERRIDE=""
TEMPLATES_OVERRIDE=""

BOLD="\033[1m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"
RED="\033[0;31m"; CYAN="\033[0;36m"; DIM="\033[2m"; RESET="\033[0m"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix)     FIX=true; shift ;;
    --quiet|-q) QUIET=true; shift ;;
    --yes|-y)  ASSUME_YES=true; FIX=true; shift ;;
    --target)  TARGET_DIR="$2"; shift 2 ;;
    --checklist) CHECKLIST_OVERRIDE="$2"; shift 2 ;;
    --templates) TEMPLATES_OVERRIDE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo -e "${YELLOW}⚠ Unknown argument: $1${RESET}" >&2; shift ;;
  esac
done

cd "$TARGET_DIR"

# ── Dependencies ──────────────────────────────────────────────────────────────

if ! command -v yq >/dev/null 2>&1; then
  echo -e "${RED}✗ yq is required for checklist parsing${RESET}" >&2
  echo "  macOS:  brew install yq" >&2
  echo "  Linux:  https://github.com/mikefarah/yq#install" >&2
  exit 2
fi

# ── Resolve checklist source ──────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
CHECKLIST=""
LOCAL_TEMPLATES_DIR=""

# Priority: explicit --checklist > next to script > remote
if [[ -n "$CHECKLIST_OVERRIDE" ]]; then
  CHECKLIST="$CHECKLIST_OVERRIDE"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/checklist.yml" ]]; then
  CHECKLIST="$SCRIPT_DIR/checklist.yml"
else
  CHECKLIST="$(mktemp)"
  if ! curl -fsSL "${DARKFLOW_REPO}/checklist.yml?t=$(date +%s)" -o "$CHECKLIST"; then
    echo -e "${RED}✗ Failed to fetch checklist.yml from ${DARKFLOW_REPO}${RESET}" >&2
    exit 2
  fi
fi

# Priority: explicit --templates > script_dir/templates > remote
if [[ -n "$TEMPLATES_OVERRIDE" ]]; then
  LOCAL_TEMPLATES_DIR="$TEMPLATES_OVERRIDE"
elif [[ -n "$SCRIPT_DIR" && -d "$SCRIPT_DIR/templates" ]]; then
  LOCAL_TEMPLATES_DIR="$SCRIPT_DIR/templates"
fi

# ── Read .darkflow ────────────────────────────────────────────────────────────

if [[ ! -f .darkflow ]]; then
  echo -e "${RED}✗ .darkflow config not found — this project doesn't have Dark Flow installed.${RESET}" >&2
  echo "  Run the installer first:  bash <(curl -fsSL ${DARKFLOW_REPO}/install.sh)" >&2
  exit 2
fi

read_config() {
  local key="$1" default="${2:-}"
  local v
  v=$(grep "^${key}=" .darkflow 2>/dev/null | head -1 | cut -d= -f2- || true)
  [[ -n "$v" ]] && echo "$v" || echo "$default"
}

SLUG=$(read_config slug "$(basename "$TARGET_DIR" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')")
MODULES=$(read_config modules "")
export SLUG  # used in $check expressions

case "$(uname)" in
  Darwin) OS=macos ;;
  Linux)  OS=linux ;;
  *)      OS=other ;;
esac

module_active() {
  local m="$1"
  [[ ",${MODULES}," == *",${m},"* ]]
}

# ── Fetch a template (local or remote) ────────────────────────────────────────

fetch_template() {
  local rel="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -n "$LOCAL_TEMPLATES_DIR" && -f "$LOCAL_TEMPLATES_DIR/$rel" ]]; then
    cp "$LOCAL_TEMPLATES_DIR/$rel" "$dest"
  else
    curl -fsSL "${DARKFLOW_REPO}/templates/${rel}?t=$(date +%s)" -o "$dest"
  fi
}

# ── Iterate checklist ─────────────────────────────────────────────────────────

ITEMS_COUNT=$(yq '.items | length' "$CHECKLIST")

MISSING_IDS=()
declare -A ITEM_TYPE ITEM_PATH ITEM_TEMPLATE ITEM_EXEC ITEM_MARKER \
            ITEM_KEY ITEM_DEFAULT ITEM_CHECK ITEM_FIX ITEM_WHEN ITEM_GROUP ITEM_DESC \
            ITEM_ROUTINE_KEY ITEM_CRON ITEM_MODEL ITEM_ENABLED

q() {
  # yq query returning "null" -> empty string
  local out
  out=$(yq -r "$1" "$CHECKLIST" 2>/dev/null || echo "")
  [[ "$out" == "null" ]] && out=""
  echo "$out"
}

for ((i = 0; i < ITEMS_COUNT; i++)); do
  id=$(q ".items[$i].id")
  [[ -z "$id" ]] && continue

  ITEM_TYPE[$id]=$(q ".items[$i].type")
  ITEM_PATH[$id]=$(q ".items[$i].path")
  ITEM_TEMPLATE[$id]=$(q ".items[$i].template")
  ITEM_EXEC[$id]=$(q ".items[$i].executable")
  ITEM_MARKER[$id]=$(q ".items[$i].marker_start")
  ITEM_KEY[$id]=$(q ".items[$i].key")
  ITEM_DEFAULT[$id]=$(q ".items[$i].default")
  ITEM_CHECK[$id]=$(q ".items[$i].check")
  ITEM_FIX[$id]=$(q ".items[$i].fix")
  ITEM_WHEN[$id]=$(q ".items[$i].when")
  ITEM_GROUP[$id]=$(q ".items[$i].group")
  ITEM_DESC[$id]=$(q ".items[$i].desc")
  ITEM_ROUTINE_KEY[$id]=$(q ".items[$i].routine_key")
  ITEM_CRON[$id]=$(q ".items[$i].cron")
  ITEM_MODEL[$id]=$(q ".items[$i].model")
  ITEM_ENABLED[$id]=$(q ".items[$i].enabled")

  # ── Evaluate `when` ────────────────────────────────────────────────────────
  when="${ITEM_WHEN[$id]}"
  if [[ -n "$when" ]]; then
    case "$when" in
      module.*)   module_active "${when#module.}" || continue ;;
      platform.macos) [[ "$OS" == macos ]] || continue ;;
      platform.linux) [[ "$OS" == linux ]] || continue ;;
      *) echo -e "${YELLOW}⚠ Unknown when= clause for ${id}: ${when}${RESET}" >&2 ;;
    esac
  fi

  # ── Evaluate presence ──────────────────────────────────────────────────────
  type="${ITEM_TYPE[$id]}"
  path="${ITEM_PATH[$id]}"
  present=false

  case "$type" in
    file)        [[ -f "$path" ]] && present=true ;;
    dir)         [[ -d "$path" ]] && present=true ;;
    marker)
      if [[ -f "$path" ]] && grep -qF "${ITEM_MARKER[$id]}" "$path"; then
        present=true
      fi ;;
    config-key)
      if [[ -f "$path" ]] && grep -q "^${ITEM_KEY[$id]}=" "$path"; then
        present=true
      fi ;;
    command)
      # Substitute ${SLUG} inside the expression then eval
      expr="${ITEM_CHECK[$id]//\$\{SLUG\}/${SLUG}}"
      if eval "$expr" >/dev/null 2>&1; then
        present=true
      fi ;;
    routine)
      # routines.yml must define a key under `routines:` matching routine_key
      if [[ -f "$path" ]]; then
        present_val=$(yq ".routines[\"${ITEM_ROUTINE_KEY[$id]}\"]" "$path" 2>/dev/null || echo "null")
        [[ "$present_val" != "null" && -n "$present_val" ]] && present=true
      fi ;;
    *)
      echo -e "${YELLOW}⚠ Unknown type for ${id}: ${type}${RESET}" >&2
      continue ;;
  esac

  $present || MISSING_IDS+=("$id")
done

# ── Report ────────────────────────────────────────────────────────────────────

TOTAL=${#MISSING_IDS[@]}

if [[ "$QUIET" != true ]]; then
  echo ""
  echo -e "${BOLD}Dark Flow installation check${RESET} ${DIM}(${ITEMS_COUNT} checks, ${TOTAL} missing)${RESET}"
fi

if [[ $TOTAL -eq 0 ]]; then
  [[ "$QUIET" != true ]] && echo -e "${GREEN}✓ All checks passed${RESET}\n"
  exit 0
fi

# Group missing by group for nicer output
declare -A BY_GROUP=()
for id in "${MISSING_IDS[@]}"; do
  g="${ITEM_GROUP[$id]:-other}"
  BY_GROUP[$g]+="${id} "
done

if [[ "$QUIET" != true ]]; then
  echo ""
  for g in "${!BY_GROUP[@]}"; do
    echo -e "${BOLD}${g}:${RESET}"
    for id in ${BY_GROUP[$g]}; do
      echo -e "  ${RED}✗${RESET} ${ITEM_PATH[$id]:-${ITEM_CHECK[$id]}}  ${DIM}— ${ITEM_DESC[$id]}${RESET}"
    done
    echo ""
  done
fi

# ── Fix mode ──────────────────────────────────────────────────────────────────

if [[ "$FIX" != true ]]; then
  echo -e "${DIM}Run with --fix to install missing items.${RESET}\n"
  exit 1
fi

# Confirm
if [[ "$ASSUME_YES" != true ]]; then
  if [[ -t 0 ]]; then
    read -rp "Install missing items now? [Y/n]: " answer
    case "${answer:-Y}" in
      [Yy]*|"") ;;
      *) echo "Aborted."; exit 1 ;;
    esac
  else
    echo -e "${YELLOW}⚠ --fix requires a TTY (use --yes to skip confirmation in scripts)${RESET}"
    exit 1
  fi
fi

# ── Fix handlers ──────────────────────────────────────────────────────────────

fix_copy_template() {
  local id="$1"
  local rel="${ITEM_TEMPLATE[$id]:-${ITEM_PATH[$id]}}"
  local dest="${ITEM_PATH[$id]}"
  fetch_template "$rel" "$dest"
  [[ "${ITEM_EXEC[$id]}" == "true" ]] && chmod +x "$dest"
  echo -e "  ${GREEN}✓${RESET} Restored ${dest}"
}

fix_mkdir() {
  local id="$1" d="${ITEM_PATH[$1]}"
  mkdir -p "$d"
  [[ ! -e "$d/.gitkeep" ]] && touch "$d/.gitkeep"
  echo -e "  ${GREEN}✓${RESET} Created ${d}/"
}

fix_append_config() {
  local id="$1" key="${ITEM_KEY[$1]}" def="${ITEM_DEFAULT[$1]}"
  local file="${ITEM_PATH[$1]}"
  if [[ -z "$def" ]]; then
    echo -e "  ${YELLOW}⚠${RESET} ${key} missing in ${file} — no default; run update.sh to regenerate"
    return
  fi
  echo "${key}=${def}" >> "$file"
  echo -e "  ${GREEN}✓${RESET} Added ${key}=${def} to ${file}"
}

fix_install_scheduler() {
  if [[ -x .darkflow.d/install-scheduler.sh ]]; then
    bash .darkflow.d/install-scheduler.sh
  else
    echo -e "  ${YELLOW}⚠${RESET} .darkflow.d/install-scheduler.sh missing — re-run update.sh first"
    return 1
  fi
}

fix_add_routine() {
  local id="$1"
  local file="${ITEM_PATH[$id]}"
  local key="${ITEM_ROUTINE_KEY[$id]}"
  local cron="${ITEM_CRON[$id]}"
  local model="${ITEM_MODEL[$id]:-sonnet}"
  local enabled="${ITEM_ENABLED[$id]:-true}"

  if [[ ! -f "$file" ]]; then
    echo -e "  ${YELLOW}⚠${RESET} ${file} missing — run update.sh first"
    return 1
  fi

  # Build the routine block as JSON then merge via yq (idempotent — overwrites only this key)
  yq -i ".routines[\"${key}\"] = {\"cron\": \"${cron}\", \"model\": \"${model}\", \"enabled\": ${enabled}}" "$file"
  echo -e "  ${GREEN}✓${RESET} Added routine ${key} (${cron:-manual}, ${model}) to ${file}"
}

fix_install_arch_skill() {
  if ! command -v npx >/dev/null 2>&1; then
    echo -e "  ${YELLOW}⚠${RESET} npx not found — install Node.js, then run:"
    echo "    npx skills add https://github.com/mattpocock/skills --skill improve-codebase-architecture"
    return 1
  fi
  npx skills add https://github.com/mattpocock/skills --skill improve-codebase-architecture
}

UPDATE_FORCE_RAN=false
fix_update_force() {
  local id="$1"
  # Run update.sh --force only once per check.sh invocation, even if multiple
  # marker items are missing. Prefer the local copy if check.sh was run from
  # the darkflow repo checkout; otherwise fetch from the remote.
  if [[ "$UPDATE_FORCE_RAN" == true ]]; then
    echo -e "  ${DIM}↳ ${ITEM_PATH[$id]} restored by the earlier update.sh --force run${RESET}"
    return 0
  fi

  echo -e "  ${CYAN}▸${RESET} Running update.sh --force to restore ${ITEM_PATH[$id]}..."
  if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/update.sh" ]]; then
    if bash "$SCRIPT_DIR/update.sh" --force --target "$TARGET_DIR"; then
      UPDATE_FORCE_RAN=true
      return 0
    fi
  else
    if bash <(curl -fsSL "${DARKFLOW_REPO}/update.sh?t=$(date +%s)") --force --target "$TARGET_DIR"; then
      UPDATE_FORCE_RAN=true
      return 0
    fi
  fi
  echo -e "  ${YELLOW}⚠${RESET} update.sh --force failed for ${ITEM_PATH[$id]}"
  return 1
}

FIXED=0
SKIPPED=0
for id in "${MISSING_IDS[@]}"; do
  handler="${ITEM_FIX[$id]}"
  if [[ -z "$handler" ]]; then
    if [[ "${ITEM_TYPE[$id]}" == "marker" ]]; then
      echo -e "  ${YELLOW}⚠${RESET} ${ITEM_PATH[$id]} block missing — run: bash update.sh --force"
    else
      echo -e "  ${YELLOW}⚠${RESET} No fix handler for ${id}"
    fi
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  case "$handler" in
    copy-template)        fix_copy_template "$id"   && FIXED=$((FIXED + 1)) || SKIPPED=$((SKIPPED + 1)) ;;
    mkdir)                fix_mkdir "$id"           && FIXED=$((FIXED + 1)) || SKIPPED=$((SKIPPED + 1)) ;;
    append-config)        fix_append_config "$id"   && FIXED=$((FIXED + 1)) || SKIPPED=$((SKIPPED + 1)) ;;
    install-scheduler)    fix_install_scheduler     && FIXED=$((FIXED + 1)) || SKIPPED=$((SKIPPED + 1)) ;;
    install-arch-skill)   fix_install_arch_skill    && FIXED=$((FIXED + 1)) || SKIPPED=$((SKIPPED + 1)) ;;
    add-routine)          fix_add_routine "$id"     && FIXED=$((FIXED + 1)) || SKIPPED=$((SKIPPED + 1)) ;;
    update-force)         fix_update_force "$id"    && FIXED=$((FIXED + 1)) || SKIPPED=$((SKIPPED + 1)) ;;
    *)
      echo -e "  ${YELLOW}⚠${RESET} Unknown fix handler '${handler}' for ${id}"
      SKIPPED=$((SKIPPED + 1)) ;;
  esac
done

echo ""
echo -e "${BOLD}Done${RESET} — fixed ${GREEN}${FIXED}${RESET}, skipped ${YELLOW}${SKIPPED}${RESET} of ${TOTAL}"
[[ $SKIPPED -eq 0 ]] && exit 0 || exit 1
