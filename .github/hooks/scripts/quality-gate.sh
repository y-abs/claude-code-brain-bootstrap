#!/bin/bash
# Copilot Hook: Stop — Quality Gate
# Reminds to run tests and check for uncommitted changes before ending.
# Adapted from .claude/hooks/exit-nudge.sh for VS Code.

WARNINGS=""

# Check for uncommitted changes
DIRTY="$(git status --porcelain 2>/dev/null | head -5 || true)"
if [ -n "$DIRTY" ]; then
  WARNINGS="${WARNINGS}\n⚠️ Uncommitted changes detected. Consider committing or stashing before ending."
fi

# Check if todo has unchecked items
if [ -f "claude/tasks/todo.md" ]; then
  UNCHECKED="$(grep -c '^\s*- \[ \]' claude/tasks/todo.md 2>/dev/null || echo 0)"
  if [ "$UNCHECKED" -gt 0 ]; then
    WARNINGS="${WARNINGS}\n⚠️ ${UNCHECKED} unchecked todo items in claude/tasks/todo.md"
  fi
fi

# Check lessons update
if [ -f "claude/tasks/lessons.md" ]; then
  LESSONS_AGE="$(find claude/tasks/lessons.md -mmin +120 2>/dev/null || true)"
  if [ -n "$LESSONS_AGE" ]; then
    WARNINGS="${WARNINGS}\nℹ️ lessons.md not updated this session — did you learn something new?"
  fi
fi

if [ -n "$WARNINGS" ]; then
  echo -e "## Exit Checklist$WARNINGS"
fi
