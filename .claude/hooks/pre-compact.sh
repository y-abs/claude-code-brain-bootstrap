#!/bin/bash
# Hook: PreCompact
# Purpose: (1) Backup session transcript to claude/tasks/session-logs/
#          (2) Append compaction marker with branch name to claude/tasks/todo.md
#          (3) Emit project-aware preservation instructions to stdout —
#              stdout from PreCompact hook becomes additional compaction summarizer instructions
# Exit: Always 0.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
LOG_DIR="$PROJECT_DIR/claude/tasks/session-logs"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')

# ─── 1. Backup transcript from stdin ───

mkdir -p "$LOG_DIR"
TRANSCRIPT=$(cat)
if [ -n "$TRANSCRIPT" ]; then
  echo "$TRANSCRIPT" > "$LOG_DIR/session-$TIMESTAMP.json"
  # Prune old sessions — keep newest 20 (portable: no head -n -N which is GNU-only)
  TOTAL=$(find "$LOG_DIR" -maxdepth 1 -name 'session-*.json' 2>/dev/null | wc -l | tr -d ' ')
  KEEP=20
  if [ "$TOTAL" -gt "$KEEP" ]; then
    find "$LOG_DIR" -maxdepth 1 -name 'session-*.json' 2>/dev/null | sort | head -n "$((TOTAL - KEEP))" | xargs rm -f 2>/dev/null
  fi
fi

# ─── 2. Append compaction marker to todo.md ───

if [ -f "$PROJECT_DIR/claude/tasks/todo.md" ]; then
  BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo 'unknown')
  {
    echo ""
    echo "---"
    echo "**[Compaction at $(date '+%Y-%m-%d %H:%M') on branch $BRANCH]** — Context was summarized. Run \`/resume\` to reload."
  } >> "$PROJECT_DIR/claude/tasks/todo.md"
fi

# ─── 3. Emit summarizer instructions to stdout ───
# Claude Code feeds this script's stdout to the compaction summarizer as extra instructions.
# Tell the summarizer what matters most for THIS project so it doesn't summarize it away.

# Detect tech stack
PROJECT_TYPE="unknown"
if [ -f "$PROJECT_DIR/package.json" ]; then
  PROJECT_TYPE="typescript"
  if grep -q '"next"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    PROJECT_TYPE="typescript/nextjs"
  elif grep -q '"react"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    PROJECT_TYPE="typescript/react"
  fi
fi
if [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/setup.py" ]; then
  PROJECT_TYPE="${PROJECT_TYPE:-python}"
fi
if [ -f "$PROJECT_DIR/go.mod" ]; then
  PROJECT_TYPE="${PROJECT_TYPE:-go}"
fi
if [ -f "$PROJECT_DIR/pnpm-workspace.yaml" ] || [ -f "$PROJECT_DIR/nx.json" ]; then
  PROJECT_TYPE="$PROJECT_TYPE (monorepo)"
fi

# Detect schema / DB anchor file
SCHEMA_FILE=""
for f in prisma/schema.prisma drizzle/schema.ts knexfile.js knexfile.ts src/db/schema.ts models.py; do
  if [ -e "$PROJECT_DIR/$f" ]; then SCHEMA_FILE="$f"; break; fi
done

# Detect API directories
KEY_DIRS=""
for d in src/api src/routes api routes server/routes controllers; do
  if [ -d "$PROJECT_DIR/$d" ]; then KEY_DIRS="$KEY_DIRS $d"; fi
done

# Git state
GIT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo '')
GIT_CHANGED=$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | head -15 || echo '')
GIT_STAGED=$(git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null | head -10 || echo '')

# Key Decisions from CLAUDE.md (settled architectural choices — expensive to re-derive)
KEY_DECISIONS=""
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
  KEY_DECISIONS=$(awk '/^## Key Decisions/{f=1; next} f && /^## /{f=0} f' \
    "$PROJECT_DIR/CLAUDE.md" 2>/dev/null | head -15 || echo '')
fi

# ─── Output summarizer instructions ───

echo "## Compaction Preservation Priorities — ${PROJECT_TYPE} project"
echo ""
echo "When summarizing, prioritize these in order:"
echo ""
echo "### 1. Decisions and reasoning (HIGHEST PRIORITY)"
echo "Keep the WHY verbatim — not just what was decided. Reasoning is expensive to re-derive."
if [ -n "$KEY_DECISIONS" ]; then
  echo ""
  echo "Settled decisions (reference by name — do NOT re-litigate these):"
  echo "$KEY_DECISIONS"
fi
if [ -n "$SCHEMA_FILE" ]; then
  echo ""
  echo "### 2. Schema/DB context — file: $SCHEMA_FILE"
  echo "Preserve column names, relationships, migration decisions, query patterns discussed."
fi
if [ -n "$KEY_DIRS" ]; then
  echo ""
  echo "### 3. API contracts — directories:$KEY_DIRS"
  echo "Preserve endpoint paths, request/response shapes, status codes, validation rules."
fi
echo ""
echo "### 4. Errors and fixes"
echo "Preserve: EXACT error message · file:line · fix applied · whether tests passed after fix."
echo ""
echo "### 5. Current work"
[ -n "$GIT_BRANCH" ] && echo "Branch: $GIT_BRANCH"
[ -n "$GIT_CHANGED" ] && echo "Uncommitted changes:" && echo "$GIT_CHANGED"
[ -n "$GIT_STAGED" ] && echo "Staged:" && echo "$GIT_STAGED"
echo ""
echo "### What to compress / drop"
echo "- Dead-end exploration → drop"
echo "- Full file contents → drop (re-readable from disk)"
echo "- Verbose tool output → keep findings only"
echo "- Repeated test-fix-test cycles → compress to: 'Fixed X by Y — tests pass'"

exit 0

