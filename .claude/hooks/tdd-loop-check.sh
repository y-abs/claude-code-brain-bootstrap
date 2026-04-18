#!/bin/bash
# TDD Loop Check — Claude Code Stop hook
#
# Runs after each Claude response. If tests/lint/typecheck fail, exit 2
# feeds the failures back to Claude and the loop continues automatically.
# Exit 0 when all green — Claude stops, work is done.
#
# Flow:
#   1. User asks Claude to implement something
#   2. Claude writes tests + implementation
#   3. Stop hook runs this script
#   4a. All green (exit 0) → Done!
#   4b. Failures (exit 2) → stderr fed back to Claude → loop continues
#   5. Claude sees failures, fixes, Stop hook runs again → repeat until green

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ tdd-loop-check.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

# ─── Activation guard — only run when source code was edited this session ─────
# TDD_FLAG is set by edit-accumulator.sh when *.ts/*.js/*.py/etc source files are written.
# It is NOT deleted by stop-batch-format.sh (which only removes .claude-edited-files-*).
# The flag is session-scoped: a new session starts clean, loop can't bleed across sessions.
#
# WHY this replaces the old bootstrap guard approach:
#
# Old approach 1 — checked "claude/bootstrap/PROMPT.md":
#   BROKEN: bootstrap cleanup (rm -rf claude/bootstrap/) runs in the SAME turn as the
#   final report. When that turn ends, Stop fires with no guard. TDD runs on full suite.
#
# Old approach 2 — also checked "claude/tasks/.bootstrap-progress.txt":
#   CRITICALLY BROKEN: .bootstrap-progress.txt is NEVER deleted after bootstrap. The guard
#   permanently disables TDD for ALL bootstrapped projects. Zero TDD utility ever.
#
# This approach: TDD only activates when the user actually writes source code. Bootstrap
# only writes .md/.json config files → no TDD flag → loop correctly skips.
MAX_ITERATIONS=25
ITERATION_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.tdd-iteration-count"
TDD_FLAG="${CLAUDE_PROJECT_DIR:-.}/claude/tasks/.tdd-source-edited-${CLAUDE_SESSION_ID:-default}"
mkdir -p "${CLAUDE_PROJECT_DIR:-.}/.claude"

if [ ! -f "$TDD_FLAG" ] && [ ! -f "$ITERATION_FILE" ]; then
  exit 0  # No source code written this session — nothing to test
fi

# ─── Track iteration count ───

if [ -f "$ITERATION_FILE" ]; then
  count=$(cat "$ITERATION_FILE")
  count=$((count + 1))
else
  count=1
fi
echo "$count" > "$ITERATION_FILE"

# ─── Safety: stop after max iterations ───

if [ "$count" -ge "$MAX_ITERATIONS" ]; then
  rm -f "$ITERATION_FILE" "$TDD_FLAG"
  echo "TDD loop reached max iterations ($MAX_ITERATIONS). Stopping." >&2
  echo "Please review failures manually and break the cycle." >&2
  exit 0
fi

# ─── Skip if no test files exist yet ───

if ! find . \( -name '*.test.*' -o -name '*.spec.*' -o -name 'test_*.py' -o -name '*_test.py' \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/vendor/*' -not -path '*/dist/*' -not -path '*/build/*' \
    -not -path '*/.next/*' -not -path '*/target/*' -not -path '*/__pycache__/*' \
    2>/dev/null | head -1 | grep -q .; then
  rm -f "$ITERATION_FILE" "$TDD_FLAG"
  exit 0
fi

# ─── Detect project type and run tests ───

if [ -f 'package.json' ]; then
  # ── JavaScript / TypeScript project ──

  # Skip if dependencies not installed — can't test without node_modules
  if [ ! -d 'node_modules' ]; then
    rm -f "$ITERATION_FILE" "$TDD_FLAG"
    exit 0
  fi

  TEST_CMD='{{TEST_CMD_PRIMARY}}'
  # Fallback detection if placeholder not replaced by bootstrap
  if [ "$TEST_CMD" = '{{TEST_CMD_PRIMARY}}' ]; then
    if grep -q '"vitest"' package.json 2>/dev/null; then
      TEST_CMD='npx vitest run'
    elif grep -q '"jest"' package.json 2>/dev/null; then
      TEST_CMD='npx jest --no-coverage'
    else
      TEST_CMD='npm test'
    fi
  fi

  # ── Nx monorepo override: run only AFFECTED tests, not the full suite ──
  # `pnpm nx run-many --target=test --all` = ALL services (minutes, requires full infra).
  # `pnpm nx affected --target=test` = only services changed since last commit (~seconds).
  # --passWithNoProjects: exit 0 if nothing affected (TDD complete, no failures to report).
  # Lint + tsc skipped for Nx: stop-batch-format.sh handles Biome; per-service tsconfig.json
  # means there is no root tsconfig.json to check from the repo root.
  if [ -f 'nx.json' ]; then
    NX_PM="${TEST_CMD%% *}"  # extract pm prefix: pnpm / npm / yarn / bun
    [[ "$NX_PM" =~ ^(pnpm|npm|yarn|bun)$ ]] || NX_PM='pnpm'
    TEST_OUTPUT=$("$NX_PM" nx affected --target=test --base=HEAD --passWithNoProjects 2>&1) || {
      echo "ITERATION $count/$MAX_ITERATIONS — Tests failing (nx affected):" >&2
      echo "$TEST_OUTPUT" | tail -40 >&2
      echo "" >&2
      echo "Fix the failing tests and try again." >&2
      exit 2
    }
  else
    TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1) || {
      echo "ITERATION $count/$MAX_ITERATIONS — Tests failing:" >&2
      echo "$TEST_OUTPUT" | tail -40 >&2
      echo "" >&2
      echo "Fix the failing tests and try again." >&2
      exit 2
    }

    # Lint (non-Nx projects only — stop-batch-format.sh covers Biome for Nx)
    LINT_CMD='{{LINT_CHECK_PRIMARY}}'
    if [ "$LINT_CMD" = '{{LINT_CHECK_PRIMARY}}' ] && grep -q '"lint"' package.json 2>/dev/null; then
      LINT_CMD='npm run lint'
    fi
    if [ "$LINT_CMD" != '{{LINT_CHECK_PRIMARY}}' ] && [ -n "$LINT_CMD" ]; then
      LINT_OUTPUT=$(eval "$LINT_CMD" 2>&1) || {
        echo "ITERATION $count/$MAX_ITERATIONS — Lint errors:" >&2
        echo "$LINT_OUTPUT" | tail -30 >&2
        exit 2
      }
    fi

    # Typecheck (TypeScript only — root tsconfig.json required, not tsconfig.base.json)
    if [ -f 'tsconfig.json' ]; then
      TYPE_OUTPUT=$(npx tsc --noEmit 2>&1) || {
        echo "ITERATION $count/$MAX_ITERATIONS — Type errors:" >&2
        echo "$TYPE_OUTPUT" | tail -30 >&2
        exit 2
      }
    fi
  fi

elif [ -f 'pyproject.toml' ] || [ -f 'setup.py' ] || [ -f 'setup.cfg' ]; then
  # ── Python project ──

  # Skip if pytest not available
  if ! command -v pytest &>/dev/null && ! python3 -c "import pytest" 2>/dev/null; then
    rm -f "$ITERATION_FILE" "$TDD_FLAG"
    exit 0
  fi

  TEST_CMD='{{TEST_CMD_PRIMARY}}'
  if [ "$TEST_CMD" = '{{TEST_CMD_PRIMARY}}' ]; then
    TEST_CMD='python3 -u -m pytest -v'
  fi

  TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1) || {
    echo "ITERATION $count/$MAX_ITERATIONS — Tests failing:" >&2
    echo "$TEST_OUTPUT" | tail -40 >&2
    exit 2
  }

  if command -v ruff &>/dev/null; then
    LINT_OUTPUT=$(ruff check . 2>&1) || {
      echo "ITERATION $count/$MAX_ITERATIONS — Lint errors:" >&2
      echo "$LINT_OUTPUT" | tail -30 >&2
      exit 2
    }
  fi

  if command -v mypy &>/dev/null; then
    TYPE_OUTPUT=$(mypy . 2>&1) || {
      echo "ITERATION $count/$MAX_ITERATIONS — Type errors:" >&2
      echo "$TYPE_OUTPUT" | tail -30 >&2
      exit 2
    }
  fi

elif [ -f 'Cargo.toml' ]; then
  # ── Rust project ──

  TEST_OUTPUT=$(cargo test 2>&1) || {
    echo "ITERATION $count/$MAX_ITERATIONS — Tests failing:" >&2
    echo "$TEST_OUTPUT" | tail -40 >&2
    exit 2
  }

elif [ -f 'go.mod' ]; then
  # ── Go project ──

  TEST_OUTPUT=$(go test ./... 2>&1) || {
    echo "ITERATION $count/$MAX_ITERATIONS — Tests failing:" >&2
    echo "$TEST_OUTPUT" | tail -40 >&2
    exit 2
  }

elif [ -f 'pubspec.yaml' ]; then
  # ── Flutter/Dart project ──

  TEST_OUTPUT=$(flutter test 2>&1) || {
    echo "ITERATION $count/$MAX_ITERATIONS — Tests failing:" >&2
    echo "$TEST_OUTPUT" | tail -40 >&2
    exit 2
  }

fi

# ─── All green — reset counter and deactivate TDD mode ───

rm -f "$ITERATION_FILE" "$TDD_FLAG"
exit 0

