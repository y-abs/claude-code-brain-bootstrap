#!/bin/bash
# Hook: PreToolUse(Bash) — Terminal Safety Gate
# Purpose: Block dangerous terminal patterns + destructive commands before execution.
# Exit: 0 = allow, 2 = block. Warnings printed to stdout (injected as system message).
# Supports CLAUDE_HOOK_PROFILE: minimal | standard (default) | strict

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$CMD" ]; then
  # If jq is not installed, warn the user (don't silently pass)
  if ! command -v jq &>/dev/null; then
    echo "⚠️ terminal-safety-gate: jq not installed — cannot parse command input. Safety checks skipped. Install jq to enable."
  fi
  exit 0
fi

PROFILE="${CLAUDE_HOOK_PROFILE:-standard}"

# === BLOCK (exit 2) — ALWAYS blocked regardless of profile ===

# Interactive editors
if echo "$CMD" | grep -qE '(^|[[:space:]])(vi|vim|nano|emacs|pico)([[:space:]]|$)'; then
  echo "🛑 BLOCKED: Interactive editor detected. Use read_file + edit tools instead."
  exit 2
fi

# Bare interactive shells
if echo "$CMD" | grep -qE 'docker[[:space:]]+exec[[:space:]]+-it'; then
  echo "🛑 BLOCKED: Interactive docker exec. Use: docker exec container command"
  exit 2
fi

if echo "$CMD" | grep -qE '(^|[[:space:]])psql[[:space:]]*$'; then
  echo "🛑 BLOCKED: Interactive psql. Use: psql -c \"SQL\" | cat"
  exit 2
fi

if echo "$CMD" | grep -qE '(^|[[:space:]])(node|python3?|ruby|irb)[[:space:]]*$'; then
  echo "🛑 BLOCKED: Interactive REPL. Use: node -e \"...\" or python3 -u -c \"...\""
  exit 2
fi

# Standalone sleep
if echo "$CMD" | grep -qE '^sleep[[:space:]]'; then
  echo "🛑 BLOCKED: Standalone sleep. Use background processes instead."
  exit 2
fi

# === DESTRUCTIVE COMMAND PROFILES ===

# Minimal: catastrophic patterns (always active)
MINIMAL_BLOCKED=false
if echo "$CMD" | grep -qiE 'rm -rf /|rm -rf \.\*|rm -rf ~'; then
  MINIMAL_BLOCKED=true; echo "🛑 BLOCKED: Catastrophic rm -rf detected [$PROFILE]" >&2
fi
if echo "$CMD" | grep -qiE 'git push.*--force.*(main|master)'; then
  MINIMAL_BLOCKED=true; echo "🛑 BLOCKED: Force push to main/master [$PROFILE]" >&2
fi
[ "$MINIMAL_BLOCKED" = true ] && exit 2

# Standard: broader destructive ops (standard + strict profiles)
if [ "$PROFILE" = "standard" ] || [ "$PROFILE" = "strict" ]; then
  STANDARD_BLOCKED=false
  if echo "$CMD" | grep -qiE 'DROP TABLE|DROP DATABASE|TRUNCATE TABLE'; then
    STANDARD_BLOCKED=true; echo "🛑 BLOCKED: Destructive SQL detected [$PROFILE]" >&2
  fi
  if echo "$CMD" | grep -qiE 'git reset --hard|docker system prune -a|chmod -R 777'; then
    STANDARD_BLOCKED=true; echo "🛑 BLOCKED: Destructive system command [$PROFILE]" >&2
  fi
  [ "$STANDARD_BLOCKED" = true ] && exit 2
fi

# Strict: risky execution patterns (strict profile only)
if [ "$PROFILE" = "strict" ]; then
  STRICT_BLOCKED=false
  if echo "$CMD" | grep -qiE 'curl.*\|.*sh|wget.*\|.*sh'; then
    STRICT_BLOCKED=true; echo "🛑 BLOCKED: Pipe-to-shell execution [$PROFILE]" >&2
  fi
  if echo "$CMD" | grep -qiE '(^|[[:space:]])eval |dd if=.* of=/dev/|> /etc/|tee /etc/'; then
    STRICT_BLOCKED=true; echo "🛑 BLOCKED: Dangerous system command [$PROFILE]" >&2
  fi
  [ "$STRICT_BLOCKED" = true ] && exit 2
fi

# === WARN (exit 0 with message) — risky but sometimes needed ===

# Git commands without --no-pager
if echo "$CMD" | grep -qE 'git[[:space:]]+(log|diff|show|branch)\b' && ! echo "$CMD" | grep -q '\-\-no-pager'; then
  if ! echo "$CMD" | grep -qE '\|[[:space:]]*(cat|head|tail|grep|wc)'; then
    echo "⚠️ WARNING: git command may trigger pager. Use: git --no-pager ... or pipe to | cat"
  fi
fi

# Docker/kubectl logs without --tail
if echo "$CMD" | grep -qE '(docker|kubectl)[[:space:]]+logs\b' && ! echo "$CMD" | grep -q '\-\-tail'; then
  if ! echo "$CMD" | grep -qE '\|[[:space:]]*(head|tail)'; then
    echo "⚠️ WARNING: Unbounded logs. Use: --tail 50 or pipe to | head -N"
  fi
fi

# Double-quoted grep with pipe alternation
if echo "$CMD" | grep -qE 'grep[[:space:]].*"[^"]*\|[^"]*"'; then
  echo "⚠️ WARNING: Pipe | inside double-quoted grep pattern. Shells may misinterpret. Use single quotes: grep -E 'a|b'"
fi

exit 0

