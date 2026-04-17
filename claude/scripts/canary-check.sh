#!/bin/bash
# canary-check.sh — Structural validation of LIVE Claude Code configuration
# Unlike validate.sh (template completeness), this checks the ACTIVE config health.
# Run periodically, via CI, or after bootstrap to verify configuration integrity.
# Exit code: 0 = all pass, 1 = failures found

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ canary-check.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -eo pipefail

PROJECT_DIR="${1:-.}"
ERRORS=0
WARNINGS=0
PASSES=0

info()  { echo "  ✅ PASS — $1"; PASSES=$((PASSES + 1)); }
warn()  { echo "  ⚠️  WARN — $1"; WARNINGS=$((WARNINGS + 1)); }
fail()  { echo "  ❌ FAIL — $1"; ERRORS=$((ERRORS + 1)); }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Code Canary Check"
echo "  Project: $PROJECT_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. CLAUDE.md exists and is in healthy range
echo ""
echo "📋 Root Instruction File..."
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
  LINES=$(wc -l < "$PROJECT_DIR/CLAUDE.md")
  if [ "$LINES" -lt 10 ]; then
    fail "CLAUDE.md is too short ($LINES lines, minimum 10)"
  elif [ "$LINES" -gt 500 ]; then
    fail "CLAUDE.md is too long ($LINES lines, maximum 500 — adherence will degrade)"
  else
    info "CLAUDE.md exists ($LINES lines)"
  fi
else
  fail "CLAUDE.md not found"
fi

# 2. @import resolution
echo ""
echo "🔗 @import Resolution..."
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
  IMPORTS=$(grep -oE '^@.+$' "$PROJECT_DIR/CLAUDE.md" 2>/dev/null || true)
  IMPORT_COUNT=0
  IMPORT_OK=0
  while IFS= read -r import; do
    [ -z "$import" ] && continue
    FILE="${import#@}"
    IMPORT_COUNT=$((IMPORT_COUNT + 1))
    if [ -f "$PROJECT_DIR/$FILE" ]; then
      IMPORT_OK=$((IMPORT_OK + 1))
    else
      fail "@import '$FILE' does not resolve to a file"
    fi
  done <<< "$IMPORTS"
  if [ "$IMPORT_COUNT" -gt 0 ]; then
    info "@import resolution ($IMPORT_OK/$IMPORT_COUNT resolve)"
  else
    warn "No @imports found in CLAUDE.md"
  fi
fi

# 3. Rule count audit (always-on rules should be < 150)
echo ""
echo "📐 Rule Count Audit..."
CLAUDE_RULES=0
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
  CLAUDE_RULES=$(grep -cE '^[[:space:]]*-[[:space:]]+\*\*|^##[[:space:]]+Rule[[:space:]]+|^###[[:space:]]+[0-9]+\.' "$PROJECT_DIR/CLAUDE.md" 2>/dev/null || echo 0)
fi

IMPORT_RULES=0
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
  for import_file in $(grep -oE '^@.+$' "$PROJECT_DIR/CLAUDE.md" 2>/dev/null | sed 's/^@//' || true); do
    if [ -f "$PROJECT_DIR/$import_file" ]; then
      COUNT=$(grep -cE '^[[:space:]]*-[[:space:]]+Do not|^##[[:space:]]+Rule[[:space:]]+|^\|[[:space:]]+' "$PROJECT_DIR/$import_file" 2>/dev/null || echo 0)
      IMPORT_RULES=$((IMPORT_RULES + COUNT))
    fi
  done
fi

TOTAL_ALWAYS_ON=$((CLAUDE_RULES + IMPORT_RULES))
if [ "$TOTAL_ALWAYS_ON" -gt 150 ]; then
  warn "Always-on rule count ($TOTAL_ALWAYS_ON) exceeds ~150 ceiling — adherence may degrade"
else
  info "Always-on rule count ($TOTAL_ALWAYS_ON) within ceiling"
fi

# 4. Token budget estimate (rough: 1 token ≈ 4 chars)
echo ""
echo "💰 Token Budget Estimate..."
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
  TOTAL_CHARS=$(wc -c < "$PROJECT_DIR/CLAUDE.md")
  for import_file in $(grep -oE '^@.+$' "$PROJECT_DIR/CLAUDE.md" 2>/dev/null | sed 's/^@//' || true); do
    if [ -f "$PROJECT_DIR/$import_file" ]; then
      IMPORT_CHARS=$(wc -c < "$PROJECT_DIR/$import_file")
      TOTAL_CHARS=$((TOTAL_CHARS + IMPORT_CHARS))
    fi
  done
  ESTIMATED_TOKENS=$((TOTAL_CHARS / 4))
  if [ "$ESTIMATED_TOKENS" -gt 15000 ]; then
    fail "Estimated always-on tokens ($ESTIMATED_TOKENS) exceeds 15K — context OVERLOADED"
  elif [ "$ESTIMATED_TOKENS" -gt 10000 ]; then
    warn "Estimated always-on tokens ($ESTIMATED_TOKENS) exceeds 10K — approaching heavy zone"
  else
    info "Estimated always-on tokens: ~$ESTIMATED_TOKENS (healthy)"
  fi
fi

# 5. Path-scoped rules
echo ""
echo "📂 Path-Scoped Rules..."
if [ -d "$PROJECT_DIR/.claude/rules" ]; then
  RULE_FILES=$(find "$PROJECT_DIR/.claude/rules" -name '*.md' | wc -l)
  info "Path-scoped rules: $RULE_FILES files"
else
  warn "No .claude/rules/ directory found"
fi

# 6. Skills inventory
echo ""
echo "🧠 Skills..."
if [ -d "$PROJECT_DIR/.claude/skills" ]; then
  SKILL_COUNT=$(find "$PROJECT_DIR/.claude/skills" -name 'SKILL.md' | wc -l)
  info "Skills found: $SKILL_COUNT"

  # Verify each skill is listed in README (warn only — UPGRADE may add skills the user hasn't documented yet)
  if [ -f "$PROJECT_DIR/claude/README.md" ]; then
    UNLISTED_SKILLS=0
    for skill_dir in "$PROJECT_DIR"/.claude/skills/*/; do
      [ -d "$skill_dir" ] || continue
      SKILL_NAME=$(basename "$skill_dir")
      if ! grep -q "$SKILL_NAME" "$PROJECT_DIR/claude/README.md" 2>/dev/null; then
        UNLISTED_SKILLS=$((UNLISTED_SKILLS + 1))
      fi
    done
    if [ "$UNLISTED_SKILLS" -gt 0 ]; then
      warn "$UNLISTED_SKILLS skill(s) not listed in claude/README.md — run post-bootstrap to update"
    else
      info "All skills listed in claude/README.md"
    fi
  fi
fi

# 7. Hooks registered in settings.json
echo ""
echo "🪝 Hooks..."
if [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
  HOOK_COUNT=$(grep -c '"command"' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null || echo 0)
  info "Hooks registered in settings.json: $HOOK_COUNT"

  # Verify hook scripts exist and are executable
  for hook_file in "$PROJECT_DIR"/.claude/hooks/*.sh; do
    [ -f "$hook_file" ] || continue
    if [ ! -x "$hook_file" ]; then
      fail "Hook script not executable: $(basename "$hook_file")"
    fi
  done
else
  fail ".claude/settings.json not found"
fi

# 8. Shell safety: edit-accumulator.sh must use `case`, never grep -E
echo ""
echo "🔒 Shell Safety (Pipe-Immune Patterns)..."
ACCUM="$PROJECT_DIR/.claude/hooks/edit-accumulator.sh"
if [ -f "$ACCUM" ]; then
  # Check non-comment lines only (grep -v strips comment lines first)
  if grep -v '^[[:space:]]*#' "$ACCUM" 2>/dev/null | grep -q 'grep -'; then
    fail "edit-accumulator.sh uses grep for extension matching — MUST use shell \`case\` (pipe-immune)"
  else
    info "edit-accumulator.sh uses case statement — pipe-immune ✓"
  fi
  if grep -q '{{CASE_EXTENSIONS}}' "$ACCUM" 2>/dev/null; then
    fail "edit-accumulator.sh still contains {{CASE_EXTENSIONS}} — placeholder not substituted"
  fi
fi

# Scan all hook scripts for grep -E with double-quoted patterns (pipe-unsafe anti-pattern)
GREP_E_DOUBLE_QUOTE=0
for hook_script in "$PROJECT_DIR"/.claude/hooks/*.sh; do
  [ -f "$hook_script" ] || continue
  BASENAME=$(basename "$hook_script")
  # Detect: grep -[flags]E[flags] "...  (double-quoted pattern — pipe-unsafe if value has |)
  # Skip comment lines (^#) — they document the anti-pattern, they don't use it
  if grep -nE 'grep[[:space:]]+-[a-zA-Z]*[qn]?[a-zA-Z]*E[a-zA-Z]*[[:space:]]+"' "$hook_script" 2>/dev/null | grep -v '^[0-9]*:[[:space:]]*#' | grep -q '.'; then
    fail "Hook $BASENAME has grep -E with double-quoted pattern — use single quotes or case statement"
    GREP_E_DOUBLE_QUOTE=$((GREP_E_DOUBLE_QUOTE + 1))
  fi
done
if [ "$GREP_E_DOUBLE_QUOTE" -eq 0 ]; then
  info "No grep -E double-quoted alternation patterns in hooks ✓"
fi

# 9. Agents
echo ""
echo "🤖 Agents..."
if [ -d "$PROJECT_DIR/.claude/agents" ]; then
  AGENT_COUNT=$(find "$PROJECT_DIR/.claude/agents" -name '*.md' | wc -l)
  info "Agents found: $AGENT_COUNT"
fi

# 10. Commands
echo ""
echo "⚡ Commands..."
if [ -d "$PROJECT_DIR/.claude/commands" ]; then
  CMD_COUNT=$(find "$PROJECT_DIR/.claude/commands" -name '*.md' | wc -l)
  info "Commands found: $CMD_COUNT"
fi

# 11. lessons.md size check
echo ""
echo "📝 Session Knowledge..."
if [ -f "$PROJECT_DIR/claude/tasks/lessons.md" ]; then
  LESSON_LINES=$(wc -l < "$PROJECT_DIR/claude/tasks/lessons.md")
  if [ "$LESSON_LINES" -gt 500 ]; then
    warn "claude/tasks/lessons.md exceeds 500 lines ($LESSON_LINES) — archive old entries"
  else
    info "claude/tasks/lessons.md size OK ($LESSON_LINES lines)"
  fi
else
  warn "claude/tasks/lessons.md not found"
fi

# 12. Stale reference scan
echo ""
echo "🔍 Stale Reference Scan..."
STALE_FOUND=0

# Check hook scripts for bare git commands (pager risk)
for hook_script in "$PROJECT_DIR"/.claude/hooks/*.sh; do
  [ -f "$hook_script" ] || continue
  BASENAME=$(basename "$hook_script")
  # Only log, show, stash trigger pager. diff --name-only is safe.
  # Skip: comment lines (^#), case patterns (*'git log'*), and --no-pager/| cat
  if grep -nE 'git[[:space:]]+(log|show|stash)' "$hook_script" 2>/dev/null | grep -v '^[0-9]*:[[:space:]]*#' | grep -vE -- "--no-pager|\| cat|\*'git" | grep -q '.'; then
    warn "Hook $BASENAME has bare git log/show/stash without --no-pager — may trigger pager"
  fi
done

# Check for references to files that don't exist
for doc in "$PROJECT_DIR"/claude/*.md; do
  [ -f "$doc" ] || continue
  for ref in $(grep -oE $'`(core/[^`]+|components/[^`]+|\\.claude/[^`]+)`' "$doc" 2>/dev/null | tr -d '`' || true); do
    if [ ! -e "$PROJECT_DIR/$ref" ] && [ ! -d "$PROJECT_DIR/$ref" ]; then
      # Skip: glob patterns, template placeholders, abbreviated paths, gitignored .local.* overrides
      if [[ "$ref" != *"*"* ]] && [[ "$ref" != *"**"* ]] && [[ "$ref" != *"<"* ]] && [[ "$ref" != *"..."* ]] && [[ "$ref" != *".local."* ]]; then
        warn "Stale reference in $(basename "$doc"): \`$ref\` does not exist"
        STALE_FOUND=1
      fi
    fi
  done
done
if [ "$STALE_FOUND" -eq 0 ]; then
  info "No stale file references found in claude/*.md"
fi

# 13. Remaining placeholder check
echo ""
echo "🔖 Placeholder Check..."
REMAINING=$(grep -rn '{{' "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/claude/" "$PROJECT_DIR/.claude/" "$PROJECT_DIR/.github/" 2>/dev/null | grep -v '_examples/' | grep -v '_template' | grep -v 'bootstrap' | grep -v 'node_modules' | grep -v 'claude/docs/' | grep -v 'claude/scripts/' | grep -v 'claude/tasks/' | grep -v "= '{{" | grep -v '.instructions.md' || true)
if [ -z "$REMAINING" ]; then
  info "No remaining {{PLACEHOLDER}} values — bootstrap complete"
else
  PLACEHOLDER_COUNT=$(echo "$REMAINING" | wc -l)
  warn "$PLACEHOLDER_COUNT remaining {{PLACEHOLDER}} values — bootstrap may be incomplete"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: ✅ $PASSES passed | ❌ $ERRORS errors | ⚠️  $WARNINGS warnings"

if [ "$ERRORS" -gt 0 ]; then
  echo "  ❌ CANARY CHECK FAILED — fix $ERRORS error(s)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  echo "  ⚠️  CANARY CHECK PASSED with $WARNINGS warning(s)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo "  ✅ CANARY CHECK PASSED — configuration is healthy!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
fi

