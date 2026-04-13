#!/bin/bash
# Hook: SessionStart(compact)
# Purpose: Re-inject context after compaction — branch, task, uncommitted, reminders.
# Exit: Always 0. Stdout is injected into Claude's context.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Context compacted — re-injecting project state"
echo "📅 $(date '+%Y-%m-%d %H:%M')"

# Branch
BRANCH=$(cd "$PROJECT_DIR" && git branch --show-current 2>/dev/null || echo "unknown")
echo "🌿 Branch: $BRANCH"

# Current task
if [ -f "$PROJECT_DIR/claude/tasks/todo.md" ]; then
  TASK=$(head -5 "$PROJECT_DIR/claude/tasks/todo.md" 2>/dev/null | grep -E '^##' | head -1 || true)
  if [ -n "$TASK" ]; then
    echo "📋 Task: $TASK"
  fi
  # Show next action
  NEXT=$(grep -m1 'NEXT →' "$PROJECT_DIR/claude/tasks/todo.md" 2>/dev/null || true)
  if [ -n "$NEXT" ]; then
    echo "➡️  $NEXT"
  fi
fi

# Uncommitted changes
UNCOMMITTED=$(cd "$PROJECT_DIR" && git status --short 2>/dev/null | wc -l)
if [ "$UNCOMMITTED" -gt 0 ]; then
  echo "📝 Uncommitted files: $UNCOMMITTED"
fi

echo ""
echo "⚡ Domain docs must be re-read from CLAUDE.md lookup table"
echo "⚡ Run /resume to reload full context, or continue with current task"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0

