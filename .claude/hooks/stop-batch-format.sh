#!/bin/bash
# Hook: Stop (batch format)
# Purpose: Batch-format all files edited during this response using the project formatter(s).
#          Supports dual-language projects: primary formatter + optional secondary formatter.
#          Uses `case` statement for extension matching — pipe-immune by design.
#          Also checks for console.log/print statements in modified files.
# Exit: Always 0. Stdout injected as system message.

# Pass through any stdin from Claude
cat > /dev/null 2>&1 || true

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
ACCUMULATOR="$PROJECT_DIR/claude/tasks/.claude-edited-files-${CLAUDE_SESSION_ID:-default}"

if [ ! -f "$ACCUMULATOR" ]; then
  exit 0
fi

FILES=$(sort -u < "$ACCUMULATOR")
if [ -z "$FILES" ]; then
  exit 0
fi

FILE_COUNT=$(echo "$FILES" | wc -l)

# ── Primary formatter ──────────────────────────────────────────────
# {{FORMATTER_COMMAND}} — Replace with your project's format command
# Examples: biome check --write, prettier --write, black, rustfmt, gofmt -w, ruff format
PRIMARY_FORMATTER="${FORMATTER_COMMAND:-}"

# ── Secondary formatter (for dual-language projects) ───────────────
# {{SECONDARY_FORMATTER_COMMAND}} — auto-detected for secondary language
# Examples: ruff format (Python in a JS-primary repo), prettier --write (JS in a Python-primary repo)
SECONDARY_FORMATTER="${SECONDARY_FORMATTER_COMMAND:-}"
# {{SECONDARY_FORMATTER_CASE_EXTS}} — case glob pattern for secondary files
# Format: *.py|*.pyi (shell case separator, pipe-immune — NEVER use grep -E here)
SECONDARY_CASE_EXTS="{{SECONDARY_FORMATTER_CASE_EXTS}}"

if [ -n "$SECONDARY_FORMATTER" ] && [ "$SECONDARY_CASE_EXTS" != "" ] && [ "$SECONDARY_CASE_EXTS" != "{{SECONDARY_FORMATTER_CASE_EXTS}}" ]; then
  # Dual-language mode: split files by extension using case (pipe-immune)
  SEC_FILES=""
  PRI_FILES=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    # The | in case patterns is a shell keyword — never misinterpreted as a command pipe
    case "$file" in
      {{SECONDARY_FORMATTER_CASE_EXTS}}) SEC_FILES="${SEC_FILES}${file}"$'\n' ;;
      *) PRI_FILES="${PRI_FILES}${file}"$'\n' ;;
    esac
  done <<< "$FILES"

  # Trim trailing newlines
  SEC_FILES="${SEC_FILES%$'\n'}"
  PRI_FILES="${PRI_FILES%$'\n'}"

  if [ -n "$PRI_FILES" ] && [ -n "$PRIMARY_FORMATTER" ]; then
    PRI_COUNT=$(echo "$PRI_FILES" | wc -l | tr -d ' ')
    echo "🎨 Formatting $PRI_COUNT primary file(s)..."
    read -ra _pri_cmd <<< "$PRIMARY_FORMATTER"
    echo "$PRI_FILES" | xargs "${_pri_cmd[@]}" 2>/dev/null || true
  fi

  if [ -n "$SEC_FILES" ]; then
    SEC_COUNT=$(echo "$SEC_FILES" | wc -l | tr -d ' ')
    echo "🎨 Formatting $SEC_COUNT secondary file(s)..."
    read -ra _sec_cmd <<< "$SECONDARY_FORMATTER"
    echo "$SEC_FILES" | xargs "${_sec_cmd[@]}" 2>/dev/null || true
  fi
elif [ -n "$PRIMARY_FORMATTER" ]; then
  # Single-language mode: format all files with primary formatter
  echo "🎨 Batch formatting $FILE_COUNT edited file(s)..."
  read -ra _pri_cmd <<< "$PRIMARY_FORMATTER"
  echo "$FILES" | xargs "${_pri_cmd[@]}" 2>/dev/null || true
fi

# Check for console.log / print statements in git-modified files
LOG_HITS=$(cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null | while read -r f; do
  [ -f "$f" ] && grep -n 'console\.log\|print(' "$f" 2>/dev/null | head -2
done)
if [ -n "$LOG_HITS" ]; then
  echo "⚠️ console.log/print() found in modified files — review before committing:"
  echo "$LOG_HITS" | head -5
fi

# Clean accumulator and session counter files
rm -f "$ACCUMULATOR"
rm -f "$PROJECT_DIR/claude/tasks/.claude-tool-counter-${CLAUDE_SESSION_ID:-default}"
rm -f "$PROJECT_DIR/claude/tasks/.claude-prompt-counter-${CLAUDE_SESSION_ID:-default}"
# Glob cleanup: remove any orphaned counter files from previous sessions or $$ bug
rm -f "$PROJECT_DIR"/claude/tasks/.claude-tool-counter-* 2>/dev/null || true
rm -f "$PROJECT_DIR"/claude/tasks/.claude-prompt-counter-* 2>/dev/null || true
rm -f "$PROJECT_DIR"/claude/tasks/.claude-edited-files-* 2>/dev/null || true

exit 0

