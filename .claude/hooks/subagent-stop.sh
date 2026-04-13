#!/bin/bash
# Hook: SubagentStop
# Purpose: Log subagent completion with timestamp, remind to verify output quality.
# Exit: Always 0. Stdout injected as system message.

INPUT=$(cat)
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // "unknown"' 2>/dev/null)

echo "✅ Subagent '$AGENT_NAME' completed at $(date '+%H:%M:%S')."

case "$AGENT_NAME" in
  research)
    echo "   Verify: Evidence section has file paths + line numbers. Pitfalls section is populated."
    ;;
  reviewer)
    echo "   Verify: All 10 review points have confidence scores. Severity markers (🔴/🟡/🟢) are assigned."
    ;;
  plan-challenger)
    echo "   Verify: Challenges survived self-refutation. Recommendation is clear."
    ;;
esac

exit 0

