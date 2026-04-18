#!/bin/bash
# Copilot Hook: PreToolUse — Config Protection
# Blocks edits to linter/formatter/compiler config files.
# Adapted from .claude/hooks/config-protection.sh for VS Code tool names.
# Exit: 0 = allow, 2 = block

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  if ! command -v jq &>/dev/null; then
    echo "⚠️ config-protection: jq not installed — protection skipped. Install jq to enable."
  fi
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

PROTECTED_PATTERNS=(
  "biome.json"
  "biome.jsonc"
  ".eslintrc*"
  ".prettierrc*"
  "prettier.config.*"
  "tsconfig.json"
  "tsconfig.*.json"
  "pyproject.toml"
  "setup.cfg"
  "Cargo.toml"
  "go.mod"
  "pom.xml"
  "build.gradle"
  ".editorconfig"
)

for PATTERN in "${PROTECTED_PATTERNS[@]}"; do
  # shellcheck disable=SC2053
  if [[ "$BASENAME" == $PATTERN ]]; then
    echo "🛑 BLOCKED: Editing config file '$BASENAME' is not allowed."
    echo "Fix the source code to comply with the existing config — don't weaken the config."
    echo "If you truly need to change it, ask the user for explicit approval first."
    exit 2
  fi
done

exit 0
