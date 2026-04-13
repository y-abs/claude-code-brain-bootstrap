#!/bin/bash
# Hook: PreToolUse(Bash) — Pre-Commit Quality Gate
# Purpose: Check staged files for debugger statements, hardcoded secrets, console.log.
#          Validates conventional commit message format for non-amend commits.
# Exit: 0 = allow, 2 = block

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$CMD" ]; then
  exit 0
fi

# Only trigger on git commit commands
if ! echo "$CMD" | grep -qE 'git[[:space:]]+commit'; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
IS_AMEND=false
if echo "$CMD" | grep -q '\-\-amend'; then
  IS_AMEND=true
fi

# Get staged files (or all changed files for amend)
if [ "$IS_AMEND" = true ]; then
  STAGED=$(cd "$PROJECT_DIR" && git diff --name-only HEAD~1 HEAD 2>/dev/null) || STAGED=""
else
  STAGED=$(cd "$PROJECT_DIR" && git diff --cached --name-only 2>/dev/null) || STAGED=""
fi

if [ -z "$STAGED" ]; then
  exit 0
fi

ISSUES=""

# Check for debugger statements
# {{SOURCE_EXTENSIONS}} — adjust file extensions for your project
DEBUGGER_HITS=$(echo "$STAGED" | grep -E '\.(js|ts|tsx|jsx|py|rb|go|rs)$' | while read -r f; do
  [ -f "$PROJECT_DIR/$f" ] && grep -nE '(debugger;|breakpoint\(\)|import pdb|binding\.pry)' "$PROJECT_DIR/$f" 2>/dev/null | head -3
done)
if [ -n "$DEBUGGER_HITS" ]; then
  ISSUES="${ISSUES}🛑 DEBUGGER statements found in staged files:\n$DEBUGGER_HITS\n\n"
fi

# Check for hardcoded secrets
SECRET_HITS=$(echo "$STAGED" | grep -E '\.(js|ts|tsx|jsx|py|rb|go|rs|json|yaml|yml|env)$' | while read -r f; do
  [ -f "$PROJECT_DIR/$f" ] && grep -nEi '(api[_-]?key|secret[_-]?key|password|private[_-]?key)[[:space:]]*[:=][[:space:]]*["\x27][A-Za-z0-9+/=]{20,}' "$PROJECT_DIR/$f" 2>/dev/null | head -3
done)
if [ -n "$SECRET_HITS" ]; then
  ISSUES="${ISSUES}🛑 Possible HARDCODED SECRETS in staged files:\n$SECRET_HITS\n\n"
fi

# Warn on console.log / print statements (non-blocking)
LOG_HITS=$(echo "$STAGED" | grep -E '\.(js|ts|tsx|jsx)$' | while read -r f; do
  [ -f "$PROJECT_DIR/$f" ] && grep -n 'console\.log' "$PROJECT_DIR/$f" 2>/dev/null | head -3
done)
if [ -n "$LOG_HITS" ]; then
  echo "⚠️ console.log found in staged files (review before pushing):"
  echo "$LOG_HITS" | head -5
fi

# Block if critical issues found
if [ -n "$ISSUES" ]; then
  printf '%b\n' "$ISSUES"
  echo "Fix the issues above before committing."
  exit 2
fi

# Validate conventional commit format (non-amend only)
if [ "$IS_AMEND" = false ]; then
  COMMIT_MSG=$(printf '%s\n' "$CMD" | sed -nE 's/.*-m[[:space:]]+"([^"]+)".*/\1/p')
  [ -z "$COMMIT_MSG" ] && COMMIT_MSG=$(printf '%s\n' "$CMD" | sed -nE "s/.*-m[[:space:]]+'([^']+)'.*/\\1/p")
  if [ -n "$COMMIT_MSG" ]; then
    if ! echo "$COMMIT_MSG" | grep -qE '^(feat|fix|docs|refactor|test|chore|build|ci|perf|revert)(\(.+\))?!?:[[:space:]].+'; then
      echo "⚠️ Commit message doesn't follow conventional format: <type>(<scope>): <description>"
      echo "   Types: feat|fix|docs|refactor|test|chore|build|ci|perf|revert"
    fi
  fi
fi

exit 0

