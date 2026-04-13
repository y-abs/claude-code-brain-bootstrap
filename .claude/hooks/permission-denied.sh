#!/bin/bash
# Hook: PermissionDenied — Audit trail for denied operations
# Purpose: Log every permission denial for security auditing and pattern detection.
# Exit: always 0 (logging only, never blocks)

set -e

LOG_DIR="claude/tasks"
LOG_FILE="$LOG_DIR/.permission-denials.log"

mkdir -p "$LOG_DIR"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
ARGUMENTS=$(echo "$INPUT" | jq -r '.arguments // "" | tostring' 2>/dev/null || echo "")
REASON=$(echo "$INPUT" | jq -r '.reason // ""' 2>/dev/null || echo "")

# Truncate arguments to 100 chars
ARGS_TRUNC="${ARGUMENTS:0:100}"
[ "${#ARGUMENTS}" -gt 100 ] && ARGS_TRUNC="${ARGS_TRUNC}..."

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

printf '%s | %s | %s | %s\n' "$TIMESTAMP" "$TOOL_NAME" "$ARGS_TRUNC" "$REASON" >> "$LOG_FILE"

exit 0

