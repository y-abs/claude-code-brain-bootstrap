#!/bin/bash
set -eo pipefail

# generate-copilot-agents.sh — Convert .claude/agents/*.md → .github/agents/*.agent.md
# Maps Claude tool names → VS Code tool names, model declarations, and body transformations.
# Idempotent: skips existing non-stub agents (>10 content lines = hand-crafted).

CLAUDE_DIR=".claude/agents"
COPILOT_DIR=".github/agents"
STUB_THRESHOLD=10  # files with ≤10 content lines are considered stubs

mkdir -p "$COPILOT_DIR"

# ─── Tool Mapping ───────────────────────────────────────────────
map_tool() {
  case "$1" in
    Read)           echo "read_file" ;;
    Grep)           echo "grep_search" ;;
    Glob)           echo "file_search" ;;
    List)           echo "list_dir" ;;
    Bash*)          echo "run_in_terminal" ;;
    Edit)           echo "replace_string_in_file" ;;
    MultiEdit)      echo "multi_replace_string_in_file" ;;
    Write)          echo "create_file" ;;
    WebFetch)       echo "fetch_webpage" ;;
    SubAgent)       echo "runSubagent" ;;
    *)              echo "$1" ;;  # pass-through unknown
  esac
}

# ─── Model Mapping ──────────────────────────────────────────────
map_model() {
  case "$1" in
    opus)    echo '["Claude Opus 4 (copilot)", "GPT-4o (copilot)"]' ;;
    sonnet)  echo '["Claude Sonnet 4 (copilot)", "GPT-4o (copilot)"]' ;;
    haiku)   echo '["Claude 3.5 Haiku (copilot)"]' ;;
    "")      echo "" ;;  # no model = inherit session default
    *)       echo "\"$1\"" ;;  # pass-through custom
  esac
}

# ─── Extract frontmatter value ──────────────────────────────────
get_fm() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" | (grep "^${key}:" || true) | head -1 | sed "s/^${key}:[[:space:]]*//"
}

# ─── Extract allowed-tools list ─────────────────────────────────
get_tools() {
  local file="$1"
  sed -n '/^---$/,/^---$/p' "$file" \
    | sed -n '/^allowed-tools:/,/^[^[:space:]-]/p' \
    | (grep '^[[:space:]]*-' || true) \
    | sed 's/^[[:space:]]*-[[:space:]]*//'
}

# ─── Extract body (after second ---) ────────────────────────────
get_body() {
  local file="$1"
  awk 'BEGIN{c=0} /^---$/{c++;next} c>=2{print}' "$file"
}

# ─── Body transformations ───────────────────────────────────────
transform_body() {
  # Replace Claude-specific tool references with VS Code equivalents
  # Order matters: specific patterns first, then general patterns
  sed \
    -e 's/run `grep -rn`/use `grep_search`/g' \
    -e 's/`grep -rn`/`grep_search`/g' \
    -e 's/`git diff/`git --no-pager diff/g' \
    -e 's/Bash(grep \*)/run_in_terminal/g' \
    -e 's/Bash(find \*)/run_in_terminal/g' \
    -e 's/Bash(git \*)/run_in_terminal/g'
}

# ─── Convert one agent ──────────────────────────────────────────
convert_agent() {
  local src="$1"
  local name
  name="$(basename "$src" .md)"
  # Name mapping: Claude "research" → Copilot "researcher" (matches hand-crafted agent)
  case "$name" in
    research) name="researcher" ;;
  esac
  local dest="${COPILOT_DIR}/${name}.agent.md"

  # Skip hand-crafted agents (>STUB_THRESHOLD content lines)
  if [ -f "$dest" ]; then
    local content_lines
    content_lines="$(awk 'BEGIN{c=0} /^---$/{c++;next} c>=2{print}' "$dest" | grep -c '[^[:space:]]' || echo "0")"
    if [ "$content_lines" -gt "$STUB_THRESHOLD" ]; then
      echo "  SKIP  $dest (hand-crafted, ${content_lines} lines)"
      return
    fi
    echo "  OVERWRITE  $dest (stub, ${content_lines} lines)"
  fi

  # Extract source metadata
  local description model_raw model_mapped
  description="$(get_fm "$src" 'description')"
  model_raw="$(get_fm "$src" 'model')"
  model_mapped="$(map_model "$model_raw")"

  # Collect and deduplicate mapped tools
  local tools_unique
  tools_unique="$(get_tools "$src" | while IFS= read -r tool; do
    map_tool "$tool"
  done | sort -u)"

  # Build frontmatter
  {
    echo "---"
    echo "description: \"${description}\""
    echo "tools:"
    echo "$tools_unique" | while IFS= read -r t; do
      [ -n "$t" ] && echo "  - $t"
    done
    if [ -n "$model_mapped" ]; then
      echo "model: ${model_mapped}"
    fi
    echo "---"
    echo ""
    get_body "$src" | transform_body
  } > "$dest"

  echo "  WROTE  $dest"
}

# ─── Main ───────────────────────────────────────────────────────
count=0
echo "Generating Copilot agents from Claude agents..."
echo "  Source: ${CLAUDE_DIR}/"
echo "  Target: ${COPILOT_DIR}/"
echo ""

for src in "${CLAUDE_DIR}"/*.md; do
  [ -f "$src" ] || continue
  convert_agent "$src"
  count=$((count + 1))
done

echo ""
echo "Done — processed ${count} agent(s)."
