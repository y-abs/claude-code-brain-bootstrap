#!/bin/bash
# setup-plugins.sh — All-in-one plugin management for bootstrap
# Handles: wait for bg install → disable claude-mem → kill worker → verify → update CLAUDE.md
# Usage: bash claude/scripts/setup-plugins.sh [project-dir]
# Safe: exits cleanly if claude CLI not available (non-Claude Code environments)

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ setup-plugins.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -eo pipefail
PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# ─── Portable sed -i ──────────────────────────────────────────────
if [[ "$(uname)" == "Darwin" ]]; then
  sed_inplace() { sed -i '' "$@"; }
else
  sed_inplace() { sed -i "$@"; }
fi

# ─── Pre-check: claude CLI available? ─────────────────────────────
if ! command -v claude &>/dev/null; then
  echo "✅ Plugin setup skipped (claude CLI not available — non-Claude Code environment)"
  # Still update CLAUDE.md placeholder even without plugin
  if [ -f "CLAUDE.md" ] && grep -q '{{INSTALLED_PLUGINS}}' "CLAUDE.md" 2>/dev/null; then
    sed_inplace $'s|<!-- {{INSTALLED_PLUGINS}}.*-->|- **claude-mem** — install manually: `claude plugin install claude-mem@thedotmack` then disable for quota protection|' "CLAUDE.md"
  fi
  exit 0
fi

echo "🔌 Plugin Setup..."

# 1. Attempt to wait for any child bg processes (no-op if Phase 1 ran in a different shell)
wait 2>/dev/null || true

# 2. Show install log if exists
if [ -f "claude/tasks/.plugin-install.log" ]; then
  sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r//g' claude/tasks/.plugin-install.log 2>/dev/null \
    | grep -v '^[[:space:]]*$' | tail -3 || true
fi

# 3. Check if installed; if not, try synchronous install once
claude plugin list > claude/tasks/.plugin-list.log 2>&1 || true
if ! sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r//g' claude/tasks/.plugin-list.log 2>/dev/null | grep -qi 'claude-mem'; then
  echo "  ⏳ Installing claude-mem..."
  claude plugin install claude-mem@thedotmack > claude/tasks/.plugin-install.log 2>&1 || true
fi

# 4. Disable claude-mem (quota protection — PostToolUse(*) uses ~48% API quota)
claude plugin disable claude-mem@thedotmack > claude/tasks/.plugin-disable.log 2>&1 || true

# 5. Kill any running worker process
# [c] = anti-self-match pattern (prevents pgrep from matching its own command line)
kill $(pgrep -f '[c]laude-mem.*worker-service' 2>/dev/null) 2>/dev/null || true

# 6. Verify final state
claude plugin list > claude/tasks/.plugin-list.log 2>&1 || true
CLEAN_LIST=$(sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r//g' claude/tasks/.plugin-list.log 2>/dev/null | grep -v '^[[:space:]]*$' || true)
if echo "$CLEAN_LIST" | grep -qi 'claude-mem'; then
  PLUGIN_STATUS="installed (disabled)"
else
  PLUGIN_STATUS="not installed — user can run: claude plugin install claude-mem@thedotmack"
fi

# 7. Update CLAUDE.md — replace plugin placeholder with actual state
if [ -f "CLAUDE.md" ] && grep -q '{{INSTALLED_PLUGINS}}' "CLAUDE.md" 2>/dev/null; then
  sed_inplace $'s|<!-- {{INSTALLED_PLUGINS}}.*-->|- **claude-mem** — persistent cross-session memory (SQLite + ChromaDB) — ⚠️ disabled by default (toggle: `bash claude/scripts/toggle-claude-mem.sh on`)|' "CLAUDE.md"
  echo "  ✅ CLAUDE.md plugin section updated"
fi

# 8. Summary (single line — avoids Claude Code UI collapse at ≥4 lines)
echo "✅ Plugins: claude-mem $PLUGIN_STATUS · Enable: bash claude/scripts/toggle-claude-mem.sh on"

# Bootstrap progress tracking (only during bootstrap)
if [ -f "claude/tasks/.bootstrap-plan.txt" ]; then echo "P4 $(date +%H:%M:%S)" >> "claude/tasks/.bootstrap-progress.txt" 2>/dev/null; fi

