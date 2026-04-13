#!/bin/bash
# Hook: PreToolUse(Write|Edit|MultiEdit)
# Purpose: Block modifications to linter/formatter/compiler config files.
#          Forces fixing source code instead of weakening config.
# Exit: 0 = allow, 2 = block

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Protected config files — add your project's config files here
# {{PROTECTED_FILES}} — populated by /bootstrap
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
  # shellcheck disable=SC2053  # Intentional glob matching (e.g., biome* matches biome.json, biome.jsonc)
  if [[ "$BASENAME" == $PATTERN ]]; then
    echo "🛡️ BLOCKED: Editing '$BASENAME' is not allowed."
    echo "   Fix the source code to comply with the config, don't weaken the config."
    echo "   If you truly need to change this config, ask the user for explicit permission."
    exit 2
  fi
done

# Block .idea/ modifications
if [[ "$FILE_PATH" == *".idea/"* ]]; then
  echo "🛡️ BLOCKED: Editing IDE configuration files (.idea/) is not allowed."
  exit 2
fi

exit 0

