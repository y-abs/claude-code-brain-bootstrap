#!/usr/bin/env bash
# populate-templates.sh — Batch placeholder replacement for Claude Code bootstrap
# Replaces ~70 mechanical {{PLACEHOLDER}} values across all template files in a single pass.
# Usage: bash claude/scripts/populate-templates.sh <discovery-env-file> [project-dir] [--dry-run] [--quiet]
# Leaves creative placeholders (architecture, domain docs) for AI to handle.
# Exit: 0 on success, 1 on error

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ populate-templates.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

# ─── Bash 4+ required (associative arrays — declare -A) ──────────
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "❌ bash 4+ required (found: ${BASH_VERSION:-unknown})" >&2
  echo "   macOS users: brew install bash" >&2
  echo "   Then re-run: /opt/homebrew/bin/bash $0 $*" >&2
  exit 1
fi

set -eo pipefail

DISCOVERY_FILE="${1:?Usage: populate-templates.sh <discovery-env-file> [project-dir] [--dry-run] [--quiet]}"
PROJECT_DIR="${2:-.}"
DRY_RUN=false
QUIET=false

# Parse optional flags
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --quiet)   QUIET=true ;;
  esac
done

if [ ! -f "$DISCOVERY_FILE" ]; then
  echo "❌ Discovery file not found: $DISCOVERY_FILE"
  exit 1
fi

cd "$PROJECT_DIR"

# ─── Portable helpers (sed_inplace, platform detection) ──────────
source "$(dirname "$0")/_platform.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Code Brain — Batch Populate"
if $DRY_RUN; then echo "  ⚠️  DRY RUN — no files will be modified"; fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Parse discovery file into associative array ──────────────────
# Handles values containing '=' by splitting on first '=' only

declare -A VALUES
while IFS= read -r line; do
  # Skip comments and empty lines
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  # Split on first '=' only (preserves '=' in values)
  key="${line%%=*}"
  value="${line#*=}"
  # Trim whitespace from key
  key=$(echo "$key" | xargs)
  [ -z "$key" ] && continue
  VALUES["$key"]="$value"
done < "$DISCOVERY_FILE"

echo "📦 Loaded ${#VALUES[@]} discovery values"

# ─── Self-Bootstrap Protection ────────────────────────────────────
# Block if running on the template repo itself (would destroy {{PLACEHOLDER}} tokens).
# Two layers: (1) trust discovery env, (2) independent filesystem check.
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
  esac
done

if [ "${VALUES[IS_TEMPLATE_REPO]}" = "true" ] && ! $FORCE; then
  echo ""
  echo "🛑 SELF-BOOTSTRAP BLOCKED — This is the template repository itself!"
  echo ""
  echo "   Running populate-templates.sh on the template would destroy the"
  echo "   {{PLACEHOLDER}} tokens that make it a reusable template."
  echo ""
  echo "   ✅ To bootstrap a real project, copy the template files first:"
  echo "      cp -r /path/to/claude-code-brain/{CLAUDE.md,.claude,.claudeignore,.mcp.json,claude,scripts,validate.sh} /your/project/"
  echo "      mkdir -p /your/project/.github/{instructions,prompts}"
  echo "      cp /path/to/claude-code-brain/.github/copilot-instructions.md /your/project/.github/"
  echo "      cp -r /path/to/claude-code-brain/.github/{instructions,prompts} /your/project/.github/"
  echo "      cd /your/project && bash claude/scripts/discover.sh . > claude/tasks/.discovery.env 2>&1"
  echo "      bash claude/scripts/populate-templates.sh claude/tasks/.discovery.env . 2>&1"
  echo ""
  echo "   🔧 To force anyway (template development): add --force flag"
  echo ""
  exit 1
fi

# Independent filesystem guard: verify at least one project manifest exists.
# Prevents bypass via hand-edited .discovery.env.
if ! $FORCE; then
  _HAS_MANIFEST=false
  for _m in package.json Cargo.toml go.mod pyproject.toml pom.xml build.gradle pubspec.yaml mix.exs setup.py requirements.txt composer.json Gemfile CMakeLists.txt Makefile deno.json; do
    if [ -f "$_m" ]; then _HAS_MANIFEST=true; break; fi
  done
  if ! $_HAS_MANIFEST && [ -f "claude/bootstrap/PROMPT.md" ] && [ -d "claude/_examples" ]; then
    echo ""
    echo "🛑 SELF-BOOTSTRAP BLOCKED — No project manifest found (package.json, Cargo.toml, etc.)"
    echo "   This appears to be the template repository, not a real project."
    echo "   Copy the template files into your project directory first."
    echo "   To force anyway: add --force flag."
    echo ""
    exit 1
  fi
fi

# ─── Define placeholder → target files mapping ───────────────────
# Only files that have mechanical {{PLACEHOLDER}} replacements.
# Architecture.md, domain docs, CLAUDE.md critical patterns are LEFT for AI.

declare -A PLACEHOLDER_FILES

# PROJECT_NAME → 9 files
PLACEHOLDER_FILES["PROJECT_NAME"]="CLAUDE.md claude/README.md claude/decisions.md .claude/agents/research.md .claude/agents/reviewer.md .claude/agents/plan-challenger.md .claude/hooks/identity-reinjection.sh .github/copilot-instructions.md .github/instructions/general.instructions.md"

# Build stack
PLACEHOLDER_FILES["PACKAGE_MANAGER"]="claude/build.md .github/instructions/general.instructions.md"
PLACEHOLDER_FILES["PACKAGE_MANAGER_VERSION"]="claude/build.md"
PLACEHOLDER_FILES["RUNTIME"]="claude/build.md .github/instructions/general.instructions.md"
PLACEHOLDER_FILES["RUNTIME_VERSION"]="claude/build.md"
PLACEHOLDER_FILES["RUNTIME_VER"]="claude/build.md"

# Formatter / Linter
PLACEHOLDER_FILES["FORMATTER"]="claude/build.md .github/instructions/general.instructions.md"
PLACEHOLDER_FILES["LINTER"]="claude/build.md .claude/commands/lint.md"
PLACEHOLDER_FILES["LINTER_CONFIG_FILE"]=".claude/commands/lint.md"
PLACEHOLDER_FILES["FORMATTER_COMMAND"]=".claude/hooks/stop-batch-format.sh"
PLACEHOLDER_FILES["LINT_CHECK_CMD"]="claude/build.md .claude/commands/lint.md .claude/commands/mr.md"
PLACEHOLDER_FILES["LINT_CHECK_PRIMARY"]=".claude/hooks/tdd-loop-check.sh"
PLACEHOLDER_FILES["LINT_FIX_CMD"]="claude/build.md .claude/commands/lint.md"
PLACEHOLDER_FILES["FORMAT_CMD"]="claude/build.md .claude/commands/lint.md"
PLACEHOLDER_FILES["STYLE_RULES"]=".claude/commands/lint.md .github/instructions/general.instructions.md"

# Test
PLACEHOLDER_FILES["TEST_FRAMEWORK"]=".github/instructions/testing.instructions.md .github/prompts/generate-tests.prompt.md"
PLACEHOLDER_FILES["COVERAGE_TOOL"]=".github/instructions/testing.instructions.md"
PLACEHOLDER_FILES["TEST_CMD_ALL"]="claude/build.md .claude/commands/test.md"
PLACEHOLDER_FILES["TEST_CMD_PRIMARY"]=".claude/hooks/tdd-loop-check.sh"
PLACEHOLDER_FILES["TEST_CMD_SINGLE"]="claude/build.md .claude/commands/test.md"
PLACEHOLDER_FILES["TEST_CMD_CI"]="claude/build.md .claude/commands/test.md .claude/commands/mr.md"
PLACEHOLDER_FILES["TEST_CMD_COVERAGE"]="claude/build.md .claude/commands/test.md"

# Build commands
PLACEHOLDER_FILES["BUILD_CMD_ALL"]="claude/build.md .claude/commands/build.md .claude/commands/mr.md"
PLACEHOLDER_FILES["BUILD_CMD_SINGLE"]="claude/build.md .claude/commands/build.md"
PLACEHOLDER_FILES["BUILD_CMD_PACKAGES"]="claude/build.md .claude/commands/build.md"
PLACEHOLDER_FILES["INSTALL_CMD"]="claude/build.md"
PLACEHOLDER_FILES["DEV_CMD"]="claude/build.md"

# Serve commands
PLACEHOLDER_FILES["SERVE_CMD_ALL"]=".claude/commands/serve.md"
PLACEHOLDER_FILES["SERVE_CMD_SINGLE"]=".claude/commands/serve.md"
PLACEHOLDER_FILES["SERVE_CMD_FRONTEND"]=".claude/commands/serve.md"
PLACEHOLDER_FILES["SERVE_CMD_BACKEND"]=".claude/commands/serve.md"

# Migration commands
PLACEHOLDER_FILES["MIGRATE_UP_CMD"]=".claude/commands/migrate.md"
PLACEHOLDER_FILES["MIGRATE_DOWN_CMD"]=".claude/commands/migrate.md"
PLACEHOLDER_FILES["MIGRATE_STATUS_CMD"]=".claude/commands/migrate.md"
PLACEHOLDER_FILES["MIGRATE_CREATE_CMD"]=".claude/commands/migrate.md"

# DB commands
PLACEHOLDER_FILES["DB_LIST_SCHEMAS_CMD"]=".claude/commands/db.md"
PLACEHOLDER_FILES["DB_LIST_TABLES_CMD"]=".claude/commands/db.md"
PLACEHOLDER_FILES["DB_DESCRIBE_CMD"]=".claude/commands/db.md"
PLACEHOLDER_FILES["DB_QUERY_CMD"]=".claude/commands/db.md"

# Dependency commands
PLACEHOLDER_FILES["DEPS_OUTDATED_CMD"]=".claude/commands/deps.md"
PLACEHOLDER_FILES["DEPS_UPDATE_CMD"]=".claude/commands/deps.md"
PLACEHOLDER_FILES["DEPS_WHY_CMD"]=".claude/commands/deps.md"
PLACEHOLDER_FILES["DEPS_DEDUPE_CMD"]=".claude/commands/deps.md"

# Security
PLACEHOLDER_FILES["SCANNER_TOOL"]="claude/cve-policy.md .claude/commands/docker.md"
PLACEHOLDER_FILES["SCAN_COMMAND"]="claude/cve-policy.md .claude/commands/deps.md"

# Hook customizations
# CASE_EXTENSIONS uses *.ext1|*.ext2 format (shell case glob patterns, NOT regex)
# The | is a shell `case` separator — pipe-immune. Never revert to grep -E here.
PLACEHOLDER_FILES["CASE_EXTENSIONS"]=".claude/hooks/edit-accumulator.sh"
PLACEHOLDER_FILES["SOURCE_EXTENSIONS"]=".claude/hooks/pre-commit-quality.sh"
PLACEHOLDER_FILES["SECONDARY_FORMATTER_COMMAND"]=".claude/hooks/stop-batch-format.sh"
# SECONDARY_FORMATTER_CASE_EXTS uses *.ext1|*.ext2 (case glob, pipe-immune)
# Replaces the old SECONDARY_FORMATTER_EXTS (regex with grep -E — pipe-unsafe)
PLACEHOLDER_FILES["SECONDARY_FORMATTER_CASE_EXTS"]=".claude/hooks/stop-batch-format.sh"

# Skills
PLACEHOLDER_FILES["TEST_FRAMEWORK_1"]=".claude/skills/tdd/SKILL.md"
PLACEHOLDER_FILES["TEST_FRAMEWORK_2"]=".claude/skills/tdd/SKILL.md"
PLACEHOLDER_FILES["LAYER_1"]=".claude/skills/tdd/SKILL.md"
PLACEHOLDER_FILES["LAYER_2"]=".claude/skills/tdd/SKILL.md"

# ─── Perform replacements ────────────────────────────────────────

REPLACED=0
SKIPPED=0
NOTFOUND=0
TOTAL_PLACEHOLDERS=${#PLACEHOLDER_FILES[@]}
CURRENT=0

for PLACEHOLDER in "${!PLACEHOLDER_FILES[@]}"; do
  VALUE="${VALUES[$PLACEHOLDER]:-}"
  CURRENT=$((CURRENT + 1))

  # Skip empty values — these need AI creative work
  if [ -z "$VALUE" ]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Validate placeholder name is in our known set (guard against injection)
  if ! [[ "$PLACEHOLDER" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Escape special characters for sed replacement
  ESCAPED_VALUE=$(printf '%s\n' "$VALUE" | sed 's/[&/\\]/\\&/g')
  PATTERN="{{${PLACEHOLDER}}}"
  # In sed BRE: escape [ \ . * ^ $ ( ) + ? — but NOT { } or | (literal in BRE)
  ESCAPED_PATTERN=$(printf '%s\n' "$PATTERN" | sed 's/[[\.*^()+?$]/\\&/g')

  FILES="${PLACEHOLDER_FILES[$PLACEHOLDER]}"
  for FILE in $FILES; do
    if [ -f "$FILE" ]; then
      if grep -q "$PATTERN" "$FILE" 2>/dev/null; then
        if $DRY_RUN; then
          $QUIET || echo "  [$CURRENT/$TOTAL_PLACEHOLDERS] $PLACEHOLDER → ${VALUE:0:50}$([ ${#VALUE} -gt 50 ] && echo '...')  in $FILE"
        else
          sed_inplace "s/${ESCAPED_PATTERN}/${ESCAPED_VALUE}/g" "$FILE"
          $QUIET || echo "  [$CURRENT/$TOTAL_PLACEHOLDERS] $PLACEHOLDER → ${VALUE:0:50}$([ ${#VALUE} -gt 50 ] && echo '...')  in $FILE"
        fi
        REPLACED=$((REPLACED + 1))
      fi
    else
      NOTFOUND=$((NOTFOUND + 1))
    fi
  done
done

echo ""
echo "📊 Replacement Summary:"
if $DRY_RUN; then
  echo "  🔍 Would replace: $REPLACED placeholder occurrences"
else
  echo "  ✅ Replaced: $REPLACED placeholder occurrences"
fi
echo "  ⏭️  Skipped (empty value — needs AI): $SKIPPED"
echo "  ⚠️  File not found: $NOTFOUND"

# ─── Special: TDD skill layers ───────────────────────────────────
# Map primary language to layer names
SKILL_FILE=".claude/skills/tdd/SKILL.md"
if [ -f "$SKILL_FILE" ] && grep -q '{{LAYER_' "$SKILL_FILE" 2>/dev/null; then
  PRIMARY="${VALUES[PRIMARY_LANGUAGE]:-}"
  # Escape values for sed (/, &, \ are special in sed replacement)
  TF_ESCAPED=$(printf '%s\n' "${VALUES[TEST_FRAMEWORK]:-Jest}" | sed 's/[&/\\]/\\&/g')
  case "$PRIMARY" in
    ts|tsx|js|jsx)
      sed_inplace 's/{{LAYER_1}}/Backend services/g; s/{{LAYER_2}}/Frontend components/g' "$SKILL_FILE"
      sed_inplace "s/{{TEST_FRAMEWORK_1}}/${TF_ESCAPED}/g; s/{{TEST_FRAMEWORK_2}}/${TF_ESCAPED}/g" "$SKILL_FILE"
      ;;
    py)
      sed_inplace 's/{{LAYER_1}}/Application/g; s/{{LAYER_2}}/Integration/g' "$SKILL_FILE"
      sed_inplace 's/{{TEST_FRAMEWORK_1}}/pytest/g; s/{{TEST_FRAMEWORK_2}}/pytest/g' "$SKILL_FILE"
      ;;
    *)
      TF_DEFAULT_ESCAPED=$(printf '%s\n' "${VALUES[TEST_FRAMEWORK]:-unknown}" | sed 's/[&/\\]/\\&/g')
      sed_inplace 's/{{LAYER_1}}/Unit/g; s/{{LAYER_2}}/Integration/g' "$SKILL_FILE"
      sed_inplace "s/{{TEST_FRAMEWORK_1}}/${TF_DEFAULT_ESCAPED}/g; s/{{TEST_FRAMEWORK_2}}/${TF_DEFAULT_ESCAPED}/g" "$SKILL_FILE"
      ;;
  esac
  echo "  🧪 TDD skill layers populated"
fi

# ─── Special: IDE Integration auto-detection ──────────────────────
# Uncomment the correct IDE section in CLAUDE.md based on detected IDE config dirs.
# Uses python3 for reliable multi-line comment handling (sed is fragile for this).
CLAUDE_MD="CLAUDE.md"
if [ -f "$CLAUDE_MD" ] && grep -q 'Uncomment the section matching your IDE' "$CLAUDE_MD" 2>/dev/null; then
  IDE_MODE=""
  [ -d ".idea" ] && IDE_MODE="intellij"
  [ -d ".vscode" ] && { [ -z "$IDE_MODE" ] && IDE_MODE="vscode" || IDE_MODE="both"; }

  if [ -n "$IDE_MODE" ] && command -v python3 &>/dev/null; then
    if ! $DRY_RUN; then
      python3 -u -c "
import re, sys
text = open('$CLAUDE_MD').read()
# Extract the commented IDE block
m = re.search(r'<!-- Uncomment the section matching your IDE:\n(.*?)-->', text, re.DOTALL)
if not m:
    sys.exit(0)
block = m.group(1)
mode = '$IDE_MODE'
if mode == 'intellij':
    # Keep IntelliJ, remove VS Code
    block = re.sub(r'\n### VS Code\n.*', '', block, flags=re.DOTALL)
elif mode == 'vscode':
    # Keep VS Code, remove IntelliJ
    block = re.sub(r'\n### IntelliJ.*?(### VS Code)', r'\n\1', block, flags=re.DOTALL)
# Replace the comment block with clean content
text = text.replace(m.group(0), block.rstrip())
open('$CLAUDE_MD', 'w').write(text)
" 2>&1
    fi
    $QUIET || echo "  🖥️  IDE detected: $IDE_MODE — uncommented IDE section in CLAUDE.md"
  elif [ -n "$IDE_MODE" ]; then
    $QUIET || echo "  ⚠️  IDE detected ($IDE_MODE) but python3 not available — IDE section left commented (AI will handle in Step 2)"
  else
    $QUIET || echo "  🖥️  No IDE config detected (.idea/ or .vscode/) — IDE section left commented"
  fi
fi

# ─── Special: Monorepo per-service CLAUDE.md stubs ────────────────
# Auto-generate CLAUDE.md stubs for each service directory in monorepos.
# This runs the existing generate-service-claudes.sh script automatically.
SERVICE_COUNT="${VALUES[SERVICE_COUNT]:-0}"
MONOREPO="${VALUES[MONOREPO_TOOL]:-}"
GENERATE_SCRIPT="claude/scripts/generate-service-claudes.sh"
if [ -f "$GENERATE_SCRIPT" ] && { [ "$SERVICE_COUNT" -gt 0 ] 2>/dev/null || [ -n "$MONOREPO" ]; }; then
  if $DRY_RUN; then
    echo "  📁 Would generate per-service CLAUDE.md stubs (monorepo with $SERVICE_COUNT services)"
  else
    bash "$GENERATE_SCRIPT" . 2>&1
  fi
fi

# ─── Special: GitHub Copilot domain docs mirror ──────────────────
# After all domain docs are populated, copy them to .github/copilot/ for Copilot users.
# This runs AFTER creative population, so it's also called in post-bootstrap as a catch-all.
COPILOT_SCRIPT="claude/scripts/generate-copilot-docs.sh"
if [ -f "$COPILOT_SCRIPT" ]; then
  if $DRY_RUN; then
    echo "  📋 Would generate GitHub Copilot domain docs mirror"
  else
    bash "$COPILOT_SCRIPT" . 2>&1
  fi
fi

# ─── Special: Plugin pre-configuration ────────────────────────────
# Report what discover.sh found. Actual plugin INSTALLATION happens in
# claude/bootstrap/PROMPT.md Phase 4 (after populate). Phase 4D updates CLAUDE.md
# with the final installed state. Here we just log the pre-install status.
HAS_MEM="${VALUES[HAS_CLAUDE_MEM]:-false}"
DETECTED_PLUGINS="${VALUES[PLUGINS]:-}"

echo ""
echo "🔌 Plugin detection (pre-install):"
echo "  claude-mem: $([ "$HAS_MEM" = "true" ] && echo '✅ already installed' || echo '⬜ not yet installed — Phase 4 will install')"
[ -n "$DETECTED_PLUGINS" ] && echo "  All detected: $DETECTED_PLUGINS"

# ─── Special: settings.json package manager + language tool permissions ────
SETTINGS=".claude/settings.json"
if [ -f "$SETTINGS" ]; then
  PKG="${VALUES[PACKAGE_MANAGER]:-}"
  # Use -F (fixed string) to prevent regex special chars in PKG from breaking grep
  if [ -n "$PKG" ] && ! grep -qF "Bash($PKG " "$SETTINGS" 2>/dev/null; then
    if $DRY_RUN; then
      echo "  ⚙️  Would add '$PKG' to settings.json permissions"
    else
      # Add package manager to permissions.allow before the Edit entry
      sed_inplace "/\"Edit\"/i\\      \"Bash($PKG *)\"," "$SETTINGS"
      echo "  ⚙️  Added '$PKG' to settings.json permissions"
    fi
  fi

  # Language-specific tool permissions
  # ONLY add tools for PRIMARY language (secondary = build utilities, not dev language)
  PRIMARY="${VALUES[PRIMARY_LANGUAGE]:-}"

  # Python tools — ONLY if primary language or primary package manager
  PKG_MGR="${VALUES[PACKAGE_MANAGER]:-}"
  PYTHON_PRIMARY=false
  case "$PRIMARY" in py|python) PYTHON_PRIMARY=true ;; esac
  case "$PKG_MGR" in pip|poetry|uv|pdm) PYTHON_PRIMARY=true ;; esac
  if $PYTHON_PRIMARY; then
    for TOOL in "python3" "python" "pytest" "ruff" "black" "mypy" "pip"; do
      if ! grep -qF "Bash($TOOL " "$SETTINGS" 2>/dev/null; then
        if ! $DRY_RUN; then
          sed_inplace "/\"Edit\"/i\\      \"Bash($TOOL *)\"," "$SETTINGS"
        fi
      fi
    done
    $QUIET || echo "  ⚙️  Added Python tool permissions (python3, pytest, ruff, etc.)"
  fi

  # Go tools — ONLY if primary language
  if [ "$PRIMARY" = "go" ]; then
    # shellcheck disable=SC2043  # Single item now; ready for future Go tools (golint, air, etc.)
    for TOOL in "go"; do
      if ! grep -qF "Bash($TOOL " "$SETTINGS" 2>/dev/null; then
        if ! $DRY_RUN; then
          sed_inplace "/\"Edit\"/i\\      \"Bash($TOOL *)\"," "$SETTINGS"
        fi
      fi
    done
    $QUIET || echo "  ⚙️  Added Go tool permissions"
  fi

  # Rust tools — ONLY if primary language
  if [ "$PRIMARY" = "rs" ] || [ "$PRIMARY" = "rust" ]; then
    for TOOL in "cargo" "rustfmt" "clippy"; do
      if ! grep -qF "Bash($TOOL " "$SETTINGS" 2>/dev/null; then
        if ! $DRY_RUN; then
          sed_inplace "/\"Edit\"/i\\      \"Bash($TOOL *)\"," "$SETTINGS"
        fi
      fi
    done
    $QUIET || echo "  ⚙️  Added Rust tool permissions"
  fi

  # Make (if Makefile exists)
  if [ -f "Makefile" ] || [ -f "makefile" ] || [ -f "GNUmakefile" ]; then
    if ! grep -qF "Bash(make " "$SETTINGS" 2>/dev/null; then
      if ! $DRY_RUN; then
        sed_inplace "/\"Edit\"/i\\      \"Bash(make *)\"," "$SETTINGS"
      fi
      $QUIET || echo "  ⚙️  Added 'make' to settings.json permissions"
    fi
  fi

  # Docker (if Docker detected — minus destructive commands already in deny)
  DOCKER_DETECTED="${VALUES[DOCKER]:-false}"
  if [ "$DOCKER_DETECTED" = "true" ]; then
    for TOOL in "docker compose" "docker build" "docker run" "docker logs" "docker ps" "docker exec"; do
      if ! grep -qF "Bash($TOOL " "$SETTINGS" 2>/dev/null; then
        if ! $DRY_RUN; then
          sed_inplace "/\"Edit\"/i\\      \"Bash($TOOL *)\"," "$SETTINGS"
        fi
      fi
    done
    $QUIET || echo "  ⚙️  Added Docker tool permissions (build, run, logs, compose)"
  fi
fi

# ─── Report remaining placeholders ────────────────────────────────
echo ""
echo "📋 Remaining placeholders (need AI creative work):"
REMAINING=$(grep -rn '{{[A-Z_][A-Z_]*}}' CLAUDE.md claude/ .claude/ .github/ 2>/dev/null | grep -v '_examples/' | grep -v '_template' | grep -v 'claude/bootstrap/PROMPT' | grep -v 'claude/docs/' | grep -v 'claude/scripts/' | grep -v 'validate.sh' || true)
if [ -z "$REMAINING" ]; then
  echo "  ✅ None — all placeholders replaced!"
else
  echo "$REMAINING" | while IFS= read -r line; do
    echo "  → $line"
  done
  echo ""
  REMAINING_COUNT=$(echo "$REMAINING" | wc -l | tr -d ' ')
  echo "  Total: $REMAINING_COUNT (these require project-specific AI analysis)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Batch population complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

