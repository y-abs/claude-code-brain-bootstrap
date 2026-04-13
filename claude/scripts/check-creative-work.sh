#!/bin/bash
# check-creative-work.sh — Verify creative population quality before proceeding to Phase 3.5
# Checks: architecture depth, CLAUDE.md placeholders, domain doc QUALITY, lookup table completeness,
#         instruction file precision, copilot-instructions.md expansion, IDE section.
# Usage: bash claude/scripts/check-creative-work.sh [project-dir]
# Exit: 0 = all critical pass, 1 = failures found

set -eo pipefail
PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

ERRORS=0
WARNINGS=0

# ─── 1. architecture.md populated (>30 lines = real content, not just template) ──────────────────
if [ -f "claude/architecture.md" ]; then
  LINES=$(wc -l < claude/architecture.md)
  if [ "$LINES" -gt 30 ]; then
    echo "  ✅ architecture.md ($LINES lines)"
  else
    echo "  ❌ architecture.md too short ($LINES lines, need >30)"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "  ❌ architecture.md MISSING"
  ERRORS=$((ERRORS + 1))
fi

# ─── 2. No remaining creative placeholders in CLAUDE.md ───────────────────────────────────────────
CREATIVE_PH=0
for PH in DOMAIN_LOOKUP_TABLE CRITICAL_PATTERNS HARD_CONSTRAINTS KEY_DECISIONS DONT_LIST; do
  if grep -q "{{$PH}}" CLAUDE.md 2>/dev/null; then
    CREATIVE_PH=$((CREATIVE_PH + 1))
  fi
done
if [ "$CREATIVE_PH" -eq 0 ]; then
  echo "  ✅ CLAUDE.md creative placeholders filled"
else
  echo "  ❌ CLAUDE.md has $CREATIVE_PH unfilled creative placeholders"
  ERRORS=$((ERRORS + 1))
fi

# ─── 3. Every domain doc in lookup table exists on disk ───────────────────────────────────────────
DOC_MISSING=0
if [ -f "CLAUDE.md" ]; then
  for DOC in $(grep -oE 'claude/[a-z_-]+\.md' CLAUDE.md 2>/dev/null | sort -u || true); do
    if [ ! -f "$DOC" ]; then
      echo "  ❌ MISSING: $DOC (referenced in CLAUDE.md)"
      DOC_MISSING=$((DOC_MISSING + 1))
    fi
  done
fi
if [ "$DOC_MISSING" -eq 0 ]; then
  echo "  ✅ All referenced domain docs exist"
else
  ERRORS=$((ERRORS + DOC_MISSING))
fi

# ─── 3b. Domain doc quality — each domain doc must have REAL content, not stubs ──────────────────
# Quality lines: "- **bold**" bullets, "- `code`" bullets, "## " section headings
# Empty stub (0 quality lines) = ERROR; shallow (1-4 quality lines) = WARNING
EMPTY_DOCS=0
LOW_QUALITY_DOCS=0
for doc in claude/*.md; do
  [ -f "$doc" ] || continue
  BASENAME=$(basename "$doc")
  case "$BASENAME" in
    architecture.md|rules.md|README.md) continue ;;
    _*) continue ;;
  esac
  # Use awk to count quality lines (always exits 0, handles empty files safely)
  QUALITY_LINES=$(awk '/^[[:space:]]*-[[:space:]]+\*\*|^[[:space:]]*-[[:space:]]+`|^##[[:space:]]/{n++} END{print n+0}' "$doc")
  if [ "$QUALITY_LINES" -eq 0 ]; then
    echo "  ❌ $BASENAME — empty stub (0 quality lines) — fill with real patterns from source code"
    EMPTY_DOCS=$((EMPTY_DOCS + 1))
  elif [ "$QUALITY_LINES" -lt 5 ]; then
    echo "  ⚠️  $BASENAME — only $QUALITY_LINES quality line(s) (target ≥5 real patterns)"
    LOW_QUALITY_DOCS=$((LOW_QUALITY_DOCS + 1))
  fi
done
if [ "$EMPTY_DOCS" -gt 0 ]; then
  echo "  ❌ $EMPTY_DOCS domain doc(s) are empty stubs — read source files and add real patterns"
  ERRORS=$((ERRORS + EMPTY_DOCS))
elif [ "$LOW_QUALITY_DOCS" -gt 0 ]; then
  echo "  ⚠️  $LOW_QUALITY_DOCS domain doc(s) below quality threshold — enrich before session end"
  WARNINGS=$((WARNINGS + LOW_QUALITY_DOCS))
else
  echo "  ✅ Domain doc quality: all docs have real content (≥5 quality lines)"
fi

# ─── 3c. Lookup table completeness — CLAUDE.md rows must cover ALL domain docs ───────────────────
DOMAIN_DOC_COUNT=0
for doc in claude/*.md; do
  [ -f "$doc" ] || continue
  case "$(basename "$doc")" in
    architecture.md|rules.md|README.md|_*) continue ;;
  esac
  DOMAIN_DOC_COUNT=$((DOMAIN_DOC_COUNT + 1))
done
# Count rows in CLAUDE.md that reference claude/*.md files (lookup table rows)
LOOKUP_ROW_COUNT=$(awk '/\|.*`?claude\/[a-z_-]+\.md`?/{n++} END{print n+0}' CLAUDE.md 2>/dev/null || echo 0)
if [ "$DOMAIN_DOC_COUNT" -eq 0 ]; then
  echo "  ❌ No domain docs in claude/ — create at least one (e.g., claude/database.md)"
  ERRORS=$((ERRORS + 1))
elif [ "$LOOKUP_ROW_COUNT" -lt "$DOMAIN_DOC_COUNT" ]; then
  echo "  ❌ Lookup table: $LOOKUP_ROW_COUNT row(s) for $DOMAIN_DOC_COUNT domain doc(s) — add missing rows to CLAUDE.md"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✅ Lookup table: $LOOKUP_ROW_COUNT row(s) covers $DOMAIN_DOC_COUNT domain doc(s)"
fi

# ─── 3d. Project-specific rules coverage — domain docs must have matching .claude/rules/ ───────────
# For each domain doc (excluding generic template files), check if a rules file exists
DOMAIN_RULES_MISSING=0
DOMAIN_RULES_PRESENT=0
GENERIC_RULES="terminal-safety build cve-policy templates decisions plugins"
for doc in claude/*.md; do
  [ -f "$doc" ] || continue
  BASENAME=$(basename "$doc" .md)
  case "$BASENAME" in
    architecture|rules|README|_*) continue ;;
  esac
  # Skip generic docs that don't need path-scoped rules
  SKIP=false
  for g in $GENERIC_RULES; do [ "$BASENAME" = "$g" ] && SKIP=true; done
  [ "$SKIP" = "true" ] && continue
  # Check if a corresponding .claude/rules/<domain>.md exists
  # (allow partial name match: e.g., messaging.md → kafka-safety.md counts)
  if [ ! -f ".claude/rules/${BASENAME}.md" ]; then
    DOMAIN_RULES_MISSING=$((DOMAIN_RULES_MISSING + 1))
  else
    DOMAIN_RULES_PRESENT=$((DOMAIN_RULES_PRESENT + 1))
  fi
done
if [ "$DOMAIN_RULES_MISSING" -gt 0 ] && [ "$DOMAIN_DOC_COUNT" -gt 3 ]; then
  echo "  ⚠️  $DOMAIN_RULES_MISSING domain doc(s) have no matching .claude/rules/<domain>.md — add path-scoped rules (item 7)"
  WARNINGS=$((WARNINGS + 1))
elif [ "$DOMAIN_RULES_PRESENT" -gt 0 ]; then
  echo "  ✅ Domain rules: $DOMAIN_RULES_PRESENT path-scoped rule file(s) found"
fi

# ─── 4. Per-service stubs (monorepos — informational, not blocking) ───────────────────────────────
# Only search directories that actually exist (find exits 1 for missing dirs → kills pipefail)
STUB_DIRS=()
for d in core services apps packages; do [ -d "$d" ] && STUB_DIRS+=("$d"); done
STUB_COUNT=0
if [ "${#STUB_DIRS[@]}" -gt 0 ]; then
  STUB_COUNT=$(find "${STUB_DIRS[@]}" -maxdepth 2 -name CLAUDE.md 2>/dev/null | wc -l | tr -d ' ')
fi
[ "$STUB_COUNT" -gt 0 ] && echo "  📁 $STUB_COUNT per-service stubs"

# ─── 5. Copilot docs mirrored ──────────────────────────────────────────────────────────────────────
COPILOT_COUNT=0
[ -d ".github/copilot" ] && COPILOT_COUNT=$(find .github/copilot -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
echo "  📋 $COPILOT_COUNT copilot docs in .github/copilot/"

# ─── 5b. Instruction file glob precision — warn if default fallback globs remain ─────────────────
# Default fallback from generate-copilot-docs.sh: applyTo: "**/<basename>*/**"
# These are heuristics — should be replaced with actual project service paths.
HEURISTIC_COUNT=0
if ls .github/instructions/*.instructions.md >/dev/null 2>&1; then
  for f in .github/instructions/*.instructions.md; do
    [ -f "$f" ] || continue
    BNAME=$(basename "$f" .instructions.md)
    # Check for the default fallback pattern: **/<basename>*/**
    if grep -q "applyTo:.*\*\*/${BNAME}\*" "$f" 2>/dev/null; then
      HEURISTIC_COUNT=$((HEURISTIC_COUNT + 1))
    fi
  done
  if [ "$HEURISTIC_COUNT" -gt 0 ]; then
    echo "  ⚠️  $HEURISTIC_COUNT instruction file(s) still have default heuristic globs — refine with actual service paths (step 5b)"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "  ✅ Instruction file globs: no default heuristic patterns detected"
  fi
fi

# ─── 5c. copilot-instructions.md lookup table expansion ───────────────────────────────────────────
if [ -f ".github/copilot-instructions.md" ] && [ "$DOMAIN_DOC_COUNT" -gt 0 ]; then
  COPILOT_ROWS=$(awk '/\|.*`?claude\/[a-z_-]+\.md`?/{n++} END{print n+0}' .github/copilot-instructions.md 2>/dev/null || echo 0)
  if [ "$COPILOT_ROWS" -lt "$DOMAIN_DOC_COUNT" ]; then
    echo "  ⚠️  copilot-instructions.md has $COPILOT_ROWS lookup row(s) but $DOMAIN_DOC_COUNT domain doc(s) — sync the table (item 5)"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "  ✅ copilot-instructions.md lookup: $COPILOT_ROWS row(s)"
  fi
fi

# ─── 6. IDE section handled ───────────────────────────────────────────────────────────────────────
if grep -q '<!-- Uncomment the section matching your IDE' CLAUDE.md 2>/dev/null; then
  echo "  ⚠️  IDE section still commented — uncomment IntelliJ or VS Code"
  WARNINGS=$((WARNINGS + 1))
else
  echo "  ✅ IDE section handled"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────────────────────────
echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "❌ Creative work: $ERRORS critical issue(s) — fix before proceeding"
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  echo "✅ Creative work passed ($WARNINGS warning(s) — address before session end)"
else
  echo "✅ Creative work passed — all quality gates met"
fi

# Bootstrap progress tracking (only during bootstrap)
if [ -f "claude/tasks/.bootstrap-plan.txt" ]; then echo "P3-check $(date +%H:%M:%S)" >> "claude/tasks/.bootstrap-progress.txt" 2>/dev/null; fi
