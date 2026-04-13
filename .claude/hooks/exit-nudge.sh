#!/bin/bash
# Hook: Stop (exit nudge)
# Purpose: Remind Claude to run the 6-point exit checklist before yielding.
# Exit: Always 0. Stdout injected as system message.

cat > /dev/null 2>&1 || true

echo "📋 Exit Checklist — verify before yielding:"
echo "  1. User correction? → Update claude/tasks/lessons.md + claude/*.md"
echo "  2. New codebase knowledge? → Same"
echo "  3. Open task in todo.md? → Mark progress"
echo "  4. Touched a domain? → Verify claude/*.md still accurate"
echo "  5. New pattern/pitfall? → Add to relevant doc + lessons.md"
echo "  6. Used terminal? → Verify no pagers, no interactive, no unbounded output"

exit 0

