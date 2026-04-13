#!/usr/bin/env bash
# integration-test.sh — End-to-end test of install.sh (FRESH + UPGRADE)
# Run: bash claude/scripts/integration-test.sh
# Exit: 0 if all pass, 1 on failure
# Designed for CI — creates temp dirs, cleans up after itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0
CLEANUP_DIRS=()

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

cleanup() {
  for d in "${CLEANUP_DIRS[@]}"; do
    rm -rf "$d" 2>/dev/null || true
  done
}
trap cleanup EXIT

make_test_repo() {
  local dir
  dir=$(mktemp -d)
  CLEANUP_DIRS+=("$dir")
  git init "$dir" >/dev/null 2>&1
  # Git needs at least one commit for rev-parse to work
  git -C "$dir" commit --allow-empty -m "init" >/dev/null 2>&1
  echo "$dir"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Integration Test — install.sh"
echo "  Source: $SCRIPT_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Test 1: --check mode ──────────────────────────────────────────
echo ""
echo "Test 1: --check mode"
if bash "$SCRIPT_DIR/install.sh" --check >/dev/null 2>&1; then
  pass "--check exits 0"
else
  fail "--check exits non-zero"
fi

# ── Test 2: FRESH install ─────────────────────────────────────────
echo ""
echo "Test 2: FRESH install"
FRESH_DIR=$(make_test_repo)

if bash "$SCRIPT_DIR/install.sh" "$FRESH_DIR" >/dev/null 2>&1; then
  pass "install.sh FRESH exits 0"
else
  fail "install.sh FRESH exits non-zero"
fi

# Verify key files exist
for f in CLAUDE.md .claudeignore .claude/settings.json claude/scripts/discover.sh; do
  if [ -e "$FRESH_DIR/$f" ]; then
    pass "FRESH: $f exists"
  else
    fail "FRESH: $f missing"
  fi
done

# Verify scripts are executable
if [ -x "$FRESH_DIR/claude/scripts/discover.sh" ]; then
  pass "FRESH: scripts are executable"
else
  fail "FRESH: scripts not executable"
fi

# Verify hooks are executable
if [ -x "$FRESH_DIR/.claude/hooks/session-start.sh" ]; then
  pass "FRESH: hooks are executable"
else
  fail "FRESH: hooks not executable"
fi

# Verify _platform.sh exists and is sourceable
if bash -c "source '$FRESH_DIR/claude/scripts/_platform.sh' && echo \$BRAIN_PLATFORM" >/dev/null 2>&1; then
  pass "FRESH: _platform.sh sourceable"
else
  fail "FRESH: _platform.sh not sourceable"
fi

# Verify file count is reasonable (should be 80+)
FILE_COUNT=$(find "$FRESH_DIR/claude" "$FRESH_DIR/.claude" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$FILE_COUNT" -ge 50 ]; then
  pass "FRESH: $FILE_COUNT files installed (≥50)"
else
  fail "FRESH: only $FILE_COUNT files (expected ≥50)"
fi

# ── Test 3: UPGRADE (re-run on same dir) ──────────────────────────
echo ""
echo "Test 3: UPGRADE install (idempotent)"

# Add a user file that must survive upgrade
echo "# My lessons" > "$FRESH_DIR/claude/tasks/lessons.md"
echo "# My architecture" > "$FRESH_DIR/claude/architecture.md"
BEFORE_LESSONS=$(cat "$FRESH_DIR/claude/tasks/lessons.md")

if bash "$SCRIPT_DIR/install.sh" "$FRESH_DIR" >/dev/null 2>&1; then
  pass "install.sh UPGRADE exits 0"
else
  fail "install.sh UPGRADE exits non-zero"
fi

# Verify user files are PRESERVED (never overwritten)
AFTER_LESSONS=$(cat "$FRESH_DIR/claude/tasks/lessons.md")
if [ "$BEFORE_LESSONS" = "$AFTER_LESSONS" ]; then
  pass "UPGRADE: lessons.md preserved (not overwritten)"
else
  fail "UPGRADE: lessons.md was overwritten!"
fi

if [ -f "$FRESH_DIR/claude/architecture.md" ]; then
  pass "UPGRADE: architecture.md preserved"
else
  fail "UPGRADE: architecture.md deleted!"
fi

# Verify backup was created
if [ -f "$FRESH_DIR/claude/tasks/.pre-upgrade-backup.tar.gz" ]; then
  pass "UPGRADE: backup created"
else
  fail "UPGRADE: no backup file"
fi

# ── Test 4: Self-bootstrap guard ──────────────────────────────────
echo ""
echo "Test 4: Self-bootstrap guard"
if bash "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR" >/dev/null 2>&1; then
  fail "Self-install should be blocked but succeeded"
else
  pass "Self-install correctly blocked"
fi

# ── Test 5: Non-git-root guard ────────────────────────────────────
echo ""
echo "Test 5: Non-git-root guard"
SUBDIR="$FRESH_DIR/some/subdir"
mkdir -p "$SUBDIR"
if bash "$SCRIPT_DIR/install.sh" "$SUBDIR" >/dev/null 2>&1; then
  fail "Subdir install should be blocked but succeeded"
else
  pass "Subdir install correctly blocked"
fi

# ── Test 6: Non-existent target guard ─────────────────────────────
echo ""
echo "Test 6: Non-existent target guard"
if bash "$SCRIPT_DIR/install.sh" "/tmp/does-not-exist-brain-$$" >/dev/null 2>&1; then
  fail "Non-existent target should be blocked but succeeded"
else
  pass "Non-existent target correctly blocked"
fi

# ── Summary ────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: ✅ $PASS passed  ❌ $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ "$FAIL" -eq 0 ] || exit 1
