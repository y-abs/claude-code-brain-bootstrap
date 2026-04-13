#!/bin/bash
# Hook: PostToolUse(Write) — Warn when creating source files without tests
# Purpose: Educational reminder (exit 0, never blocks). Only active in strict profile.
# Requires: CLAUDE_HOOK_PROFILE=strict

PROFILE="${CLAUDE_HOOK_PROFILE:-standard}"
[ "$PROFILE" != "strict" ] && exit 0

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
if [ -z "$FILE_PATH" ]; then
  if ! command -v jq &>/dev/null; then
    echo "⚠️ warn-missing-test: jq not installed — cannot parse file path. Install jq to enable."
  fi
  exit 0
fi

# Skip non-code files (check extension first — cheapest guard)
if ! echo "$FILE_PATH" | grep -qE '\.(py|ts|tsx|js|jsx|go|rs|java|rb|swift)$'; then
  exit 0
fi

# Skip test files
if echo "$FILE_PATH" | grep -qE '(test|__test__|\.test\.|\.spec\.|__tests__|tests/)'; then
  exit 0
fi

# Only check files inside a recognizable source tree
# Matches: src/, app/, lib/, core/, components/, services/, packages/, handlers/, controllers/
if ! echo "$FILE_PATH" | grep -qE '/(src|app|lib|core|components|services|packages|handlers|controllers)/'; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")
NAME_NO_EXT="${BASENAME%.*}"
EXT="${BASENAME##*.}"

# Check for corresponding test file
FOUND_TEST=false
for test_dir in "tests" "__tests__" "test" "spec"; do
  for test_pattern in "test_${NAME_NO_EXT}" "${NAME_NO_EXT}_test" "${NAME_NO_EXT}.test" "${NAME_NO_EXT}.spec"; do
    if find . -path "*/${test_dir}/${test_pattern}.*" -o -path "*/${test_pattern}.${EXT}" 2>/dev/null | grep -q .; then
      FOUND_TEST=true
      break 2
    fi
  done
done

if [ "$FOUND_TEST" = "false" ]; then
  echo "💡 New source file without corresponding test: $FILE_PATH"
  echo "   Consider creating a test file for this module."
fi

exit 0

