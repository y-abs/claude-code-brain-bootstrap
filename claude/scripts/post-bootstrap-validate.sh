#!/bin/bash
# post-bootstrap-validate.sh — Unified post-bootstrap validation
# Runs validate.sh + canary-check.sh in a single pass, auto-fixes common issues.
# Replaces the 3-pass validation (Phase 4 manual + validate.sh + canary-check.sh).
# Usage: bash claude/scripts/post-bootstrap-validate.sh [project-dir]
# Exit: 0 if healthy, 1 if critical failures remain after auto-fix

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ post-bootstrap-validate.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -eo pipefail
PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

ERRORS=0

# ─── Portable sed -i (macOS vs GNU) ──────────────────────────────
if [[ "$(uname)" == "Darwin" ]]; then
  sed_inplace() { sed -i '' "$@"; }
else
  sed_inplace() { sed -i "$@"; }
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Post-Bootstrap Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Step 0: Template integrity check ─────────────────────────────
# If this IS the template repo (not a real project), verify placeholders are intact.
IS_TEMPLATE=false
if [ -f "claude/bootstrap/PROMPT.md" ] && [ -d "claude/_examples" ] && [ -f "claude/scripts/validate.sh" ] && [ -f "claude/docs/DETAILED_GUIDE.md" ]; then
  _HAS_MANIFEST=false
  for _m in package.json Cargo.toml go.mod pyproject.toml pom.xml build.gradle pubspec.yaml mix.exs setup.py requirements.txt composer.json Gemfile CMakeLists.txt Makefile deno.json; do
    [ -f "$_m" ] && _HAS_MANIFEST=true && break
  done
  if ! $_HAS_MANIFEST; then IS_TEMPLATE=true; fi
fi

if $IS_TEMPLATE; then
  echo ""
  echo "🛡️  Template integrity check (template repo detected)..."
  TEMPLATE_OK=true
  if [ -f "CLAUDE.md" ] && ! grep -q '{{PROJECT_NAME}}' CLAUDE.md 2>/dev/null; then
    echo "  ❌ CRITICAL: CLAUDE.md is missing {{PROJECT_NAME}} placeholder — template corrupted!"
    echo "     → Restore from git: git checkout -- CLAUDE.md"
    TEMPLATE_OK=false
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ CLAUDE.md {{PROJECT_NAME}} placeholder intact"
  fi
  # Count total placeholders — template should have 90+ across all files
  PLACEHOLDER_COUNT=$(grep -rEc '\{\{[A-Z_]+\}\}' CLAUDE.md claude/ .claude/ .github/ 2>/dev/null | awk -F: '{s+=$2} END {print s+0}' || echo 0)
  if [ "$PLACEHOLDER_COUNT" -lt 50 ]; then
    echo "  ❌ CRITICAL: Only $PLACEHOLDER_COUNT placeholders found (expected 90+) — template may be corrupted"
    echo "     → Restore from git: git checkout -- ."
    TEMPLATE_OK=false
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ $PLACEHOLDER_COUNT placeholders intact (healthy)"
  fi
  if $TEMPLATE_OK; then
    echo "  ✅ Template integrity: PASSED"
  fi
fi

# ─── Step 1: Auto-fix common issues before validation ─────────────

echo ""
echo "🔧 Auto-fixing common issues..."

# Fix hook permissions
HOOKS_FIXED=0
for hook in .claude/hooks/*.sh claude/scripts/*.sh; do
  if [ -f "$hook" ] && [ ! -x "$hook" ]; then
    chmod +x "$hook"
    HOOKS_FIXED=$((HOOKS_FIXED + 1))
  fi
done
[ "$HOOKS_FIXED" -gt 0 ] && echo "  ✅ Fixed $HOOKS_FIXED non-executable scripts"

# Ensure validate.sh is executable
[ -f "claude/scripts/validate.sh" ] && [ ! -x "claude/scripts/validate.sh" ] && chmod +x claude/scripts/validate.sh

# Fix settings.json if malformed (common: trailing comma)
if [ -f ".claude/settings.json" ]; then
  if ! jq . .claude/settings.json > /dev/null 2>&1; then
    echo "  ⚠️  settings.json is invalid JSON — attempting auto-fix (trailing commas)"
    # Use sed to remove trailing commas before } or ]
    sed_inplace 's/,[[:space:]]*}/}/g; s/,[[:space:]]*]/]/g' .claude/settings.json
    if jq . .claude/settings.json > /dev/null 2>&1; then
      echo "  ✅ settings.json auto-fixed"
    else
      echo "  ❌ settings.json still invalid — manual fix needed"
      ERRORS=$((ERRORS + 1))
    fi
  fi
fi

# ─── Step 2: Run validate.sh ─────────────────────────────────────

echo ""
echo "📋 Running validate.sh..."
if [ -f "claude/scripts/validate.sh" ]; then
  VALIDATE_OUTPUT=$(bash claude/scripts/validate.sh 2>&1 || true)
  echo "$VALIDATE_OUTPUT"
  VALIDATE_PASS=$(echo "$VALIDATE_OUTPUT" | grep -oE '✅ [0-9]+' | tail -1 | awk '{print $2}') || true
  VALIDATE_FAIL=$(echo "$VALIDATE_OUTPUT" | grep -oE '❌ [0-9]+' | tail -1 | awk '{print $2}') || true
  echo ""
  echo "  validate.sh: ${VALIDATE_PASS:-0} passed, ${VALIDATE_FAIL:-0} failed"
  [ "${VALIDATE_FAIL:-0}" -gt 0 ] && ERRORS=$((ERRORS + VALIDATE_FAIL))
else
  echo "  ⚠️  validate.sh not found — skipping"
fi

# ─── Step 3: Run canary-check.sh ─────────────────────────────────

echo ""
echo "🐤 Running canary-check.sh..."
if [ -f "claude/scripts/canary-check.sh" ]; then
  CANARY_OUTPUT=$(bash claude/scripts/canary-check.sh . 2>&1 || true)
  echo "$CANARY_OUTPUT"
  CANARY_ERRORS=$(echo "$CANARY_OUTPUT" | grep -c '❌ FAIL') || CANARY_ERRORS=0
  echo ""
  echo "  canary-check.sh: $CANARY_ERRORS errors found"
  [ "$CANARY_ERRORS" -gt 0 ] && ERRORS=$((ERRORS + CANARY_ERRORS))
else
  echo "  ⚠️  canary-check.sh not found — skipping"
fi

# ─── Step 4: Final placeholder check ─────────────────────────────

echo ""
echo "🔖 Final placeholder check..."
REMAINING=$(grep -rEn '\{\{[A-Z_]+\}\}' CLAUDE.md claude/ .claude/ .github/ 2>/dev/null | grep -v '_examples/' | grep -v '_template' | grep -v 'bootstrap/PROMPT' | grep -v 'claude/docs/' | grep -v 'claude/scripts/' | grep -v 'claude/tasks/' | grep -v 'validate.sh' || true)
if [ -z "$REMAINING" ]; then
  echo "  ✅ No remaining placeholders"
else
  PCOUNT=$(echo "$REMAINING" | wc -l | tr -d ' ')
  echo "  ⚠️  $PCOUNT placeholder occurrences remain (AI creative work needed)"
  echo "$REMAINING" | head -15
fi

# ─── Step 5: Domain doc stubs exist for all lookup table references ──

echo ""
echo "📚 Domain doc reference check..."
DOC_WARNINGS=0
if [ -f "CLAUDE.md" ]; then
  # Extract claude/*.md paths from the lookup table (lines with backtick-quoted paths)
  REFERENCED_DOCS=$(grep -oE 'claude/[a-z_-]+\.md' CLAUDE.md 2>/dev/null | sort -u || true)
  for DOC in $REFERENCED_DOCS; do
    if [ ! -f "$DOC" ]; then
      echo "  ⚠️  CLAUDE.md references '$DOC' but file does not exist"
      DOC_WARNINGS=$((DOC_WARNINGS + 1))
    fi
  done
  if [ "$DOC_WARNINGS" -eq 0 ]; then
    echo "  ✅ All referenced domain docs exist"
  else
    echo "  ⚠️  $DOC_WARNINGS referenced doc(s) missing — create stubs or remove from lookup table"
  fi
fi

# ─── Step 6: Hard Constraints ↔ .claudeignore consistency ─────────

echo ""
echo "🔒 Hard Constraints ↔ .claudeignore sync check..."
HC_WARNINGS=0
if [ -f "CLAUDE.md" ] && [ -f ".claudeignore" ]; then
  # Extract file extensions/patterns from "NEVER add" lines in Hard Constraints
  NEVER_PATTERNS=$(grep -i 'NEVER add.*to context' CLAUDE.md 2>/dev/null | grep -oE '\*\.[a-z0-9]+' || true)
  for PAT in $NEVER_PATTERNS; do
    # Check if the pattern (or **/ prefixed version) exists in .claudeignore
    if ! grep -qF "$PAT" .claudeignore 2>/dev/null; then
      echo "  ⚠️  Hard Constraint references '$PAT' but no matching glob in .claudeignore"
      HC_WARNINGS=$((HC_WARNINGS + 1))
    fi
  done
  if [ "$HC_WARNINGS" -eq 0 ] && [ -n "$NEVER_PATTERNS" ]; then
    echo "  ✅ All Hard Constraint patterns have matching .claudeignore globs"
  elif [ -z "$NEVER_PATTERNS" ]; then
    echo "  ℹ️  No 'NEVER add' patterns found in Hard Constraints (OK if none needed)"
  fi
fi

# ─── Summary ──────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ERRORS" -gt 0 ]; then
  echo "  ❌ VALIDATION: $ERRORS critical issue(s) found"
  echo "  → Fix the issues above, then re-run this script"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
else
  echo "  ✅ VALIDATION PASSED — configuration is healthy!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
fi

