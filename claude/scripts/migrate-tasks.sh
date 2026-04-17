#!/usr/bin/env bash
# migrate-tasks.sh — Deterministic tasks/ directory migration
# Moves ONLY known Claude files from old layout (tasks/ or .tasks/) to claude/tasks/.
# NEVER moves non-Claude files. NEVER deletes source directories.
#
# Usage: bash claude/scripts/migrate-tasks.sh [--discovery-env <path>] [--target <dir>] [--dry-run]
# Exit:  0 = migrated, 1 = error, 2 = nothing to do

# ─── Source guard ─────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ migrate-tasks.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -eo pipefail

# ─── Parse arguments ──────────────────────────────────────────────
DISCOVERY_ENV=""
TARGET="."
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --discovery-env) DISCOVERY_ENV="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

cd "$TARGET"

# ─── Platform helpers ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_platform.sh"

# ─── Detect migration need ────────────────────────────────────────
LAYOUT_MIGRATION="false"

if [ -n "$DISCOVERY_ENV" ] && [ -f "$DISCOVERY_ENV" ]; then
  LAYOUT_MIGRATION=$(grep '^LAYOUT_MIGRATION_NEEDED=' "$DISCOVERY_ENV" 2>/dev/null | head -1 | cut -d= -f2 || echo "false")
fi

# Fallback: detect directly if no discovery env
if [ "$LAYOUT_MIGRATION" = "false" ]; then
  if [ -d "tasks" ] && [ ! -d "claude/tasks" ]; then
    # Old layout: tasks/ exists, claude/tasks/ doesn't
    if [ -f "tasks/lessons.md" ] || [ -f "tasks/todo.md" ]; then
      LAYOUT_MIGRATION="true"
    fi
  elif [ -d "tasks" ] && [ -d "claude/tasks" ]; then
    # Both exist — check if old has Claude files not yet in new
    if [ -f "tasks/lessons.md" ] && [ ! -f "claude/tasks/lessons.md" ]; then
      LAYOUT_MIGRATION="merge"
    elif [ -f "tasks/todo.md" ] && [ ! -f "claude/tasks/todo.md" ]; then
      LAYOUT_MIGRATION="merge"
    fi
  elif [ -d ".tasks" ]; then
    if [ -f ".tasks/lessons.md" ] || [ -f ".tasks/todo.md" ]; then
      LAYOUT_MIGRATION="true"
    fi
  fi
fi

if [ "$LAYOUT_MIGRATION" = "false" ]; then
  echo "✅ No tasks migration needed"
  exit 2
fi

echo "🔄 Tasks migration: mode=$LAYOUT_MIGRATION"
$DRY_RUN && echo "  ⚠️  DRY RUN — no files will be modified"

# ─── Allowlisted Claude files (ONLY these get moved) ──────────────
CLAUDE_FILES=(
  "lessons.md"
  "todo.md"
  "CLAUDE_ERRORS.md"
  "bootstrap-report.md"
  ".bootstrap-plan.txt"
  ".bootstrap-progress.txt"
  ".discovery.env"
  ".permission-denials.log"
)

CLAUDE_DIRS=(
  "session-logs"
)

CLAUDE_GLOBS=(
  ".claude-*"
  ".bootstrap-*"
)

# ─── Detect source directory ──────────────────────────────────────
SRC_DIR=""
if [ -d "tasks" ] && { [ -f "tasks/lessons.md" ] || [ -f "tasks/todo.md" ]; }; then
  SRC_DIR="tasks"
elif [ -d ".tasks" ] && { [ -f ".tasks/lessons.md" ] || [ -f ".tasks/todo.md" ]; }; then
  SRC_DIR=".tasks"
fi

if [ -z "$SRC_DIR" ]; then
  echo "✅ No Claude files found in tasks/ or .tasks/"
  exit 2
fi

DEST_DIR="claude/tasks"
MOVED=0
SKIPPED=0

# ─── Ensure destination ───────────────────────────────────────────
if ! $DRY_RUN; then
  mkdir -p "$DEST_DIR"
fi

# ─── Move allowlisted files ──────────────────────────────────────
for FILE in "${CLAUDE_FILES[@]}"; do
  if [ -f "$SRC_DIR/$FILE" ]; then
    if [ -f "$DEST_DIR/$FILE" ]; then
      if [ "$LAYOUT_MIGRATION" = "merge" ] && [ "$FILE" = "lessons.md" ]; then
        echo "  📝 $FILE: would APPEND to existing $DEST_DIR/$FILE"
        if ! $DRY_RUN; then
          echo "" >> "$DEST_DIR/$FILE"
          echo "<!-- Migrated from $SRC_DIR/ on $(date +%Y-%m-%d) -->" >> "$DEST_DIR/$FILE"
          cat "$SRC_DIR/$FILE" >> "$DEST_DIR/$FILE"
          rm "$SRC_DIR/$FILE"
        fi
        MOVED=$((MOVED + 1))
      else
        echo "  ⏭️  $FILE: already exists in $DEST_DIR/ — skipping"
        SKIPPED=$((SKIPPED + 1))
      fi
    else
      echo "  📦 $FILE: $SRC_DIR/ → $DEST_DIR/"
      if ! $DRY_RUN; then
        mv "$SRC_DIR/$FILE" "$DEST_DIR/$FILE"
      fi
      MOVED=$((MOVED + 1))
    fi
  fi
done

# ─── Move allowlisted directories ─────────────────────────────────
for DIR in "${CLAUDE_DIRS[@]}"; do
  if [ -d "$SRC_DIR/$DIR" ]; then
    if [ -d "$DEST_DIR/$DIR" ]; then
      echo "  ⏭️  $DIR/: already exists in $DEST_DIR/ — skipping"
      SKIPPED=$((SKIPPED + 1))
    else
      echo "  📦 $DIR/: $SRC_DIR/ → $DEST_DIR/"
      if ! $DRY_RUN; then
        mv "$SRC_DIR/$DIR" "$DEST_DIR/$DIR"
      fi
      MOVED=$((MOVED + 1))
    fi
  fi
done

# ─── Move allowlisted glob patterns ───────────────────────────────
for GLOB in "${CLAUDE_GLOBS[@]}"; do
  # Use find to avoid glob expansion issues
  while IFS= read -r FILE; do
    [ -z "$FILE" ] && continue
    BASENAME=$(basename "$FILE")
    if [ -e "$DEST_DIR/$BASENAME" ]; then
      SKIPPED=$((SKIPPED + 1))
    else
      echo "  📦 $BASENAME: $SRC_DIR/ → $DEST_DIR/"
      if ! $DRY_RUN; then
        mv "$FILE" "$DEST_DIR/$BASENAME"
      fi
      MOVED=$((MOVED + 1))
    fi
  done < <(find "$SRC_DIR" -maxdepth 1 -name "$GLOB" -type f 2>/dev/null)
done

# ─── Update references (ONLY if actually moved files) ─────────────
if [ "$MOVED" -gt 0 ] && ! $DRY_RUN; then
  # Update plansDirectory in settings.json
  if [ -f ".claude/settings.json" ] && command -v jq &>/dev/null; then
    CURRENT_PLANS=$(jq -r '.plansDirectory // ""' .claude/settings.json 2>/dev/null)
    if [ "$CURRENT_PLANS" != "./claude/tasks/" ]; then
      TMP=$(mktemp)
      jq '.plansDirectory = "./claude/tasks/"' .claude/settings.json > "$TMP" && mv "$TMP" .claude/settings.json
      echo "  ⚙️  settings.json plansDirectory → ./claude/tasks/"
    fi
  fi

  # Update hook scripts: tasks/ → claude/tasks/ (exact word boundary)
  for HOOK in .claude/hooks/*.sh; do
    [ -f "$HOOK" ] || continue
    if grep -q '"tasks/' "$HOOK" 2>/dev/null || grep -q '/tasks/' "$HOOK" 2>/dev/null; then
      # Only replace bare tasks/ refs, not claude/tasks/ (which is already correct)
      sed_inplace 's|"tasks/|"claude/tasks/|g' "$HOOK"
      sed_inplace 's|\./tasks/|./claude/tasks/|g' "$HOOK"
      # Don't replace already-correct claude/tasks/ → claude/claude/tasks/
      sed_inplace 's|claude/claude/tasks/|claude/tasks/|g' "$HOOK"
    fi
  done

  # Update CLAUDE.md references
  if [ -f "CLAUDE.md" ]; then
    # Only update bare tasks/ references, not already-correct claude/tasks/
    sed_inplace 's|`tasks/lessons\.md`|`claude/tasks/lessons.md`|g' CLAUDE.md
    sed_inplace 's|`tasks/todo\.md`|`claude/tasks/todo.md`|g' CLAUDE.md
    sed_inplace 's|`tasks/CLAUDE_ERRORS\.md`|`claude/tasks/CLAUDE_ERRORS.md`|g' CLAUDE.md
    # Don't double-prefix
    sed_inplace 's|claude/claude/tasks/|claude/tasks/|g' CLAUDE.md
  fi

  echo "  ⚙️  Updated references in hooks and CLAUDE.md"
elif [ "$MOVED" -gt 0 ] && $DRY_RUN; then
  echo "  ⚙️  Would update plansDirectory, hook scripts, and CLAUDE.md references"
fi

# ─── Summary (NEVER delete source directory) ──────────────────────
REMAINING=$(find "$SRC_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "📊 Migration summary:"
echo "  📦 Moved: $MOVED Claude file(s)"
echo "  ⏭️  Skipped: $SKIPPED (already in $DEST_DIR/)"
echo "  📁 $SRC_DIR/ still has $REMAINING non-Claude file(s) — NOT touched"
echo "  ⚠️  $SRC_DIR/ directory preserved (your files are still there)"

