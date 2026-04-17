#!/bin/bash
# generate-copilot-docs.sh — Mirror claude/*.md domain docs to .github/copilot/ for GitHub Copilot
# Also creates domain-scoped .github/instructions/<domain>.instructions.md files.
# Usage: bash claude/scripts/generate-copilot-docs.sh [root_dir]
# Safe to re-run: only creates missing files, never overwrites existing.

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ generate-copilot-docs.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -euo pipefail

ROOT="${1:-.}"
CREATED=0
SKIPPED=0

echo "📋 Mirroring domain docs to .github/copilot/ ..."

# ─── Create .github/copilot/ if it doesn't exist ─────────────────
COPILOT_DIR="$ROOT/.github/copilot"
mkdir -p "$COPILOT_DIR"

# ─── Mirror claude/*.md → .github/copilot/*.md ───────────────────
# Exclude: README.md, templates.md, terminal-safety.md, plugins.md, decisions.md
# (these are Claude Code-specific, not relevant for Copilot)

for doc in "$ROOT"/claude/*.md; do
  [ -f "$doc" ] || continue
  BASENAME=$(basename "$doc")

  # Skip excluded files
  case "$BASENAME" in
    README.md|templates.md|terminal-safety.md|plugins.md|decisions.md) continue ;;
  esac

  TARGET="$COPILOT_DIR/$BASENAME"

  # Never overwrite existing copilot docs (user may have customized)
  if [ -f "$TARGET" ]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  cp "$doc" "$TARGET"
  CREATED=$((CREATED + 1))
done

# ─── Create domain-scoped .github/instructions/ files ─────────────
INSTRUCTIONS_DIR="$ROOT/.github/instructions"
mkdir -p "$INSTRUCTIONS_DIR"

# For each domain doc, create a matching .github/instructions/<domain>.instructions.md
# with proper applyTo glob patterns based on domain name heuristics
for doc in "$COPILOT_DIR"/*.md; do
  [ -f "$doc" ] || continue
  BASENAME=$(basename "$doc" .md)

  # Skip non-domain docs
  case "$BASENAME" in
    architecture|build|cve-policy|rules) continue ;;
  esac

  INSTRUCTION_FILE="$INSTRUCTIONS_DIR/${BASENAME}.instructions.md"

  # ─── Near-duplicate detection (singular/plural) ────────────────────
  # If "webhooks.instructions.md" is about to be created but "webhook.instructions.md"
  # already exists (or vice versa), consolidate into the canonical name (from the domain doc).
  # This prevents two files covering the same domain with slightly different names.
  if [ ! -f "$INSTRUCTION_FILE" ]; then
    # Try the opposite plural form
    case "$BASENAME" in
      *s) ALT_BASE="${BASENAME%s}" ;;         # webhooks → webhook
      *)  ALT_BASE="${BASENAME}s" ;;           # webhook → webhooks
    esac
    ALT_FILE="$INSTRUCTIONS_DIR/${ALT_BASE}.instructions.md"
    if [ -f "$ALT_FILE" ]; then
      echo "  ⚠ Consolidating near-duplicate: ${ALT_BASE}.instructions.md → ${BASENAME}.instructions.md"
      mv "$ALT_FILE" "$INSTRUCTION_FILE"
    fi
  fi

  # Stub detection: overwrite if the file is a bootstrap-generated stub (hollow content).
  # A stub has < 4 content lines OR contains TODO markers — a human-written file won't have either.
  # This ensures UPGRADE enriches stubs from prior runs instead of leaving them hollow forever.
  IS_STUB=false
  if [ -f "$INSTRUCTION_FILE" ]; then
    CONTENT_LINES=$(awk '!/^---$|^applyTo:|^#|^>|^[[:space:]]*$/{n++} END{print n+0}' "$INSTRUCTION_FILE")
    HAS_TODO=$(awk '/TODO:/{n++} END{print n+0}' "$INSTRUCTION_FILE")
    if [ "$CONTENT_LINES" -lt 4 ] || [ "$HAS_TODO" -gt 0 ]; then
      IS_STUB=true
    fi
  fi
  # Skip if substantial user-written file; process if missing or a stub
  if [ -f "$INSTRUCTION_FILE" ] && [ "$IS_STUB" = "false" ]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  [ "$IS_STUB" = "true" ] && echo "  ↻ Enriching stub: $(basename "$INSTRUCTION_FILE")"

  # Determine applyTo glob based on domain name
  APPLY_TO=""
  case "$BASENAME" in
    database|db)
      APPLY_TO="**/migrations/**,**/knex*,**/prisma/**,**/*migration*,**/*schema*"
      ;;
    auth|keycloak)
      APPLY_TO="**/auth/**,**/keycloak/**,**/*guard*,**/*token*,**/*jwt*"
      ;;
    messaging|kafka)
      APPLY_TO="**/kafka/**,**/*producer*,**/*consumer*,**/*topic*,**/*message*"
      ;;
    invoice*|lifecycle)
      APPLY_TO="**/invoice*/**,**/lifecycle*/**,**/status*/**,**/workflow*/**"
      ;;
    webhook*|adapter*)
      APPLY_TO="**/webhook*/**,**/adapter*/**,**/notifier*/**,**/callback*/**"
      ;;
    enrollment|onboarding)
      APPLY_TO="**/enrollment*/**,**/onboarding*/**,**/signup*/**,**/registration*/**"
      ;;
    reporting)
      APPLY_TO="**/report*/**,**/aggregat*/**,**/xslt/**"
      ;;
    protocols)
      APPLY_TO="**/protocol*/**,**/format*/**,**/convert*/**,**/transform*/**"
      ;;
    *)
      APPLY_TO="**/${BASENAME}*/**"
      ;;
  esac

  # Extract key patterns from the domain doc to create a useful instruction file
  # (not just an empty pointer). Grab ## headings + first 2-3 bullet points per section.
  SRC_DOC="$ROOT/claude/${BASENAME}.md"
  KEY_PATTERNS=""
  if [ -f "$SRC_DOC" ]; then
    # Richer extraction: section headings, bold bullets, code bullets, NEVER/ALWAYS patterns
    # Captures the structural skeleton of the domain doc — up to 15 lines
    KEY_PATTERNS=$(grep -E '^##[[:space:]]|^[[:space:]]*-[[:space:]]+\*\*|^[[:space:]]*-[[:space:]]+`|\*\*NEVER\*\*|\*\*ALWAYS\*\*' "$SRC_DOC" | head -15 | sed 's/^[[:space:]]*//' || true)
  fi

  if [ -n "$KEY_PATTERNS" ]; then
    printf '%s\n' "---" \
      "applyTo: \"${APPLY_TO}\"" \
      "---" \
      "# ${BASENAME^} Domain — Scoped Instructions" \
      "" \
      "> Full domain reference: \`claude/${BASENAME}.md\`" \
      "" \
      "## Key Patterns (extracted from domain doc)" \
      "" \
      "$KEY_PATTERNS" \
      "" \
      "> See \`claude/${BASENAME}.md\` for the complete reference." \
      > "$INSTRUCTION_FILE"
  else
    printf '%s\n' "---" \
      "applyTo: \"${APPLY_TO}\"" \
      "---" \
      "# ${BASENAME^} Domain — Scoped Instructions" \
      "" \
      "> Auto-generated by bootstrap. Enrich with 3-5 key patterns from \`claude/${BASENAME}.md\`." \
      "> Full domain reference: \`claude/${BASENAME}.md\`" \
      "" \
      "## Key Patterns" \
      "<!-- TODO: Extract 3-5 critical patterns from claude/${BASENAME}.md -->" \
      "<!-- Example: -->" \
      "<!-- - **NEVER do X** — reason -->" \
      "<!-- - \`functionName()\` takes Y, not Z -->" \
      "" \
      "## Pitfalls" \
      "<!-- TODO: Add 2-3 domain-specific pitfalls -->" \
      > "$INSTRUCTION_FILE"
  fi

  CREATED=$((CREATED + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Copilot docs: $CREATED created/enriched, $SKIPPED skipped (substantial, preserved)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


