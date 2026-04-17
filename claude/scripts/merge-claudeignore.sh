#!/usr/bin/env bash
# merge-claudeignore.sh — Deterministic .claudeignore union merge
# Preserves ALL user patterns. Adds only missing template patterns with stack-aware filtering.
#
# Usage: bash claude/scripts/merge-claudeignore.sh --template <file> --target <file> --discovery-env <file> [--dry-run]
# Exit:  0 = merged, 1 = error, 2 = nothing to add

# ─── Source guard ─────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ merge-claudeignore.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -eo pipefail

# ─── Parse arguments ──────────────────────────────────────────────
TEMPLATE=""
TARGET_FILE=""
DISCOVERY_ENV=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template) TEMPLATE="$2"; shift 2 ;;
    --target) TARGET_FILE="$2"; shift 2 ;;
    --discovery-env) DISCOVERY_ENV="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

if [ -z "$TEMPLATE" ] || [ ! -f "$TEMPLATE" ]; then
  echo "❌ Template not found: ${TEMPLATE:-<not specified>}" >&2; exit 1
fi
if [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ]; then
  echo "❌ Target not found: ${TARGET_FILE:-<not specified>}" >&2; exit 1
fi

echo "🔄 .claudeignore union merge"
$DRY_RUN && echo "  ⚠️  DRY RUN — no files will be modified"

# ─── Read discovery env ───────────────────────────────────────────
PRIMARY_LANG=""
PACKAGE_MANAGER=""

if [ -n "$DISCOVERY_ENV" ] && [ -f "$DISCOVERY_ENV" ]; then
  PRIMARY_LANG=$(grep '^PRIMARY_LANGUAGE=' "$DISCOVERY_ENV" 2>/dev/null | head -1 | cut -d= -f2 || true)
  PACKAGE_MANAGER=$(grep '^PACKAGE_MANAGER=' "$DISCOVERY_ENV" 2>/dev/null | head -1 | cut -d= -f2 || true)
fi

# ─── Stack-aware skip patterns ────────────────────────────────────
# Patterns to EXCLUDE from template additions based on primary language/stack
should_skip_pattern() {
  local pattern="$1"

  # Python patterns: only if primary is Python
  case "$PRIMARY_LANG" in
    py|python) return 1 ;;  # don't skip — Python IS primary
  esac
  case "$PACKAGE_MANAGER" in
    pip|poetry|uv|pdm) return 1 ;;  # don't skip — Python package manager
  esac
  case "$pattern" in
    *__pycache__*|*.pyc|*.venv*|*venv/*|*site-packages*|*.mypy_cache*|*.pytest_cache*|*.ruff_cache*)
      return 0 ;;  # skip — Python is not primary
  esac

  # Rust patterns: only if primary is Rust
  case "$PRIMARY_LANG" in rs|rust) return 1 ;; esac
  case "$pattern" in
    **/target/|Cargo.lock) return 0 ;; # Only skip Cargo.lock if Rust isn't primary; target/ is universal
  esac

  # Gradle/Scala: only if detected
  case "$PRIMARY_LANG" in java|kotlin|scala|groovy) return 1 ;; esac
  case "$pattern" in
    *.gradle/*|*.bsp/*|*.metals/*|*.bloop/*) return 0 ;;
  esac

  # Yarn/Bun lock files: only for that package manager
  case "$PACKAGE_MANAGER" in
    yarn) ;;
    *) case "$pattern" in yarn.lock) return 0 ;; esac ;;
  esac
  case "$PACKAGE_MANAGER" in
    bun) ;;
    *) case "$pattern" in bun.lockb|bun.lock) return 0 ;; esac ;;
  esac

  return 1  # don't skip (include)
}

# ─── Extract non-comment, non-empty lines from a file ─────────────
extract_patterns() {
  grep -v '^#' "$1" 2>/dev/null | grep -v '^[[:space:]]*$' | sed 's/[[:space:]]*$//' | sort -u || true
}

# ─── Compute patterns to add ──────────────────────────────────────
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

extract_patterns "$TARGET_FILE" > "$TMPDIR/user_patterns.txt"
extract_patterns "$TEMPLATE" > "$TMPDIR/template_patterns.txt"

ADDED=0
SKIPPED=0
TO_ADD=""

while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue

  # Already in user file?
  if grep -qFx "$pattern" "$TMPDIR/user_patterns.txt" 2>/dev/null; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Stack-aware filter?
  if should_skip_pattern "$pattern"; then
    echo "  🚫 Skip (not in stack): $pattern"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  TO_ADD="${TO_ADD}${pattern}
"
  ADDED=$((ADDED + 1))
done < "$TMPDIR/template_patterns.txt"

if [ "$ADDED" -eq 0 ]; then
  echo "✅ .claudeignore: all template patterns already present ($SKIPPED checked)"
  exit 2
fi

echo "  ➕ Adding $ADDED new pattern(s), $SKIPPED already present/filtered"

if $DRY_RUN; then
  echo ""
  echo "Patterns to add:"
  echo "$TO_ADD" | head -20
  [ "$ADDED" -gt 20 ] && echo "  ... ($ADDED total)"
else
  {
    echo ""
    echo "# Added by Brain Bootstrap $(date +%Y-%m-%d)"
    echo "$TO_ADD"
  } >> "$TARGET_FILE"
  echo "✅ .claudeignore: $ADDED pattern(s) added"
fi

