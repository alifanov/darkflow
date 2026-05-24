#!/usr/bin/env bash
# Setup GitHub issue labels for Dark Flow workflow
# Run standalone: bash setup-labels.sh
# Or called from install.sh

set -euo pipefail

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
DIM="\033[2m"
RESET="\033[0m"

PRUNE_EFFORT=false
for arg in "$@"; do
  case "$arg" in
    --prune-effort) PRUNE_EFFORT=true ;;
    -h|--help)
      echo "Usage: setup-labels.sh [--prune-effort]"
      echo "  --prune-effort  Delete legacy effort:xs/s/m/l labels (removed in v2.10.0)"
      exit 0 ;;
  esac
done

label() {
  local name="$1" color="$2" desc="$3"
  if gh label create "$name" --color "$color" --description "$desc" 2>/dev/null; then
    echo -e "${GREEN}✓ created: $name${RESET}"
  else
    # Update if already exists
    if gh label edit "$name" --color "$color" --description "$desc" 2>/dev/null; then
      echo -e "${YELLOW}↻ updated: $name${RESET}"
    fi
  fi
}

echo "Setting up Dark Flow labels..."

if [[ "$PRUNE_EFFORT" == true ]]; then
  echo ""
  echo "Pruning legacy effort:* labels..."
  for l in effort:xs effort:s effort:m effort:l; do
    if gh label delete "$l" --yes 2>/dev/null; then
      echo -e "${YELLOW}× deleted: $l${RESET}"
    else
      echo -e "${DIM}  skip: $l (not present)${RESET}"
    fi
  done
  echo ""
fi

# status:* — lifecycle state machine
label "status:proposed"    "fbca04" "Created by agent, awaiting human decision"
label "status:approved"    "0e8a16" "Human approved — agent may pick up"
label "status:rejected"    "b60205" "Won't do — do not recreate without new data"
label "status:needs-info"  "d4c5f9" "Needs context — agent clarifies in comment"
label "status:in-progress" "1d76db" "Agent started; comment has branch/PR link"
label "status:blocked"     "e99695" "Blocked by external factor"

# source:* — where the recommendation came from
label "source:posthog"         "5319e7" "From insights/analytics/* (PostHog/HogQL)"
label "source:gsc"             "5319e7" "From insights/search-console/* (GSC)"
label "source:ads"             "5319e7" "From insights/ads/* (Google Ads)"
label "source:signoz"          "5319e7" "From SigNoz observability"
label "source:security-review" "5319e7" "From security audit"
label "source:ux-audit"        "5319e7" "From UI review / session recordings"
label "source:user-feedback"   "5319e7" "From insights/qualitative/*"
label "source:manual"          "5319e7" "Hypothesis without data source"

# priority:*
label "priority:p0" "b60205" "Breaks revenue or disables a feature right now"
label "priority:p1" "d93f0b" "This week"
label "priority:p2" "fbca04" "This month"
label "priority:p3" "cccccc" "Someday / nice-to-have"

echo ""
echo "Labels ready. You can now filter with:"
echo "  gh issue list --label 'status:approved' --state open"
