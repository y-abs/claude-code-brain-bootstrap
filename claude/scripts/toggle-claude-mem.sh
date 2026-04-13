#!/usr/bin/env bash
# toggle-claude-mem.sh — Toggle claude-mem plugin ON/OFF
#
# Usage:
#   ./claude/scripts/toggle-claude-mem.sh          # Toggle (flip current state)
#   ./claude/scripts/toggle-claude-mem.sh on       # Enable
#   ./claude/scripts/toggle-claude-mem.sh off      # Disable + kill worker
#   ./claude/scripts/toggle-claude-mem.sh status   # Show current state
#
# Why: claude-mem consumes significant API quota via background observer sessions
# (~48% of quota in a 45-min session). Disable during heavy batch work or low quota.

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ toggle-claude-mem.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -euo pipefail

PLUGIN="claude-mem@thedotmack"
WORKER_PATTERN="claude-mem.*worker-service"

# Pre-check: claude CLI must be available
if ! command -v claude &>/dev/null; then
  echo "❌ claude CLI not found — install Claude Code first"
  exit 1
fi

get_status() {
  local output
  output=$(claude plugin list 2>&1)
  # Scope grep to the specific plugin line to avoid false matches from other plugins
  local plugin_line
  plugin_line=$(echo "$output" | grep -i 'claude-mem' || true)
  if [ -z "$plugin_line" ]; then
    echo "not installed"
  elif echo "$plugin_line" | grep -q 'enabled'; then
    echo "enabled"
  elif echo "$plugin_line" | grep -q 'disabled'; then
    echo "disabled"
  else
    echo "installed (status unclear)"
  fi
}

enable_plugin() {
  echo "🟢 Enabling claude-mem..."
  if ! claude plugin enable "$PLUGIN" 2>&1; then
    echo "❌ Failed to enable — plugin may not be installed"
    echo "   Install: claude plugin install $PLUGIN"
    exit 1
  fi
  echo "✅ claude-mem ENABLED — will activate on next Claude Code session"
}

disable_plugin() {
  echo "🔴 Disabling claude-mem..."
  if ! claude plugin disable "$PLUGIN" 2>&1; then
    echo "❌ Failed to disable — plugin may not be installed"
    echo "   Install: claude plugin install $PLUGIN"
    exit 1
  fi
  local pids
  pids=$(pgrep -f "$WORKER_PATTERN" 2>/dev/null || true)
  if [ -n "$pids" ]; then
    echo "   Stopping worker service (PIDs: $pids)..."
    kill "$pids" 2>/dev/null || true
    echo "   Worker stopped."
  fi
  echo "✅ claude-mem DISABLED — no more background API consumption"
}

show_status() {
  local state
  state=$(get_status)
  local worker_running="no"
  if pgrep -f "$WORKER_PATTERN" >/dev/null 2>&1; then
    worker_running="yes (PID: $(pgrep -f "$WORKER_PATTERN" | head -1))"
  fi
  echo "claude-mem plugin: $state"
  echo "worker service:    $worker_running"
  echo "health endpoint:   $(curl -sf http://localhost:37777/health 2>/dev/null || echo 'not responding')"
}

case "${1:-toggle}" in
  on|enable)   enable_plugin ;;
  off|disable) disable_plugin ;;
  status|s)    show_status ;;
  toggle|t)
    current=$(get_status)
    if [ "$current" = "enabled" ]; then
      disable_plugin
    else
      enable_plugin
    fi
    ;;
  *) echo "Usage: $0 [on|off|status|toggle]"; exit 1 ;;
esac

