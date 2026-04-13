#!/bin/bash
# phase2-verify.sh — Phase 2 post-merge verification (UPGRADE path only)
# Single-line output: never triggers Claude Code's UI collapse (threshold: ~3 lines).
# Usage: bash claude/scripts/phase2-verify.sh [project-dir]
# Exit:  0 = all critical checks pass, 1 = data loss detected (restore from backup)

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ phase2-verify.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

PROJECT_DIR="${1:-.}"
ERRORS=0
ISSUES=""

test -f "$PROJECT_DIR/claude/tasks/lessons.md" \
  || { ISSUES="${ISSUES}lessons.md MISSING · "; ERRORS=$((ERRORS + 1)); }

test -f "$PROJECT_DIR/claude/tasks/todo.md" \
  || { ISSUES="${ISSUES}todo.md MISSING · "; ERRORS=$((ERRORS + 1)); }

if command -v jq &>/dev/null; then
  jq . "$PROJECT_DIR/.claude/settings.json" > /dev/null 2>&1 \
    || { ISSUES="${ISSUES}settings.json BROKEN · "; ERRORS=$((ERRORS + 1)); }
else
  ISSUES="${ISSUES}jq not installed (cannot validate settings.json) · "; ERRORS=$((ERRORS + 1))
fi

BACKUP=""
test -f "$PROJECT_DIR/claude/tasks/.pre-upgrade-backup.tar.gz" \
  && BACKUP=" · backup ✓" \
  || BACKUP=" · no backup ⚠️"

if [ "$ERRORS" -eq 0 ]; then
  echo "✅ Phase 2 OK: lessons.md ✓ · todo.md ✓ · settings.json ✓${BACKUP}"
else
  echo "❌ Phase 2 FAILED: ${ISSUES%· }"
  echo "   Restore: tar xzf claude/tasks/.pre-upgrade-backup.tar.gz"
  exit 1
fi

