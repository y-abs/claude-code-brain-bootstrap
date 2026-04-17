#!/usr/bin/env bash
# dry-run.sh — Preview ALL structural changes /bootstrap would make
# Runs every merge script in --dry-run mode. Changes nothing on disk.
#
# Usage: bash claude/scripts/dry-run.sh [project-dir]
# Exit:  0 always

# ─── Source guard ─────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ dry-run.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

PROJECT_DIR="${1:-.}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISCOVERY_ENV="$PROJECT_DIR/claude/tasks/.discovery.env"
BOOTSTRAP_DIR="$PROJECT_DIR/claude/bootstrap"

echo "╔══════════════════════════════════════════════════════╗"
echo "║  ᗺB  Brain Bootstrap — Dry Run Preview               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  No files will be modified. This is a preview only."
echo ""

# ─── 1. Tasks migration ──────────────────────────────────────────
echo "━━━ 1/5 Tasks Migration ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "$DISCOVERY_ENV" ]; then
  bash "$SCRIPTS_DIR/migrate-tasks.sh" --discovery-env "$DISCOVERY_ENV" --target "$PROJECT_DIR" --dry-run 2>&1 || true
else
  bash "$SCRIPTS_DIR/migrate-tasks.sh" --target "$PROJECT_DIR" --dry-run 2>&1 || true
fi
echo ""

# ─── 2. CLAUDE.md section merge ──────────────────────────────────
echo "━━━ 2/5 CLAUDE.md Section Merge ━━━━━━━━━━━━━━━━━━━━━"
TMPL="$BOOTSTRAP_DIR/_CLAUDE.md.template"
if [ -f "$TMPL" ] && [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
  bash "$SCRIPTS_DIR/merge-claude-md.sh" --template "$TMPL" --target "$PROJECT_DIR/CLAUDE.md" --dry-run 2>&1 || true
else
  echo "  ⏭️  Skipped (template or target missing)"
fi
echo ""

# ─── 3. settings.json deep merge ─────────────────────────────────
echo "━━━ 3/5 settings.json Deep Merge ━━━━━━━━━━━━━━━━━━━━"
TMPL="$BOOTSTRAP_DIR/_settings.json.template"
if [ -f "$TMPL" ] && [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
  bash "$SCRIPTS_DIR/merge-settings.sh" \
    --template "$TMPL" \
    --target "$PROJECT_DIR/.claude/settings.json" \
    --discovery-env "$DISCOVERY_ENV" \
    --dry-run 2>&1 || true
else
  echo "  ⏭️  Skipped (template or target missing)"
fi
echo ""

# ─── 4. .claudeignore union merge ─────────────────────────────────
echo "━━━ 4/5 .claudeignore Union Merge ━━━━━━━━━━━━━━━━━━━"
TMPL="$BOOTSTRAP_DIR/_claudeignore.template"
if [ -f "$TMPL" ] && [ -f "$PROJECT_DIR/.claudeignore" ]; then
  bash "$SCRIPTS_DIR/merge-claudeignore.sh" \
    --template "$TMPL" \
    --target "$PROJECT_DIR/.claudeignore" \
    --discovery-env "$DISCOVERY_ENV" \
    --dry-run 2>&1 || true
else
  echo "  ⏭️  Skipped (template or target missing)"
fi
echo ""

# ─── 5. Creative work manifest ────────────────────────────────────
echo "━━━ 5/5 Creative Work Manifest ━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPTS_DIR/pre-creative-check.sh" "$PROJECT_DIR" 2>&1 || true
echo ""

echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅ Dry run complete — no files were modified         ║"
echo "╚══════════════════════════════════════════════════════╝"

