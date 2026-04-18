#!/bin/bash
# generate-copilot-prompts.sh — Convert .claude/commands/*.md → .github/prompts/*.prompt.md
#
# Idempotent: never overwrites existing prompts (user may have customized).
# Detects stubs (< 4 content lines) → overwrites stubs.
#
# Usage:
#   bash claude/scripts/generate-copilot-prompts.sh [target-dir]
#   Default target-dir: current directory

set -euo pipefail

TARGET="${1:-.}"
COMMANDS_DIR="$TARGET/.claude/commands"
PROMPTS_DIR="$TARGET/.github/prompts"
CREATED=0
SKIPPED=0
STUB_OVERWRITTEN=0

if [ ! -d "$COMMANDS_DIR" ]; then
  echo "❌ No .claude/commands/ directory found at $TARGET"
  exit 1
fi

mkdir -p "$PROMPTS_DIR"

# ── Tool name mapping: Claude → VS Code ──────────────────────────
map_tool() {
  case "$1" in
    Read)           echo "read_file" ;;
    Write)          echo "create_file" ;;
    Edit)           echo "replace_string_in_file" ;;
    MultiEdit)      echo "multi_replace_string_in_file" ;;
    Grep)           echo "grep_search" ;;
    Glob)           echo "file_search" ;;
    List)           echo "list_dir" ;;
    Bash|Bash\(*)   echo "run_in_terminal" ;;
    *)              echo "$1" ;;
  esac
}

# ── Check if file is a stub (< 4 non-empty content lines after frontmatter) ──
is_stub() {
  local file="$1"
  local in_frontmatter=false
  local content_lines=0
  while IFS= read -r line; do
    if [ "$in_frontmatter" = false ] && [ "$line" = "---" ]; then
      in_frontmatter=true
      continue
    fi
    if [ "$in_frontmatter" = true ] && [ "$line" = "---" ]; then
      in_frontmatter=false
      continue
    fi
    if [ "$in_frontmatter" = false ]; then
      # Count non-empty, non-comment lines
      case "$line" in
        ''|'#'*|'<!--'*) continue ;;
        *) content_lines=$((content_lines + 1)) ;;
      esac
    fi
  done < "$file"
  [ "$content_lines" -lt 4 ]
}

# ── Extract YAML frontmatter value ───────────────────────────────
get_frontmatter() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep -E "^${key}:" | head -1 | sed "s/^${key}:[[:space:]]*//" || true
}

# ── Extract body (everything after frontmatter) ──────────────────
get_body() {
  local file="$1"
  awk 'BEGIN{n=0} /^---$/{n++; if(n==2){skip=1; next}} skip{print}' "$file"
}

# ── Convert a single command to a prompt ─────────────────────────
convert_command() {
  local cmd_file="$1"
  local cmd_name
  cmd_name="$(basename "$cmd_file" .md)"
  local prompt_file="$PROMPTS_DIR/${cmd_name}.prompt.md"

  # Skip if non-stub exists
  if [ -f "$prompt_file" ]; then
    if ! is_stub "$prompt_file"; then
      SKIPPED=$((SKIPPED + 1))
      return
    fi
    STUB_OVERWRITTEN=$((STUB_OVERWRITTEN + 1))
  fi

  # Extract frontmatter values
  local description effort dmi allowed_tools argument_hint
  description="$(get_frontmatter "$cmd_file" 'description')"
  effort="$(get_frontmatter "$cmd_file" 'effort')"
  dmi="$(get_frontmatter "$cmd_file" 'disable-model-invocation')"
  allowed_tools="$(get_frontmatter "$cmd_file" 'allowed-tools')"
  argument_hint="$(get_frontmatter "$cmd_file" 'argument-hint')"

  # Build prompt frontmatter
  local fm=""
  fm="---"$'\n'

  # Description (required)
  if [ -n "$description" ]; then
    fm="${fm}description: ${description}"$'\n'
  else
    fm="${fm}description: ${cmd_name} command"$'\n'
  fi

  # Mode: always agent (needs tool access for any useful work)
  fm="${fm}agent: \"agent\""$'\n'

  # Tools mapping
  if [ -n "$allowed_tools" ]; then
    fm="${fm}tools:"$'\n'
    # Parse comma or newline-separated tool names
    local mapped_tools=""
    while IFS= read -r tool; do
      tool="$(echo "$tool" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [ -z "$tool" ] && continue
      local mapped
      mapped="$(map_tool "$tool")"
      mapped_tools="${mapped_tools}  - ${mapped}"$'\n'
    done <<< "$(echo "$allowed_tools" | tr ',' '\n')"
    fm="${fm}${mapped_tools}"
  fi

  # Argument hint
  if [ -n "$argument_hint" ]; then
    fm="${fm}argument-hint: ${argument_hint}"$'\n'
  fi

  fm="${fm}---"

  # Get body and transform it
  local body
  body="$(get_body "$cmd_file")"

  # Transform Claude-specific syntax:
  # 1. Remove !`backtick` prefetch lines → convert to tool hints
  # 2. Remove `> ultrathink` lines
  # 3. Replace $ARGUMENTS with {{input}}
  body="$(echo "$body" | sed '/^>[[:space:]]*ultrathink/d')"
  body="$(echo "$body" | sed 's/\$ARGUMENTS/{{input}}/g')"
  # Convert !`command` prefetch to context hint
  body="$(echo "$body" | sed 's/!\`\(.*\)\`/**Context:** Use terminal to run: `\1`/')"

  # Write prompt file
  printf '%s\n\n%s\n' "$fm" "$body" > "$prompt_file"
  CREATED=$((CREATED + 1))
}

# ── Main loop ────────────────────────────────────────────────────
for cmd_file in "$COMMANDS_DIR"/*.md; do
  [ -f "$cmd_file" ] || continue
  convert_command "$cmd_file"
done

echo "✅ Copilot prompts generated:"
echo "   Created: $CREATED"
echo "   Stubs overwritten: $STUB_OVERWRITTEN"
echo "   Skipped (existing): $SKIPPED"
echo "   Location: $PROMPTS_DIR/"
