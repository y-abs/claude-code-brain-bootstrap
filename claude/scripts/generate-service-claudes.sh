#!/bin/bash
# generate-service-claudes.sh — Generate CLAUDE.md stubs for each service in a monorepo
# Usage: bash claude/scripts/generate-service-claudes.sh [root_dir]
# Scans common monorepo service directories and creates minimal CLAUDE.md stubs.
# Supports 2-level nesting: if a child has no manifest, its grandchildren are scanned.

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ generate-service-claudes.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -euo pipefail

ROOT="${1:-.}"
CREATED=0
SKIPPED=0

echo "🔍 Scanning for monorepo service directories..."

# Common monorepo container directories
SERVICE_PARENTS=(
  "core" "services" "apps" "packages" "libs" "lib"
  "modules" "plugins" "components" "internal" "external"
  "backend" "frontend" "web" "api" "workers" "lambdas"
  "functions" "microservices" "crates" "cmd" "pkg"
)

# Check if a directory has a project manifest (package.json, Cargo.toml, etc.)
has_manifest() {
  local dir="$1"
  [ -f "$dir/package.json" ] || [ -f "$dir/Cargo.toml" ] || [ -f "$dir/go.mod" ] || \
  [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ] || \
  [ -f "$dir/setup.py" ] || [ -f "$dir/pyproject.toml" ]
}

# Create a CLAUDE.md stub for a service directory
create_stub() {
  local service_dir="${1%/}"
  local SERVICE_NAME
  SERVICE_NAME=$(basename "$service_dir")

  # Skip hidden dirs, node_modules, dist, build artifacts
  case "$SERVICE_NAME" in
    .*|node_modules|dist|build|target|__pycache__) return ;;
  esac

  local CLAUDE_FILE="$service_dir/CLAUDE.md"

  # Never overwrite existing CLAUDE.md
  if [ -f "$CLAUDE_FILE" ]; then
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  # Detect stack from manifest files
  local STACK="unknown"
  local TEST_CMD=""
  local BUILD_CMD=""
  local DESCRIPTION=""

  if [ -f "$service_dir/package.json" ]; then
    STACK="Node.js"
    if command -v jq &>/dev/null; then
      DESCRIPTION=$(jq -r '.description // empty' "$service_dir/package.json" 2>/dev/null || true)
      local HAS_TEST
      HAS_TEST=$(jq -r '.scripts.test // empty' "$service_dir/package.json" 2>/dev/null || true)
      local HAS_BUILD
      HAS_BUILD=$(jq -r '.scripts.build // empty' "$service_dir/package.json" 2>/dev/null || true)
      [ -n "$HAS_TEST" ] && TEST_CMD="pnpm --filter $SERVICE_NAME test"
      [ -n "$HAS_BUILD" ] && BUILD_CMD="pnpm --filter $SERVICE_NAME build"
    fi
  elif [ -f "$service_dir/Cargo.toml" ]; then
    STACK="Rust"
    TEST_CMD="cargo test -p $SERVICE_NAME"
    BUILD_CMD="cargo build -p $SERVICE_NAME"
  elif [ -f "$service_dir/go.mod" ]; then
    STACK="Go"
    TEST_CMD="go test ./$SERVICE_NAME/..."
    BUILD_CMD="go build ./$SERVICE_NAME/..."
  elif [ -f "$service_dir/pom.xml" ] || [ -f "$service_dir/build.gradle" ] || [ -f "$service_dir/build.gradle.kts" ]; then
    STACK="Java/Kotlin"
    TEST_CMD="mvn test -pl $SERVICE_NAME"
    BUILD_CMD="mvn package -pl $SERVICE_NAME"
  elif [ -f "$service_dir/setup.py" ] || [ -f "$service_dir/pyproject.toml" ]; then
    STACK="Python"
    TEST_CMD="python3 -u -m pytest $SERVICE_NAME"
    BUILD_CMD=""
  fi

  # Fallback description from directory name
  if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$SERVICE_NAME" | tr '-' ' ' | tr '_' ' ')
  fi

  # Detect key directories
  local KEY_FILES=""
  [ -d "${service_dir}/src" ] && KEY_FILES="$KEY_FILES\n- \`src/\` — source code"
  [ -d "${service_dir}/test" ] || [ -d "${service_dir}/tests" ] || [ -d "${service_dir}/__tests__" ] && KEY_FILES="$KEY_FILES\n- \`test/\` — tests"
  [ -f "${service_dir}/Dockerfile" ] && KEY_FILES="$KEY_FILES\n- \`Dockerfile\` — container build"
  [ -d "${service_dir}/migrations" ] && KEY_FILES="$KEY_FILES\n- \`migrations/\` — database migrations"

  # Build the CLAUDE.md content
  local CONTENT="# $SERVICE_NAME\n> $DESCRIPTION\n\n## Stack\n$STACK\n\n## Key files"
  if [ -n "$KEY_FILES" ]; then
    CONTENT="$CONTENT$KEY_FILES"
  else
    CONTENT="$CONTENT\n- \`.\` — service root"
  fi

  CONTENT="$CONTENT\n\n## Commands"
  [ -n "$TEST_CMD" ] && CONTENT="$CONTENT\n- Test: \`$TEST_CMD\`"
  [ -n "$BUILD_CMD" ] && CONTENT="$CONTENT\n- Build: \`$BUILD_CMD\`"
  if [ -z "$TEST_CMD" ] && [ -z "$BUILD_CMD" ]; then
    CONTENT="$CONTENT\n<!-- Add test and build commands as you discover them -->"
  fi

  # Write the stub (printf '%b' processes our \n markers without interpreting escapes in $DESCRIPTION)
  printf '%b\n' "$CONTENT" > "$CLAUDE_FILE"
  CREATED=$((CREATED + 1))
  echo "  ✅ Created: $CLAUDE_FILE"
}

for parent in "${SERVICE_PARENTS[@]}"; do
  PARENT_DIR="$ROOT/$parent"
  [ -d "$PARENT_DIR" ] || continue

  for service_dir in "$PARENT_DIR"/*/; do
    [ -d "$service_dir" ] || continue

    if has_manifest "$service_dir"; then
      # Direct child is a service — create stub
      create_stub "$service_dir"
    else
      # Direct child has no manifest — likely a container dir (e.g., core/packages/, components/external/)
      # Scan one level deeper for actual services
      for nested_dir in "$service_dir"*/; do
        [ -d "$nested_dir" ] || continue
        create_stub "$nested_dir"
      done
    fi
  done
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: $CREATED created, $SKIPPED skipped (already exist)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

