#!/bin/bash
# cross-layer-check.sh — Verify symbol exists across all monorepo layers
# Usage: bash cross-layer-check.sh <symbol> [--exact]
# Populated by bootstrap with project-specific layer directories.

set -euo pipefail

SYMBOL="${1:-}"
EXACT="${2:-}"

if [ -z "$SYMBOL" ]; then
  echo "Usage: cross-layer-check.sh <symbol> [--exact]"
  echo "  <symbol>   Field name, enum value, or status code to search"
  printf '  --exact    Use word-boundary matching (-w flag)\n'
  exit 1
fi

if [ "$EXACT" = "--exact" ]; then
  GREP_FLAGS="-rnwE"
else
  GREP_FLAGS="-rnE"
fi

TOTAL_LAYERS=0
HIT_LAYERS=0

# Define layers — customize these for your monorepo structure.
# Each entry: "LABEL:DIR1,DIR2,..."
# The bootstrap will populate these from the actual repo layout.
LAYERS=(
  # {{CROSS_LAYER_DIRS}} — Populated by bootstrap. Example:
  # "Backend:core/services,src/api"
  # "Frontend:core/ui,src/web"
  # "Shared packages:core/packages,lib"
  # "Tests:test,tests,__tests__"
  # "Migrations:migrations,db"
  # "Documentation:claude,doc,docs"
)

# Fallback: auto-detect common directories if LAYERS is empty
if [ ${#LAYERS[@]} -eq 0 ]; then
  LAYERS=()
  for dir in src lib core services apps packages; do
    [ -d "$dir" ] && LAYERS+=("Source ($dir):$dir")
  done
  for dir in test tests __tests__ spec; do
    [ -d "$dir" ] && LAYERS+=("Tests ($dir):$dir")
  done
  for dir in migrations db database; do
    [ -d "$dir" ] && LAYERS+=("Database ($dir):$dir")
  done
  for dir in doc docs claude; do
    [ -d "$dir" ] && LAYERS+=("Docs ($dir):$dir")
  done
fi

echo "🔍 Cross-layer check: '$SYMBOL' $([ "$EXACT" = "--exact" ] && echo "(exact match)" || echo "(substring)")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for entry in "${LAYERS[@]}"; do
  LABEL="${entry%%:*}"
  DIRS_CSV="${entry#*:}"
  IFS=',' read -ra DIRS <<< "$DIRS_CSV"

  TOTAL_LAYERS=$((TOTAL_LAYERS + 1))
  COUNT=0

  for dir in "${DIRS[@]}"; do
    dir=$(echo "$dir" | xargs)  # trim whitespace
    if [ -d "$dir" ]; then
      HITS=$(grep $GREP_FLAGS "$SYMBOL" "$dir" --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.java' --include='*.py' --include='*.go' --include='*.rs' --include='*.rb' --include='*.sql' --include='*.md' 2>/dev/null | wc -l || true)
      COUNT=$((COUNT + HITS))
    fi
  done

  if [ "$COUNT" -gt 0 ]; then
    echo "  ✅ $LABEL: $COUNT hits"
    HIT_LAYERS=$((HIT_LAYERS + 1))
  else
    echo "  ❌ $LABEL: no hits"
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Result: $HIT_LAYERS/$TOTAL_LAYERS layers contain '$SYMBOL'"

if [ "$HIT_LAYERS" -lt 3 ] && [ "$TOTAL_LAYERS" -ge 3 ]; then
  echo "  ⚠️  WARNING: Found in fewer than 3 layers — likely incomplete implementation"
  exit 1
fi

