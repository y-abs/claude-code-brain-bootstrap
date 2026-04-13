#!/bin/bash
# Hook: PostToolUse(Edit|Write|MultiEdit)
# Purpose: Record edited file paths to a session-scoped temp file for batch formatting at Stop.
# Exit: Always 0.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

ACCUMULATOR="${CLAUDE_PROJECT_DIR:-.}/claude/tasks/.claude-edited-files-${CLAUDE_SESSION_ID:-default}"

# Only accumulate formattable source files.
# Uses shell `case` — pipe-immune (| is a case separator, NOT regex).
# Never use grep -E here: alternation values break silently when pipes are misquoted.
case "$FILE_PATH" in
  {{CASE_EXTENSIONS}}) echo "$FILE_PATH" >> "$ACCUMULATOR" ;;
esac

exit 0

