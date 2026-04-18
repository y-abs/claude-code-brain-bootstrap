#!/bin/bash
# Copilot Hook: PreToolUse — Terminal Safety Gate
# Blocks dangerous terminal patterns before execution.
# Adapted from .claude/hooks/terminal-safety-gate.sh for VS Code.
# Exit: 0 = allow, 2 = block

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$CMD" ]; then
  if ! command -v jq &>/dev/null; then
    echo "⚠️ terminal-safety: jq not installed — safety checks skipped. Install jq to enable."
  fi
  exit 0
fi

# === BLOCK — Interactive editors ===
if echo "$CMD" | grep -qE '(^|[[:space:]])(vi|vim|nano|emacs|pico)([[:space:]]|$)'; then
  echo "🛑 BLOCKED: Interactive editor detected. Use the file editing tools instead."
  exit 2
fi

# === BLOCK — Interactive docker ===
if echo "$CMD" | grep -qE 'docker[[:space:]]+exec[[:space:]]+-it'; then
  echo "🛑 BLOCKED: Interactive docker exec. Use: docker exec container command"
  exit 2
fi

# === BLOCK — Interactive psql ===
if echo "$CMD" | grep -qE '(^|[[:space:]])psql[[:space:]]*$'; then
  echo "🛑 BLOCKED: Interactive psql. Use: psql -c \"SQL\" | cat"
  exit 2
fi

# === BLOCK — Interactive REPL ===
if echo "$CMD" | grep -qE '(^|[[:space:]])(node|python3?|ruby|irb)[[:space:]]*$'; then
  echo "🛑 BLOCKED: Interactive REPL. Use: node -e \"...\" or python3 -c \"...\""
  exit 2
fi

# === BLOCK — Sleep without background ===
if echo "$CMD" | grep -qE '(^|[[:space:]])sleep[[:space:]]+[0-9]'; then
  echo "🛑 BLOCKED: sleep command detected. Use background execution for long-running tasks."
  exit 2
fi

# === WARN — Missing pager guards ===
if echo "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+(log|show|diff|stash)' && ! echo "$CMD" | grep -q '\-\-no-pager'; then
  echo "⚠️ WARNING: git command without --no-pager may hang. Use: git --no-pager ..."
fi

exit 0
