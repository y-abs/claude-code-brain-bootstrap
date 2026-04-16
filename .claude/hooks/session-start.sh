#!/bin/bash
# Hook: SessionStart(startup|resume|clear)
# Purpose: Inject branch, current task, uncommitted changes, recent commits, and critical reminders on cold session starts.
# Exit: Always 0. Stdout is injected into Claude's context.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📅 $(date '+%Y-%m-%d %H:%M') — Session Start"

# Branch
BRANCH=$(cd "$PROJECT_DIR" && git branch --show-current 2>/dev/null || echo "unknown")
echo "🌿 Branch: $BRANCH"

# Current task
if [ -f "$PROJECT_DIR/claude/tasks/todo.md" ]; then
  TASK=$(head -5 "$PROJECT_DIR/claude/tasks/todo.md" 2>/dev/null | grep -E '^##' | head -1 || true)
  if [ -n "$TASK" ]; then
    echo "📋 Task: $TASK"
  fi
fi

# Uncommitted changes
UNCOMMITTED=$(cd "$PROJECT_DIR" && git status --short 2>/dev/null | head -10)
if [ -n "$UNCOMMITTED" ]; then
  echo "📝 Uncommitted files:"
  echo "$UNCOMMITTED"
fi

# Recent commits
echo "📜 Recent commits:"
cd "$PROJECT_DIR" && git --no-pager log --oneline -5 2>/dev/null || echo "  (no commits)"

echo ""

# jq check — three safety hooks depend on it; warn loudly if absent
if ! command -v jq &>/dev/null; then
  echo "⚠️  WARNING: jq not found — config-protection, terminal-safety, and commit-quality hooks"
  echo "   are INACTIVE (they silently pass through without jq). Install: brew install jq"
fi

echo "⚡ First steps: Read claude/tasks/lessons.md + claude/architecture.md + claude/rules.md"
echo "⚡ NEVER git push autonomously — present summary, wait for confirmation"
echo "⚡ Temp files → ./claude/tasks/ — never /tmp/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0

