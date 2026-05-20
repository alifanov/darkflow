#!/usr/bin/env bash
# Installs a system scheduler that runs the Dark Flow dispatcher every 15 min.
# macOS: launchd job in ~/Library/LaunchAgents/
# Linux: crontab entry
#
# Run from anywhere inside the project:
#   bash .darkflow.d/install-scheduler.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

info()    { echo -e "${CYAN}▸ $*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }

read_config() {
  local key="$1" default="${2:-}"
  grep "^${key}=" "${PROJECT_ROOT}/.darkflow" 2>/dev/null | cut -d= -f2- || echo "$default"
}

SLUG=$(read_config slug "")
if [[ -z "$SLUG" ]]; then
  SLUG=$(basename "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')
fi

DISPATCHER="${PROJECT_ROOT}/.darkflow.d/darkflow-run.sh"

if [[ ! -f "$DISPATCHER" ]]; then
  echo "darkflow-run.sh not found at ${DISPATCHER}. Run install.sh first." >&2
  exit 1
fi

OS="$(uname)"

case "$OS" in
  Darwin)
    PLIST_PATH="$HOME/Library/LaunchAgents/com.darkflow.${SLUG}.plist"

    if [[ -f "$PLIST_PATH" ]]; then
      launchctl unload "$PLIST_PATH" 2>/dev/null || true
      info "Replacing existing launchd job: com.darkflow.${SLUG}"
    fi

    cat > "$PLIST_PATH" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.darkflow.${SLUG}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${PROJECT_ROOT}/.darkflow.d/darkflow-run.sh</string>
  </array>
  <key>WorkingDirectory</key><string>${PROJECT_ROOT}</string>
  <key>StartInterval</key><integer>900</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>${PROJECT_ROOT}/.darkflow.d/launchd.out.log</string>
  <key>StandardErrorPath</key><string>${PROJECT_ROOT}/.darkflow.d/launchd.err.log</string>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
</dict></plist>
PLIST_EOF

    launchctl load "$PLIST_PATH"
    success "Installed launchd job: com.darkflow.${SLUG} (every 15 min)"
    info "Logs: ${PROJECT_ROOT}/.darkflow.d/launchd.{out,err}.log"
    info "Remove: bash .darkflow.d/uninstall-scheduler.sh"
    ;;

  Linux)
    CRON_LINE="*/15 * * * * cd ${PROJECT_ROOT} && /bin/bash .darkflow.d/darkflow-run.sh >> .darkflow.d/cron.log 2>&1  # darkflow:${SLUG}"
    (crontab -l 2>/dev/null | grep -v "# darkflow:${SLUG}"; echo "$CRON_LINE") | crontab -
    success "Added crontab entry for darkflow:${SLUG} (every 15 min)"
    info "Logs: ${PROJECT_ROOT}/.darkflow.d/cron.log"
    info "Remove: bash .darkflow.d/uninstall-scheduler.sh"
    ;;

  *)
    warn "Unsupported OS: $OS"
    echo "Add the dispatcher to your scheduler manually:"
    echo "  ${DISPATCHER}"
    exit 1
    ;;
esac

echo ""
echo -e "${BOLD}Dependency check:${RESET}"
if command -v yq &>/dev/null; then
  success "yq found: $(which yq)"
else
  warn "yq not found — install before the scheduler fires: brew install yq"
fi
if command -v claude &>/dev/null; then
  success "claude found: $(which claude)"
else
  warn "claude not found — install Claude Code: https://claude.ai/code"
fi
