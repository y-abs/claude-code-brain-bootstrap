#!/usr/bin/env bash
# merge-claude-md.sh — Deterministic CLAUDE.md section merger
# Appends ONLY genuinely missing sections from template. Never modifies existing content.
# Uses heading similarity matching to detect equivalent sections (emoji-tolerant).
#
# Usage: bash claude/scripts/merge-claude-md.sh --template <file> --target <file> [--dry-run]
# Exit:  0 = success, 1 = error, 2 = nothing to add

# ─── Source guard ─────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ merge-claude-md.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -eo pipefail

# ─── Parse arguments ──────────────────────────────────────────────
TEMPLATE=""
TARGET_FILE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template) TEMPLATE="$2"; shift 2 ;;
    --target) TARGET_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

if [ -z "$TEMPLATE" ] || [ ! -f "$TEMPLATE" ]; then
  echo "❌ Template file not found: ${TEMPLATE:-<not specified>}" >&2
  exit 1
fi
if [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ]; then
  echo "❌ Target file not found: ${TARGET_FILE:-<not specified>}" >&2
  exit 1
fi

echo "🔄 CLAUDE.md section merge"
$DRY_RUN && echo "  ⚠️  DRY RUN — no files will be modified"

# ─── Normalize heading for comparison ─────────────────────────────
# Strips emoji, special chars, lowercases, collapses whitespace
normalize_heading() {
  echo "$1" | \
    sed 's/[^a-zA-Z0-9 ]//g' | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/  */ /g; s/^ //; s/ $//'
}

# ─── Extract ## headings from a file ──────────────────────────────
extract_headings() {
  grep '^## ' "$1" 2>/dev/null | sed 's/^## //' || true
}

# ─── Extract section content (heading + body until next ## or EOF) ─
extract_section() {
  local file="$1"
  local heading="$2"
  # Escape heading for awk
  awk -v h="## $heading" '
    $0 == h { found=1; print; next }
    found && /^## / { exit }
    found { print }
  ' "$file"
}

# ─── Check if user has a similar heading ──────────────────────────
# Returns 0 if match found, 1 if not
heading_matches() {
  local template_norm="$1"
  local user_headings_file="$2"

  while IFS= read -r user_heading; do
    [ -z "$user_heading" ] && continue
    local user_norm
    user_norm=$(normalize_heading "$user_heading")

    # Exact match after normalization
    if [ "$template_norm" = "$user_norm" ]; then
      return 0
    fi

    # Prefix match: user heading starts with template's first 2 words
    local tmpl_prefix
    tmpl_prefix=$(echo "$template_norm" | awk '{print $1, $2}')
    local user_prefix
    user_prefix=$(echo "$user_norm" | awk '{print $1, $2}')
    if [ -n "$tmpl_prefix" ] && [ "$tmpl_prefix" = "$user_prefix" ]; then
      return 0
    fi

    # Keyword overlap: if ≥70% of template words appear in user heading
    local tmpl_words match_count total
    tmpl_words=$(echo "$template_norm" | tr ' ' '\n' | sort -u)
    total=$(echo "$tmpl_words" | grep -c . || echo 0)
    if [ "$total" -le 1 ]; then
      # Single-word heading: exact match only (already checked above)
      continue
    fi
    match_count=0
    for word in $tmpl_words; do
      [ ${#word} -lt 3 ] && continue  # skip short words
      if echo "$user_norm" | grep -qw "$word" 2>/dev/null; then
        match_count=$((match_count + 1))
      fi
    done
    # ≥70% keyword match
    threshold=$((total * 70 / 100))
    [ "$threshold" -lt 1 ] && threshold=1
    if [ "$match_count" -ge "$threshold" ]; then
      return 0
    fi
  done < "$user_headings_file"

  return 1
}

# ─── Main merge logic ─────────────────────────────────────────────
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Extract headings
extract_headings "$TARGET_FILE" > "$TMPDIR/user_headings.txt"
extract_headings "$TEMPLATE" > "$TMPDIR/template_headings.txt"

ADDED=0
SKIPPED=0
SECTIONS_TO_ADD=""

while IFS= read -r heading; do
  [ -z "$heading" ] && continue
  norm=$(normalize_heading "$heading")

  if heading_matches "$norm" "$TMPDIR/user_headings.txt"; then
    echo "  ✅ SKIP: ## $heading (already covered)"
    SKIPPED=$((SKIPPED + 1))
  else
    echo "  ➕ ADD:  ## $heading"
    ADDED=$((ADDED + 1))
    # Collect section content
    SECTION=$(extract_section "$TEMPLATE" "$heading")
    SECTIONS_TO_ADD="${SECTIONS_TO_ADD}
<!-- Added by Brain Bootstrap $(date +%Y-%m-%d) -->
${SECTION}
"
  fi
done < "$TMPDIR/template_headings.txt"

# ─── Apply changes ────────────────────────────────────────────────
if [ "$ADDED" -eq 0 ]; then
  echo ""
  echo "✅ CLAUDE.md: all template sections already covered ($SKIPPED matched)"
  exit 0
fi

# Budget check
CURRENT_LINES=$(wc -l < "$TARGET_FILE" | tr -d ' ')
ADDED_LINES=$(echo "$SECTIONS_TO_ADD" | wc -l | tr -d ' ')
TOTAL=$((CURRENT_LINES + ADDED_LINES))

if [ "$TOTAL" -gt 250 ]; then
  echo ""
  echo "  ⚠️  BUDGET WARNING: result would be $TOTAL lines (>250). Consider offloading to claude/*.md"
fi

if $DRY_RUN; then
  echo ""
  echo "📊 Would add $ADDED section(s), skip $SKIPPED. Current: ${CURRENT_LINES}L → ${TOTAL}L"
  echo ""
  echo "Sections to add:"
  echo "$SECTIONS_TO_ADD" | head -30
  [ "$ADDED_LINES" -gt 30 ] && echo "  ... ($ADDED_LINES total lines)"
else
  echo "$SECTIONS_TO_ADD" >> "$TARGET_FILE"
  echo ""
  echo "📊 Added $ADDED section(s), skipped $SKIPPED. Now: ${TOTAL} lines"
fi

