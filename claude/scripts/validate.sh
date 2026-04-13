#!/bin/bash
# validate.sh — Template consistency and completeness validator
# Run: bash claude/scripts/validate.sh
# Exit: 0 if all checks pass, 1 if any fail

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ validate.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -euo pipefail

PASS=0
FAIL=0
WARN=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN + 1)); }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ᗺB  Brain Bootstrap  ·  Validator  ·  by y-abs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 0. Template integrity (only when running on the template repo itself)
IS_TEMPLATE=false
if [ -f "claude/bootstrap/PROMPT.md" ] && [ -f "claude/bootstrap/REFERENCE.md" ] && [ -d "claude/_examples" ] && [ -f "claude/scripts/validate.sh" ] && [ -f "claude/docs/DETAILED_GUIDE.md" ]; then
  _HAS_MANIFEST=false
  for _m in package.json Cargo.toml go.mod pyproject.toml pom.xml build.gradle pubspec.yaml mix.exs setup.py requirements.txt composer.json Gemfile CMakeLists.txt Makefile deno.json; do
    [ -f "$_m" ] && _HAS_MANIFEST=true && break
  done
  if ! $_HAS_MANIFEST; then IS_TEMPLATE=true; fi
fi

if $IS_TEMPLATE; then
  # ══════════════════════════════════════════════════════════════════
  # TEMPLATE-REPO-ONLY CHECKS — These run ONLY in the Brain Bootstrap
  # template repository itself (no package.json / manifest file).
  #
  # ⚠️ END-USER REPOS NEVER REACH THIS BLOCK.
  # Files like .github/ISSUE_TEMPLATE/, .github/workflows/, CONTRIBUTING.md,
  # and .shellcheckrc are NOT installed by install.sh into user projects.
  # Do NOT check for them outside this IS_TEMPLATE guard.
  # ══════════════════════════════════════════════════════════════════
  echo ""
  echo "🛡️  Template integrity (self-bootstrap protection)..."
  if grep -q '{{PROJECT_NAME}}' CLAUDE.md 2>/dev/null; then
    pass "CLAUDE.md {{PROJECT_NAME}} placeholder intact"
  else
    fail "CLAUDE.md missing {{PROJECT_NAME}} — template was corrupted by self-bootstrap! Restore: git checkout -- CLAUDE.md"
  fi
  _PH_COUNT=$(grep -rEc '\{\{[A-Z_]+\}\}' CLAUDE.md claude/ .claude/ .github/ 2>/dev/null | awk -F: '{s+=$2} END {print s+0}' || echo 0)
  if [ "$_PH_COUNT" -ge 50 ]; then
    pass "Template has $_PH_COUNT placeholders (healthy)"
  else
    fail "Template only has $_PH_COUNT placeholders (expected 90+) — likely corrupted"
  fi
  if grep -q 'IS_TEMPLATE_REPO' claude/scripts/populate-templates.sh 2>/dev/null; then
    pass "populate-templates.sh has self-bootstrap guard"
  else
    fail "populate-templates.sh missing self-bootstrap guard"
  fi

  # Community files — TEMPLATE REPO ONLY (install.sh does NOT copy these to user repos)
  echo ""
  echo "🤝 Community files (template repo only — never installed to user projects)..."
  COMMUNITY_FILES=(
    "CONTRIBUTING.md"
    ".github/PULL_REQUEST_TEMPLATE.md"
    ".github/ISSUE_TEMPLATE/bug-report.yml"
    ".github/ISSUE_TEMPLATE/feature-request.yml"
    ".github/ISSUE_TEMPLATE/config.yml"
    ".github/workflows/ci.yml"
    ".shellcheckrc"
  )
  for f in "${COMMUNITY_FILES[@]}"; do
    if [ -f "$f" ]; then pass "$f"; else fail "MISSING: $f"; fi
  done

  # Bootstrap scaffolding (only in template repo — deleted post-bootstrap in user repos)
  echo ""
  echo "🧠 Bootstrap scaffolding..."
  BOOTSTRAP_FILES=(
    "claude/bootstrap/PROMPT.md"
    "claude/bootstrap/REFERENCE.md"
    "claude/bootstrap/UPGRADE_GUIDE.md"
  )
  for f in "${BOOTSTRAP_FILES[@]}"; do
    if [ -f "$f" ]; then pass "$f"; else fail "MISSING: $f"; fi
  done
fi

# 1. Required files exist
echo ""
echo "📁 Required files..."
REQUIRED_FILES=(
  "CLAUDE.md"
  "CLAUDE.local.md.example"
  ".claudeignore"
  ".mcp.json"
  "claude/README.md"
  "claude/architecture.md"
  "claude/rules.md"
  "claude/terminal-safety.md"
  "claude/build.md"
  "claude/templates.md"
  "claude/cve-policy.md"
  ".claude/settings.json"
  ".claude/settings.local.json.example"
  "claude/tasks/lessons.md"
  "claude/tasks/todo.md"
  "claude/tasks/CLAUDE_ERRORS.md"
  "claude/scripts/canary-check.sh"
  "claude/scripts/toggle-claude-mem.sh"
  "claude/scripts/phase2-verify.sh"
  "claude/scripts/tdd-loop-check.sh"
  "claude/decisions.md"
  "claude/plugins.md"
  "claude/docs/DETAILED_GUIDE.md"
)
for f in "${REQUIRED_FILES[@]}"; do
  if [ -f "$f" ]; then pass "$f"; else fail "MISSING: $f"; fi
done

# 2. Hook scripts exist and are executable
echo ""
echo "🪝 Hook scripts..."
HOOKS=(
  ".claude/hooks/session-start.sh"
  ".claude/hooks/on-compact.sh"
  ".claude/hooks/pre-compact.sh"
  ".claude/hooks/config-protection.sh"
  ".claude/hooks/terminal-safety-gate.sh"
  ".claude/hooks/pre-commit-quality.sh"
  ".claude/hooks/suggest-compact.sh"
  ".claude/hooks/identity-reinjection.sh"
  ".claude/hooks/subagent-stop.sh"
  ".claude/hooks/stop-batch-format.sh"
  ".claude/hooks/exit-nudge.sh"
  ".claude/hooks/edit-accumulator.sh"
  ".claude/hooks/permission-denied.sh"
  ".claude/hooks/warn-missing-test.sh"
)
for h in "${HOOKS[@]}"; do
  if [ -f "$h" ]; then
    if [ -x "$h" ]; then pass "$h (executable)"; else fail "$h (not executable — run: chmod +x $h)"; fi
  else
    fail "MISSING: $h"
  fi
done

# 3. settings.json is valid JSON
echo ""
echo "⚙️  Settings..."
if command -v jq &> /dev/null; then
  if jq . .claude/settings.json > /dev/null 2>&1; then
    pass "settings.json is valid JSON"
  else
    fail "settings.json is INVALID JSON"
  fi
else
  warn "jq not installed — cannot validate JSON"
fi

# 4. Commands exist
echo ""
echo "📝 Slash commands..."
COMMANDS=(
  plan review mr ticket build test lint debug
  serve migrate db context docker deps diff git
  cleanup maintain checkpoint resume bootstrap
  mcp squad-plan research update-code-index health
)
for cmd in "${COMMANDS[@]}"; do
  if [ -f ".claude/commands/$cmd.md" ]; then pass "/cmd: $cmd"; else fail "MISSING command: $cmd.md"; fi
done

# 5. Agents exist
echo ""
echo "🤖 Subagents..."
for agent in research reviewer plan-challenger session-reviewer security-auditor; do
  if [ -f ".claude/agents/$agent.md" ]; then pass "agent: $agent"; else fail "MISSING agent: $agent.md"; fi
done

# 6. Skills exist
echo ""
echo "🧠 Skills..."
for skill in tdd root-cause-trace changelog careful cross-layer-check; do
  if [ -f ".claude/skills/$skill/SKILL.md" ]; then pass "skill: $skill"; else fail "MISSING skill: $skill/SKILL.md"; fi
done

# 7. Rules exist
echo ""
echo "📐 Path-scoped rules..."
for rule in terminal-safety self-maintenance _template-domain-rule quality-gates typescript python nodejs-backend react memory domain-learning practice-capture agents; do
  if [ -f ".claude/rules/$rule.md" ]; then pass "rule: $rule"; else fail "MISSING rule: $rule.md"; fi
done

# 8. GitHub Copilot files
echo ""
echo "🐙 GitHub Copilot..."
COPILOT_FILES=(
  ".github/copilot-instructions.md"
  ".github/instructions/general.instructions.md"
  ".github/instructions/testing.instructions.md"
  ".github/instructions/_template.instructions.md"
  ".github/prompts/generate-tests.prompt.md"
  ".github/prompts/review-rules.prompt.md"
  ".github/prompts/_template.prompt.md"
)
for f in "${COPILOT_FILES[@]}"; do
  if [ -f "$f" ]; then pass "$f"; else fail "MISSING: $f"; fi
done

# 8b. Scripts are executable
echo ""
echo "🔧 Scripts..."
for script in claude/scripts/canary-check.sh claude/scripts/toggle-claude-mem.sh claude/scripts/discover.sh claude/scripts/populate-templates.sh claude/scripts/post-bootstrap-validate.sh claude/scripts/generate-service-claudes.sh claude/scripts/generate-copilot-docs.sh claude/scripts/phase2-verify.sh claude/scripts/setup-plugins.sh claude/scripts/check-creative-work.sh claude/scripts/validate.sh claude/scripts/tdd-loop-check.sh; do
  if [ -f "$script" ]; then
    if [ -x "$script" ]; then pass "$script (executable)"; else fail "$script exists but NOT executable — run: chmod +x $script"; fi
  else
    fail "MISSING: $script"
  fi
done

# 9. Domain-free check (only in template-added files, not the entire repo)
# Skip if the template has been bootstrapped — i.e., {{PROJECT_NAME}} in CLAUDE.md is gone.
# Previous bug: checking for ANY remaining placeholder caused false positives during bootstrap,
# because command files still have {{BUILD_CMD_SINGLE}} etc. while CLAUDE.md is already personalized.
# Fix: use {{PROJECT_NAME}} in CLAUDE.md as the single personalization indicator.
echo ""
if [ -f "CLAUDE.md" ] && ! grep -q '{{PROJECT_NAME}}' CLAUDE.md 2>/dev/null; then
  echo "🔒 Domain-free verification... SKIPPED (template is bootstrapped — {{PROJECT_NAME}} replaced)"
  pass "Bootstrapped instance detected — domain-free check not applicable"
else
  echo "🔒 Domain-free verification (template files only)..."
  # Guard: template must not contain project-specific references.
  # These are generic examples — the bootstrap replaces them with real project terms.
  # If a contributor accidentally runs bootstrap on the template itself,
  # project-specific data leaks into template files. This check catches that.
  FORBIDDEN_TERMS='my-company|my-project|example\.com|TODO_REPLACE'
  TEMPLATE_PATHS="CLAUDE.md CLAUDE.local.md.example .claudeignore claude/ .claude/ .github/"
  read -ra _tpath_arr <<< "$TEMPLATE_PATHS"
  HITS=$(grep -rniE "$FORBIDDEN_TERMS" "${_tpath_arr[@]}" --include='*.md' --include='*.json' --include='*.sh' 2>/dev/null | grep -v '.git/' | grep -v 'validate.sh' | grep -v '_template' | grep -v '_examples' | grep -v 'claude/tasks/' | grep -v 'claude/docs/' | grep -v 'CONTRIBUTING' || true)
  if [ -z "$HITS" ]; then
    pass "No forbidden domain references found"
  else
    fail "Forbidden domain references found:"
    echo "$HITS" | head -10
  fi
fi

# 10. CLAUDE.md line count
echo ""
echo "📏 Size checks..."
if [ -f CLAUDE.md ]; then
  CLAUDE_LINES=$(wc -l < CLAUDE.md)
  if [ "$CLAUDE_LINES" -le 200 ]; then
    pass "CLAUDE.md: $CLAUDE_LINES lines (≤200)"
  else
    warn "CLAUDE.md: $CLAUDE_LINES lines (>200 — consider trimming)"
  fi
else
  fail "CLAUDE.md missing — cannot check size"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: ✅ $PASS passed | ❌ $FAIL failed | ⚠️  $WARN warnings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FAIL" -gt 0 ]; then exit 1; else exit 0; fi

