#!/bin/bash
# Hook: PreToolUse(*)
# Purpose: Suggest strategic /compact at 50 tool calls and every 25 after.
# Exit: Always 0.

# Session-scoped counter
# ⚠️ Fallback MUST be a fixed string, NOT $$ — each hook invocation is a new PID,
# so $$ creates a different file every time, leaking 100+ orphan files per session.
COUNTER_FILE="${CLAUDE_PROJECT_DIR:-.}/claude/tasks/.claude-tool-counter-${CLAUDE_SESSION_ID:-default}"

# Initialize if missing
if [ ! -f "$COUNTER_FILE" ]; then
  echo "0" > "$COUNTER_FILE"
fi

# Increment
COUNT=$(cat "$COUNTER_FILE")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Suggest compaction at 50, 75, 100, ...
if [ "$COUNT" -eq 50 ]; then
  echo "💡 50 tool calls this session. Consider running /compact to free context before it auto-compacts mid-task."
elif [ "$COUNT" -gt 50 ] && [ $(( (COUNT - 50) % 25 )) -eq 0 ]; then
  echo "💡 $COUNT tool calls. Strategic /compact recommended to prevent auto-compaction mid-task."
fi

exit 0

