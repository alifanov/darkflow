#!/usr/bin/env bash
# Removes the Dark Flow system scheduler (launchd job on macOS, crontab entry on Linux).
# Run from anywhere inside the project.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

read_config() {
  local key="$1" default="${2:-}"
  grep "^${key}=" "${PROJECT_ROOT}/.darkflow" 2>/dev/null | cut -d= -f2- || echo "$default"
}

SLUG=$(read_config slug "")
if [[ -z "$SLUG" ]]; then
  SLUG=$(basename "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')
fi

OS="$(uname)"

case "$OS" in
  Darwin)
    PLIST="$HOME/Library/LaunchAgents/com.darkflow.${SLUG}.plist"
    if [[ -f "$PLIST" ]]; then
      launchctl unload "$PLIST" 2>/dev/null || true
      rm "$PLIST"
      echo "Removed launchd job: com.darkflow.${SLUG}"
    else
      echo "No launchd job found at: $PLIST"
    fi
    ;;
  Linux)
    if crontab -l 2>/dev/null | grep -q "# darkflow:${SLUG}"; then
      crontab -l | grep -v "# darkflow:${SLUG}" | crontab -
      echo "Removed crontab entry for darkflow:${SLUG}"
    else
      echo "No crontab entry found for darkflow:${SLUG}"
    fi
    ;;
  *)
    echo "Unsupported OS: $OS — remove the scheduler job manually."
    exit 1
    ;;
esac
