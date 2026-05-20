#!/usr/bin/env bash
# Setup GitHub issue labels for Dark Flow workflow
# Run standalone: bash setup-labels.sh
# Or called from install.sh

set -euo pipefail

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

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

# area:* — where in the codebase (extend for your project)
label "area:worker"    "c2e0c6" "Background worker / job queue"
label "area:api"       "c2e0c6" "API routes / backend"
label "area:landing"   "c2e0c6" "Landing page / SEO pages"
label "area:checkout"  "c2e0c6" "Payment / checkout flow"
label "area:auth"      "c2e0c6" "Authentication"
label "area:dashboard" "c2e0c6" "User dashboard / app"
label "area:email"     "c2e0c6" "Email templates / sending"
label "area:checks"       "c2e0c6" "Security checks / scheduled jobs"
label "area:architecture" "c2e0c6" "Cross-cutting architectural concerns"
label "area:docs"         "c2e0c6" "Documentation in docs/"
label "area:infra"        "c2e0c6" "Infrastructure / CI / config"

# priority:*
label "priority:p0" "b60205" "Breaks revenue or disables a feature right now"
label "priority:p1" "d93f0b" "This week"
label "priority:p2" "fbca04" "This month"
label "priority:p3" "cccccc" "Someday / nice-to-have"

# effort:*
label "effort:xs" "bfdadc" "≤ 30 minutes"
label "effort:s"  "bfdadc" "~ 2 hours"
label "effort:m"  "bfdadc" "~ half a day"
label "effort:l"  "bfdadc" "> 1 day — split into sub-issues"

echo ""
echo "Labels ready. You can now filter with:"
echo "  gh issue list --label 'status:approved' --state open"
