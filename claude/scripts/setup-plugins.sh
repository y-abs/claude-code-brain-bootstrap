#!/bin/bash
# setup-plugins.sh — All-in-one plugin management for bootstrap
# Handles: wait for bg install → disable claude-mem → kill worker → verify → update CLAUDE.md
#          + graphify knowledge graph: pip install → skill install → git hooks
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


# ─── Portable helpers (sed_inplace, safe_pgrep, platform detection)
source "$(dirname "$0")/_platform.sh"

# ═════════════════════════════════════════════════════════════════
# SECTION 1: claude-mem (Claude Code plugin)
# ═════════════════════════════════════════════════════════════════

if ! command -v claude &>/dev/null; then
  echo "✅ claude-mem setup skipped (claude CLI not available — non-Claude Code environment)"
  # Still update CLAUDE.md placeholder even without plugin
  if [ -f "CLAUDE.md" ] && grep -q '{{INSTALLED_PLUGINS}}' "CLAUDE.md" 2>/dev/null; then
    sed_inplace $'s|<!-- {{INSTALLED_PLUGINS}}.*-->|- **claude-mem** — install manually: `claude plugin install claude-mem@thedotmack` then disable for quota protection|' "CLAUDE.md"
  fi
  CLAUDE_MEM_STATUS="skipped (no claude CLI)"
else
  echo "🔌 Plugin Setup — claude-mem..."

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
  WORKER_PIDS=$(safe_pgrep '[c]laude-mem.*worker-service')
  if [ -n "$WORKER_PIDS" ]; then kill $WORKER_PIDS 2>/dev/null || true; fi

  # 6. Verify final state
  claude plugin list > claude/tasks/.plugin-list.log 2>&1 || true
  CLEAN_LIST=$(sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r//g' claude/tasks/.plugin-list.log 2>/dev/null | grep -v '^[[:space:]]*$' || true)
  if echo "$CLEAN_LIST" | grep -qi 'claude-mem'; then
    CLAUDE_MEM_STATUS="installed (disabled)"
  else
    CLAUDE_MEM_STATUS="not installed — user can run: claude plugin install claude-mem@thedotmack"
  fi

  # 7. Update CLAUDE.md — replace plugin placeholder with actual state
  if [ -f "CLAUDE.md" ] && grep -q '{{INSTALLED_PLUGINS}}' "CLAUDE.md" 2>/dev/null; then
    sed_inplace $'s|<!-- {{INSTALLED_PLUGINS}}.*-->|- **claude-mem** — persistent cross-session memory (SQLite + ChromaDB) — ⚠️ disabled by default (toggle: `bash claude/scripts/toggle-claude-mem.sh on`)|' "CLAUDE.md"
    echo "  ✅ CLAUDE.md plugin section updated"
  fi

  echo "  ✅ claude-mem: $CLAUDE_MEM_STATUS"
fi

# ═════════════════════════════════════════════════════════════════
# SECTION 2: graphify (knowledge graph — Python package + skill)
# ═════════════════════════════════════════════════════════════════

echo ""
echo "🔌 Plugin Setup — graphify..."

# Detect Python 3.10+ (required by graphify)
GRAPHIFY_PYTHON=""
for py_cmd in python3 python; do
  if command -v "$py_cmd" &>/dev/null; then
    PY_VER=$("$py_cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
    PY_MAJOR="${PY_VER%%.*}"
    PY_MINOR="${PY_VER##*.}"
    if [ "${PY_MAJOR:-0}" -ge 3 ] && [ "${PY_MINOR:-0}" -ge 10 ]; then
      GRAPHIFY_PYTHON="$py_cmd"
      break
    fi
  fi
done

if [ -z "$GRAPHIFY_PYTHON" ]; then
  echo "  ⚠️  graphify skipped — Python 3.10+ not found"
  echo "     Install Python 3.10+ and run: pip install graphifyy && graphify install && graphify hook install"
  GRAPHIFY_STATUS="skipped (Python 3.10+ not found)"
else
  # Check if graphify is already installed
  if "$GRAPHIFY_PYTHON" -c "import graphify" 2>/dev/null; then
    GRAPHIFY_INSTALLED=true
    GRAPHIFY_VER=$("$GRAPHIFY_PYTHON" -c "from importlib.metadata import version; print(version('graphifyy'))" 2>/dev/null || echo "unknown")
    echo "  ✅ graphify $GRAPHIFY_VER already installed"
  else
    echo "  ⏳ Installing graphify (pip install graphifyy)..."
    if "$GRAPHIFY_PYTHON" -m pip install graphifyy -q 2>/dev/null || "$GRAPHIFY_PYTHON" -m pip install graphifyy -q --break-system-packages 2>/dev/null; then
      GRAPHIFY_INSTALLED=true
      GRAPHIFY_VER=$("$GRAPHIFY_PYTHON" -c "from importlib.metadata import version; print(version('graphifyy'))" 2>/dev/null || echo "unknown")
      echo "  ✅ graphify $GRAPHIFY_VER installed"
    else
      GRAPHIFY_INSTALLED=false
      echo "  ⚠️  pip install graphifyy failed — try manually: pip install graphifyy"
    fi
  fi

  if [ "$GRAPHIFY_INSTALLED" = "true" ]; then
    # Install the global skill (graphify install — copies SKILL.md to ~/.claude/skills/)
    if command -v graphify &>/dev/null; then
      GRAPHIFY_CMD="graphify"
    else
      GRAPHIFY_CMD="$GRAPHIFY_PYTHON -m graphify"
    fi

    # Global skill install (one-time per machine)
    $GRAPHIFY_CMD install > claude/tasks/.graphify-install.log 2>&1 || true

    # Git hooks (post-commit + post-checkout — auto-rebuild graph on commit/branch switch)
    $GRAPHIFY_CMD hook install > claude/tasks/.graphify-hooks.log 2>&1 || true

    GRAPHIFY_STATUS="$GRAPHIFY_VER installed · skill registered · git hooks active"
    echo "  ✅ graphify skill registered + git hooks installed"
    echo "  👉 Run /graphify . to build the knowledge graph (first run ~5 min, then incremental)"
  else
    GRAPHIFY_STATUS="install failed — manual: pip install graphifyy && graphify install"
  fi
fi

# ═════════════════════════════════════════════════════════════════
# SUMMARY (compact — avoids Claude Code UI collapse at ≥4 lines)
# ═════════════════════════════════════════════════════════════════

echo ""
echo "✅ Plugins: claude-mem ${CLAUDE_MEM_STATUS:-skipped} · graphify ${GRAPHIFY_STATUS:-skipped}"
if [ -f "claude/tasks/.bootstrap-plan.txt" ]; then echo "P4 $(date +%H:%M:%S)" >> "claude/tasks/.bootstrap-progress.txt" 2>/dev/null; fi

