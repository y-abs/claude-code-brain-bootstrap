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

# TDD activation flag — written only for SOURCE CODE files (not config/json/markdown).
# This is a SEPARATE file from the Biome accumulator above. It is NOT deleted by
# stop-batch-format.sh (which only removes .claude-edited-files-*).
# tdd-loop-check.sh reads this flag to know "was real code written this session?"
# The flag is deleted by tdd-loop-check.sh when all tests pass (loop ends cleanly).
#
# Why hardcoded, not {{CASE_EXTENSIONS}}? The TDD loop is universal for source languages —
# it fires for ANY code file, not just the project's primary formatter-managed files.
# Using a separate fixed case avoids coupling TDD activation to formatter config.
case "$FILE_PATH" in
  *.js|*.ts|*.tsx|*.jsx|*.mjs|*.cjs|\
  *.py|*.go|*.rs|*.java|*.kt|*.scala|\
  *.rb|*.swift|*.cs|*.cpp|*.c|*.h|\
  *.php|*.ex|*.exs|*.hs|*.dart)
    TDD_FLAG="${CLAUDE_PROJECT_DIR:-.}/claude/tasks/.tdd-source-edited-${CLAUDE_SESSION_ID:-default}"
    touch "$TDD_FLAG" 2>/dev/null || true
    ;;
esac

exit 0

