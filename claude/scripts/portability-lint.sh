#!/usr/bin/env bash
# portability-lint.sh — Detect non-portable patterns in shell scripts
# Run: bash claude/scripts/portability-lint.sh
# Exit: 0 if clean, 1 if violations found
# Design: EXTENSIBLE — add new patterns to check(), no CI changes needed.
# When you discover a new GNU-only pattern, add ONE line here. CI catches it forever.

set -euo pipefail

ERRORS=0
WARNINGS=0

# check SEVERITY "description" "grep-pattern" ["extra-filter"]
check() {
  local severity="$1" description="$2" pattern="$3" extra_filter="${4:-}"
  local hits
  # Search .sh files, exclude comments (lines starting with optional whitespace + #)
  hits=$(grep -rn "$pattern" --include='*.sh' . 2>/dev/null | grep -v 'portability-lint\.sh' | grep -v '^\([^:]*:\)\{0,1\}[[:space:]]*#' || true)
  # Apply optional extra filter (e.g., exclude known-safe patterns)
  if [ -n "$extra_filter" ] && [ -n "$hits" ]; then
    hits=$(echo "$hits" | eval "$extra_filter" || true)
  fi
  if [ -n "$hits" ]; then
    if [ "$severity" = "ERROR" ]; then
      echo "  ❌ $description"
      ERRORS=$((ERRORS + 1))
    else
      echo "  ⚠️  $description"
      WARNINGS=$((WARNINGS + 1))
    fi
    echo "$hits" | head -5 | sed 's/^/     /'
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Portability Lint — Cross-Platform Safety"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── GNU coreutils / grep ───────────────────────────────────────────
check ERROR \
  "head -n -N (negative count) — GNU-only, BSD rejects" \
  'head -n -[0-9]'

check ERROR \
  "grep -P (PCRE flag) — not on macOS default grep" \
  'grep -[a-zA-Z]*P ' \
  "grep -v '_platform.sh'"

check ERROR \
  "readlink -f — GNU-only (macOS has no -f)" \
  'readlink -f'

check ERROR \
  "stat --format or stat -c — GNU stat (macOS uses stat -f)" \
  'stat --format\|stat -c '

check ERROR \
  "date --date= or date -d — GNU date parsing" \
  'date --date\|date -d '

# ── sed -i without wrapper ────────────────────────────────────────
# sed -i on GNU needs no arg, BSD needs ''. Scripts MUST use sed_inplace() from _platform.sh.
# Allow: sed_inplace calls, _platform.sh itself, and sed -i '' (already BSD-safe)
check ERROR \
  "Bare sed -i (not via sed_inplace) — breaks on macOS" \
  'sed -i ' \
  "grep -v 'sed_inplace\|_platform\.sh\|sed -i .\\x27\\x27'"

# ── awk portability ────────────────────────────────────────────────
check ERROR \
  "\\s in awk — gawk-only, use [[:space:]]" \
  '\\s' \
  "grep 'awk'"

check ERROR \
  "\\w in awk — gawk-only, use [[:alnum:]_]" \
  '\\w' \
  "grep 'awk'"

# ── Process substitution (warning, not error — works in bash 3.2+) ─
check WARN \
  "< <() process substitution — prefer tmpfile for Git Bash compat" \
  '< <('

# ── Summary ────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo "  ✅ All clear — no portability issues"
elif [ "$ERRORS" -eq 0 ]; then
  echo "  ⚠️  0 errors, $WARNINGS warning(s)"
else
  echo "  ❌ $ERRORS error(s), $WARNINGS warning(s)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit "$ERRORS"
