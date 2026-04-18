#!/bin/bash
# Copilot Hook: SessionStart — Inject session context
# Outputs JSON with additionalContext for session awareness.
# Adapted from .claude/hooks/session-start.sh for VS Code.

BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"

# Recent lessons (last 5 lines)
LESSONS=""
if [ -f "claude/tasks/lessons.md" ]; then
  LESSONS="$(tail -5 claude/tasks/lessons.md 2>/dev/null || true)"
fi

# Current todo state
TODO=""
if [ -f "claude/tasks/todo.md" ]; then
  TODO="$(grep -E '^\s*-\s*\[[ x]\]' claude/tasks/todo.md 2>/dev/null | tail -5 || true)"
fi

# jq availability warning
JQ_WARNING=""
if ! command -v jq &>/dev/null; then
  JQ_WARNING=" | ⚠️ jq not installed — safety hooks degraded"
fi

cat <<EOF
{
  "additionalContext": "Session context: branch=${BRANCH}${JQ_WARNING}\n\nRecent lessons:\n${LESSONS}\n\nOpen todos:\n${TODO}"
}
EOF
