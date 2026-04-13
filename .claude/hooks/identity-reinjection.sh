#!/bin/bash
# Hook: UserPromptSubmit
# Purpose: Detect active domain from claude/tasks/todo.md; inject full identity block periodically.
# Exit: Always 0. Stdout injected into context.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Prompt counter for periodic identity refresh
# ⚠️ Fallback MUST be a fixed string, NOT $$ — each hook invocation is a new PID.
PROMPT_FILE="${CLAUDE_PROJECT_DIR:-.}/claude/tasks/.claude-prompt-counter-${CLAUDE_SESSION_ID:-default}"
if [ ! -f "$PROMPT_FILE" ]; then
  echo "0" > "$PROMPT_FILE"
fi
COUNT=$(cat "$PROMPT_FILE")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$PROMPT_FILE"

# Detect active domain from todo.md
if [ -f "$PROJECT_DIR/claude/tasks/todo.md" ]; then
  DOMAIN=$(grep -m1 'domain:' "$PROJECT_DIR/claude/tasks/todo.md" 2>/dev/null | sed 's/.*domain:[[:space:]]*//' || true)
  if [ -n "$DOMAIN" ]; then
    echo "🏷️ Active domain: $DOMAIN"
  fi
fi

# Full identity block every 10 prompts (configurable)
INTERVAL=10
if [ $((COUNT % INTERVAL)) -eq 0 ]; then
  echo "━━━ Identity Refresh ━━━"
  echo "You are working on: {{PROJECT_NAME}}"
  echo "Exit checklist is MANDATORY before yielding."
  echo "NEVER git push autonomously."
  echo "━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0

