#!/usr/bin/env bash
# discover.sh — Single-pass repository scanner for Claude Code bootstrap
# Replaces 15+ sequential discovery commands with 1 script execution.
# Outputs KEY=VALUE pairs to stdout — consumable by populate-templates.sh and AI.
# Usage: bash claude/scripts/discover.sh [project-dir]
# Exit: Always 0 (informational output only)

# ─── Bash 4+ required (associative arrays — declare -A) ──────────
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "❌ bash 4+ required (found: ${BASH_VERSION:-unknown})" >&2
  echo "   macOS users: brew install bash" >&2
  echo "   Then re-run: /opt/homebrew/bin/bash $0 $*" >&2
  exit 1
fi

set -o pipefail
PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR" || exit 1

emit() { echo "$1=$2"; }

echo "# ============================================="
echo "# Claude Code Bootstrap — Discovery Results"
echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "# Project: $PWD"
echo "# ============================================="
echo ""

# ─── Pre-Flight: Existing Configuration ───────────────────────────

echo "# --- Pre-Flight ---"
emit "HAS_CLAUDE_MD" "$([ -f "CLAUDE.md" ] && echo true || echo false)"
emit "HAS_DOT_CLAUDE" "$([ -d ".claude" ] && echo true || echo false)"
emit "HAS_CLAUDE_DIR" "$([ -d "claude" ] && echo true || echo false)"
emit "HAS_LESSONS_NEW" "$([ -f "claude/tasks/lessons.md" ] && echo true || echo false)"
emit "HAS_LESSONS_ROOT" "$([ -f "tasks/lessons.md" ] && echo true || echo false)"
emit "HAS_LESSONS_DOT" "$([ -f ".tasks/lessons.md" ] && echo true || echo false)"
emit "HAS_SCRIPTS_ROOT" "$([ -d "scripts" ] && [ -f "scripts/discover.sh" ] && echo true || echo false)"
emit "HAS_SCRIPTS_NEW" "$([ -d "claude/scripts" ] && echo true || echo false)"

# Mode decision
# UPGRADE only if config exists AND has been bootstrapped.
#
# PROBLEM: {{PROJECT_NAME}} in CLAUDE.md is an UNRELIABLE FRESH signal.
# When a user copies a new template over an existing bootstrapped config,
# CLAUDE.md gets the template version (with {{PROJECT_NAME}}) even though
# the prior config is intact. We need additional signals.
#
# TWO AUTHORITATIVE UPGRADE INDICATORS (neither can be faked by a template copy):
#
#   1. tasks/lessons.md or .tasks/lessons.md at the REPO ROOT
#      The template ONLY ships claude/tasks/ — a lessons.md at the root is
#      always from an existing Claude Code config, never from a template copy.
#
#   2. claude/tasks/CLAUDE_ERRORS.md WITHOUT {{PROJECT_NAME}}
#      The template always ships CLAUDE_ERRORS.md WITH {{PROJECT_NAME}}.
#      Once bootstrap runs, the placeholder is replaced → no placeholder = was bootstrapped.
#
# Priority:
#   1. Root-level lessons.md present               → UPGRADE  (old-layout or prior config)
#   2. CLAUDE_ERRORS.md bootstrapped (no {{...}})  → UPGRADE  (bootstrap ran previously)
#   3. Neither above, but {{PROJECT_NAME}} in CLAUDE.md → FRESH (genuine new install)
#   4. Neither above, no placeholder               → UPGRADE  (hand-crafted or prior bootstrap)

_has_old_layout=false
{ [ -f "tasks/lessons.md" ] || [ -f ".tasks/lessons.md" ]; } && _has_old_layout=true

_errors_bootstrapped=false
if [ -f "claude/tasks/CLAUDE_ERRORS.md" ] && ! grep -q '{{PROJECT_NAME}}' "claude/tasks/CLAUDE_ERRORS.md" 2>/dev/null; then
  _errors_bootstrapped=true
fi

if [ -f "CLAUDE.md" ] || [ -d ".claude" ] || [ -d "claude" ]; then
  if [ "$_has_old_layout" = "true" ] || [ "$_errors_bootstrapped" = "true" ]; then
    emit "MODE" "UPGRADE"
  elif [ -f "CLAUDE.md" ] && grep -q '{{PROJECT_NAME}}' CLAUDE.md 2>/dev/null; then
    emit "MODE" "FRESH"
  else
    emit "MODE" "UPGRADE"
  fi
else
  emit "MODE" "FRESH"
fi

# Directory structure normalization detection
# Check both tasks/ and .tasks/ (some setups use dot-prefixed)
if { [ -f "tasks/lessons.md" ] || [ -f ".tasks/lessons.md" ]; } && [ ! -f "claude/tasks/lessons.md" ]; then
  emit "LAYOUT_MIGRATION_NEEDED" "true"
elif [ -f ".tasks/lessons.md" ] && [ -f "claude/tasks/lessons.md" ]; then
  # claude/tasks/ exists but .tasks/ has separate real data that should be merged
  emit "LAYOUT_MIGRATION_NEEDED" "merge"
else
  emit "LAYOUT_MIGRATION_NEEDED" "false"
fi

# ─── Self-Bootstrap Protection ─────────────────────────────────────
# Detect if this IS the template repo itself (not a copy inside a real project).
# Heuristic: all 4 unique template markers exist AND no project manifest file exists.
# A real project always has at least one manifest (package.json, Cargo.toml, etc.).
PROJECT_MANIFESTS=(
  package.json Cargo.toml go.mod go.sum pyproject.toml pom.xml
  build.gradle build.gradle.kts pubspec.yaml mix.exs setup.py
  requirements.txt composer.json Gemfile CMakeLists.txt Makefile makefile
  GNUmakefile deno.json deno.jsonc stack.yaml build.sbt deps.edn
  project.clj renv.lock uv.lock pdm.lock poetry.lock Pipfile.lock
  Package.swift dune-project cpanfile Makefile.PL
)
IS_TEMPLATE_REPO=false
if [ -f "bootstrap/PROMPT.md" ] && [ -d "claude/_examples" ] && [ -f "bootstrap/validate.sh" ] && [ -f "claude/docs/DETAILED_GUIDE.md" ]; then
  HAS_ANY_MANIFEST=false
  for manifest in "${PROJECT_MANIFESTS[@]}"; do
    if [ -f "$manifest" ]; then
      HAS_ANY_MANIFEST=true
      break
    fi
  done
  if ! $HAS_ANY_MANIFEST; then
    IS_TEMPLATE_REPO=true
  fi
fi
emit "IS_TEMPLATE_REPO" "$IS_TEMPLATE_REPO"

echo ""

# ─── Project Identity ─────────────────────────────────────────────

echo "# --- Identity ---"
# Project name: from package.json > Cargo.toml > go.mod > pyproject.toml > directory name
PROJECT_NAME=""
if [ -f "package.json" ]; then
  PROJECT_NAME=$(jq -r '.name // empty' package.json 2>/dev/null || true)
  PROJECT_DESC=$(jq -r '.description // empty' package.json 2>/dev/null || true)
fi
if [ -z "$PROJECT_NAME" ] && [ -f "Cargo.toml" ]; then
  PROJECT_NAME=$(grep -m1 '^name' Cargo.toml 2>/dev/null | sed 's/name[[:space:]]*=[[:space:]]*"\(.*\)"/\1/' || true)
fi
if [ -z "$PROJECT_NAME" ] && [ -f "go.mod" ]; then
  PROJECT_NAME=$(head -1 go.mod 2>/dev/null | awk '{print $2}' | xargs basename 2>/dev/null || true)
fi
if [ -z "$PROJECT_NAME" ] && [ -f "pyproject.toml" ]; then
  PROJECT_NAME=$(grep -m1 '^name' pyproject.toml 2>/dev/null | sed 's/^name[[:space:]]*=[[:space:]]*"\(.*\)"/\1/' || true)
fi
[ -z "$PROJECT_NAME" ] && PROJECT_NAME=$(basename "$PWD")
emit "PROJECT_NAME" "$PROJECT_NAME"

# FIX 9: Extract PROJECT_DESCRIPTION from package.json 'description' field or README.md first paragraph.
PROJECT_DESC=""
if [ -f "package.json" ]; then
  PROJECT_DESC=$(jq -r '.description // empty' package.json 2>/dev/null | head -1 || true)
fi
if [ -z "$PROJECT_DESC" ] && [ -f "README.md" ]; then
  # First non-empty line after the H1 title that isn't a badge/shield or HTML comment
  PROJECT_DESC=$(awk 'NR>1 && /^[A-Z>a-z]/ && !/^\[!/ && !/^<!--/ && !/^>/ { print; exit }' README.md 2>/dev/null | head -c 200 || true)
fi
emit "PROJECT_DESCRIPTION" "${PROJECT_DESC:-}"

echo ""

# ─── Languages ────────────────────────────────────────────────────

echo "# --- Languages ---"
# Single find pass for ALL extensions — source code + infra/config files
# Exclusions: build artifacts, dependency dirs, virtual envs, generated files
FIND_EXCL='-not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/vendor/*" -not -path "*/target/*" -not -path "*/__pycache__/*" -not -path "*/.venv/*" -not -path "*/venv/*" -not -path "*/site-packages/*" -not -path "*/.next/*" -not -path "*/.nuxt/*" -not -path "*/coverage/*" -not -path "*/__snapshots__/*" -not -path "*/.cache/*" -not -path "*/generated/*"'

# Source code languages
# Includes: all major languages + C/C++ headers + SFC frameworks + common data/schema types
LANG_COUNTS=$(eval "find . -type f \( \
  -name '*.ts' -o -name '*.tsx' -o -name '*.mts' -o -name '*.cts' \
  -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' \
  -o -name '*.vue' -o -name '*.svelte' -o -name '*.astro' \
  -o -name '*.py' -o -name '*.pyi' \
  -o -name '*.go' -o -name '*.rs' \
  -o -name '*.java' -o -name '*.kt' -o -name '*.kts' -o -name '*.scala' -o -name '*.groovy' \
  -o -name '*.rb' -o -name '*.php' -o -name '*.cs' \
  -o -name '*.c' -o -name '*.h' -o -name '*.cpp' -o -name '*.hpp' -o -name '*.cc' -o -name '*.hh' -o -name '*.cxx' -o -name '*.hxx' \
  -o -name '*.m' -o -name '*.mm' \
  -o -name '*.swift' -o -name '*.dart' \
  -o -name '*.sh' -o -name '*.bash' -o -name '*.zsh' \
  -o -name '*.ex' -o -name '*.exs' \
  -o -name '*.lua' -o -name '*.zig' -o -name '*.jl' -o -name '*.pl' -o -name '*.pm' \
  -o -name '*.ml' -o -name '*.fs' -o -name '*.clj' -o -name '*.r' -o -name '*.R' \
  -o -name '*.sql' -o -name '*.proto' -o -name '*.graphql' -o -name '*.gql' \
  \) $FIND_EXCL" 2>/dev/null | awk -F. '{ext=$NF; counts[ext]++} END {for(e in counts) printf "%s:%d,", e, counts[e]}' | sed 's/,$//')

# Infrastructure/config files (tracked separately — not "source code" but critical for infra repos)
INFRA_COUNTS=$(eval "find . -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.tf' -o -name '*.hcl' -o -name '*.toml' \) $FIND_EXCL -not -path '*/claude/*' -not -path '*/.claude/*'" 2>/dev/null | awk -F. '{ext=$NF; counts[ext]++} END {for(e in counts) printf "%s:%d,", e, counts[e]}' | sed 's/,$//')

emit "LANGUAGES" "$LANG_COUNTS"
emit "INFRA_FILES" "$INFRA_COUNTS"

# Normalize variant extensions for PRIMARY_LANG detection.
# Maps: .h→c, .hpp/.hh/.cc/.cxx/.hxx→cpp, .bash/.zsh→sh, .kts→kt, .pyi→py,
#        .mm→m, .mts/.cts/.mjs/.cjs→ts/js, .gql→graphql, .pm→pl, .exs→ex, etc.
# Raw LANG_COUNTS keeps per-extension detail; NORM_COUNTS merges for PRIMARY_LANG.
NORM_COUNTS=""
declare -A _NORM_MAP
for pair in $(echo "$LANG_COUNTS" | tr ',' ' '); do
  [ -z "$pair" ] && continue
  EXT="${pair%%:*}"; CNT="${pair##*:}"
  [ -z "$CNT" ] && continue
  # Map variant extension to canonical
  case "$EXT" in
    h)             CANON="c" ;;
    hpp|hh|cc|cxx|hxx) CANON="cpp" ;;
    bash|zsh)      CANON="sh" ;;
    kts)           CANON="kt" ;;
    pyi)           CANON="py" ;;
    mm)            CANON="m" ;;
    mts|cts)       CANON="ts" ;;
    mjs|cjs)       CANON="js" ;;
    gql)           CANON="graphql" ;;
    pm)            CANON="pl" ;;
    exs)           CANON="ex" ;;
    gvy)           CANON="groovy" ;;
    R)             CANON="r" ;;
    *)             CANON="$EXT" ;;
  esac
  _NORM_MAP["$CANON"]=$(( ${_NORM_MAP["$CANON"]:-0} + CNT ))
done
for key in "${!_NORM_MAP[@]}"; do
  NORM_COUNTS="${NORM_COUNTS}${key}:${_NORM_MAP[$key]},"
done
NORM_COUNTS="${NORM_COUNTS%,}"
unset _NORM_MAP

# Primary language (most source files — uses normalized counts)
PRIMARY_LANG=""
MAX_COUNT=0
for pair in $(echo "$NORM_COUNTS" | tr ',' ' '); do
  [ -z "$pair" ] && continue
  EXT="${pair%%:*}"
  CNT="${pair##*:}"
  [ -z "$CNT" ] && continue
  if [ "$CNT" -gt "$MAX_COUNT" ] 2>/dev/null; then
    MAX_COUNT="$CNT"
    PRIMARY_LANG="$EXT"
  fi
done

# FIX 1: TypeScript override — when tsconfig.json exists at root and TS files are significant,
# the project is TypeScript-first even if .js files outnumber .ts (compiled output inflates .js count)
if [ "$PRIMARY_LANG" = "js" ] && { [ -f "tsconfig.json" ] || [ -f "tsconfig.base.json" ] || [ -f "tsconfig.build.json" ]; }; then
  TS_COUNT=$(echo "$LANG_COUNTS" | tr ',' '\n' | grep '^ts:' | cut -d: -f2)
  TSX_COUNT=$(echo "$LANG_COUNTS" | tr ',' '\n' | grep '^tsx:' | cut -d: -f2)
  TS_TOTAL=$(( ${TS_COUNT:-0} + ${TSX_COUNT:-0} ))
  if [ "$TS_TOTAL" -gt 50 ]; then
    PRIMARY_LANG="ts"
  fi
fi
emit "PRIMARY_LANGUAGE" "$PRIMARY_LANG"
SECONDARY_LANGS=""
for pair in $(echo "$NORM_COUNTS" | tr ',' ' '); do
  [ -z "$pair" ] && continue
  EXT="${pair%%:*}"
  CNT="${pair##*:}"
  [ "$EXT" = "$PRIMARY_LANG" ] && continue
  [ "$CNT" -lt 5 ] 2>/dev/null && continue
  SECONDARY_LANGS="${SECONDARY_LANGS}${EXT},"
done
emit "SECONDARY_LANGUAGES" "${SECONDARY_LANGS%,}"

# Primary category: infrastructure, backend, frontend, fullstack, library
# Derived from compound signals — more accurate than file count alone
INFRA_SCORE=0; APP_SCORE=0
if [ -d "helm" ] || find . -maxdepth 3 -name 'Chart.yaml' 2>/dev/null | head -1 | grep -q '.'; then INFRA_SCORE=$((INFRA_SCORE+3)); fi
if find . -maxdepth 3 -name '*.tf' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q '.'; then INFRA_SCORE=$((INFRA_SCORE+3)); fi
if [ -f "ansible.cfg" ] || find . -maxdepth 2 -name 'playbook*.yml' 2>/dev/null | head -1 | grep -q '.'; then INFRA_SCORE=$((INFRA_SCORE+2)); fi
if [ "$PRIMARY_LANG" = "sh" ] && [ -n "$INFRA_COUNTS" ]; then INFRA_SCORE=$((INFRA_SCORE+2)); fi
if [ -f "package.json" ]; then APP_SCORE=$((APP_SCORE+3)); fi
if [ -f "pom.xml" ] || [ -f "build.gradle" ]; then APP_SCORE=$((APP_SCORE+2)); fi
if [ -f "pubspec.yaml" ]; then APP_SCORE=$((APP_SCORE+2)); fi
HAS_REACT=false
if [ -f "package.json" ] && jq -e '.dependencies.react // .devDependencies.react // empty' package.json &>/dev/null; then HAS_REACT=true; fi
PRIMARY_CATEGORY="backend"
if [ "$INFRA_SCORE" -gt "$APP_SCORE" ] 2>/dev/null; then
  PRIMARY_CATEGORY="infrastructure"
elif $HAS_REACT && [ "$APP_SCORE" -gt 0 ] 2>/dev/null; then
  # Check for backend code alongside frontend
  BE_COUNT=0
  for pair in $(echo "$LANG_COUNTS" | tr ',' ' '); do
    EXT="${pair%%:*}"; CNT="${pair##*:}"
    case "$EXT" in ts|js|py|go|rs|java|kt|dart) BE_COUNT=$((BE_COUNT + CNT)) ;; esac
  done
  [ "$BE_COUNT" -gt 50 ] 2>/dev/null && PRIMARY_CATEGORY="fullstack" || PRIMARY_CATEGORY="frontend"
elif [ -f "package.json" ] && ! jq -e '.dependencies["express"] // .dependencies["fastify"] // .dependencies["@nestjs/core"] // empty' package.json &>/dev/null && $HAS_REACT; then
  PRIMARY_CATEGORY="frontend"
fi
# Library: no main app entry, is a shared package
if [ -f "package.json" ] && jq -e '.main // .exports // empty' package.json &>/dev/null && ! [ -f "src/index.ts" ]; then PRIMARY_CATEGORY="library"; fi
emit "PRIMARY_CATEGORY" "$PRIMARY_CATEGORY"

echo ""

# ─── Package Manager ──────────────────────────────────────────────

echo "# --- Package Manager ---"
PKG_MGR="" PKG_VER="" RUNTIME="" RUNTIME_VER=""

if [ -f "pnpm-lock.yaml" ]; then
  PKG_MGR="pnpm"
  PKG_VER=$(pnpm --version 2>/dev/null || echo "9+")
elif [ -f "yarn.lock" ]; then
  PKG_MGR="yarn"
  PKG_VER=$(yarn --version 2>/dev/null || echo "1+")
elif [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
  PKG_MGR="bun"
  PKG_VER=$(bun --version 2>/dev/null || echo "1.0+")
elif [ -f "package-lock.json" ]; then
  PKG_MGR="npm"
  PKG_VER=$(npm --version 2>/dev/null || echo "10+")
elif [ -f "deno.lock" ] || [ -f "deno.json" ] || [ -f "deno.jsonc" ]; then
  PKG_MGR="deno"
  PKG_VER=$(deno --version 2>/dev/null | head -1 | awk '{print $2}' || echo "2.0+")
elif [ -f "Cargo.lock" ]; then
  PKG_MGR="cargo"
  PKG_VER=$(cargo --version 2>/dev/null | awk '{print $2}' || echo "1.75+")
elif [ -f "poetry.lock" ]; then
  PKG_MGR="poetry"
  PKG_VER=$(poetry --version 2>/dev/null | awk '{print $3}' || echo "1.8+")
elif [ -f "Pipfile.lock" ]; then
  PKG_MGR="pipenv"
  PKG_VER=$(pipenv --version 2>/dev/null | awk '{print $3}' || echo "2024+")
elif [ -f "uv.lock" ]; then
  PKG_MGR="uv"
  PKG_VER=$(uv --version 2>/dev/null | awk '{print $2}' || echo "0.4+")
elif [ -f "pdm.lock" ]; then
  PKG_MGR="pdm"
  PKG_VER=$(pdm --version 2>/dev/null | awk '{print $2}' || echo "2+")
elif [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
  PKG_MGR="pip"
  PKG_VER=$(pip --version 2>/dev/null | awk '{print $2}' || echo "24+")
elif [ -f "pyproject.toml" ]; then
  # Smart detection: check tool-specific sections before falling back to pip
  if grep -q '\[tool\.uv\]' pyproject.toml 2>/dev/null; then
    PKG_MGR="uv"; PKG_VER=$(uv --version 2>/dev/null | awk '{print $2}' || echo "0.4+")
  elif grep -q '\[tool\.pdm\]' pyproject.toml 2>/dev/null; then
    PKG_MGR="pdm"; PKG_VER=$(pdm --version 2>/dev/null | awk '{print $2}' || echo "2+")
  elif grep -q '\[tool\.hatch\]' pyproject.toml 2>/dev/null; then
    PKG_MGR="hatch"; PKG_VER=$(hatch --version 2>/dev/null | awk '{print $2}' || echo "1+")
  else
    PKG_MGR="pip"; PKG_VER=$(pip --version 2>/dev/null | awk '{print $2}' || echo "24+")
  fi
elif [ -f "go.sum" ] || [ -f "go.mod" ]; then
  PKG_MGR="go modules"
  PKG_VER=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' || echo "1.22+")
elif [ -f "Gemfile.lock" ]; then
  PKG_MGR="bundler"
  PKG_VER=$(bundler --version 2>/dev/null | awk '{print $3}' || echo "2+")
elif [ -f "pom.xml" ]; then
  PKG_MGR="maven"
  PKG_VER=$(mvn --version 2>/dev/null | head -1 | awk '{print $3}' || echo "3.9+")
elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
  PKG_MGR="gradle"
  PKG_VER=$(gradle --version 2>/dev/null | grep 'Gradle' | awk '{print $2}' || echo "8+")
elif [ -f "composer.lock" ] || [ -f "composer.json" ]; then
  PKG_MGR="composer"
  PKG_VER=$(composer --version 2>/dev/null | awk '{print $3}' || echo "2+")
elif [ -f "Package.swift" ]; then
  PKG_MGR="swift-package-manager"
  PKG_VER=$(swift --version 2>/dev/null | head -1 | awk '{print $4}' || echo "5.9+")
elif [ -f "mix.lock" ] || [ -f "mix.exs" ]; then
  PKG_MGR="mix"
  PKG_VER=$(elixir --version 2>/dev/null | tail -1 | awk '{print $2}' || echo "1.16+")
elif [ -f "pubspec.yaml" ] || [ -f "pubspec.lock" ]; then
  PKG_MGR="pub"
  PKG_VER=$(dart --version 2>/dev/null | awk '{print $4}' || echo "3.0+")
elif [ -f "build.sbt" ]; then
  PKG_MGR="sbt"
  PKG_VER=$(sbt --version 2>/dev/null | tail -1 | awk '{print $NF}' || echo "1.9+")
elif [ -f "stack.yaml" ]; then
  PKG_MGR="stack"
  PKG_VER=$(stack --version 2>/dev/null | head -1 | awk '{print $2}' || echo "2.13+")
elif find . -maxdepth 1 -name '*.cabal' 2>/dev/null | head -1 | grep -q '.'; then
  PKG_MGR="cabal"
  PKG_VER=$(cabal --version 2>/dev/null | head -1 | awk '{print $3}' || echo "3.10+")
elif [ -f "dune-project" ]; then
  PKG_MGR="dune/opam"
  PKG_VER=$(ocaml --version 2>/dev/null | awk '{print $NF}' || echo "5.1+")
elif [ -f "project.clj" ]; then
  PKG_MGR="lein"
  PKG_VER=$(lein --version 2>/dev/null | awk '{print $2}' || echo "2.10+")
elif [ -f "deps.edn" ]; then
  PKG_MGR="clojure-cli"
  PKG_VER=$(clojure --version 2>/dev/null | awk '{print $2}' || echo "1.11+")
elif [ -f "renv.lock" ]; then
  PKG_MGR="renv"
  PKG_VER=$(Rscript -e 'cat(as.character(packageVersion("renv")))' 2>/dev/null || echo "1.0+")
elif [ -f "Manifest.toml" ] || ([ -f "Project.toml" ] && grep -q 'julia' Project.toml 2>/dev/null); then
  PKG_MGR="julia-pkg"
  PKG_VER=$(julia --version 2>/dev/null | awk '{print $3}' || echo "1.10+")
elif [ -f "cpanfile" ] || [ -f "Makefile.PL" ]; then
  PKG_MGR="cpanm"
  PKG_VER=$(cpanm --version 2>/dev/null | head -1 | awk '{print $3}' || echo "1.7+")
elif [ -f "CMakeLists.txt" ] && { [ "$PRIMARY_LANG" = "c" ] || [ "$PRIMARY_LANG" = "cpp" ]; }; then
  PKG_MGR="cmake"
  PKG_VER=$(cmake --version 2>/dev/null | head -1 | awk '{print $3}' || echo "3.25+")
fi
emit "PACKAGE_MANAGER" "$PKG_MGR"
emit "PACKAGE_MANAGER_VERSION" "$PKG_VER"

# ─── Helper: pkg_cmd ──────────────────────────────────────────────
# Returns the correct command to invoke a package.json script.
# npm requires `run` for non-lifecycle scripts (`npm run build`, `npm run lint`).
# Only 4 lifecycle shortcuts work without `run`: test, start, stop, restart.
# pnpm, yarn, bun, deno all resolve scripts implicitly — no `run` needed.
pkg_cmd() {
  local script="$1"
  if [ "$PKG_MGR" = "npm" ]; then
    case "$script" in
      test|start|stop|restart) echo "npm $script" ;;
      *) echo "npm run $script" ;;
    esac
  else
    echo "$PKG_MGR $script"
  fi
}

# Runtime
case "$PRIMARY_LANG" in
  ts|tsx|js|jsx)
    RUNTIME="Node.js"
    if [ -f "package.json" ]; then
      RUNTIME_VER=$(jq -r '.engines.node // empty' package.json 2>/dev/null || true)
    fi
    [ -z "$RUNTIME_VER" ] && RUNTIME_VER=$(node --version 2>/dev/null | sed 's/v//' || echo "22+")
    ;;
  py) RUNTIME="Python"; RUNTIME_VER=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "3.11+") ;;
  go) RUNTIME="Go"; RUNTIME_VER=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' || echo "1.22+") ;;
  rs) RUNTIME="Rust"; RUNTIME_VER=$(rustc --version 2>/dev/null | awk '{print $2}' || echo "1.75+") ;;
  java|kt|scala|groovy) RUNTIME="JVM"; RUNTIME_VER=$(java --version 2>/dev/null | head -1 | awk '{print $2}' || echo "21+") ;;
  rb) RUNTIME="Ruby"; RUNTIME_VER=$(ruby --version 2>/dev/null | awk '{print $2}' || echo "3.2+") ;;
  php) RUNTIME="PHP"; RUNTIME_VER=$(php --version 2>/dev/null | head -1 | awk '{print $2}' || echo "8.2+") ;;
  cs) RUNTIME=".NET"; RUNTIME_VER=$(dotnet --version 2>/dev/null || echo "8.0+") ;;
  swift) RUNTIME="Swift"; RUNTIME_VER=$(swift --version 2>/dev/null | head -1 | awk '{print $4}' || echo "5.9+") ;;
  dart) RUNTIME="Dart"; RUNTIME_VER=$(dart --version 2>/dev/null | awk '{print $4}' || echo "3.0+") ;;
  lua) RUNTIME="Lua"; RUNTIME_VER=$(lua -v 2>/dev/null | awk '{print $2}' || echo "5.4+") ;;
  zig) RUNTIME="Zig"; RUNTIME_VER=$(zig version 2>/dev/null || echo "0.13+") ;;
  jl) RUNTIME="Julia"; RUNTIME_VER=$(julia --version 2>/dev/null | awk '{print $3}' || echo "1.10+") ;;
  pl) RUNTIME="Perl"; RUNTIME_VER=$(perl --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+' | head -1 || echo "5.36+") ;;
  m) RUNTIME="Objective-C"; RUNTIME_VER=$(clang --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "15+") ;;
  clj) RUNTIME="JVM (Clojure)"; RUNTIME_VER=$(java --version 2>/dev/null | head -1 | awk '{print $2}' || echo "21+") ;;
  ml) RUNTIME="OCaml"; RUNTIME_VER=$(ocaml --version 2>/dev/null | awk '{print $NF}' || echo "5.1+") ;;
  hs) RUNTIME="Haskell"; RUNTIME_VER=$(ghc --version 2>/dev/null | awk '{print $NF}' || echo "9.6+") ;;
  r) RUNTIME="R"; RUNTIME_VER=$(R --version 2>/dev/null | head -1 | awk '{print $3}' || echo "4.3+") ;;
  *) RUNTIME="unknown"; RUNTIME_VER="" ;;
esac
# Override for Bun/Deno (detected from pkg manager, not file extension)
if [ "$PKG_MGR" = "bun" ]; then
  RUNTIME="Bun"; RUNTIME_VER=$(bun --version 2>/dev/null || echo "1.0+")
elif [ "$PKG_MGR" = "deno" ]; then
  RUNTIME="Deno"; RUNTIME_VER=$(deno --version 2>/dev/null | head -1 | awk '{print $2}' || echo "2.0+")
elif [ "$PKG_MGR" = "mix" ]; then
  RUNTIME="Elixir"; RUNTIME_VER=$(elixir --version 2>/dev/null | head -1 | awk '{print $2}' || echo "1.16+")
elif [ "$PKG_MGR" = "pub" ]; then
  if [ -f "pubspec.yaml" ] && grep -q 'flutter:' pubspec.yaml 2>/dev/null; then
    RUNTIME="Flutter/Dart"; RUNTIME_VER=$(flutter --version 2>/dev/null | head -1 | awk '{print $2}' || dart --version 2>/dev/null | awk '{print $4}' || echo "3.0+")
  else
    RUNTIME="Dart"; RUNTIME_VER=$(dart --version 2>/dev/null | awk '{print $4}' || echo "3.0+")
  fi
elif [ "$PKG_MGR" = "swift-package-manager" ]; then
  RUNTIME="Swift"; RUNTIME_VER=$(swift --version 2>/dev/null | head -1 | awk '{print $4}' || echo "5.9+")
fi
# H1: shell+pip repos have Python as tooling runtime even if PRIMARY_LANG=sh
if [ "$RUNTIME" = "unknown" ] && [ "$PKG_MGR" = "pip" ]; then
  RUNTIME="Python (tooling)"; RUNTIME_VER=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "3.11+")
elif [ "$RUNTIME" = "unknown" ] && { [ "$PKG_MGR" = "poetry" ] || [ "$PKG_MGR" = "pdm" ] || [ "$PKG_MGR" = "uv" ] || [ "$PKG_MGR" = "pipenv" ] || [ "$PKG_MGR" = "hatch" ]; }; then
  RUNTIME="Python"; RUNTIME_VER=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "3.11+")
fi
emit "RUNTIME" "$RUNTIME"
emit "RUNTIME_VER" "$RUNTIME_VER"

echo ""

# ─── Monorepo Detection (early — needed by Test/Build sections) ────
MONOREPO="false"; MONOREPO_TOOL=""
if [ -f "pnpm-workspace.yaml" ]; then MONOREPO="true"; MONOREPO_TOOL="pnpm-workspace"; fi
if [ -f "nx.json" ]; then MONOREPO="true"; MONOREPO_TOOL="${MONOREPO_TOOL:+$MONOREPO_TOOL+}Nx"; fi
if [ -f "turbo.json" ]; then MONOREPO="true"; MONOREPO_TOOL="${MONOREPO_TOOL:+$MONOREPO_TOOL+}Turborepo"; fi
if [ -f "lerna.json" ]; then MONOREPO="true"; MONOREPO_TOOL="${MONOREPO_TOOL:+$MONOREPO_TOOL+}Lerna"; fi
if [ -f "package.json" ] && jq -e '.workspaces' package.json &>/dev/null; then
  MONOREPO="true"; MONOREPO_TOOL="${MONOREPO_TOOL:-npm-workspaces}"
fi
# Additional monorepo tools
if [ -f "rush.json" ]; then MONOREPO="true"; MONOREPO_TOOL="${MONOREPO_TOOL:+$MONOREPO_TOOL+}Rush"; fi
if [ -f "WORKSPACE" ] || [ -f "WORKSPACE.bazel" ] || [ -f "MODULE.bazel" ]; then MONOREPO="true"; MONOREPO_TOOL="${MONOREPO_TOOL:+$MONOREPO_TOOL+}Bazel"; fi
if [ -f "settings.gradle" ] || [ -f "settings.gradle.kts" ]; then MONOREPO="true"; MONOREPO_TOOL="${MONOREPO_TOOL:+$MONOREPO_TOOL+}Gradle-multimodule"; fi
if [ -f ".moon/workspace.yml" ] || [ -f "moon.yml" ]; then MONOREPO="true"; MONOREPO_TOOL="${MONOREPO_TOOL:+$MONOREPO_TOOL+}Moon"; fi
if [ -f "pants.toml" ]; then MONOREPO="true"; MONOREPO_TOOL="${MONOREPO_TOOL:+$MONOREPO_TOOL+}Pants"; fi

# ─── Formatter / Linter ───────────────────────────────────────────

echo "# --- Formatter / Linter ---"
FORMATTER="" LINTER="" LINTER_CONFIG="" FORMATTER_CMD="" LINT_CHECK="" LINT_FIX="" FORMAT_CMD="" STYLE_RULES=""

if [ -f "biome.json" ] || [ -f "biome.jsonc" ]; then
  FORMATTER="Biome"; LINTER="Biome"
  LINTER_CONFIG=""; for _f in biome.json biome.jsonc; do [ -f "$_f" ] && LINTER_CONFIG="$_f" && break; done
  FORMATTER_CMD="npx biome check --write"
  LINT_CHECK="npx biome check ."; LINT_FIX="npx biome check --write ."; FORMAT_CMD="npx biome format --write ."
  # Extract style rules from biome config
  if [ -f "$LINTER_CONFIG" ]; then
    # shellcheck disable=SC2034  # INDENT used for future STYLE_RULES expansion
    INDENT=$(jq -r '.formatter.indentStyle // "space"' "$LINTER_CONFIG" 2>/dev/null || echo "space")
    WIDTH=$(jq -r '.formatter.indentWidth // 2' "$LINTER_CONFIG" 2>/dev/null || echo 2)
    LINE=$(jq -r '.formatter.lineWidth // 80' "$LINTER_CONFIG" 2>/dev/null || echo 80)
    QUOTE=$(jq -r '.javascript.formatter.quoteStyle // "double"' "$LINTER_CONFIG" 2>/dev/null || echo "double")
    SEMI=$(jq -r '.javascript.formatter.semicolons // "always"' "$LINTER_CONFIG" 2>/dev/null || echo "always")
    QUOTE_STR="Double quotes"
    if [ "$QUOTE" = "single" ]; then QUOTE_STR="Single quotes"; fi
    SEMI_STR="no semicolons"
    if [ "$SEMI" = "always" ]; then SEMI_STR="semicolons always"; fi
    STYLE_RULES="$QUOTE_STR, $SEMI_STR, ${WIDTH}-space indent, ${LINE} char line width"
  fi
  # FIX 2: Script-first — prefer package.json scripts over reconstructed npx commands.
  # 'pnpm lint' / 'pnpm format' are more reliable than bare 'npx biome ...' for projects
  # that add extra flags (--max-diagnostics, --write, etc.) in their scripts.
  if [ -f "package.json" ] && [ -n "$PKG_MGR" ]; then
    _L=$(jq -r '.scripts.lint // empty' package.json 2>/dev/null || true)
    _LW=$(jq -r '.scripts["lint:write"] // .scripts["lint:fix"] // empty' package.json 2>/dev/null || true)
    _F=$(jq -r '.scripts.format // .scripts["format:write"] // empty' package.json 2>/dev/null || true)
    [ -n "$_L" ]  && LINT_CHECK="$(pkg_cmd lint)"
    [ -n "$_LW" ] && LINT_FIX="$(pkg_cmd lint:write)"
    [ -n "$_F" ]  && FORMAT_CMD="$(pkg_cmd format)" && FORMATTER_CMD="$(pkg_cmd format)"
  fi
elif [ -f ".prettierrc" ] || [ -f ".prettierrc.json" ] || [ -f ".prettierrc.js" ] || [ -f ".prettierrc.yaml" ] || [ -f ".prettierrc.yml" ] || [ -f ".prettierrc.toml" ] || [ -f "prettier.config.js" ] || [ -f "prettier.config.mjs" ] || [ -f "prettier.config.cjs" ] || [ -f "prettier.config.ts" ]; then
  FORMATTER="Prettier"; LINTER="${LINTER:-Prettier}"
  LINTER_CONFIG=""; for _f in .prettierrc .prettierrc.json .prettierrc.js .prettierrc.yaml .prettierrc.yml .prettierrc.toml prettier.config.js prettier.config.mjs prettier.config.cjs prettier.config.ts; do [ -f "$_f" ] && LINTER_CONFIG="$_f" && break; done
  FORMATTER_CMD="npx prettier --write ."; LINT_CHECK="npx prettier --check ."; LINT_FIX="npx prettier --write ."; FORMAT_CMD="npx prettier --write ."
fi

# Linter (may be separate from formatter)
if [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || [ -f "eslint.config.ts" ] || [ -f "eslint.config.mts" ] || [ -f "eslint.config.cts" ]; then
  [ -z "$LINTER" ] && LINTER="ESLint"
  LINTER_CONFIG="${LINTER_CONFIG:-$(find . -maxdepth 1 \( -name '.eslintrc*' -o -name 'eslint.config.*' \) 2>/dev/null | head -1 | sed 's|^\./||')}"
  [ -z "$LINT_CHECK" ] && LINT_CHECK="npx eslint ."
  [ -z "$LINT_FIX" ] && LINT_FIX="npx eslint --fix ."
fi

# Python formatters
if [ "$PRIMARY_LANG" = "py" ]; then
  if [ -f "pyproject.toml" ] && grep -q 'ruff' pyproject.toml 2>/dev/null; then
    FORMATTER="Ruff"; LINTER="Ruff"; LINTER_CONFIG="pyproject.toml"
    FORMATTER_CMD="ruff format ."; LINT_CHECK="ruff check ."; LINT_FIX="ruff check --fix ."; FORMAT_CMD="ruff format ."
    STYLE_RULES="Ruff defaults (PEP 8 compliant)"
  elif command -v black &>/dev/null || ([ -f "pyproject.toml" ] && grep -q 'black' pyproject.toml 2>/dev/null); then
    FORMATTER="Black"; LINTER="${LINTER:-Flake8}"
    FORMATTER_CMD="black ."; FORMAT_CMD="black ."
    [ -z "$LINT_CHECK" ] && LINT_CHECK="flake8 ."
    [ -z "$LINT_FIX" ] && LINT_FIX="$LINT_CHECK"
  fi
fi

# Rust
if [ "$PRIMARY_LANG" = "rs" ]; then
  FORMATTER="rustfmt"; LINTER="clippy"; LINTER_CONFIG="Cargo.toml"
  FORMATTER_CMD="cargo fmt"; LINT_CHECK="cargo clippy"; LINT_FIX="cargo clippy --fix"; FORMAT_CMD="cargo fmt"
fi

# Go
if [ "$PRIMARY_LANG" = "go" ]; then
  FORMATTER="gofmt"; LINTER="golangci-lint"; LINTER_CONFIG=".golangci.yml"
  FORMATTER_CMD="gofmt -w ."; LINT_CHECK="golangci-lint run"; LINT_FIX="golangci-lint run --fix"; FORMAT_CMD="gofmt -w ."
  [ -f ".golangci.yml" ] || [ -f ".golangci.yaml" ] || LINTER_CONFIG=""
fi

# dprint (Rust/TS-based multi-language formatter)
if [ -z "$FORMATTER" ] && { [ -f "dprint.json" ] || [ -f ".dprint.json" ]; }; then
  FORMATTER="dprint"; LINTER="${LINTER:-dprint}"
  LINTER_CONFIG=""; for _f in dprint.json .dprint.json; do [ -f "$_f" ] && LINTER_CONFIG="$_f" && break; done
  FORMATTER_CMD="dprint fmt"; LINT_CHECK="dprint check"; LINT_FIX="dprint fmt"; FORMAT_CMD="dprint fmt"
fi

# oxlint (fast Rust-based JS/TS linter)
if [ -z "$LINTER" ] && [ -f "package.json" ]; then
  OX_DEPS=$(jq -r '(.devDependencies // {} | keys[])' package.json 2>/dev/null || true)
  echo "$OX_DEPS" | grep -q '^oxlint$' && LINTER="oxlint" && LINT_CHECK="npx oxlint ." && LINT_FIX="npx oxlint --fix ."
fi

# stylelint (CSS linter, often alongside other linters)
STYLE_LINTER=""
if [ -f ".stylelintrc" ] || [ -f ".stylelintrc.json" ] || [ -f "stylelint.config.js" ]; then
  STYLE_LINTER="stylelint"
fi

# PHP formatters
if [ "$PRIMARY_LANG" = "php" ]; then
  if [ -f ".php-cs-fixer.php" ] || [ -f ".php_cs" ]; then
    FORMATTER="PHP-CS-Fixer"; LINTER="${LINTER:-PHP-CS-Fixer}"
    FORMATTER_CMD="php-cs-fixer fix"; LINT_CHECK="php-cs-fixer fix --dry-run"; LINT_FIX="php-cs-fixer fix"; FORMAT_CMD="php-cs-fixer fix"
  elif [ -f "phpstan.neon" ] || [ -f "phpstan.neon.dist" ]; then
    LINTER="PHPStan"; LINT_CHECK="phpstan analyse"
  fi
  [ -f "pint.json" ] && FORMATTER="Laravel Pint" && FORMATTER_CMD="./vendor/bin/pint" && FORMAT_CMD="./vendor/bin/pint"
fi

# Java/Kotlin formatters
if [ "$PRIMARY_LANG" = "java" ] || [ "$PRIMARY_LANG" = "kt" ]; then
  if [ -f ".editorconfig" ] && [ -f "pom.xml" ] && grep -q 'spotless' pom.xml 2>/dev/null; then
    FORMATTER="Spotless"; LINTER="${LINTER:-Spotless}"
    FORMATTER_CMD="mvn spotless:apply"; LINT_CHECK="mvn spotless:check"; FORMAT_CMD="mvn spotless:apply"
  elif [ "$PRIMARY_LANG" = "kt" ] && { [ -f ".editorconfig" ] || [ -f "ktlint" ]; }; then
    FORMATTER="ktlint"; LINTER="ktlint"
    FORMATTER_CMD="ktlint --format"; LINT_CHECK="ktlint"; FORMAT_CMD="ktlint --format"
  fi
  [ -z "$LINT_FIX" ] && LINT_FIX="$LINT_CHECK"
fi

# Scala
if [ "$PRIMARY_LANG" = "scala" ]; then
  if [ -f ".scalafmt.conf" ]; then
    FORMATTER="scalafmt"; LINTER="scalafmt"
    FORMATTER_CMD="scalafmt"; LINT_CHECK="scalafmt --check"; FORMAT_CMD="scalafmt"
  fi
  if [ -f ".scalafix.conf" ] || ([ -f "build.sbt" ] && grep -q 'scalafix' build.sbt 2>/dev/null); then
    LINTER="${LINTER:-scalafix}"; LINT_CHECK="${LINT_CHECK:-sbt scalafix}"; LINT_FIX="${LINT_FIX:-sbt scalafix}"
    STATIC_ANALYZERS="${STATIC_ANALYZERS}scalafix,"
  fi
  if [ -f "build.sbt" ] && grep -q 'wartremover' build.sbt 2>/dev/null; then
    STATIC_ANALYZERS="${STATIC_ANALYZERS}WartRemover,"
  fi
fi

# Ruby
if [ "$PRIMARY_LANG" = "rb" ]; then
  if [ -f ".rubocop.yml" ]; then
    FORMATTER="RuboCop"; LINTER="RuboCop"; LINTER_CONFIG=".rubocop.yml"
    FORMATTER_CMD="rubocop -a"; LINT_CHECK="rubocop"; LINT_FIX="rubocop -a"; FORMAT_CMD="rubocop -a"
  fi
fi

# C/C++
if [ "$PRIMARY_LANG" = "c" ] || [ "$PRIMARY_LANG" = "cpp" ]; then
  if [ -f ".clang-format" ]; then
    FORMATTER="clang-format"; LINTER="${LINTER:-clang-tidy}"
    FORMATTER_CMD="clang-format -i"; LINT_CHECK="clang-tidy"; FORMAT_CMD="clang-format -i"
  fi
fi

# C# / .NET
if [ "$PRIMARY_LANG" = "cs" ]; then
  FORMATTER="dotnet format"; LINTER="dotnet format"
  FORMATTER_CMD="dotnet format"; LINT_CHECK="dotnet format --verify-no-changes"; LINT_FIX="dotnet format"; FORMAT_CMD="dotnet format"
fi

# Dart
if [ "$PRIMARY_LANG" = "dart" ]; then
  FORMATTER="dart format"; LINTER="dart analyze"
  LINTER_CONFIG="analysis_options.yaml"
  [ ! -f "analysis_options.yaml" ] && LINTER_CONFIG=""
  FORMATTER_CMD="dart format ."; LINT_CHECK="dart analyze"; LINT_FIX="dart fix --apply"; FORMAT_CMD="dart format ."
  STYLE_RULES="Dart style guide (dart format defaults)"
  # Flutter projects: prefer flutter analyze (includes additional Flutter-specific checks)
  if [ -f "pubspec.yaml" ] && grep -q 'flutter:' pubspec.yaml 2>/dev/null; then
    LINTER="flutter analyze"
    LINT_CHECK="flutter analyze"; LINT_FIX="dart fix --apply"
  fi
  # Detect popular lint packages
  if [ -f "analysis_options.yaml" ]; then
    if grep -q 'flutter_lints\|package:flutter_lints' analysis_options.yaml 2>/dev/null; then STYLE_RULES="flutter_lints (Dart style guide)"; fi
    if grep -q 'very_good_analysis' analysis_options.yaml 2>/dev/null; then STYLE_RULES="very_good_analysis (strict Dart lints)"; fi
    if grep -q 'lint:' analysis_options.yaml 2>/dev/null; then STYLE_RULES="package:lint (opinionated Dart lints)"; fi
  fi
fi

# Shell scripts (shellcheck + shfmt)
if [ "$PRIMARY_LANG" = "sh" ]; then
  SHELLCHECK_FILES=$'$(find . -name "*.sh" -not -path "*/.git/*" -not -path "*/node_modules/*" -type f)'
  if command -v shfmt &>/dev/null; then
    FORMATTER="shfmt"
    FORMATTER_CMD="shfmt -w ."
    FORMAT_CMD="shfmt -w ."
    LINT_CHECK="${LINT_CHECK:-shfmt -d .}"  # -d = diff mode, exits non-zero if files differ (no writes)
    LINT_FIX="${LINT_FIX:-shfmt -w .}"
  fi
  if command -v shellcheck &>/dev/null; then
    LINTER="${LINTER:-shellcheck}"
    # Use find to scan all subdirectories, not just *.sh in current dir
    LINT_CHECK="shellcheck ${SHELLCHECK_FILES}"
    LINT_FIX="shellcheck --format=diff ${SHELLCHECK_FILES} | git apply"
  fi
  # Detect .shellcheckrc config
  if [ -f ".shellcheckrc" ]; then LINTER_CONFIG="${LINTER_CONFIG:-.shellcheckrc}"; fi
fi

# Elixir (mix format + credo)
if [ "$PRIMARY_LANG" = "ex" ]; then
  FORMATTER="mix format"; LINTER="${LINTER:-mix format}"
  LINTER_CONFIG=""; [ -f ".formatter.exs" ] && LINTER_CONFIG=".formatter.exs"
  FORMATTER_CMD="mix format"; FORMAT_CMD="mix format"
  LINT_CHECK="mix format --check-formatted"; LINT_FIX="mix format"
  if [ -f "mix.exs" ] && grep -q 'credo' mix.exs 2>/dev/null; then
    LINTER="credo"; LINT_CHECK="mix credo --strict"; LINT_FIX="mix credo --strict"
    STATIC_ANALYZERS="${STATIC_ANALYZERS}credo,"
  fi
  if [ -f "mix.exs" ] && grep -q 'dialyxir' mix.exs 2>/dev/null; then
    STATIC_ANALYZERS="${STATIC_ANALYZERS}dialyzer,"
  fi
fi

# Swift (SwiftFormat + SwiftLint)
if [ "$PRIMARY_LANG" = "swift" ]; then
  if [ -f ".swiftformat" ] || command -v swiftformat &>/dev/null; then
    FORMATTER="SwiftFormat"; LINTER_CONFIG="${LINTER_CONFIG:-.swiftformat}"
    FORMATTER_CMD="swiftformat ."; FORMAT_CMD="swiftformat ."
    LINT_CHECK="${LINT_CHECK:-swiftformat --lint .}"; LINT_FIX="${LINT_FIX:-swiftformat .}"
  fi
  if [ -f ".swiftlint.yml" ] || command -v swiftlint &>/dev/null; then
    LINTER="${LINTER:-SwiftLint}"; LINTER_CONFIG="${LINTER_CONFIG:-.swiftlint.yml}"
    LINT_CHECK="swiftlint lint"; LINT_FIX="swiftlint lint --fix"
  fi
fi

# Lua (StyLua + LuaCheck)
if [ "$PRIMARY_LANG" = "lua" ]; then
  if [ -f "stylua.toml" ] || [ -f ".stylua.toml" ] || command -v stylua &>/dev/null; then
    FORMATTER="StyLua"; LINTER_CONFIG=""; for _f in stylua.toml .stylua.toml; do [ -f "$_f" ] && LINTER_CONFIG="$_f" && break; done
    FORMATTER_CMD="stylua ."; FORMAT_CMD="stylua ."
    LINT_CHECK="${LINT_CHECK:-stylua --check .}"; LINT_FIX="${LINT_FIX:-stylua .}"
  fi
  if [ -f ".luacheckrc" ] || command -v luacheck &>/dev/null; then
    LINTER="${LINTER:-LuaCheck}"; LINTER_CONFIG="${LINTER_CONFIG:-.luacheckrc}"
    LINT_CHECK="luacheck ."; LINT_FIX="luacheck ."
  fi
fi

# Zig (zig fmt — built-in)
if [ "$PRIMARY_LANG" = "zig" ]; then
  FORMATTER="zig fmt"; LINTER="zig fmt"
  FORMATTER_CMD="zig fmt ."; FORMAT_CMD="zig fmt ."
  LINT_CHECK="zig fmt --check ."; LINT_FIX="zig fmt ."
fi

# Perl (perltidy + perlcritic)
if [ "$PRIMARY_LANG" = "pl" ]; then
  if command -v perltidy &>/dev/null || [ -f ".perltidyrc" ]; then
    FORMATTER="perltidy"; LINTER_CONFIG="${LINTER_CONFIG:-.perltidyrc}"
    FORMATTER_CMD="perltidy -b ."; FORMAT_CMD="perltidy -b ."
  fi
  if command -v perlcritic &>/dev/null || [ -f ".perlcriticrc" ]; then
    LINTER="${LINTER:-perlcritic}"; LINTER_CONFIG="${LINTER_CONFIG:-.perlcriticrc}"
    LINT_CHECK="perlcritic ."; LINT_FIX="perlcritic ."
  fi
fi

# Groovy (CodeNarc)
if [ "$PRIMARY_LANG" = "groovy" ]; then
  if [ -f "codenarc.groovy" ] || [ -f "codenarc.xml" ]; then
    LINTER="CodeNarc"; LINTER_CONFIG=""; for _f in codenarc.groovy codenarc.xml; do [ -f "$_f" ] && LINTER_CONFIG="$_f" && break; done
    LINT_CHECK="codenarc"; LINT_FIX="codenarc"
  fi
fi

# Haskell (fourmolu/ormolu + HLint)
if [ "$PRIMARY_LANG" = "hs" ]; then
  if command -v fourmolu &>/dev/null; then
    FORMATTER="fourmolu"; FORMATTER_CMD="fourmolu --mode inplace ."; FORMAT_CMD="fourmolu --mode inplace ."
    LINT_CHECK="${LINT_CHECK:-fourmolu --mode check .}"; LINT_FIX="${LINT_FIX:-fourmolu --mode inplace .}"
  elif command -v ormolu &>/dev/null; then
    FORMATTER="ormolu"; FORMATTER_CMD="ormolu --mode inplace ."; FORMAT_CMD="ormolu --mode inplace ."
    LINT_CHECK="${LINT_CHECK:-ormolu --mode check .}"; LINT_FIX="${LINT_FIX:-ormolu --mode inplace .}"
  fi
  if command -v hlint &>/dev/null; then
    LINTER="${LINTER:-HLint}"; LINT_CHECK="hlint ."; LINT_FIX="hlint --refactor ."
  fi
fi

# OCaml (ocamlformat)
if [ "$PRIMARY_LANG" = "ml" ]; then
  if [ -f ".ocamlformat" ] || command -v ocamlformat &>/dev/null; then
    FORMATTER="ocamlformat"; LINTER_CONFIG="${LINTER_CONFIG:-.ocamlformat}"
    FORMATTER_CMD="dune fmt"; FORMAT_CMD="dune fmt"
    LINT_CHECK="${LINT_CHECK:-dune fmt --preview}"; LINT_FIX="${LINT_FIX:-dune fmt}"
  fi
fi

# Clojure (cljfmt + clj-kondo)
if [ "$PRIMARY_LANG" = "clj" ]; then
  if command -v cljfmt &>/dev/null || ([ -f "deps.edn" ] && grep -q 'cljfmt' deps.edn 2>/dev/null); then
    FORMATTER="cljfmt"; FORMATTER_CMD="cljfmt fix"; FORMAT_CMD="cljfmt fix"
    LINT_CHECK="${LINT_CHECK:-cljfmt check}"; LINT_FIX="${LINT_FIX:-cljfmt fix}"
  fi
  if command -v clj-kondo &>/dev/null || [ -f ".clj-kondo/config.edn" ]; then
    LINTER="${LINTER:-clj-kondo}"; LINTER_CONFIG="${LINTER_CONFIG:-.clj-kondo/config.edn}"
    LINT_CHECK="clj-kondo --lint src"; LINT_FIX="clj-kondo --lint src"
  fi
fi

# R (styler + lintr)
if [ "$PRIMARY_LANG" = "r" ]; then
  FORMATTER="styler"; FORMATTER_CMD='Rscript -e "styler::style_dir()"'; FORMAT_CMD='Rscript -e "styler::style_dir()"'
  if [ -f ".lintr" ]; then
    LINTER="lintr"; LINTER_CONFIG=".lintr"
    LINT_CHECK='Rscript -e "lintr::lint_dir()"'; LINT_FIX='Rscript -e "lintr::lint_dir()"'
  fi
fi

# Python additional linters (mypy, pylint — often used alongside formatter)
STATIC_ANALYZERS=""
if [ "$PRIMARY_LANG" = "py" ]; then
  [ -f "mypy.ini" ] || [ -f ".mypy.ini" ] || ([ -f "pyproject.toml" ] && grep -q 'mypy' pyproject.toml 2>/dev/null) && STATIC_ANALYZERS="${STATIC_ANALYZERS}mypy,"
  [ -f ".pylintrc" ] || ([ -f "pyproject.toml" ] && grep -q 'pylint' pyproject.toml 2>/dev/null) && STATIC_ANALYZERS="${STATIC_ANALYZERS}pylint,"
  [ -f "pyproject.toml" ] && grep -q 'bandit' pyproject.toml 2>/dev/null && STATIC_ANALYZERS="${STATIC_ANALYZERS}bandit,"
fi

emit "FORMATTER" "$FORMATTER"
emit "LINTER" "${LINTER:-$FORMATTER}"
emit "LINTER_CONFIG_FILE" "$LINTER_CONFIG"
emit "FORMATTER_COMMAND" "$FORMATTER_CMD"
emit "LINT_CHECK_CMD" "$LINT_CHECK"
emit "LINT_FIX_CMD" "$LINT_FIX"
emit "FORMAT_CMD" "$FORMAT_CMD"

# Secondary formatter for dual-language projects
# Detect formatter for secondary languages so stop-batch-format.sh can dispatch per-extension.
# Emits TWO extension formats:
#   SECONDARY_FORMATTER_EXTS      — regex (\.py$) — legacy, NOT used in hooks (grep -E pipe-unsafe)
#   SECONDARY_FORMATTER_CASE_EXTS — case glob (*.py|*.pyi) — used in stop-batch-format.sh (pipe-immune)
SEC_FORMATTER_CMD=""
SEC_FORMATTER_EXTS=""
SEC_FORMATTER_CASE_EXTS=""
for _sec in $(echo "${SECONDARY_LANGS%,}" | tr ',' ' '); do
  [ -z "$_sec" ] && continue
  case "$_sec" in
    py)
      if [ -f "pyproject.toml" ] && grep -q 'ruff' pyproject.toml 2>/dev/null; then
        SEC_FORMATTER_CMD="ruff format"; SEC_FORMATTER_EXTS='\.py$'; SEC_FORMATTER_CASE_EXTS='*.py|*.pyi'
      elif command -v black &>/dev/null; then
        SEC_FORMATTER_CMD="black"; SEC_FORMATTER_EXTS='\.py$'; SEC_FORMATTER_CASE_EXTS='*.py|*.pyi'
      fi
      ;;
    ts|tsx|js|jsx|mts|cts|mjs|cjs)
      if [ -f "biome.json" ] || [ -f "biome.jsonc" ]; then
        SEC_FORMATTER_CMD="npx biome check --write"; SEC_FORMATTER_EXTS='\.(js|ts|tsx|jsx|css|json)$'; SEC_FORMATTER_CASE_EXTS='*.js|*.ts|*.tsx|*.jsx|*.css|*.json'
      elif [ -f ".prettierrc" ] || [ -f ".prettierrc.json" ] || [ -f "prettier.config.js" ] || [ -f "prettier.config.mjs" ]; then
        SEC_FORMATTER_CMD="npx prettier --write"; SEC_FORMATTER_EXTS='\.(js|ts|tsx|jsx|css|html|json)$'; SEC_FORMATTER_CASE_EXTS='*.js|*.ts|*.tsx|*.jsx|*.css|*.html|*.json'
      fi
      ;;
    go)  SEC_FORMATTER_CMD="gofmt -w"; SEC_FORMATTER_EXTS='\.go$'; SEC_FORMATTER_CASE_EXTS='*.go' ;;
    rs)  SEC_FORMATTER_CMD="rustfmt"; SEC_FORMATTER_EXTS='\.rs$'; SEC_FORMATTER_CASE_EXTS='*.rs' ;;
    rb)  SEC_FORMATTER_CMD="rubocop -a"; SEC_FORMATTER_EXTS='\.rb$'; SEC_FORMATTER_CASE_EXTS='*.rb|*.erb' ;;
    php) SEC_FORMATTER_CMD="php-cs-fixer fix"; SEC_FORMATTER_EXTS='\.php$'; SEC_FORMATTER_CASE_EXTS='*.php' ;;
  esac
  # Only take the first detected secondary formatter (most repos have 2 languages max)
  [ -n "$SEC_FORMATTER_CMD" ] && break
done
emit "SECONDARY_FORMATTER_COMMAND" "$SEC_FORMATTER_CMD"
emit "SECONDARY_FORMATTER_EXTS" "$SEC_FORMATTER_EXTS"
emit "SECONDARY_FORMATTER_CASE_EXTS" "$SEC_FORMATTER_CASE_EXTS"

# .editorconfig: universal style rules fallback (when no formatter-specific config)
if [ -z "$STYLE_RULES" ] || [ "$STYLE_RULES" = "Project defaults" ]; then
  if [ -f ".editorconfig" ]; then
    EC_INDENT=$(grep -E '^[[:space:]]*indent_style[[:space:]]*=' .editorconfig 2>/dev/null | tail -1 | awk -F= '{gsub(/[[:space:]]/, "", $2); print $2}' || echo "space")
    EC_SIZE=$(grep -E '^[[:space:]]*indent_size[[:space:]]*=' .editorconfig 2>/dev/null | tail -1 | awk -F= '{gsub(/[[:space:]]/, "", $2); print $2}' || echo "2")
    EC_LINE=$(grep -E '^[[:space:]]*max_line_length[[:space:]]*=' .editorconfig 2>/dev/null | tail -1 | awk -F= '{gsub(/[[:space:]]/, "", $2); print $2}' || echo "")
    EC_EOL=$(grep -E '^[[:space:]]*end_of_line[[:space:]]*=' .editorconfig 2>/dev/null | tail -1 | awk -F= '{gsub(/[[:space:]]/, "", $2); print $2}' || echo "lf")
    LINE_STR="${EC_LINE:+, ${EC_LINE} char line width}"
    STYLE_RULES="${EC_INDENT} indent (${EC_SIZE}), ${EC_EOL} line endings${LINE_STR} (EditorConfig)"
  fi
fi

emit "STYLE_RULES" "${STYLE_RULES:-Project defaults}"
emit "STYLE_LINTER" "${STYLE_LINTER:-}"
emit "STATIC_ANALYZERS" "${STATIC_ANALYZERS%,}"

echo ""

# ─── Test Framework Detection (emits deferred to after Build Commands) ─────

TEST_FW="" COVERAGE="" TEST_ALL="" TEST_SINGLE="" TEST_CI="" TEST_COV=""
E2E_FW=""

# Fastest signal: read scripts.test from package.json — most reliable for JS/TS
if [ -f "package.json" ]; then
  SCRIPTS_TEST=$(jq -r '.scripts.test // empty' package.json 2>/dev/null || true)
  if echo "$SCRIPTS_TEST" | grep -qi 'vitest'; then TEST_FW="Vitest"; COVERAGE="v8/istanbul"; fi
  if [ -z "$TEST_FW" ] && echo "$SCRIPTS_TEST" | grep -qi 'jest'; then TEST_FW="Jest"; COVERAGE="jest --coverage"; fi
  if [ -z "$TEST_FW" ] && echo "$SCRIPTS_TEST" | grep -qi 'mocha'; then TEST_FW="Mocha"; COVERAGE="nyc"; fi
  if [ -z "$TEST_FW" ] && echo "$SCRIPTS_TEST" | grep -qi 'ava'; then TEST_FW="AVA"; COVERAGE="c8"; fi
fi

# Shell test frameworks (bats, shunit2) — checked first for sh primary lang repos
if [ "$PRIMARY_LANG" = "sh" ]; then
  if command -v bats &>/dev/null || find . -name '*.bats' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q '.'; then
    TEST_FW="bats"
    TEST_ALL=$'bats $(find . -name "*.bats" -not -path "*/.git/*" -type f)'
    TEST_SINGLE="bats"
    TEST_CI=$'bats --formatter tap $(find . -name "*.bats" -type f)'
    TEST_COV=""
  elif find . -name 'shunit2' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q '.'; then
    TEST_FW="shunit2"
    TEST_ALL='find . -name "*_test.sh" -type f | xargs bash'
    TEST_SINGLE="bash"
    TEST_CI="$TEST_ALL"
    TEST_COV=""
  else
    # Fallback for shell repos: syntax check as "test"
    TEST_FW="none (syntax-check)"
    TEST_ALL=$'bash -n $(find . -name "*.sh" -not -path "*/.git/*" -type f)'
    TEST_SINGLE="bash -n"
    TEST_CI="$TEST_ALL"
    TEST_COV=""
  fi
fi
if [ -f "vitest.config.ts" ] || [ -f "vitest.config.js" ] || [ -f "vitest.config.mts" ]; then
  TEST_FW="Vitest"; COVERAGE="v8/istanbul"
elif [ -f "jest.config.ts" ] || [ -f "jest.config.js" ] || [ -f "jest.config.mjs" ]; then
  TEST_FW="Jest"; COVERAGE="jest --coverage"
elif [ -f ".mocharc.yml" ] || [ -f ".mocharc.json" ] || [ -f ".mocharc.js" ]; then
  TEST_FW="Mocha"; COVERAGE="nyc"
elif [ -f "ava.config.js" ] || [ -f "ava.config.mjs" ] || [ -f "ava.config.cjs" ]; then
  TEST_FW="AVA"; COVERAGE="c8"
elif [ -f ".nycrc" ] || [ -f ".nycrc.json" ]; then
  TEST_FW="Mocha+nyc"; COVERAGE="nyc"
fi

# Fallback: detect from package.json devDependencies (JS/TS ecosystem)
if [ -z "$TEST_FW" ] && [ -f "package.json" ]; then
  TEST_DEPS=$(jq -r '(.devDependencies // {} | keys[])' package.json 2>/dev/null || true)
  echo "$TEST_DEPS" | grep -q '^vitest$' && TEST_FW="Vitest" && COVERAGE="v8/istanbul"
  [ -z "$TEST_FW" ] && echo "$TEST_DEPS" | grep -q '^jest$\|^@jest' && TEST_FW="Jest" && COVERAGE="jest --coverage"
  [ -z "$TEST_FW" ] && echo "$TEST_DEPS" | grep -q '^mocha$' && TEST_FW="Mocha" && COVERAGE="nyc"
  [ -z "$TEST_FW" ] && echo "$TEST_DEPS" | grep -q '^ava$' && TEST_FW="AVA" && COVERAGE="c8"
  [ -z "$TEST_FW" ] && echo "$TEST_DEPS" | grep -q '^tap$' && TEST_FW="tap" && COVERAGE="tap --coverage-report"
  [ -z "$TEST_FW" ] && echo "$TEST_DEPS" | grep -q '^uvu$' && TEST_FW="uvu" && COVERAGE="c8"
  # E2E / integration test frameworks (detected alongside unit test fw)
  echo "$TEST_DEPS" | grep -q '^playwright$\|^@playwright' && E2E_FW="${E2E_FW}Playwright,"
  echo "$TEST_DEPS" | grep -q '^cypress$' && E2E_FW="${E2E_FW}Cypress,"
  echo "$TEST_DEPS" | grep -q '^puppeteer$' && E2E_FW="${E2E_FW}Puppeteer,"
  echo "$TEST_DEPS" | grep -q '^@testing-library' && E2E_FW="${E2E_FW}Testing-Library,"
  echo "$TEST_DEPS" | grep -q '^supertest$' && E2E_FW="${E2E_FW}Supertest,"
  echo "$TEST_DEPS" | grep -q '^storybook$\|^@storybook' && E2E_FW="${E2E_FW}Storybook,"
fi

# Bun / Deno built-in test runners
if [ -z "$TEST_FW" ] && [ "$PKG_MGR" = "bun" ]; then
  TEST_FW="bun:test"; COVERAGE="bun test --coverage"
fi
if [ -z "$TEST_FW" ] && [ "$PKG_MGR" = "deno" ]; then
  TEST_FW="Deno.test"; COVERAGE="deno test --coverage"
fi

# Python test frameworks
if [ -z "$TEST_FW" ]; then
  if [ -f "pytest.ini" ] || [ -f "conftest.py" ]; then
    TEST_FW="pytest"; COVERAGE="pytest-cov"
  elif [ -f "pyproject.toml" ] && grep -q 'pytest' pyproject.toml 2>/dev/null; then
    TEST_FW="pytest"; COVERAGE="pytest-cov"
  elif [ -f "setup.cfg" ] && grep -q 'pytest' setup.cfg 2>/dev/null; then
    TEST_FW="pytest"; COVERAGE="pytest-cov"
  elif [ -f "tox.ini" ]; then
    TEST_FW="tox+pytest"; COVERAGE="pytest-cov"
  elif [ -f "pyproject.toml" ] && grep -q 'unittest' pyproject.toml 2>/dev/null; then
    TEST_FW="unittest"; COVERAGE="coverage.py"
  fi
fi

# Go testing (built-in)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "go" ]; then
  TEST_FW="go test"; COVERAGE="go test -cover"
fi

# Rust testing (built-in)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "rs" ]; then
  TEST_FW="cargo test"; COVERAGE="cargo tarpaulin"
fi

# Java/Kotlin test frameworks — handled below in polyglot section

# Ruby test frameworks
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "rb" ]; then
  if [ -f "Gemfile" ] && grep -q 'rspec' Gemfile 2>/dev/null; then
    TEST_FW="RSpec"; COVERAGE="simplecov"
  elif [ -f "Gemfile" ] && grep -q 'minitest' Gemfile 2>/dev/null; then
    TEST_FW="Minitest"; COVERAGE="simplecov"
  fi
fi

# PHP test frameworks
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "php" ]; then
  if [ -f "phpunit.xml" ] || [ -f "phpunit.xml.dist" ]; then
    TEST_FW="PHPUnit"; COVERAGE="phpunit --coverage-html"
  elif [ -f "composer.json" ] && grep -q 'pest' composer.json 2>/dev/null; then
    TEST_FW="Pest"; COVERAGE="pest --coverage"
  fi
fi

# C#/.NET test frameworks
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "cs" ]; then
  TEST_FW="xUnit/NUnit"; COVERAGE="coverlet"
fi

# Dart test framework (built-in dart test + package:test)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "dart" ]; then
  TEST_FW="dart test"; COVERAGE="dart test --coverage"
  # Check for flutter_test in pubspec.yaml (Flutter projects use flutter test)
  if [ -f "pubspec.yaml" ] && grep -q 'flutter_test' pubspec.yaml 2>/dev/null; then
    TEST_FW="flutter_test"; COVERAGE="flutter test --coverage"
  fi
fi

# C/C++ test frameworks (GoogleTest, Catch2, CTest, doctest, Boost.Test)
if [ -z "$TEST_FW" ] && { [ "$PRIMARY_LANG" = "c" ] || [ "$PRIMARY_LANG" = "cpp" ]; }; then
  if [ -f "CMakeLists.txt" ] && grep -qiE 'gtest|google_test|googletest' CMakeLists.txt 2>/dev/null; then
    TEST_FW="GoogleTest"; COVERAGE="gcov/lcov"
  elif find . -maxdepth 3 -name 'catch.hpp' -o -name 'catch2' -o -name 'catch_amalgamated.hpp' 2>/dev/null | head -1 | grep -q '.'; then
    TEST_FW="Catch2"; COVERAGE="gcov/lcov"
  elif [ -f "CMakeLists.txt" ] && grep -qiE 'doctest' CMakeLists.txt 2>/dev/null; then
    TEST_FW="doctest"; COVERAGE="gcov/lcov"
  elif [ -f "CMakeLists.txt" ] && grep -qi 'enable_testing\|add_test\|ctest' CMakeLists.txt 2>/dev/null; then
    TEST_FW="CTest"; COVERAGE="gcov/lcov"
  elif [ -f "CMakeLists.txt" ] && grep -qi 'Boost.*Test' CMakeLists.txt 2>/dev/null; then
    TEST_FW="Boost.Test"; COVERAGE="gcov/lcov"
  fi
fi

# Scala test frameworks (ScalaTest, specs2, MUnit)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "scala" ]; then
  if [ -f "build.sbt" ]; then
    if grep -q 'scalatest' build.sbt 2>/dev/null; then
      TEST_FW="ScalaTest"; COVERAGE="sbt-scoverage"
    elif grep -q 'specs2' build.sbt 2>/dev/null; then
      TEST_FW="specs2"; COVERAGE="sbt-scoverage"
    elif grep -q 'munit' build.sbt 2>/dev/null; then
      TEST_FW="MUnit"; COVERAGE="sbt-scoverage"
    elif grep -q 'scalacheck' build.sbt 2>/dev/null; then
      TEST_FW="ScalaCheck"; COVERAGE="sbt-scoverage"
    fi
  fi
fi

# Elixir (ExUnit — built-in)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "ex" ]; then
  TEST_FW="ExUnit"; COVERAGE="mix test --cover"
fi

# Zig (built-in test runner)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "zig" ]; then
  TEST_FW="zig test"; COVERAGE=""
fi

# Lua test frameworks (busted, luaunit)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "lua" ]; then
  if [ -f ".busted" ] || find . -maxdepth 3 -name '*_spec.lua' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q '.'; then
    TEST_FW="busted"; COVERAGE="luacov"
  elif find . -maxdepth 3 -name 'test*.lua' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q '.'; then
    TEST_FW="luaunit"; COVERAGE="luacov"
  fi
fi

# Perl test frameworks (prove / Test::More)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "pl" ]; then
  if [ -d "t" ] || find . -maxdepth 2 -name '*.t' -type f 2>/dev/null | head -1 | grep -q '.'; then
    TEST_FW="Test::More (prove)"; COVERAGE="Devel::Cover"
  fi
fi

# Haskell test frameworks (hspec, tasty, HUnit)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "hs" ]; then
  if find . -maxdepth 1 -name '*.cabal' 2>/dev/null | head -1 | grep -q '.'; then
    _CABAL=$(find . -maxdepth 1 -name '*.cabal' 2>/dev/null | head -1)
    if grep -qi 'hspec' "$_CABAL" 2>/dev/null; then TEST_FW="hspec"; COVERAGE="hpc"
    elif grep -qi 'tasty' "$_CABAL" 2>/dev/null; then TEST_FW="tasty"; COVERAGE="hpc"
    else TEST_FW="HUnit"; COVERAGE="hpc"
    fi
  elif [ -f "stack.yaml" ]; then
    TEST_FW="stack test"; COVERAGE="hpc"
  fi
fi

# OCaml test frameworks (alcotest, OUnit)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "ml" ]; then
  if [ -f "dune-project" ] || [ -f "dune" ]; then
    TEST_FW="dune test"; COVERAGE="bisect_ppx"
  fi
fi

# Clojure (clojure.test — built-in)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "clj" ]; then
  if [ -f "project.clj" ]; then
    TEST_FW="clojure.test (lein)"; COVERAGE="cloverage"
  elif [ -f "deps.edn" ]; then
    TEST_FW="clojure.test"; COVERAGE="cloverage"
  fi
fi

# R (testthat)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "r" ]; then
  if [ -d "tests" ] && { [ -f "tests/testthat.R" ] || [ -d "tests/testthat" ]; }; then
    TEST_FW="testthat"; COVERAGE="covr"
  fi
fi

# Julia (Test — built-in)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "jl" ]; then
  if [ -d "test" ] && [ -f "test/runtests.jl" ]; then
    TEST_FW="Julia Test"; COVERAGE="Coverage.jl"
  fi
fi

# Objective-C / Objective-C++ (XCTest)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "m" ]; then
  TEST_FW="XCTest"; COVERAGE="llvm-cov"
fi

# Groovy (Spock)
if [ -z "$TEST_FW" ] && [ "$PRIMARY_LANG" = "groovy" ]; then
  if [ -f "build.gradle" ] && grep -q 'spock' build.gradle 2>/dev/null; then
    TEST_FW="Spock"; COVERAGE="JaCoCo"
  fi
fi

# Python: nox (alternative to tox)
if [ -z "$TEST_FW" ] && [ -f "noxfile.py" ]; then
  TEST_FW="nox+pytest"; COVERAGE="pytest-cov"
fi

# BDD / Cucumber — detected across ALL languages by .feature files
if find . -maxdepth 4 -name '*.feature' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q '.'; then
  E2E_FW="${E2E_FW}Cucumber/Gherkin,"
fi

# ── Monorepo deep scan ──
# If still no test framework AND we're a monorepo, scan child package.json + config files
IS_MONO="$MONOREPO"

if [ -z "$TEST_FW" ] && [ "$IS_MONO" = "true" ]; then
  DEEP_MOCHA=$(find . -maxdepth 4 -name '.mocharc*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1)
  DEEP_VITEST=$(find . -maxdepth 4 -name 'vitest.config.*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1)
  DEEP_JEST=$(find . -maxdepth 4 -name 'jest.config.*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1)

  # Count occurrences to report the dominant framework
  MOCHA_N=0; VITEST_N=0; JEST_N=0
  if [ -n "$DEEP_MOCHA" ]; then MOCHA_N=$(find . -maxdepth 4 -name '.mocharc*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l | tr -d ' '); fi
  if [ -n "$DEEP_VITEST" ]; then VITEST_N=$(find . -maxdepth 4 -name 'vitest.config.*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l | tr -d ' '); fi
  if [ -n "$DEEP_JEST" ]; then JEST_N=$(find . -maxdepth 4 -name 'jest.config.*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l | tr -d ' '); fi

  # Pick dominant by count, or list all if multiple
  FW_PARTS=""
  if [ "$MOCHA_N" -gt 0 ] 2>/dev/null; then FW_PARTS="${FW_PARTS}Mocha,"; fi
  if [ "$VITEST_N" -gt 0 ] 2>/dev/null; then FW_PARTS="${FW_PARTS}Vitest,"; fi
  if [ "$JEST_N" -gt 0 ] 2>/dev/null; then FW_PARTS="${FW_PARTS}Jest,"; fi

  if [ -n "$FW_PARTS" ]; then
    TEST_FW="${FW_PARTS%,}"
    # Coverage: pick from first detected
    if [ "$VITEST_N" -gt 0 ] 2>/dev/null; then COVERAGE="v8/istanbul"
    elif [ "$JEST_N" -gt 0 ] 2>/dev/null; then COVERAGE="jest --coverage"
    else COVERAGE="nyc"
    fi
  fi

  # Also scan child devDependencies for frameworks not caught by config files
  if [ -z "$TEST_FW" ]; then
    CHILD_DEPS=$(find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -20 | xargs jq -r '(.devDependencies // {} | keys[])' 2>/dev/null | sort -u || true)
    if echo "$CHILD_DEPS" | grep -q '^vitest$'; then TEST_FW="${TEST_FW:+$TEST_FW+}Vitest"; COVERAGE="v8/istanbul"; fi
    if echo "$CHILD_DEPS" | grep -q '^jest$'; then TEST_FW="${TEST_FW:+$TEST_FW+}Jest"; COVERAGE="${COVERAGE:-jest --coverage}"; fi
    if echo "$CHILD_DEPS" | grep -q '^mocha$'; then TEST_FW="${TEST_FW:+$TEST_FW+}Mocha"; COVERAGE="${COVERAGE:-nyc}"; fi
  fi
fi

# ── Polyglot repos: Java/Kotlin tests (regardless of PRIMARY_LANG) ──
# A monorepo with PRIMARY_LANG=js can still have 700+ Java files under components/
if ! echo "$TEST_FW" | grep -qi 'junit\|testng'; then
  JAVA_TEST=""
  # Check root pom.xml
  if [ -f "pom.xml" ]; then
    if grep -qE 'junit-jupiter|junit5' pom.xml 2>/dev/null; then JAVA_TEST="JUnit 5"; fi
    if [ -z "$JAVA_TEST" ] && grep -q 'junit' pom.xml 2>/dev/null; then JAVA_TEST="JUnit 4"; fi
    if [ -z "$JAVA_TEST" ] && grep -q 'testng' pom.xml 2>/dev/null; then JAVA_TEST="TestNG"; fi
  fi
  # Check child pom.xml files (monorepo Java modules)
  if [ -z "$JAVA_TEST" ]; then
    CHILD_POM=$(find . -maxdepth 4 -name 'pom.xml' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -5)
    for pom in $CHILD_POM; do
      if grep -qE 'junit-jupiter|junit5' "$pom" 2>/dev/null; then JAVA_TEST="JUnit 5"; break; fi
      if grep -q 'junit' "$pom" 2>/dev/null; then JAVA_TEST="JUnit 4"; fi
    done
  fi
  # Check Gradle
  if [ -z "$JAVA_TEST" ] && { [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; }; then
    JAVA_TEST="JUnit 5"
  fi
  if [ -n "$JAVA_TEST" ]; then
    TEST_FW="${TEST_FW:+$TEST_FW+}${JAVA_TEST}"
    COVERAGE="${COVERAGE:+$COVERAGE+}JaCoCo"
  fi
fi

# Derive test commands from package manager + framework
case "$PKG_MGR" in
  pnpm|npm|yarn)
    TEST_ALL="${PKG_MGR} test"
    TEST_SINGLE="${PKG_MGR} --filter"
    TEST_CI="${PKG_MGR} test -- --reporter=junit"
    TEST_COV="${PKG_MGR} test -- --coverage"
    [ "$PKG_MGR" = "pnpm" ] && TEST_SINGLE="pnpm --filter"
    [ "$PKG_MGR" = "npm" ] && TEST_SINGLE="npm test --workspace"
    [ "$PKG_MGR" = "yarn" ] && TEST_SINGLE="yarn workspace"
    ;;
  pip|poetry|pipenv)
    TEST_ALL="pytest"
    TEST_SINGLE="pytest tests/"
    TEST_CI="pytest --junitxml=report.xml"
    TEST_COV="pytest --cov=. --cov-report=html"
    ;;
  cargo)
    TEST_ALL="cargo test"
    TEST_SINGLE="cargo test -p"
    TEST_CI="cargo test -- --format=json"
    TEST_COV="cargo tarpaulin --out html"
    ;;
  go*)
    TEST_ALL="go test ./..."
    TEST_SINGLE="go test"
    TEST_CI="go test -v -json ./..."
    TEST_COV="go test -coverprofile=coverage.out ./..."
    ;;
  maven)
    TEST_ALL="mvn test"
    TEST_SINGLE="mvn -pl"
    TEST_CI="mvn test -Dmaven.test.failure.ignore=false"
    TEST_COV="mvn test jacoco:report"
    ;;
  gradle)
    TEST_ALL="gradle test"
    TEST_SINGLE="gradle :module:test"
    TEST_CI="gradle test --no-daemon"
    TEST_COV="gradle test jacocoTestReport"
    ;;
  bun)
    TEST_ALL="bun test"
    TEST_SINGLE="bun test"
    TEST_CI="bun test --reporter=junit"
    TEST_COV="bun test --coverage"
    ;;
  deno)
    TEST_ALL="deno test"
    TEST_SINGLE="deno test"
    TEST_CI="deno test --reporter=junit"
    TEST_COV="deno test --coverage"
    ;;
  bundler)
    TEST_ALL="bundle exec rspec"
    TEST_SINGLE="bundle exec rspec spec/"
    TEST_CI="bundle exec rspec --format documentation"
    TEST_COV="bundle exec rspec"
    ;;
  uv|pdm|hatch)
    TEST_ALL="pytest"
    TEST_SINGLE="pytest tests/"
    TEST_CI="pytest --junitxml=report.xml"
    TEST_COV="pytest --cov=. --cov-report=html"
    ;;
  mix)
    TEST_ALL="mix test"
    TEST_SINGLE="mix test"
    TEST_CI="mix test --formatter ExUnit.CLIFormatter"
    TEST_COV="mix test --cover"
    ;;
  pub)
    if [ -f "pubspec.yaml" ] && grep -q 'flutter:' pubspec.yaml 2>/dev/null; then
      TEST_ALL="flutter test"
      TEST_SINGLE="flutter test"
      TEST_CI="flutter test --reporter expanded"
      TEST_COV="flutter test --coverage"
    else
      TEST_ALL="dart test"
      TEST_SINGLE="dart test"
      TEST_CI="dart test --reporter expanded"
      TEST_COV="dart test --coverage"
    fi
    ;;
  sbt)
    TEST_ALL="sbt test"
    TEST_SINGLE="sbt testOnly"
    TEST_CI="sbt test"
    TEST_COV="sbt jacoco"
    ;;
  composer)
    TEST_ALL="composer test"
    TEST_SINGLE="vendor/bin/phpunit"
    TEST_CI="vendor/bin/phpunit --log-junit report.xml"
    TEST_COV="vendor/bin/phpunit --coverage-html coverage"
    ;;
  swift-package-manager)
    TEST_ALL="swift test"
    TEST_SINGLE="swift test --filter"
    TEST_CI="swift test"
    TEST_COV="swift test --enable-code-coverage"
    ;;
  stack)
    TEST_ALL="stack test"
    TEST_SINGLE="stack test --test-arguments"
    TEST_CI="stack test"
    TEST_COV="stack test --coverage"
    ;;
  cabal)
    TEST_ALL="cabal test"
    TEST_SINGLE="cabal test"
    TEST_CI="cabal test"
    TEST_COV="cabal test --enable-coverage"
    ;;
  dune*)
    TEST_ALL="dune runtest"
    TEST_SINGLE="dune runtest"
    TEST_CI="dune runtest"
    TEST_COV="bisect-ppx-report html"
    ;;
  lein)
    TEST_ALL="lein test"
    TEST_SINGLE="lein test"
    TEST_CI="lein test"
    TEST_COV="lein cloverage"
    ;;
  clojure-cli)
    TEST_ALL="clojure -M:test"
    TEST_SINGLE="clojure -M:test"
    TEST_CI="clojure -M:test"
    TEST_COV="clojure -M:cloverage"
    ;;
  renv)
    TEST_ALL='Rscript -e "devtools::test()"'
    TEST_SINGLE='Rscript -e "testthat::test_file()"'
    TEST_CI='Rscript -e "devtools::test()"'
    TEST_COV='Rscript -e "covr::package_coverage()"'
    ;;
  julia-pkg)
    TEST_ALL="julia --project=. -e 'using Pkg; Pkg.test()'"
    TEST_SINGLE="julia --project=. test/runtests.jl"
    TEST_CI="julia --project=. -e 'using Pkg; Pkg.test()'"
    TEST_COV="julia --project=. -e 'using LocalCoverage; coverage_summary()'"
    ;;
  cpanm)
    TEST_ALL="prove -r t/"
    TEST_SINGLE="prove"
    TEST_CI="prove -r t/ --formatter=TAP::Formatter::JUnit"
    TEST_COV="cover -test"
    ;;
  cmake)
    TEST_ALL="cmake --build build && ctest --test-dir build"
    TEST_SINGLE="ctest --test-dir build -R"
    TEST_CI="ctest --test-dir build --output-on-failure"
    TEST_COV="cmake --build build && ctest --test-dir build && gcov src/*.c"
    ;;
esac

# Nx monorepo override — pnpm/npm run-many is wrong; Nx requires nx run-many
if echo "${MONOREPO_TOOL:-}" | grep -q 'Nx'; then
  NX_PM="${PKG_MGR:-pnpm}"
  TEST_ALL="${NX_PM} nx run-many --target=build --all"
  TEST_SINGLE="${NX_PM} nx test <service-name>"
  TEST_CI="${NX_PM} nx run-many --target=test --all --parallel=2"
  TEST_COV="${NX_PM} nx run-many --target=test --all -- --coverage"
fi

# FIX 3: Script-first for build/test/serve/ci-test — check package.json scripts before assuming defaults.
# Projects often have customised scripts with extra flags. Using the script name is always more accurate.
if [ -f "package.json" ] && [ -n "$PKG_MGR" ]; then
  _BUILD=$(jq -r '.scripts.build // empty' package.json 2>/dev/null || true)
  _TEST=$(jq -r '.scripts.test // empty' package.json 2>/dev/null || true)
  _CI_TEST=$(jq -r '.scripts["ci:test"] // empty' package.json 2>/dev/null || true)
  _SERVE=$(jq -r '.scripts.serve // empty' package.json 2>/dev/null || true)
  _DEV=$(jq -r '.scripts.dev // empty' package.json 2>/dev/null || true)
  [ -n "$_BUILD" ] && BUILD_ALL="$(pkg_cmd build)"
  [ -n "$_TEST" ]  && TEST_ALL="$(pkg_cmd test)"
  [ -n "$_CI_TEST" ] && TEST_CI="$(pkg_cmd ci:test)"
  # SERVE_CMD_ALL: prefer 'serve' script over 'dev' script; clear if neither exists
  if [ -n "$_SERVE" ]; then
    DEV_CMD="$(pkg_cmd serve)"
  elif [ -z "$_DEV" ]; then
    DEV_CMD=""  # No 'dev' script — don't emit a wrong command
  fi
fi

# ─── Multi-language augmentation ──────────────────────────────────
# When PRIMARY_LANG is JS/TS but Python test files also exist, or vice versa,
# combine commands so TEST_CMD_ALL and LINT_CHECK_CMD cover both stacks.

# Case A: JS/TS primary + Python backend (e.g. TypeScript frontend + Python API/NVR)
if [ "$PRIMARY_LANG" = "ts" ] || [ "$PRIMARY_LANG" = "tsx" ] || [ "$PRIMARY_LANG" = "js" ]; then
  # Detect Python test suite
  _PY_TEST_FILE=$(find . -maxdepth 5 \( -name 'test_*.py' -o -name '*_test.py' \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1 || true)
  _PY_TEST_DIR=$(find . -maxdepth 3 -type d \( -name 'test' -o -name 'tests' \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1 || true)
  if [ -n "$_PY_TEST_FILE" ] || [ -n "$_PY_TEST_DIR" ]; then
    # Determine Python test runner
    if find . -maxdepth 2 -name 'pytest.ini' -o -name 'conftest.py' 2>/dev/null | grep -q '.' 2>/dev/null; then
      _PY_TEST_CMD="pytest"
      _PY_TEST_COV="pytest --cov=. --cov-report=html"
    elif [ -n "$_PY_TEST_DIR" ]; then
      _DIR_NAME="${_PY_TEST_DIR#./}"
      _PY_TEST_CMD="python3 -u -m unittest discover -s ${_DIR_NAME}"
      _PY_TEST_COV="python3 -u -m unittest discover -s ${_DIR_NAME}"
    fi
    # Combine: prepend Python tests (they are typically faster / the primary backend)
    [ -n "$_PY_TEST_CMD" ] && TEST_ALL="${_PY_TEST_CMD} && ${TEST_ALL}"
    [ -n "$_PY_TEST_COV" ] && TEST_COV="${_PY_TEST_COV} && ${TEST_COV}"
    # Detect Python linter (ruff preferred, fallback flake8)
    if [ -f "pyproject.toml" ] && grep -q 'ruff' pyproject.toml 2>/dev/null; then
      _PY_LINT="ruff check ."
      _PY_LINT_FIX="ruff check --fix ."
    elif command -v flake8 >/dev/null 2>&1 || [ -f ".flake8" ] || [ -f "setup.cfg" ]; then
      _PY_LINT="flake8 ."
      _PY_LINT_FIX="flake8 ."
    fi
    [ -n "$_PY_LINT" ] && LINT_CHECK="${_PY_LINT} && ${LINT_CHECK}"
    [ -n "$_PY_LINT_FIX" ] && LINT_FIX="${_PY_LINT_FIX} && ${LINT_FIX}"
    # Also expose standalone Python test command via secondary variable
    # shellcheck disable=SC2034  # Reserved for future multi-language test emit
    emit_secondary_test="$_PY_TEST_CMD"
  fi
  # If the package.json is in a subdirectory (e.g. web/), prefix commands with --prefix
  _PKG_SUBDIR=$(find . -maxdepth 2 -name 'package.json' \
    -not -path '*/node_modules/*' -not -path './.git/*' \
    -not -name './package.json' 2>/dev/null | head -1 || true)
  if [ -n "$_PKG_SUBDIR" ] && [ "$_PKG_SUBDIR" != "./package.json" ]; then
    _SUB=$(dirname "$_PKG_SUBDIR" | sed 's|^\./||')
    # Replace bare npm/yarn/pnpm commands with --prefix variant for the subdir package
    TEST_ALL="${TEST_ALL/#npm test/npm --prefix ${_SUB} test}"
    TEST_CI="${TEST_CI/#npm test/npm --prefix ${_SUB} test}"
    TEST_COV="${TEST_COV/#npm run coverage/npm --prefix ${_SUB} run coverage}"
    LINT_CHECK="${LINT_CHECK/#npm run lint/npm --prefix ${_SUB} run lint}"
    LINT_FIX="${LINT_FIX/#npm run lint/npm --prefix ${_SUB} run lint}"
    FORMAT_CMD="${FORMAT_CMD/#npm run prettier/npm --prefix ${_SUB} run prettier}"
  fi
fi

# Case B: Python primary + JS/TS frontend (e.g. Django + React, FastAPI + Svelte)
if [ "$PRIMARY_LANG" = "py" ]; then
  _JS_PKG=$(find . -maxdepth 2 -name 'package.json' \
    -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1 || true)
  if [ -n "$_JS_PKG" ]; then
    _JS_DIR=$(dirname "$_JS_PKG" | sed 's|^\./||')
    _JS_TEST=$(jq -r '.scripts.test // empty' "$_JS_PKG" 2>/dev/null || true)
    _JS_LINT=$(jq -r '.scripts.lint // empty' "$_JS_PKG" 2>/dev/null || true)
    [ -n "$_JS_TEST" ] && TEST_ALL="${TEST_ALL} && npm --prefix ${_JS_DIR} test"
    [ -n "$_JS_LINT" ] && LINT_CHECK="${LINT_CHECK} && npm --prefix ${_JS_DIR} run lint"
    [ -n "$_JS_LINT" ] && LINT_FIX="${LINT_FIX} && npm --prefix ${_JS_DIR} run lint:fix"
  fi
fi

echo "# --- Build Commands ---"
emit "BUILD_CMD_ALL" "$BUILD_ALL"
emit "BUILD_CMD_SINGLE" "$BUILD_SINGLE"
emit "BUILD_CMD_PACKAGES" "$BUILD_PKG"
emit "INSTALL_CMD" "$INSTALL_CMD"
emit "DEV_CMD" "$DEV_CMD"

# Deferred test emits — MUST come after Nx override AND script-first Fix 3
echo "# --- Test Framework ---"
emit "TEST_FRAMEWORK" "${TEST_FW:-unknown}"
emit "COVERAGE_TOOL" "${COVERAGE:-unknown}"
emit "E2E_FRAMEWORKS" "${E2E_FW%,}"
emit "TEST_CMD_ALL" "$TEST_ALL"
emit "TEST_CMD_SINGLE" "$TEST_SINGLE"
emit "TEST_CMD_CI" "$TEST_CI"
emit "TEST_CMD_COVERAGE" "$TEST_COV"

echo ""


# ─── Serve Commands ───────────────────────────────────────────────

echo "# --- Serve Commands ---"
# FIX 4: SERVE_CMD_ALL already adjusted above by script-first logic (DEV_CMD may now be 'pnpm serve').
emit "SERVE_CMD_ALL" "${DEV_CMD:-}"
emit "SERVE_CMD_SINGLE" "${BUILD_SINGLE:+${BUILD_SINGLE/ build/ dev}}"
emit "SERVE_CMD_FRONTEND" ""
emit "SERVE_CMD_BACKEND" ""

echo ""

# ─── Migration / DB Commands ──────────────────────────────────────

echo "# --- Database / Migration ---"
DB_TYPE="" MIGRATE_UP="" MIGRATE_DOWN="" MIGRATE_STATUS="" MIGRATE_CREATE=""
DB_SCHEMAS="" DB_TABLES="" DB_DESCRIBE="" DB_QUERY=""

# Fast detection: check package.json deps + top-level config files only (no full-repo scan)
HAS_PRISMA=false; HAS_KNEX=false; HAS_TYPEORM=false; HAS_ALEMBIC=false
HAS_DRIZZLE=false; HAS_SEQUELIZE=false; HAS_MIKROORM=false; HAS_DJANGO=false
if [ -f "package.json" ]; then
  PKG_DEPS=$(jq -r '(.dependencies // {} | keys[]) , (.devDependencies // {} | keys[])' package.json 2>/dev/null || true)
  echo "$PKG_DEPS" | grep -q '^prisma$\|^@prisma' && HAS_PRISMA=true
  echo "$PKG_DEPS" | grep -q '^knex$' && HAS_KNEX=true
  echo "$PKG_DEPS" | grep -q '^typeorm$' && HAS_TYPEORM=true
  echo "$PKG_DEPS" | grep -q '^drizzle-orm$' && HAS_DRIZZLE=true
  echo "$PKG_DEPS" | grep -q '^sequelize$' && HAS_SEQUELIZE=true
  echo "$PKG_DEPS" | grep -q '^@mikro-orm' && HAS_MIKROORM=true
fi
[ -d "prisma" ] || [ -f "prisma/schema.prisma" ] && HAS_PRISMA=true
[ -f "knexfile.js" ] || [ -f "knexfile.ts" ] && HAS_KNEX=true
[ -f "alembic.ini" ] || [ -d "alembic" ] && HAS_ALEMBIC=true
[ -f "manage.py" ] && grep -q 'django' manage.py 2>/dev/null && HAS_DJANGO=true

if $HAS_PRISMA; then
  DB_TYPE="prisma"
  MIGRATE_UP="npx prisma migrate deploy"; MIGRATE_DOWN="npx prisma migrate reset"
  MIGRATE_STATUS="npx prisma migrate status"; MIGRATE_CREATE="npx prisma migrate dev --name"
elif $HAS_DRIZZLE; then
  DB_TYPE="drizzle"
  MIGRATE_UP="npx drizzle-kit push"; MIGRATE_DOWN="npx drizzle-kit drop"
  MIGRATE_STATUS="npx drizzle-kit check"; MIGRATE_CREATE="npx drizzle-kit generate"
elif $HAS_KNEX; then
  DB_TYPE="knex"
  MIGRATE_UP="npx knex migrate:latest"; MIGRATE_DOWN="npx knex migrate:rollback"
  MIGRATE_STATUS="npx knex migrate:status"; MIGRATE_CREATE="npx knex migrate:make"
elif $HAS_TYPEORM; then
  DB_TYPE="typeorm"
  MIGRATE_UP="npx typeorm migration:run"; MIGRATE_DOWN="npx typeorm migration:revert"
  MIGRATE_STATUS="npx typeorm migration:show"; MIGRATE_CREATE="npx typeorm migration:create"
elif $HAS_ALEMBIC; then
  DB_TYPE="alembic"
  MIGRATE_UP="alembic upgrade head"; MIGRATE_DOWN="alembic downgrade -1"
  MIGRATE_STATUS="alembic history"; MIGRATE_CREATE="alembic revision --autogenerate -m"
elif [ -f "Gemfile" ] && grep -q 'activerecord\|rails' Gemfile 2>/dev/null; then
  DB_TYPE="activerecord"
  MIGRATE_UP="rails db:migrate"; MIGRATE_DOWN="rails db:rollback"
  MIGRATE_STATUS="rails db:migrate:status"; MIGRATE_CREATE="rails generate migration"
elif $HAS_DJANGO; then
  DB_TYPE="django"
  MIGRATE_UP="python manage.py migrate"; MIGRATE_DOWN="python manage.py migrate <app> <migration>"
  MIGRATE_STATUS="python manage.py showmigrations"; MIGRATE_CREATE="python manage.py makemigrations"
elif $HAS_SEQUELIZE; then
  DB_TYPE="sequelize"
  MIGRATE_UP="npx sequelize-cli db:migrate"; MIGRATE_DOWN="npx sequelize-cli db:migrate:undo"
  MIGRATE_STATUS="npx sequelize-cli db:migrate:status"; MIGRATE_CREATE="npx sequelize-cli migration:generate --name"
elif $HAS_MIKROORM; then
  DB_TYPE="mikro-orm"
  MIGRATE_UP="npx mikro-orm migration:up"; MIGRATE_DOWN="npx mikro-orm migration:down"
  MIGRATE_STATUS="npx mikro-orm migration:list"; MIGRATE_CREATE="npx mikro-orm migration:create"
fi

# Diesel (Rust ORM) — separate check since it uses Cargo.toml
if [ -z "$DB_TYPE" ] && [ -f "Cargo.toml" ] && grep -q 'diesel' Cargo.toml 2>/dev/null; then
  DB_TYPE="diesel"
  MIGRATE_UP="diesel migration run"; MIGRATE_DOWN="diesel migration revert"
  MIGRATE_STATUS="diesel migration list"; MIGRATE_CREATE="diesel migration generate"
fi

# EF Core (.NET) — separate check
if [ -z "$DB_TYPE" ]; then
  for csproj in $(find . -maxdepth 3 -name '*.csproj' 2>/dev/null | head -3); do
    if grep -q 'EntityFrameworkCore' "$csproj" 2>/dev/null; then
      DB_TYPE="ef-core"
      MIGRATE_UP="dotnet ef database update"; MIGRATE_DOWN="dotnet ef database update <previous>"
      MIGRATE_STATUS="dotnet ef migrations list"; MIGRATE_CREATE="dotnet ef migrations add"
      break
    fi
  done
fi

# Flyway (Java) — check pom.xml and build.gradle
if [ -z "$DB_TYPE" ]; then
  for _pom in $(find . -maxdepth 3 -name 'pom.xml' -not -path '*/target/*' -not -path '*/.git/*' 2>/dev/null | head -5); do
    if grep -q 'flyway' "$_pom" 2>/dev/null; then
      DB_TYPE="flyway"
      MIGRATE_UP="flyway migrate"; MIGRATE_DOWN="flyway undo"
      MIGRATE_STATUS="flyway info"; MIGRATE_CREATE="flyway migrate -baselineOnMigrate=true"
      break
    fi
  done
fi
if [ -z "$DB_TYPE" ] && { [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; }; then
  GRADLE_F=""; for _f in build.gradle build.gradle.kts; do [ -f "$_f" ] && GRADLE_F="$_f" && break; done
  if grep -q 'flyway' "$GRADLE_F" 2>/dev/null; then
    DB_TYPE="flyway"
    MIGRATE_UP="gradle flywayMigrate"; MIGRATE_DOWN="gradle flywayUndo"
    MIGRATE_STATUS="gradle flywayInfo"; MIGRATE_CREATE=""
  fi
fi

# Liquibase (Java)
if [ -z "$DB_TYPE" ]; then
  for _pom in $(find . -maxdepth 3 -name 'pom.xml' -not -path '*/target/*' -not -path '*/.git/*' 2>/dev/null | head -5); do
    if grep -q 'liquibase' "$_pom" 2>/dev/null; then
      DB_TYPE="liquibase"
      MIGRATE_UP="liquibase update"; MIGRATE_DOWN="liquibase rollback-count 1"
      MIGRATE_STATUS="liquibase status"; MIGRATE_CREATE="liquibase generate-changelog"
      break
    fi
  done
fi

# Ecto (Elixir)
if [ -z "$DB_TYPE" ] && [ -f "mix.exs" ] && grep -q 'ecto' mix.exs 2>/dev/null; then
  DB_TYPE="ecto"
  MIGRATE_UP="mix ecto.migrate"; MIGRATE_DOWN="mix ecto.rollback"
  MIGRATE_STATUS="mix ecto.migrations"; MIGRATE_CREATE="mix ecto.gen.migration"
fi

# Goose (Go)
if [ -z "$DB_TYPE" ] && [ -f "go.mod" ] && grep -q 'pressly/goose\|goose' go.mod 2>/dev/null; then
  DB_TYPE="goose"
  MIGRATE_UP="goose up"; MIGRATE_DOWN="goose down"
  MIGRATE_STATUS="goose status"; MIGRATE_CREATE="goose create"
fi

# SQLx (Rust)
if [ -z "$DB_TYPE" ] && [ -f "Cargo.toml" ] && grep -q 'sqlx' Cargo.toml 2>/dev/null; then
  DB_TYPE="sqlx"
  MIGRATE_UP="sqlx migrate run"; MIGRATE_DOWN="sqlx migrate revert"
  MIGRATE_STATUS="sqlx migrate info"; MIGRATE_CREATE="sqlx migrate add"
fi

for cfg in package.json docker-compose.yml docker-compose.yaml compose.yml compose.yaml .env .env.example; do
  [ -f "$cfg" ] || continue
  if grep -qiE 'postgres|postgresql|pg_' "$cfg" 2>/dev/null; then DB_ENGINE="postgresql"; break; fi
  if grep -qiE 'mysql|mariadb' "$cfg" 2>/dev/null; then DB_ENGINE="mysql"; break; fi
  if grep -qiE 'sqlite' "$cfg" 2>/dev/null; then DB_ENGINE="sqlite"; break; fi
  if grep -qiE 'mongodb|mongoose' "$cfg" 2>/dev/null; then DB_ENGINE="mongodb"; break; fi
  if grep -qiE 'redis' "$cfg" 2>/dev/null; then DB_ENGINE="redis"; break; fi
done

# Also check Prisma schema — most reliable source
if [ -z "$DB_ENGINE" ] && [ -f "prisma/schema.prisma" ]; then
  PRISMA_PROVIDER=$(grep -E '^[[:space:]]*provider[[:space:]]*=' prisma/schema.prisma 2>/dev/null | head -1 | awk -F'"' '{print $2}' || true)
  if [ -n "$PRISMA_PROVIDER" ]; then DB_ENGINE="$PRISMA_PROVIDER"; fi
fi

case "$DB_ENGINE" in
  postgresql)
    DB_SCHEMAS="psql -c '\\dn'"; DB_TABLES="psql -c '\\dt'"; DB_DESCRIBE="psql -c '\\d+'"
    DB_QUERY="psql -c"
    [ -z "$DB_TYPE" ] && DB_TYPE="postgresql"
    ;;
  mysql)
    DB_SCHEMAS="mysql -e 'SHOW DATABASES'"; DB_TABLES="mysql -e 'SHOW TABLES'"; DB_DESCRIBE="mysql -e 'DESCRIBE'"
    DB_QUERY="mysql -e"
    [ -z "$DB_TYPE" ] && DB_TYPE="mysql"
    ;;
  sqlite)
    # SQLite path is configured at runtime — use DB_PATH env var with no hardcoded default.
    # The bootstrap will emit these as-is; the user must set DB_PATH or substitute manually.
    DB_TABLES=$'sqlite3 "$DB_PATH" ".tables"'
    DB_DESCRIBE=$'sqlite3 "$DB_PATH" ".schema <table>"'
    DB_QUERY=$'sqlite3 "$DB_PATH"'
    DB_SCHEMAS=""   # SQLite has no schemas
    [ -z "$DB_TYPE" ] && DB_TYPE="sqlite"
    ;;
  mongodb)
    DB_SCHEMAS="mongosh --eval 'db.adminCommand({listDatabases:1})' --quiet"
    DB_TABLES="mongosh --eval 'db.getCollectionNames()' --quiet"
    DB_DESCRIBE="mongosh --eval 'db.<collection>.findOne()' --quiet"
    DB_QUERY="mongosh --eval"
    [ -z "$DB_TYPE" ] && DB_TYPE="mongodb"
    ;;
esac

# FIX 8: Infer DB commands from package.json pg/pg-promise dependency when engine not found in config.
# knex+pg is a very common combo; the knexfile may not be in standard locations.
if [ -z "$DB_SCHEMAS" ] && [ -f "package.json" ]; then
  _ALL_WORKSPACE_DEPS=$(find . -maxdepth 4 -name 'package.json' \
    -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/.git/*' \
    -not -path '*/.*/*' \
    2>/dev/null | head -30 | \
    xargs -IFILE jq -r '(.dependencies // {} | keys[]) , (.devDependencies // {} | keys[])' FILE 2>/dev/null || true)
  if echo "$_ALL_WORKSPACE_DEPS" | grep -q '^pg$\|^pg-promise$\|^postgres$\|^@neondatabase'; then
    DB_SCHEMAS="psql \$DATABASE_URL -c '\\dn'"
    DB_TABLES="psql \$DATABASE_URL -c '\\dt'"
    DB_DESCRIBE="psql \$DATABASE_URL -c '\\d <table>'"
    DB_QUERY="psql \$DATABASE_URL -c 'SELECT ...'"
    [ -z "$DB_TYPE" ] && DB_TYPE="${DB_TYPE:-knex}"
  fi
fi

# FIX 5: Migration script-first — prefer package.json scripts over reconstructed npx/alembic commands.
# Projects often wrap migration tools with extra flags (multi-tenant iteration, env loading, etc.).
if [ -f "package.json" ] && [ -n "$PKG_MGR" ]; then
  _MIG_UP=$(jq -r '.scripts["db:migrate"] // .scripts["migrate"] // .scripts["migrate:latest"] // empty' package.json 2>/dev/null || true)
  _MIG_DOWN=$(jq -r '.scripts["db:rollback"] // .scripts["migrate:rollback"] // empty' package.json 2>/dev/null || true)
  _MIG_STATUS=$(jq -r '.scripts["db:status"] // .scripts["migrate:status"] // empty' package.json 2>/dev/null || true)
  _MIG_CREATE=$(jq -r '.scripts["db:create"] // .scripts["migrate:make"] // .scripts["migrate:create"] // empty' package.json 2>/dev/null || true)
  [ -n "$_MIG_UP" ] && MIGRATE_UP="$(pkg_cmd db:migrate)"
  [ -n "$_MIG_DOWN" ] && MIGRATE_DOWN="$(pkg_cmd db:rollback)"
  [ -n "$_MIG_STATUS" ] && MIGRATE_STATUS="$(pkg_cmd db:status)"
  [ -n "$_MIG_CREATE" ] && MIGRATE_CREATE="$(pkg_cmd db:create)"
fi

emit "DATABASE" "${DB_TYPE:-none}"
emit "MIGRATE_UP_CMD" "$MIGRATE_UP"
emit "MIGRATE_DOWN_CMD" "$MIGRATE_DOWN"
emit "MIGRATE_STATUS_CMD" "$MIGRATE_STATUS"
emit "MIGRATE_CREATE_CMD" "$MIGRATE_CREATE"
emit "DB_LIST_SCHEMAS_CMD" "$DB_SCHEMAS"
emit "DB_LIST_TABLES_CMD" "$DB_TABLES"
emit "DB_DESCRIBE_CMD" "$DB_DESCRIBE"
emit "DB_QUERY_CMD" "$DB_QUERY"

echo ""

# ─── Dependency Management Commands ───────────────────────────────

echo "# --- Dependency Management ---"
DEPS_OUTDATED="" DEPS_UPDATE="" DEPS_WHY="" DEPS_DEDUPE=""

case "$PKG_MGR" in
  pnpm) DEPS_OUTDATED="pnpm outdated"; DEPS_UPDATE="pnpm update"; DEPS_WHY="pnpm why"; DEPS_DEDUPE="pnpm dedupe" ;;
  npm) DEPS_OUTDATED="npm outdated"; DEPS_UPDATE="npm update"; DEPS_WHY="npm explain"; DEPS_DEDUPE="npm dedupe" ;;
  yarn) DEPS_OUTDATED="yarn outdated"; DEPS_UPDATE="yarn upgrade"; DEPS_WHY="yarn why"; DEPS_DEDUPE="yarn dedupe" ;;
  pip) DEPS_OUTDATED="pip list --outdated"; DEPS_UPDATE="pip install --upgrade"; DEPS_WHY="pip show"; DEPS_DEDUPE="" ;;
  poetry) DEPS_OUTDATED="poetry show --outdated"; DEPS_UPDATE="poetry update"; DEPS_WHY="poetry show"; DEPS_DEDUPE="" ;;
  cargo) DEPS_OUTDATED="cargo outdated"; DEPS_UPDATE="cargo update -p"; DEPS_WHY="cargo tree -i"; DEPS_DEDUPE="" ;;
  go*) DEPS_OUTDATED="go list -u -m all"; DEPS_UPDATE="go get -u"; DEPS_WHY="go mod why"; DEPS_DEDUPE="go mod tidy" ;;
  maven) DEPS_OUTDATED="mvn versions:display-dependency-updates"; DEPS_UPDATE="mvn versions:use-latest-releases"; DEPS_WHY="mvn dependency:tree"; DEPS_DEDUPE="" ;;
  bun) DEPS_OUTDATED="bun outdated"; DEPS_UPDATE="bun update"; DEPS_WHY="bun pm ls"; DEPS_DEDUPE="" ;;
  deno) DEPS_OUTDATED="deno info"; DEPS_UPDATE="deno cache --reload"; DEPS_WHY="deno info"; DEPS_DEDUPE="" ;;
  bundler) DEPS_OUTDATED="bundle outdated"; DEPS_UPDATE="bundle update"; DEPS_WHY="bundle info"; DEPS_DEDUPE="" ;;
  uv) DEPS_OUTDATED="uv pip list --outdated"; DEPS_UPDATE="uv pip install --upgrade"; DEPS_WHY="uv pip show"; DEPS_DEDUPE="uv sync" ;;
  pdm) DEPS_OUTDATED="pdm outdated"; DEPS_UPDATE="pdm update"; DEPS_WHY="pdm show"; DEPS_DEDUPE="pdm lock" ;;
  hatch) DEPS_OUTDATED="pip list --outdated"; DEPS_UPDATE="pip install --upgrade"; DEPS_WHY="pip show"; DEPS_DEDUPE="" ;;
  mix) DEPS_OUTDATED="mix hex.outdated"; DEPS_UPDATE="mix deps.update --all"; DEPS_WHY="mix deps"; DEPS_DEDUPE="" ;;
  pub)
    if [ -f "pubspec.yaml" ] && grep -q 'flutter:' pubspec.yaml 2>/dev/null; then
      DEPS_OUTDATED="flutter pub outdated"; DEPS_UPDATE="flutter pub upgrade"; DEPS_WHY="flutter pub deps"; DEPS_DEDUPE=""
    else
      DEPS_OUTDATED="dart pub outdated"; DEPS_UPDATE="dart pub upgrade"; DEPS_WHY="dart pub deps"; DEPS_DEDUPE=""
    fi
    ;;
  sbt) DEPS_OUTDATED="sbt dependencyUpdates"; DEPS_UPDATE="sbt update"; DEPS_WHY="sbt dependencyTree"; DEPS_DEDUPE="" ;;
  composer) DEPS_OUTDATED="composer outdated"; DEPS_UPDATE="composer update"; DEPS_WHY="composer depends"; DEPS_DEDUPE="" ;;
  swift-package-manager) DEPS_OUTDATED="swift package show-dependencies"; DEPS_UPDATE="swift package update"; DEPS_WHY="swift package show-dependencies"; DEPS_DEDUPE="" ;;
  stack) DEPS_OUTDATED="stack list-dependencies"; DEPS_UPDATE="stack update"; DEPS_WHY="stack ls dependencies"; DEPS_DEDUPE="" ;;
  cabal) DEPS_OUTDATED="cabal list --installed"; DEPS_UPDATE="cabal update && cabal install"; DEPS_WHY="cabal info"; DEPS_DEDUPE="" ;;
  dune*) DEPS_OUTDATED="opam list --upgradable"; DEPS_UPDATE="opam update && opam upgrade"; DEPS_WHY="opam show"; DEPS_DEDUPE="" ;;
  lein) DEPS_OUTDATED="lein ancient"; DEPS_UPDATE="lein deps"; DEPS_WHY="lein deps :tree"; DEPS_DEDUPE="" ;;
  clojure-cli) DEPS_OUTDATED="clojure -M:outdated"; DEPS_UPDATE="clojure -M:deps prep"; DEPS_WHY="clojure -Stree"; DEPS_DEDUPE="" ;;
  renv) DEPS_OUTDATED='Rscript -e "renv::status()"'; DEPS_UPDATE='Rscript -e "renv::update()"'; DEPS_WHY='Rscript -e "packageDescription()"'; DEPS_DEDUPE='Rscript -e "renv::snapshot()"' ;;
  julia-pkg) DEPS_OUTDATED="julia -e 'using Pkg; Pkg.status(outdated=true)'"; DEPS_UPDATE="julia -e 'using Pkg; Pkg.update()'"; DEPS_WHY="julia -e 'using Pkg; Pkg.status()'"; DEPS_DEDUPE="" ;;
  cpanm) DEPS_OUTDATED="cpan-outdated"; DEPS_UPDATE="cpanm --installdeps ."; DEPS_WHY="perldoc"; DEPS_DEDUPE="" ;;
  cmake) DEPS_OUTDATED=""; DEPS_UPDATE=""; DEPS_WHY=""; DEPS_DEDUPE="" ;;
  gradle) DEPS_OUTDATED="gradle dependencyUpdates"; DEPS_UPDATE="gradle dependencies"; DEPS_WHY="gradle dependencyInsight"; DEPS_DEDUPE="" ;;
esac

emit "DEPS_OUTDATED_CMD" "$DEPS_OUTDATED"
emit "DEPS_UPDATE_CMD" "$DEPS_UPDATE"
emit "DEPS_WHY_CMD" "$DEPS_WHY"
emit "DEPS_DEDUPE_CMD" "$DEPS_DEDUPE"

echo ""

# ─── Security Scanner ─────────────────────────────────────────────

echo "# --- Security ---"
SCANNER="" SCAN_CMD=""
# FIX 6: Multiple scanners — detect ALL active scanners, not just the first one found.
# Many enterprise repos use SonarQube (SAST) + Trivy (CVE/container scanning) simultaneously.
SCANNER="" SCAN_CMD=""
if find . -maxdepth 4 -name 'sonar-project.properties' 2>/dev/null | head -1 | grep -q '.'; then
  SCANNER="SonarQube"; SCAN_CMD="sonar-scanner"
fi
if [ -f "trivy.yaml" ] || [ -f ".trivy.yaml" ] || [ -f ".trivyignore" ]; then
  [ -n "$SCANNER" ] && SCANNER="${SCANNER}+Trivy" || SCANNER="Trivy"
  [ -n "$SCAN_CMD" ] && SCAN_CMD="${SCAN_CMD} / trivy fs ." || SCAN_CMD="trivy fs ."
fi
if [ -z "$SCANNER" ]; then
  if [ -f ".semgrepignore" ] || [ -f "semgrep.yml" ] || find . -maxdepth 2 -name '.semgrep.yml' 2>/dev/null | head -1 | grep -q '.'; then
    SCANNER="Semgrep"; SCAN_CMD="semgrep --config=auto ."
  elif command -v snyk &>/dev/null; then
    SCANNER="Snyk"; SCAN_CMD="snyk test"
  elif [ "$PKG_MGR" = "npm" ] || [ "$PKG_MGR" = "pnpm" ] || [ "$PKG_MGR" = "yarn" ] || [ "$PKG_MGR" = "bun" ]; then
    SCANNER="${PKG_MGR} audit"; SCAN_CMD="${PKG_MGR} audit"
  elif [ "$PKG_MGR" = "pip" ] || [ "$PKG_MGR" = "poetry" ] || [ "$PKG_MGR" = "pdm" ] || [ "$PKG_MGR" = "uv" ]; then
    SCANNER="pip-audit"; SCAN_CMD="pip-audit"
  elif [ "$PKG_MGR" = "cargo" ]; then
    SCANNER="cargo-audit"; SCAN_CMD="cargo audit"
  elif [ "$PKG_MGR" = "go modules" ]; then
    SCANNER="govulncheck"; SCAN_CMD="govulncheck ./..."
  fi
fi
emit "SCANNER_TOOL" "$SCANNER"
emit "SCAN_COMMAND" "$SCAN_CMD"

echo ""

# ─── Architecture ─────────────────────────────────────────────────

echo "# --- Architecture ---"
# Monorepo already detected early (before Formatter/Linter) — just emit
emit "MONOREPO" "$MONOREPO"
emit "MONOREPO_TOOL" "$MONOREPO_TOOL"

# CI System
CI=""
[ -d ".github/workflows" ] && CI="github-actions"
[ -f ".gitlab-ci.yml" ] && CI="${CI:+$CI+}gitlab-ci"
[ -f "Jenkinsfile" ] && CI="${CI:+$CI+}jenkins"
[ -d ".circleci" ] && CI="${CI:+$CI+}circleci"
[ -f "azure-pipelines.yml" ] && CI="${CI:+$CI+}azure-devops"
[ -f "bitbucket-pipelines.yml" ] && CI="${CI:+$CI+}bitbucket"
[ -f ".travis.yml" ] && CI="${CI:+$CI+}travis"
[ -f ".drone.yml" ] || [ -f ".drone.yaml" ] && CI="${CI:+$CI+}drone"
[ -d ".buildkite" ] && CI="${CI:+$CI+}buildkite"
[ -f ".woodpecker.yml" ] || [ -f ".woodpecker.yaml" ] || [ -d ".woodpecker" ] && CI="${CI:+$CI+}woodpecker"
[ -f "codefresh.yml" ] && CI="${CI:+$CI+}codefresh"
[ -f "cloudbuild.yaml" ] || [ -f "cloudbuild.yml" ] && CI="${CI:+$CI+}google-cloud-build"
[ -f "buildspec.yml" ] || [ -f "buildspec.yaml" ] && CI="${CI:+$CI+}aws-codebuild"
[ -f "Earthfile" ] && CI="${CI:+$CI+}earthly"
[ -f "Taskfile.yml" ] || [ -f "Taskfile.yaml" ] && CI="${CI:+$CI+}taskfile"
[ -f "Makefile" ] || [ -f "makefile" ] || [ -f "GNUmakefile" ] && CI="${CI:+$CI+}make"
[ -f "Justfile" ] && CI="${CI:+$CI+}just"
[ -f "Rakefile" ] && CI="${CI:+$CI+}rake"
if [ -d ".tekton" ] || find . -maxdepth 2 -name 'tekton*.yaml' 2>/dev/null | head -1 | grep -q '.'; then CI="${CI:+$CI+}tekton"; fi
[ -f "Tiltfile" ] && CI="${CI:+$CI+}tilt"
emit "CI_SYSTEM" "${CI:-none}"

# Docker
DOCKER="false"
if [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] || \
   [ -f "compose.yml" ] || [ -f "compose.yaml" ] || \
   find . -maxdepth 3 -name 'Dockerfile*' -type f 2>/dev/null | head -1 | grep -q '.'; then
  DOCKER="true"
fi
emit "DOCKER" "$DOCKER"

# Shell
emit "SHELL_NAME" "$(basename "${SHELL:-/bin/bash}")"

# Case-statement glob patterns for edit-accumulator.sh
# Format: *.ext1|*.ext2  (shell case separator, NOT regex) — pipe-immune by design.
# The | here is a shell keyword in `case`, never misinterpreted as a command pipe.
# Includes BOTH primary AND secondary language extensions (for dual-language repos).
CASE_EXT=""
case "$PRIMARY_LANG" in
  ts|tsx|js|jsx) CASE_EXT='*.js|*.ts|*.tsx|*.jsx|*.json|*.css|*.scss|*.html|*.vue|*.svelte|*.astro' ;;
  py)            CASE_EXT='*.py|*.pyi' ;;
  go)            CASE_EXT='*.go' ;;
  rs)            CASE_EXT='*.rs|*.toml' ;;
  java|kt)       CASE_EXT='*.java|*.kt|*.kts|*.xml' ;;
  scala)         CASE_EXT='*.scala|*.sbt|*.sc' ;;
  groovy)        CASE_EXT='*.groovy|*.gvy|*.gradle' ;;
  rb)            CASE_EXT='*.rb|*.erb|*.rake|*.gemspec' ;;
  php)           CASE_EXT='*.php' ;;
  cs)            CASE_EXT='*.cs|*.razor|*.cshtml|*.vb' ;;
  c)             CASE_EXT='*.c|*.h' ;;
  cpp)           CASE_EXT='*.cpp|*.hpp|*.cc|*.hh|*.cxx|*.hxx|*.h' ;;
  swift)         CASE_EXT='*.swift' ;;
  dart)          CASE_EXT='*.dart|*.yaml' ;;
  sh)            CASE_EXT='*.sh|*.bash|*.zsh|*.yaml|*.yml' ;;
  ex)            CASE_EXT='*.ex|*.exs|*.heex|*.leex' ;;
  lua)           CASE_EXT='*.lua' ;;
  zig)           CASE_EXT='*.zig' ;;
  m)             CASE_EXT='*.m|*.mm|*.h' ;;
  pl)            CASE_EXT='*.pl|*.pm|*.t' ;;
  clj)           CASE_EXT='*.clj|*.cljs|*.cljc|*.edn' ;;
  ml)            CASE_EXT='*.ml|*.mli' ;;
  hs)            CASE_EXT='*.hs|*.lhs' ;;
  r)             CASE_EXT='*.r|*.R|*.Rmd' ;;
  jl)            CASE_EXT='*.jl' ;;
  sql)           CASE_EXT='*.sql' ;;
  proto)         CASE_EXT='*.proto' ;;
  graphql)       CASE_EXT='*.graphql|*.gql' ;;
  *)             CASE_EXT='*.js|*.ts|*.py|*.go|*.rs|*.java|*.json|*.css|*.html' ;;
esac

# Merge secondary language extensions (deduplication via associative array)
# This ensures dual-language repos (e.g., Python backend + React frontend) accumulate ALL formattable files.
declare -A _EXT_SEEN
for _e in $(echo "$CASE_EXT" | tr '|' ' '); do _EXT_SEEN["$_e"]=1; done
for _sec in $(echo "${SECONDARY_LANGS%,}" | tr ',' ' '); do
  [ -z "$_sec" ] && continue
  _SEC_EXT=""
  case "$_sec" in
    ts|tsx|js|jsx|mts|cts|mjs|cjs) _SEC_EXT='*.js *.ts *.tsx *.jsx *.json *.css *.scss *.html *.vue *.svelte *.astro' ;;
    py)            _SEC_EXT='*.py *.pyi' ;;
    go)            _SEC_EXT='*.go' ;;
    rs)            _SEC_EXT='*.rs' ;;
    java|kt)       _SEC_EXT='*.java *.kt *.kts' ;;
    scala)         _SEC_EXT='*.scala *.sbt' ;;
    groovy)        _SEC_EXT='*.groovy *.gvy' ;;
    rb)            _SEC_EXT='*.rb *.erb *.rake' ;;
    php)           _SEC_EXT='*.php' ;;
    cs)            _SEC_EXT='*.cs *.vb' ;;
    c)             _SEC_EXT='*.c *.h' ;;
    cpp)           _SEC_EXT='*.cpp *.hpp *.cc *.hh *.h' ;;
    swift)         _SEC_EXT='*.swift' ;;
    dart)          _SEC_EXT='*.dart' ;;
    sh)            _SEC_EXT='*.sh *.bash *.zsh' ;;
    ex)            _SEC_EXT='*.ex *.exs' ;;
    lua)           _SEC_EXT='*.lua' ;;
    zig)           _SEC_EXT='*.zig' ;;
    m)             _SEC_EXT='*.m *.mm' ;;
    pl)            _SEC_EXT='*.pl *.pm' ;;
    clj)           _SEC_EXT='*.clj *.cljs *.cljc' ;;
    ml)            _SEC_EXT='*.ml *.mli' ;;
    hs)            _SEC_EXT='*.hs' ;;
    r)             _SEC_EXT='*.r *.R' ;;
    jl)            _SEC_EXT='*.jl' ;;
    sql)           _SEC_EXT='*.sql' ;;
    proto)         _SEC_EXT='*.proto' ;;
    graphql)       _SEC_EXT='*.graphql *.gql' ;;
  esac
  for _e in $_SEC_EXT; do
    if [ -z "${_EXT_SEEN[$_e]:-}" ]; then
      CASE_EXT="${CASE_EXT}|${_e}"
      _EXT_SEEN["$_e"]=1
    fi
  done
done
unset _EXT_SEEN _SEC_EXT _sec _e
printf 'CASE_EXTENSIONS=%s\n' "$CASE_EXT"


echo ""

# ─── Top-Level Directory Listing ──────────────────────────────────

echo "# --- Directory Structure ---"
# L2: Use find instead of ls (zsh no-match safe, locale-independent)
TOP_DIRS=$(find . -maxdepth 1 -mindepth 1 -type d -not -name '.*' 2>/dev/null | sed 's|^\./||' | sort | tr '\n' ',' | sed 's/,$//')
echo "TOP_DIRS=${TOP_DIRS}"

# H4: Service/package discovery for monorepos
# Scan MULTIPLE service directories — real monorepos have services in several places
# e.g. core/ (Node.js), components/internal/ (Java), components/external/ (infra)
ALL_SERVICE_DIRS=""
ALL_SERVICES=""
SHARED_PACKAGES=""

# Level-1 candidates: core/, services/, apps/, backend/, src/
for candidate in core services apps backend src; do
  if [ -d "$candidate" ] && [ "$(find "$candidate" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)" -gt 1 ]; then
    ALL_SERVICE_DIRS="${ALL_SERVICE_DIRS}${candidate},"
    SVC_LIST=$(find "$candidate" -maxdepth 1 -mindepth 1 -type d -not -name 'packages' -not -name 'libs' -not -name 'shared' -not -name 'node_modules' 2>/dev/null | sed "s|^${candidate}/||" | sort)
    ALL_SERVICES="${ALL_SERVICES}${SVC_LIST}"$'\n'
    # Detect shared packages inside service dir (e.g. core/packages/)
    for pkgsub in packages libs shared; do
      if [ -d "${candidate}/${pkgsub}" ]; then
        PKG_LIST=$(find "${candidate}/${pkgsub}" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sed "s|^${candidate}/${pkgsub}/||" | sort | tr '\n' ',' | sed 's/,$//')
        if [ -n "$PKG_LIST" ]; then SHARED_PACKAGES="${SHARED_PACKAGES}${PKG_LIST},"; fi
      fi
    done
  fi
done

# Level-2 candidates: components/internal/, components/external/ (nested service dirs)
for nested in components/internal components/external modules/internal modules/external; do
  if [ -d "$nested" ] && [ "$(find "$nested" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)" -gt 0 ]; then
    ALL_SERVICE_DIRS="${ALL_SERVICE_DIRS}${nested},"
    SVC_LIST=$(find "$nested" -maxdepth 1 -mindepth 1 -type d -not -name 'packages' -not -name 'node_modules' 2>/dev/null | sed "s|^${nested}/||" | sort)
    ALL_SERVICES="${ALL_SERVICES}${SVC_LIST}"$'\n'
  fi
done

# Top-level shared packages (packages/, libs/, shared/)
for pkgdir in packages libs shared; do
  if [ -d "$pkgdir" ]; then
    PKG_LIST=$(find "$pkgdir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sed "s|^${pkgdir}/||" | sort | tr '\n' ',' | sed 's/,$//')
    if [ -n "$PKG_LIST" ]; then SHARED_PACKAGES="${SHARED_PACKAGES}${PKG_LIST},"; fi
  fi
done

# Deduplicate and format
ALL_SERVICE_DIRS=$(echo "${ALL_SERVICE_DIRS%,}" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
SERVICES=$(echo "$ALL_SERVICES" | grep -v '^$' | sort -u | head -50 | tr '\n' ',' | sed 's/,$//')
SERVICE_COUNT=$(echo "$ALL_SERVICES" | grep -v '^$' | sort -u | wc -l | tr -d ' ')
SHARED_PACKAGES=$(echo "${SHARED_PACKAGES%,}" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')

emit "SERVICE_DIR" "$ALL_SERVICE_DIRS"
emit "SERVICE_COUNT" "$SERVICE_COUNT"
emit "SERVICES" "$SERVICES"
emit "SHARED_PACKAGES" "$SHARED_PACKAGES"

# Frameworks detected
echo ""
echo "# --- Frameworks ---"
FRAMEWORKS=""

# ── Node.js / JavaScript / TypeScript ──
if [ -f "package.json" ]; then
  DEPS=$(jq -r '(.dependencies // {} | keys[]) , (.devDependencies // {} | keys[])' package.json 2>/dev/null || true)  # Backend
  echo "$DEPS" | grep -q '^@nestjs' && FRAMEWORKS="${FRAMEWORKS}NestJS,"
  echo "$DEPS" | grep -q '^express$' && FRAMEWORKS="${FRAMEWORKS}Express,"
  echo "$DEPS" | grep -q '^fastify$' && FRAMEWORKS="${FRAMEWORKS}Fastify,"
  echo "$DEPS" | grep -q '^koa$' && FRAMEWORKS="${FRAMEWORKS}Koa,"
  echo "$DEPS" | grep -q '^hono$' && FRAMEWORKS="${FRAMEWORKS}Hono,"
  echo "$DEPS" | grep -q '^@hapi' && FRAMEWORKS="${FRAMEWORKS}Hapi,"
  echo "$DEPS" | grep -q '^@adonisjs' && FRAMEWORKS="${FRAMEWORKS}AdonisJS,"
  echo "$DEPS" | grep -q '^elysia$' && FRAMEWORKS="${FRAMEWORKS}Elysia,"
  echo "$DEPS" | grep -q '^@trpc' && FRAMEWORKS="${FRAMEWORKS}tRPC,"
  echo "$DEPS" | grep -q '^graphql$\|^@apollo' && FRAMEWORKS="${FRAMEWORKS}GraphQL,"
  echo "$DEPS" | grep -q '^socket.io$\|^ws$' && FRAMEWORKS="${FRAMEWORKS}WebSocket,"
  # Frontend
  echo "$DEPS" | grep -q '^react$\|^react-dom$' && FRAMEWORKS="${FRAMEWORKS}React,"
  echo "$DEPS" | grep -q '^next$' && FRAMEWORKS="${FRAMEWORKS}Next.js,"
  echo "$DEPS" | grep -q '^vue$' && FRAMEWORKS="${FRAMEWORKS}Vue,"
  echo "$DEPS" | grep -q '^nuxt$' && FRAMEWORKS="${FRAMEWORKS}Nuxt,"
  echo "$DEPS" | grep -q '^@angular' && FRAMEWORKS="${FRAMEWORKS}Angular,"
  echo "$DEPS" | grep -q '^svelte$' && FRAMEWORKS="${FRAMEWORKS}Svelte,"
  echo "$DEPS" | grep -q '^@sveltejs/kit' && FRAMEWORKS="${FRAMEWORKS}SvelteKit,"
  echo "$DEPS" | grep -q '^solid-js$' && FRAMEWORKS="${FRAMEWORKS}SolidJS,"
  echo "$DEPS" | grep -q '^@remix-run' && FRAMEWORKS="${FRAMEWORKS}Remix,"
  echo "$DEPS" | grep -q '^astro$' && FRAMEWORKS="${FRAMEWORKS}Astro,"
  echo "$DEPS" | grep -q '^gatsby$' && FRAMEWORKS="${FRAMEWORKS}Gatsby,"
  echo "$DEPS" | grep -q '^@tanstack' && FRAMEWORKS="${FRAMEWORKS}TanStack,"
  echo "$DEPS" | grep -q '^@reduxjs\|^redux$' && FRAMEWORKS="${FRAMEWORKS}Redux,"
  echo "$DEPS" | grep -q '^zustand$' && FRAMEWORKS="${FRAMEWORKS}Zustand,"
  echo "$DEPS" | grep -q '^@mui\|^@material-ui' && FRAMEWORKS="${FRAMEWORKS}MUI,"
  echo "$DEPS" | grep -q '^tailwindcss$' && FRAMEWORKS="${FRAMEWORKS}Tailwind,"
  echo "$DEPS" | grep -q '^@chakra-ui' && FRAMEWORKS="${FRAMEWORKS}Chakra-UI,"
  echo "$DEPS" | grep -q '^shadcn' && FRAMEWORKS="${FRAMEWORKS}shadcn/ui,"
  # Build tools
  echo "$DEPS" | grep -q '^vite$' && FRAMEWORKS="${FRAMEWORKS}Vite,"
  echo "$DEPS" | grep -q '^webpack$' && FRAMEWORKS="${FRAMEWORKS}Webpack,"
  echo "$DEPS" | grep -q '^esbuild$' && FRAMEWORKS="${FRAMEWORKS}esbuild,"
  echo "$DEPS" | grep -q '^rollup$' && FRAMEWORKS="${FRAMEWORKS}Rollup,"
  echo "$DEPS" | grep -q '^tsup$' && FRAMEWORKS="${FRAMEWORKS}tsup,"
  # ORM / Database
  echo "$DEPS" | grep -q '^prisma$\|^@prisma' && FRAMEWORKS="${FRAMEWORKS}Prisma,"
  echo "$DEPS" | grep -q '^typeorm$' && FRAMEWORKS="${FRAMEWORKS}TypeORM,"
  echo "$DEPS" | grep -q '^drizzle-orm$' && FRAMEWORKS="${FRAMEWORKS}Drizzle,"
  echo "$DEPS" | grep -q '^sequelize$' && FRAMEWORKS="${FRAMEWORKS}Sequelize,"
  echo "$DEPS" | grep -q '^knex$' && FRAMEWORKS="${FRAMEWORKS}Knex,"
  echo "$DEPS" | grep -q '^@mikro-orm' && FRAMEWORKS="${FRAMEWORKS}MikroORM,"
  echo "$DEPS" | grep -q '^mongoose$' && FRAMEWORKS="${FRAMEWORKS}Mongoose,"
  echo "$DEPS" | grep -q '^@supabase' && FRAMEWORKS="${FRAMEWORKS}Supabase,"
  echo "$DEPS" | grep -q '^firebase$\|^@firebase' && FRAMEWORKS="${FRAMEWORKS}Firebase,"
  # Message queues
  echo "$DEPS" | grep -q '^kafkajs$\|^@nestjs/microservices' && FRAMEWORKS="${FRAMEWORKS}Kafka,"
  echo "$DEPS" | grep -q '^bullmq$\|^bull$' && FRAMEWORKS="${FRAMEWORKS}BullMQ,"
  echo "$DEPS" | grep -q '^amqplib$' && FRAMEWORKS="${FRAMEWORKS}RabbitMQ,"
  # Auth
  echo "$DEPS" | grep -q '^passport$\|^@nestjs/passport' && FRAMEWORKS="${FRAMEWORKS}Passport,"
  echo "$DEPS" | grep -q '^next-auth$\|^@auth' && FRAMEWORKS="${FRAMEWORKS}NextAuth,"
  echo "$DEPS" | grep -q '^keycloak' && FRAMEWORKS="${FRAMEWORKS}Keycloak,"
  echo "$DEPS" | grep -q '^auth0$\|^@auth0' && FRAMEWORKS="${FRAMEWORKS}Auth0,"
  echo "$DEPS" | grep -q '^@clerk' && FRAMEWORKS="${FRAMEWORKS}Clerk,"
  echo "$DEPS" | grep -q '^lucia$\|^@lucia-auth' && FRAMEWORKS="${FRAMEWORKS}Lucia,"
  echo "$DEPS" | grep -q '^supertokens-node$\|^supertokens-auth-react$' && FRAMEWORKS="${FRAMEWORKS}SuperTokens,"
  echo "$DEPS" | grep -q '^@workos' && FRAMEWORKS="${FRAMEWORKS}WorkOS,"
  echo "$DEPS" | grep -q '^@casl' && FRAMEWORKS="${FRAMEWORKS}CASL,"
  echo "$DEPS" | grep -q '^jsonwebtoken$\|^jose$' && FRAMEWORKS="${FRAMEWORKS}JWT,"
  # Desktop / Mobile
  echo "$DEPS" | grep -q '^electron$' && FRAMEWORKS="${FRAMEWORKS}Electron,"
  echo "$DEPS" | grep -q '^react-native$' && FRAMEWORKS="${FRAMEWORKS}React-Native,"
  echo "$DEPS" | grep -q '^expo$\|^expo-' && FRAMEWORKS="${FRAMEWORKS}Expo,"
  echo "$DEPS" | grep -q '^@capacitor' && FRAMEWORKS="${FRAMEWORKS}Capacitor,"
  echo "$DEPS" | grep -q '^@ionic' && FRAMEWORKS="${FRAMEWORKS}Ionic,"
  # Validation / Utilities
  echo "$DEPS" | grep -q '^zod$' && FRAMEWORKS="${FRAMEWORKS}Zod,"
  echo "$DEPS" | grep -q '^rxjs$' && FRAMEWORKS="${FRAMEWORKS}RxJS,"
  echo "$DEPS" | grep -q '^ioredis$\|^redis$' && FRAMEWORKS="${FRAMEWORKS}Redis-Client,"
  echo "$DEPS" | grep -q '^stripe$' && FRAMEWORKS="${FRAMEWORKS}Stripe,"
  echo "$DEPS" | grep -q '^three$' && FRAMEWORKS="${FRAMEWORKS}Three.js,"
  # Additional frontend frameworks
  echo "$DEPS" | grep -q '^@builder.io/qwik\|^@qwik.dev/qwik' && FRAMEWORKS="${FRAMEWORKS}Qwik,"
  echo "$DEPS" | grep -q '^htmx.org$' && FRAMEWORKS="${FRAMEWORKS}HTMX,"
  echo "$DEPS" | grep -q '^alpinejs$' && FRAMEWORKS="${FRAMEWORKS}Alpine.js,"
  echo "$DEPS" | grep -q '^lit$\|^lit-element$' && FRAMEWORKS="${FRAMEWORKS}Lit,"
  echo "$DEPS" | grep -q '^preact$' && FRAMEWORKS="${FRAMEWORKS}Preact,"
  echo "$DEPS" | grep -q '^ember-source$\|^@ember/application' && FRAMEWORKS="${FRAMEWORKS}Ember.js,"
  echo "$DEPS" | grep -q '^@11ty/eleventy$' && FRAMEWORKS="${FRAMEWORKS}Eleventy,"
  echo "$DEPS" | grep -q '^@stencil/core$' && FRAMEWORKS="${FRAMEWORKS}Stencil,"
  # GraphQL ecosystem enhancements (Apollo Server v4+, Yoga, TypeGraphQL, schema-first tools)
  echo "$DEPS" | grep -q '^@apollo/server$\|^graphql-yoga$' && ! echo "$FRAMEWORKS" | grep -q 'GraphQL' && FRAMEWORKS="${FRAMEWORKS}GraphQL,"
  echo "$DEPS" | grep -q '^type-graphql$' && FRAMEWORKS="${FRAMEWORKS}TypeGraphQL,"
  echo "$DEPS" | grep -q '^@pothos/core$' && FRAMEWORKS="${FRAMEWORKS}Pothos,"
  echo "$DEPS" | grep -q '^urql$\|^@urql/core$' && FRAMEWORKS="${FRAMEWORKS}URQL,"
  # State management additions
  echo "$DEPS" | grep -q '^pinia$' && FRAMEWORKS="${FRAMEWORKS}Pinia,"
  echo "$DEPS" | grep -q '^jotai$' && FRAMEWORKS="${FRAMEWORKS}Jotai,"
  echo "$DEPS" | grep -q '^mobx$' && FRAMEWORKS="${FRAMEWORKS}MobX,"
  echo "$DEPS" | grep -q '^xstate$\|^@xstate/core$' && FRAMEWORKS="${FRAMEWORKS}XState,"
  # UI tooling
  echo "$DEPS" | grep -q '^storybook$\|^@storybook/core' && FRAMEWORKS="${FRAMEWORKS}Storybook,"
  echo "$DEPS" | grep -q '^styled-components$' && FRAMEWORKS="${FRAMEWORKS}styled-components,"
  echo "$DEPS" | grep -q '^@emotion/react$' && FRAMEWORKS="${FRAMEWORKS}Emotion,"
  echo "$DEPS" | grep -q '^swr$' && FRAMEWORKS="${FRAMEWORKS}SWR,"
  # AI / LLM SDKs
  echo "$DEPS" | grep -q '^openai$' && FRAMEWORKS="${FRAMEWORKS}OpenAI-SDK,"
  echo "$DEPS" | grep -q '^@anthropic-ai/sdk$' && FRAMEWORKS="${FRAMEWORKS}Anthropic-SDK,"
  echo "$DEPS" | grep -q '^ai$' && FRAMEWORKS="${FRAMEWORKS}Vercel-AI,"
  echo "$DEPS" | grep -q '^@langchain/' && FRAMEWORKS="${FRAMEWORKS}LangChain-JS,"
  # HTTP clients
  echo "$DEPS" | grep -q '^axios$' && FRAMEWORKS="${FRAMEWORKS}Axios,"
  echo "$DEPS" | grep -q '^got$' && FRAMEWORKS="${FRAMEWORKS}Got,"
  echo "$DEPS" | grep -q '^node-fetch$\|^undici$' && FRAMEWORKS="${FRAMEWORKS}Undici,"
  # Validation
  echo "$DEPS" | grep -q '^class-validator$' && FRAMEWORKS="${FRAMEWORKS}class-validator,"
  echo "$DEPS" | grep -q '^class-transformer$' && FRAMEWORKS="${FRAMEWORKS}class-transformer,"
  echo "$DEPS" | grep -q '^joi$\|^@hapi/joi$' && FRAMEWORKS="${FRAMEWORKS}Joi,"
  echo "$DEPS" | grep -q '^yup$' && FRAMEWORKS="${FRAMEWORKS}Yup,"
  echo "$DEPS" | grep -q '^ajv$' && FRAMEWORKS="${FRAMEWORKS}Ajv,"
  # Forms
  echo "$DEPS" | grep -q '^react-hook-form$' && FRAMEWORKS="${FRAMEWORKS}React-Hook-Form,"
  echo "$DEPS" | grep -q '^formik$' && FRAMEWORKS="${FRAMEWORKS}Formik,"
  # Testing / E2E
  echo "$DEPS" | grep -q '^cypress$' && FRAMEWORKS="${FRAMEWORKS}Cypress,"
  echo "$DEPS" | grep -q '^@playwright/test$\|^playwright$' && FRAMEWORKS="${FRAMEWORKS}Playwright,"
  echo "$DEPS" | grep -q '^puppeteer' && FRAMEWORKS="${FRAMEWORKS}Puppeteer,"
  echo "$DEPS" | grep -q '^@testing-library' && FRAMEWORKS="${FRAMEWORKS}Testing-Library,"
  echo "$DEPS" | grep -q '^msw$' && FRAMEWORKS="${FRAMEWORKS}MSW,"
  # Logging / Observability
  echo "$DEPS" | grep -q '^winston$' && FRAMEWORKS="${FRAMEWORKS}Winston,"
  echo "$DEPS" | grep -q '^pino$' && FRAMEWORKS="${FRAMEWORKS}Pino,"
  echo "$DEPS" | grep -q '^@sentry' && FRAMEWORKS="${FRAMEWORKS}Sentry,"
  echo "$DEPS" | grep -q '^@opentelemetry' && FRAMEWORKS="${FRAMEWORKS}OpenTelemetry,"
  echo "$DEPS" | grep -q '^@datadog' && FRAMEWORKS="${FRAMEWORKS}Datadog,"
  echo "$DEPS" | grep -q '^newrelic$' && FRAMEWORKS="${FRAMEWORKS}New-Relic,"
  # Messaging (additional)
  echo "$DEPS" | grep -q '^nats$\|^nats.ws$' && FRAMEWORKS="${FRAMEWORKS}NATS,"
  echo "$DEPS" | grep -q '^agenda$\|^@agenda/' && FRAMEWORKS="${FRAMEWORKS}Agenda,"
  echo "$DEPS" | grep -q '^bee-queue$' && FRAMEWORKS="${FRAMEWORKS}Bee-Queue,"
  # NestJS ecosystem
  echo "$DEPS" | grep -q '^@nestjs/swagger$' && FRAMEWORKS="${FRAMEWORKS}NestJS-Swagger,"
  echo "$DEPS" | grep -q '^@nestjs/graphql$' && FRAMEWORKS="${FRAMEWORKS}NestJS-GraphQL,"
  echo "$DEPS" | grep -q '^@nestjs/schedule$' && FRAMEWORKS="${FRAMEWORKS}NestJS-Schedule,"
  echo "$DEPS" | grep -q '^@nestjs/config$' && FRAMEWORKS="${FRAMEWORKS}NestJS-Config,"
  echo "$DEPS" | grep -q '^@nestjs/bull$\|^@nestjs/bullmq$' && FRAMEWORKS="${FRAMEWORKS}NestJS-Bull,"
  echo "$DEPS" | grep -q '^@nestjs/cache-manager$\|^@nestjs/caching$' && FRAMEWORKS="${FRAMEWORKS}NestJS-Cache,"
  # i18n
  echo "$DEPS" | grep -q '^i18next$\|^next-intl$\|^react-i18next$' && FRAMEWORKS="${FRAMEWORKS}i18n,"
  # Cloud SDKs
  echo "$DEPS" | grep -q '^@aws-sdk' && FRAMEWORKS="${FRAMEWORKS}AWS-SDK,"
  echo "$DEPS" | grep -q '^@google-cloud' && FRAMEWORKS="${FRAMEWORKS}GCP-SDK,"
  echo "$DEPS" | grep -q '^@azure' && FRAMEWORKS="${FRAMEWORKS}Azure-SDK,"
  # AWS specific products
  echo "$DEPS" | grep -q '^@aws-sdk/client-s3$' && FRAMEWORKS="${FRAMEWORKS}AWS-S3,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-sqs$' && FRAMEWORKS="${FRAMEWORKS}AWS-SQS,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-sns$' && FRAMEWORKS="${FRAMEWORKS}AWS-SNS,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-dynamodb$\|^@aws-sdk/lib-dynamodb$' && FRAMEWORKS="${FRAMEWORKS}AWS-DynamoDB,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-lambda$' && FRAMEWORKS="${FRAMEWORKS}AWS-Lambda,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-cognito' && FRAMEWORKS="${FRAMEWORKS}AWS-Cognito,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-ses$\|^@aws-sdk/client-sesv2$' && FRAMEWORKS="${FRAMEWORKS}AWS-SES,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-secrets-manager$' && FRAMEWORKS="${FRAMEWORKS}AWS-SecretsManager,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-eventbridge$' && FRAMEWORKS="${FRAMEWORKS}AWS-EventBridge,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-ecs$\|^@aws-sdk/client-sts$' && FRAMEWORKS="${FRAMEWORKS}AWS-ECS,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-cloudwatch$' && FRAMEWORKS="${FRAMEWORKS}AWS-CloudWatch,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-kinesis$' && FRAMEWORKS="${FRAMEWORKS}AWS-Kinesis,"
  echo "$DEPS" | grep -q '^@aws-sdk/client-stepfunctions$' && FRAMEWORKS="${FRAMEWORKS}AWS-StepFunctions,"
  # GCP specific products
  echo "$DEPS" | grep -q '^@google-cloud/pubsub$' && FRAMEWORKS="${FRAMEWORKS}GCP-PubSub,"
  echo "$DEPS" | grep -q '^@google-cloud/firestore$' && FRAMEWORKS="${FRAMEWORKS}GCP-Firestore,"
  echo "$DEPS" | grep -q '^@google-cloud/bigquery$' && FRAMEWORKS="${FRAMEWORKS}GCP-BigQuery,"
  echo "$DEPS" | grep -q '^@google-cloud/storage$' && FRAMEWORKS="${FRAMEWORKS}GCP-Storage,"
  echo "$DEPS" | grep -q '^@google-cloud/functions-framework$' && FRAMEWORKS="${FRAMEWORKS}GCP-Functions,"
  echo "$DEPS" | grep -q '^@google-cloud/tasks$' && FRAMEWORKS="${FRAMEWORKS}GCP-Tasks,"
  echo "$DEPS" | grep -q '^@google-cloud/secret-manager$' && FRAMEWORKS="${FRAMEWORKS}GCP-SecretManager,"
  echo "$DEPS" | grep -q '^@google-cloud/spanner$' && FRAMEWORKS="${FRAMEWORKS}GCP-Spanner,"
  # Azure specific products
  echo "$DEPS" | grep -q '^@azure/service-bus$' && FRAMEWORKS="${FRAMEWORKS}Azure-ServiceBus,"
  echo "$DEPS" | grep -q '^@azure/cosmos$' && FRAMEWORKS="${FRAMEWORKS}Azure-CosmosDB,"
  echo "$DEPS" | grep -q '^@azure/storage-blob$' && FRAMEWORKS="${FRAMEWORKS}Azure-Blob,"
  echo "$DEPS" | grep -q '^@azure/identity$' && FRAMEWORKS="${FRAMEWORKS}Azure-Identity,"
  echo "$DEPS" | grep -q '^@azure/functions$' && FRAMEWORKS="${FRAMEWORKS}Azure-Functions,"
  echo "$DEPS" | grep -q '^@azure/keyvault' && FRAMEWORKS="${FRAMEWORKS}Azure-KeyVault,"
  echo "$DEPS" | grep -q '^@azure/event-hubs$' && FRAMEWORKS="${FRAMEWORKS}Azure-EventHubs,"
  echo "$DEPS" | grep -q '^@azure/msal' && FRAMEWORKS="${FRAMEWORKS}Azure-AD,"
  # UI libraries (additional)
  echo "$DEPS" | grep -q '^@radix-ui' && FRAMEWORKS="${FRAMEWORKS}Radix-UI,"
  echo "$DEPS" | grep -q '^@headlessui' && FRAMEWORKS="${FRAMEWORKS}Headless-UI,"
  echo "$DEPS" | grep -q '^framer-motion$\|^motion$' && FRAMEWORKS="${FRAMEWORKS}Framer-Motion,"
  echo "$DEPS" | grep -q '^@mantine' && FRAMEWORKS="${FRAMEWORKS}Mantine,"
  echo "$DEPS" | grep -q '^antd$\|^@ant-design' && FRAMEWORKS="${FRAMEWORKS}Ant-Design,"
  # Data / Visualization
  echo "$DEPS" | grep -q '^d3$\|^@visx' && FRAMEWORKS="${FRAMEWORKS}D3,"
  echo "$DEPS" | grep -q '^chart.js$\|^react-chartjs' && FRAMEWORKS="${FRAMEWORKS}Chart.js,"
  echo "$DEPS" | grep -q '^recharts$' && FRAMEWORKS="${FRAMEWORKS}Recharts,"
  # Search
  echo "$DEPS" | grep -q '^@elastic/elasticsearch$' && FRAMEWORKS="${FRAMEWORKS}Elasticsearch,"
  echo "$DEPS" | grep -q '^meilisearch$\|^@meilisearch' && FRAMEWORKS="${FRAMEWORKS}Meilisearch,"
  echo "$DEPS" | grep -q '^@algolia' && FRAMEWORKS="${FRAMEWORKS}Algolia,"
  # File / Media
  echo "$DEPS" | grep -q '^sharp$' && FRAMEWORKS="${FRAMEWORKS}Sharp,"
  echo "$DEPS" | grep -q '^multer$' && FRAMEWORKS="${FRAMEWORKS}Multer,"
  echo "$DEPS" | grep -q '^nodemailer$' && FRAMEWORKS="${FRAMEWORKS}Nodemailer,"
  # Payments / Billing / Commerce (JS/TS) — widest provider ecosystem across all languages
  # JS/TS is used for SaaS frontends+backends, e-commerce, fintech apps, startup APIs
  echo "$DEPS" | grep -q '^@mollie/api-client$\|^mollie$' && FRAMEWORKS="${FRAMEWORKS}Mollie,"
  echo "$DEPS" | grep -q '^@gocardless/gocardless-nodejs$\|^gocardless-pro$' && FRAMEWORKS="${FRAMEWORKS}GoCardless,"
  echo "$DEPS" | grep -q '^@adyen/api-library$\|^@adyen/web$' && FRAMEWORKS="${FRAMEWORKS}Adyen,"
  echo "$DEPS" | grep -q '^braintree$' && FRAMEWORKS="${FRAMEWORKS}Braintree,"
  echo "$DEPS" | grep -q '^square$\|^@square/web-sdk$' && FRAMEWORKS="${FRAMEWORKS}Square,"
  echo "$DEPS" | grep -q '^@checkout.com\|^checkout-sdk$' && FRAMEWORKS="${FRAMEWORKS}Checkout.com,"
  echo "$DEPS" | grep -q '^@klarna/checkout-sdk$\|^@klarna/react-checkout$' && FRAMEWORKS="${FRAMEWORKS}Klarna,"
  echo "$DEPS" | grep -q '^@paddle/paddle-js$\|^paddle-js$' && FRAMEWORKS="${FRAMEWORKS}Paddle,"
  echo "$DEPS" | grep -q '^chargebee$\|^chargebee-js$' && FRAMEWORKS="${FRAMEWORKS}Chargebee,"
  echo "$DEPS" | grep -q '^recurly$' && FRAMEWORKS="${FRAMEWORKS}Recurly,"
  echo "$DEPS" | grep -q '^paystack$' && FRAMEWORKS="${FRAMEWORKS}Paystack,"
  echo "$DEPS" | grep -q '^razorpay$' && FRAMEWORKS="${FRAMEWORKS}Razorpay,"
  echo "$DEPS" | grep -q '^@lemonsqueezy/lemonsqueezy.js$' && FRAMEWORKS="${FRAMEWORKS}LemonSqueezy,"
  echo "$DEPS" | grep -q '^plaid$' && FRAMEWORKS="${FRAMEWORKS}Plaid,"
  echo "$DEPS" | grep -q '^zuora$' && FRAMEWORKS="${FRAMEWORKS}Zuora,"
  echo "$DEPS" | grep -q '^@paypal' && FRAMEWORKS="${FRAMEWORKS}PayPal,"
  # Communication / Notifications (JS/TS) — always co-deployed with payment systems
  echo "$DEPS" | grep -q '^twilio$' && FRAMEWORKS="${FRAMEWORKS}Twilio,"
  echo "$DEPS" | grep -q '^@sendgrid/mail$\|^sendgrid$' && FRAMEWORKS="${FRAMEWORKS}SendGrid,"
  echo "$DEPS" | grep -q '^resend$' && FRAMEWORKS="${FRAMEWORKS}Resend,"
  echo "$DEPS" | grep -q '^postmark$' && FRAMEWORKS="${FRAMEWORKS}Postmark,"
  echo "$DEPS" | grep -q '^mailgun.js$\|^mailgun-js$' && FRAMEWORKS="${FRAMEWORKS}Mailgun,"
  echo "$DEPS" | grep -q '^@novu/node$\|^novu$' && FRAMEWORKS="${FRAMEWORKS}Novu,"
  echo "$DEPS" | grep -q '^@onesignal/node-onesignal$' && FRAMEWORKS="${FRAMEWORKS}OneSignal,"
  # Feature Flags (JS/TS) — critical for phased payment rollouts
  echo "$DEPS" | grep -q '^launchdarkly-js-client-sdk$\|^launchdarkly-node-server-sdk$' && FRAMEWORKS="${FRAMEWORKS}LaunchDarkly,"
  echo "$DEPS" | grep -q '^flagsmith$\|^flagsmith-es$' && FRAMEWORKS="${FRAMEWORKS}Flagsmith,"
  echo "$DEPS" | grep -q '^unleash-client$\|^@unleash/nextjs$' && FRAMEWORKS="${FRAMEWORKS}Unleash,"
  echo "$DEPS" | grep -q '^posthog-js$\|^posthog-node$' && FRAMEWORKS="${FRAMEWORKS}PostHog,"
  # Product Analytics (JS/TS) — conversion / funnel / revenue tracking
  echo "$DEPS" | grep -q '^@segment/analytics-js$\|^analytics-node$' && FRAMEWORKS="${FRAMEWORKS}Segment,"
  echo "$DEPS" | grep -q '^@amplitude/analytics-browser$\|^amplitude-js$' && FRAMEWORKS="${FRAMEWORKS}Amplitude,"
  echo "$DEPS" | grep -q '^mixpanel-browser$\|^mixpanel$' && FRAMEWORKS="${FRAMEWORKS}Mixpanel,"
  # Tax Compliance (JS/TS) — mandatory for global commerce
  echo "$DEPS" | grep -q '^taxjar$\|^@taxjar/taxjar$' && FRAMEWORKS="${FRAMEWORKS}TaxJar,"
  echo "$DEPS" | grep -q '^@avalara/avatax$\|^avalara$' && FRAMEWORKS="${FRAMEWORKS}Avalara,"
  # CMS / Headless CMS (JS/TS) — content-driven SaaS, marketing sites, editorial platforms
  echo "$DEPS" | grep -q '^strapi$\|^@strapi' && FRAMEWORKS="${FRAMEWORKS}Strapi,"
  echo "$DEPS" | grep -q '^payload$\|^@payloadcms' && FRAMEWORKS="${FRAMEWORKS}Payload,"
  echo "$DEPS" | grep -q '^contentful$\|^@contentful' && FRAMEWORKS="${FRAMEWORKS}Contentful,"
  echo "$DEPS" | grep -q '^@sanity/client$\|^sanity$\|^next-sanity$' && FRAMEWORKS="${FRAMEWORKS}Sanity,"
  echo "$DEPS" | grep -q '^@directus/sdk$\|^directus$' && FRAMEWORKS="${FRAMEWORKS}Directus,"
  echo "$DEPS" | grep -q '^@keystonejs/core$\|^@keystone-6' && FRAMEWORKS="${FRAMEWORKS}KeystoneJS,"
  echo "$DEPS" | grep -q '^ghost-admin-api$\|^@tryghost' && FRAMEWORKS="${FRAMEWORKS}Ghost,"
  echo "$DEPS" | grep -q '^@builder.io/sdk$\|^@builder.io/react$' && FRAMEWORKS="${FRAMEWORKS}Builder.io,"
  echo "$DEPS" | grep -q '^@prismic/client$\|^prismic' && FRAMEWORKS="${FRAMEWORKS}Prismic,"
  echo "$DEPS" | grep -q '^@storyblok/js$\|^@storyblok/react$' && FRAMEWORKS="${FRAMEWORKS}Storyblok,"
  # E-commerce Platforms (JS/TS) — headless commerce, marketplace backends, D2C
  echo "$DEPS" | grep -q '^@medusajs/medusa$\|^medusa-interfaces$' && FRAMEWORKS="${FRAMEWORKS}Medusa,"
  echo "$DEPS" | grep -q '^@saleor/sdk$\|^saleor' && FRAMEWORKS="${FRAMEWORKS}Saleor,"
  echo "$DEPS" | grep -q '^@shopify/shopify-api$\|^@shopify/hydrogen$' && FRAMEWORKS="${FRAMEWORKS}Shopify,"
  echo "$DEPS" | grep -q '^@commercetools' && FRAMEWORKS="${FRAMEWORKS}Commercetools,"
  echo "$DEPS" | grep -q '^@bigcommerce' && FRAMEWORKS="${FRAMEWORKS}BigCommerce,"
  echo "$DEPS" | grep -q '^@vendure' && FRAMEWORKS="${FRAMEWORKS}Vendure,"
  # Vector DB / RAG / AI Infra (JS/TS) — retrieval-augmented generation, semantic search, AI apps
  echo "$DEPS" | grep -q '^@pinecone-database/pinecone$' && FRAMEWORKS="${FRAMEWORKS}Pinecone,"
  echo "$DEPS" | grep -q '^chromadb$' && FRAMEWORKS="${FRAMEWORKS}ChromaDB,"
  echo "$DEPS" | grep -q '^weaviate-ts-client$\|^weaviate-client$' && FRAMEWORKS="${FRAMEWORKS}Weaviate,"
  echo "$DEPS" | grep -q '^@qdrant/js-client-rest$' && FRAMEWORKS="${FRAMEWORKS}Qdrant,"
  echo "$DEPS" | grep -q '^@upstash/vector$' && FRAMEWORKS="${FRAMEWORKS}Upstash-Vector,"
  echo "$DEPS" | grep -q '^llamaindex$\|^@llamaindex' && FRAMEWORKS="${FRAMEWORKS}LlamaIndex,"
  echo "$DEPS" | grep -q '^@huggingface/inference$' && FRAMEWORKS="${FRAMEWORKS}HuggingFace,"
  echo "$DEPS" | grep -q '^cohere-ai$' && FRAMEWORKS="${FRAMEWORKS}Cohere,"
  echo "$DEPS" | grep -q '^replicate$' && FRAMEWORKS="${FRAMEWORKS}Replicate,"
  echo "$DEPS" | grep -q '^@trigger.dev/sdk$' && FRAMEWORKS="${FRAMEWORKS}Trigger.dev,"
  echo "$DEPS" | grep -q '^@temporalio/client$\|^@temporalio/worker$' && FRAMEWORKS="${FRAMEWORKS}Temporal,"
  # Blockchain / Web3 (JS/TS) — DeFi, NFT, dApps, wallet integration
  echo "$DEPS" | grep -q '^ethers$' && FRAMEWORKS="${FRAMEWORKS}Ethers.js,"
  echo "$DEPS" | grep -q '^web3$' && FRAMEWORKS="${FRAMEWORKS}Web3.js,"
  echo "$DEPS" | grep -q '^hardhat$' && FRAMEWORKS="${FRAMEWORKS}Hardhat,"
  echo "$DEPS" | grep -q '^viem$' && FRAMEWORKS="${FRAMEWORKS}Viem,"
  echo "$DEPS" | grep -q '^@wagmi/core$\|^wagmi$' && FRAMEWORKS="${FRAMEWORKS}Wagmi,"
  echo "$DEPS" | grep -q '^@solana/web3.js$' && FRAMEWORKS="${FRAMEWORKS}Solana,"
  echo "$DEPS" | grep -q '^@thirdweb-dev' && FRAMEWORKS="${FRAMEWORKS}Thirdweb,"
  echo "$DEPS" | grep -q '^@rainbow-me/rainbowkit$' && FRAMEWORKS="${FRAMEWORKS}RainbowKit,"
  # Gaming / Interactive (JS/TS) — browser games, simulations, interactive media
  echo "$DEPS" | grep -q '^phaser$' && FRAMEWORKS="${FRAMEWORKS}Phaser,"
  echo "$DEPS" | grep -q '^pixi.js$\|^@pixi' && FRAMEWORKS="${FRAMEWORKS}PixiJS,"
  echo "$DEPS" | grep -q '^@babylonjs/core$\|^babylonjs$' && FRAMEWORKS="${FRAMEWORKS}BabylonJS,"
  echo "$DEPS" | grep -q '^playcanvas$' && FRAMEWORKS="${FRAMEWORKS}PlayCanvas,"
  echo "$DEPS" | grep -q '^@tauri-apps/api$' && FRAMEWORKS="${FRAMEWORKS}Tauri,"
  # PDF / Document Generation (JS/TS) — invoicing, reporting, contract generation
  echo "$DEPS" | grep -q '^pdfkit$' && FRAMEWORKS="${FRAMEWORKS}PDFKit,"
  echo "$DEPS" | grep -q '^jspdf$' && FRAMEWORKS="${FRAMEWORKS}jsPDF,"
  echo "$DEPS" | grep -q '^@react-pdf/renderer$' && FRAMEWORKS="${FRAMEWORKS}React-PDF,"
  echo "$DEPS" | grep -q '^docx$' && FRAMEWORKS="${FRAMEWORKS}docx,"
  echo "$DEPS" | grep -q '^exceljs$' && FRAMEWORKS="${FRAMEWORKS}ExcelJS,"
  echo "$DEPS" | grep -q '^papaparse$\|^csv-parse$' && FRAMEWORKS="${FRAMEWORKS}CSV-Parser,"
  # Geospatial / Mapping (JS/TS) — logistics, delivery, real estate, fleet management
  echo "$DEPS" | grep -q '^mapbox-gl$\|^@mapbox' && FRAMEWORKS="${FRAMEWORKS}Mapbox,"
  echo "$DEPS" | grep -q '^leaflet$\|^react-leaflet$' && FRAMEWORKS="${FRAMEWORKS}Leaflet,"
  echo "$DEPS" | grep -q '^@turf/turf$\|^@turf' && FRAMEWORKS="${FRAMEWORKS}Turf.js,"
  echo "$DEPS" | grep -q '^ol$' && FRAMEWORKS="${FRAMEWORKS}OpenLayers,"
  echo "$DEPS" | grep -q '^@googlemaps/js-api-loader$\|^@react-google-maps' && FRAMEWORKS="${FRAMEWORKS}Google-Maps,"
  # Media / Image Processing (JS/TS) — user-generated content, CDN, video platforms
  echo "$DEPS" | grep -q '^cloudinary$\|^@cloudinary' && FRAMEWORKS="${FRAMEWORKS}Cloudinary,"
  echo "$DEPS" | grep -q '^fluent-ffmpeg$\|^@ffmpeg/ffmpeg$' && FRAMEWORKS="${FRAMEWORKS}FFmpeg,"
  echo "$DEPS" | grep -q '^@uploadthing' && FRAMEWORKS="${FRAMEWORKS}UploadThing,"
  echo "$DEPS" | grep -q '^@mux/mux-player$\|^@mux' && FRAMEWORKS="${FRAMEWORKS}Mux,"
  # IoT / MQTT (JS/TS) — smart home, industrial IoT, telemetry
  echo "$DEPS" | grep -q '^mqtt$\|^async-mqtt$' && FRAMEWORKS="${FRAMEWORKS}MQTT,"
  echo "$DEPS" | grep -q '^aedes$' && FRAMEWORKS="${FRAMEWORKS}Aedes-MQTT,"
  # Real-time / Collaboration (JS/TS) — beyond Socket.IO: managed real-time services
  echo "$DEPS" | grep -q '^pusher$\|^pusher-js$' && FRAMEWORKS="${FRAMEWORKS}Pusher,"
  echo "$DEPS" | grep -q '^ably$' && FRAMEWORKS="${FRAMEWORKS}Ably,"
  echo "$DEPS" | grep -q '^livekit-client$\|^@livekit' && FRAMEWORKS="${FRAMEWORKS}LiveKit,"
  echo "$DEPS" | grep -q '^@yjs/yjs$\|^yjs$' && FRAMEWORKS="${FRAMEWORKS}Yjs,"
  echo "$DEPS" | grep -q '^@liveblocks' && FRAMEWORKS="${FRAMEWORKS}Liveblocks,"
  # SSO / Identity (JS/TS) — enterprise auth, SAML, OIDC
  echo "$DEPS" | grep -q '^passport-saml$\|^@node-saml/passport-saml$' && FRAMEWORKS="${FRAMEWORKS}SAML,"
  echo "$DEPS" | grep -q '^@ory/client$\|^@ory/kratos-client$' && FRAMEWORKS="${FRAMEWORKS}Ory,"
  echo "$DEPS" | grep -q '^@descope/web-sdk$\|^@descope' && FRAMEWORKS="${FRAMEWORKS}Descope,"
  echo "$DEPS" | grep -q '^@frontegg' && FRAMEWORKS="${FRAMEWORKS}Frontegg,"
  # Testing infrastructure (JS/TS) — contract testing, load testing, visual regression
  echo "$DEPS" | grep -q '^@pact-foundation/pact$' && FRAMEWORKS="${FRAMEWORKS}Pact,"
  echo "$DEPS" | grep -q '^artillery$' && FRAMEWORKS="${FRAMEWORKS}Artillery,"
  echo "$DEPS" | grep -q '^@axe-core/playwright$\|^axe-core$' && FRAMEWORKS="${FRAMEWORKS}axe-core,"
  echo "$DEPS" | grep -q '^nock$' && FRAMEWORKS="${FRAMEWORKS}Nock,"
  # Scheduling / Cron (JS/TS) — recurring jobs, task scheduling
  echo "$DEPS" | grep -q '^node-cron$\|^cron$' && FRAMEWORKS="${FRAMEWORKS}node-cron,"
  # Caching
  echo "$DEPS" | grep -q '^cache-manager$' && FRAMEWORKS="${FRAMEWORKS}CacheManager,"
  echo "$DEPS" | grep -q '^keyv$' && FRAMEWORKS="${FRAMEWORKS}Keyv,"
  # Serverless / Edge (JS/TS) — functions-as-a-service, edge compute
  echo "$DEPS" | grep -q '^@cloudflare/workers-types$\|^wrangler$' && FRAMEWORKS="${FRAMEWORKS}Cloudflare-Workers,"
  echo "$DEPS" | grep -q '^@netlify/functions$' && FRAMEWORKS="${FRAMEWORKS}Netlify-Functions,"
  echo "$DEPS" | grep -q '^@vercel/functions$\|^@vercel/edge$' && FRAMEWORKS="${FRAMEWORKS}Vercel-Functions,"
  echo "$DEPS" | grep -q '^@openfaas/faas-provider$' && FRAMEWORKS="${FRAMEWORKS}OpenFaaS,"
  echo "$DEPS" | grep -q '^serverless-http$' && FRAMEWORKS="${FRAMEWORKS}Serverless-HTTP,"
  # CSS / Styling (JS/TS) — beyond Tailwind and styled-components
  echo "$DEPS" | grep -q '^@vanilla-extract/css$' && FRAMEWORKS="${FRAMEWORKS}Vanilla-Extract,"
  echo "$DEPS" | grep -q '^@stitches/react$' && FRAMEWORKS="${FRAMEWORKS}Stitches,"
  echo "$DEPS" | grep -q '^@unocss/core$\|^unocss$' && FRAMEWORKS="${FRAMEWORKS}UnoCSS,"
  echo "$DEPS" | grep -q '^windicss$' && FRAMEWORKS="${FRAMEWORKS}WindiCSS,"
  echo "$DEPS" | grep -q '^panda-css$\|^@pandacss' && FRAMEWORKS="${FRAMEWORKS}PandaCSS,"
  echo "$DEPS" | grep -q '^@picocss/pico$' && FRAMEWORKS="${FRAMEWORKS}PicoCSS,"
  echo "$DEPS" | grep -q '^daisyui$' && FRAMEWORKS="${FRAMEWORKS}DaisyUI,"
  echo "$DEPS" | grep -q '^@nextui-org/react$' && FRAMEWORKS="${FRAMEWORKS}NextUI,"
  echo "$DEPS" | grep -q '^@fluentui/react-components$\|^@fluentui/react$' && FRAMEWORKS="${FRAMEWORKS}Fluent-UI,"
  echo "$DEPS" | grep -q '^@blueprintjs/core$' && FRAMEWORKS="${FRAMEWORKS}BlueprintJS,"
  echo "$DEPS" | grep -q '^@tremor/react$' && FRAMEWORKS="${FRAMEWORKS}Tremor,"
  echo "$DEPS" | grep -q '^@ark-ui/react$\|^@park-ui' && FRAMEWORKS="${FRAMEWORKS}Ark-UI,"
  # Animation (JS/TS) — interactive UX, onboarding, data viz transitions
  echo "$DEPS" | grep -q '^gsap$' && FRAMEWORKS="${FRAMEWORKS}GSAP,"
  echo "$DEPS" | grep -q '^@react-spring/core$\|^react-spring$' && FRAMEWORKS="${FRAMEWORKS}React-Spring,"
  echo "$DEPS" | grep -q '^lottie-web$\|^lottie-react$' && FRAMEWORKS="${FRAMEWORKS}Lottie,"
  echo "$DEPS" | grep -q '^animejs$\|^@animejs/anime$' && FRAMEWORKS="${FRAMEWORKS}Anime.js,"
  echo "$DEPS" | grep -q '^@motionone/dom$\|^motion-one$' && FRAMEWORKS="${FRAMEWORKS}Motion-One,"
  echo "$DEPS" | grep -q '^@formkit/auto-animate$' && FRAMEWORKS="${FRAMEWORKS}AutoAnimate,"
  # Table / Data Grid (JS/TS) — enterprise data-intensive UIs
  echo "$DEPS" | grep -q '^@tanstack/react-table$\|^@tanstack/table-core$' && FRAMEWORKS="${FRAMEWORKS}TanStack-Table,"
  echo "$DEPS" | grep -q '^ag-grid-community$\|^ag-grid-react$' && FRAMEWORKS="${FRAMEWORKS}AG-Grid,"
  echo "$DEPS" | grep -q '^@handsontable/react$\|^handsontable$' && FRAMEWORKS="${FRAMEWORKS}Handsontable,"
  # Rich Text / Editor (JS/TS) — content editing, CMS, documentation
  echo "$DEPS" | grep -q '^@tiptap/core$\|^@tiptap/react$' && FRAMEWORKS="${FRAMEWORKS}Tiptap,"
  echo "$DEPS" | grep -q '^@lexical/react$\|^lexical$' && FRAMEWORKS="${FRAMEWORKS}Lexical,"
  echo "$DEPS" | grep -q '^@ckeditor/ckeditor5-react$\|^ckeditor5$' && FRAMEWORKS="${FRAMEWORKS}CKEditor,"
  echo "$DEPS" | grep -q '^quill$\|^react-quill$' && FRAMEWORKS="${FRAMEWORKS}Quill,"
  echo "$DEPS" | grep -q '^prosemirror-state$\|^@remirror' && FRAMEWORKS="${FRAMEWORKS}ProseMirror,"
  echo "$DEPS" | grep -q '^slate$\|^slate-react$' && FRAMEWORKS="${FRAMEWORKS}Slate,"
  echo "$DEPS" | grep -q '^@milkdown/core$' && FRAMEWORKS="${FRAMEWORKS}Milkdown,"
  echo "$DEPS" | grep -q '^@blocknote/core$\|^@blocknote/react$' && FRAMEWORKS="${FRAMEWORKS}BlockNote,"
  # Date / Time (JS/TS) — universal dependency in business apps
  echo "$DEPS" | grep -q '^date-fns$' && FRAMEWORKS="${FRAMEWORKS}date-fns,"
  echo "$DEPS" | grep -q '^dayjs$' && FRAMEWORKS="${FRAMEWORKS}Day.js,"
  echo "$DEPS" | grep -q '^luxon$' && FRAMEWORKS="${FRAMEWORKS}Luxon,"
  echo "$DEPS" | grep -q '^moment$' && FRAMEWORKS="${FRAMEWORKS}Moment.js,"
  echo "$DEPS" | grep -q '^@js-temporal' && FRAMEWORKS="${FRAMEWORKS}Temporal-Polyfill,"
  # DI / Architecture (JS/TS) — enterprise patterns in Node backends
  echo "$DEPS" | grep -q '^inversify$' && FRAMEWORKS="${FRAMEWORKS}Inversify,"
  echo "$DEPS" | grep -q '^tsyringe$' && FRAMEWORKS="${FRAMEWORKS}TSyringe,"
  echo "$DEPS" | grep -q '^awilix$' && FRAMEWORKS="${FRAMEWORKS}Awilix,"
  # Process / Workflow (JS/TS) — orchestration, long-running processes
  echo "$DEPS" | grep -q '^inngest$' && FRAMEWORKS="${FRAMEWORKS}Inngest,"
  echo "$DEPS" | grep -q '^@defer/client$' && FRAMEWORKS="${FRAMEWORKS}Defer,"
  echo "$DEPS" | grep -q '^quirrel$' && FRAMEWORKS="${FRAMEWORKS}Quirrel,"
  echo "$DEPS" | grep -q '^graphile-worker$' && FRAMEWORKS="${FRAMEWORKS}Graphile-Worker,"
  # Headless browser / Scraping (JS/TS) — data extraction, testing
  echo "$DEPS" | grep -q '^cheerio$' && FRAMEWORKS="${FRAMEWORKS}Cheerio,"
  echo "$DEPS" | grep -q '^crawlee$' && FRAMEWORKS="${FRAMEWORKS}Crawlee,"
  # Monorepo / Build (JS/TS) — workspace management
  echo "$DEPS" | grep -q '^changesets$\|^@changesets/cli$' && FRAMEWORKS="${FRAMEWORKS}Changesets,"
  echo "$DEPS" | grep -q '^lerna$' && FRAMEWORKS="${FRAMEWORKS}Lerna,"
  echo "$DEPS" | grep -q '^@swc/core$\|^swc$' && FRAMEWORKS="${FRAMEWORKS}SWC,"
  echo "$DEPS" | grep -q '^unbuild$' && FRAMEWORKS="${FRAMEWORKS}unbuild,"
  echo "$DEPS" | grep -q '^@parcel/core$\|^parcel$' && FRAMEWORKS="${FRAMEWORKS}Parcel,"
  # Config / Env (JS/TS) — environment management
  echo "$DEPS" | grep -q '^dotenv$' && FRAMEWORKS="${FRAMEWORKS}dotenv,"
  echo "$DEPS" | grep -q '^@t3-oss/env-nextjs$\|^@t3-oss/env-core$' && FRAMEWORKS="${FRAMEWORKS}T3-Env,"
  echo "$DEPS" | grep -q '^convex$\|^@convex-dev' && FRAMEWORKS="${FRAMEWORKS}Convex,"
  # Accessibility (JS/TS) — inclusive design, compliance
  echo "$DEPS" | grep -q '^@react-aria/.*$\|^react-aria$' && FRAMEWORKS="${FRAMEWORKS}React-Aria,"
  # Drag & Drop (JS/TS) — interactive UIs, kanban boards
  echo "$DEPS" | grep -q '^@dnd-kit/core$' && FRAMEWORKS="${FRAMEWORKS}dnd-kit,"
  echo "$DEPS" | grep -q '^react-beautiful-dnd$' && FRAMEWORKS="${FRAMEWORKS}react-beautiful-dnd,"
  # Notifications / Toast (JS/TS) — UX feedback
  echo "$DEPS" | grep -q '^sonner$' && FRAMEWORKS="${FRAMEWORKS}Sonner,"
  echo "$DEPS" | grep -q '^react-hot-toast$' && FRAMEWORKS="${FRAMEWORKS}React-Hot-Toast,"
  # CLI (JS/TS) — building CLI tools
  echo "$DEPS" | grep -q '^commander$' && FRAMEWORKS="${FRAMEWORKS}Commander,"
  echo "$DEPS" | grep -q '^@oclif/core$\|^oclif$' && FRAMEWORKS="${FRAMEWORKS}Oclif,"
  echo "$DEPS" | grep -q '^ink$' && FRAMEWORKS="${FRAMEWORKS}Ink,"
  echo "$DEPS" | grep -q '^citty$\|^@unjs/citty$' && FRAMEWORKS="${FRAMEWORKS}Citty,"
  # Cron / Rate Limiting (JS/TS) — API protection
  echo "$DEPS" | grep -q '^rate-limiter-flexible$' && FRAMEWORKS="${FRAMEWORKS}Rate-Limiter,"
  echo "$DEPS" | grep -q '^bottleneck$' && FRAMEWORKS="${FRAMEWORKS}Bottleneck,"
  # Error tracking (JS/TS) — beyond Sentry
  echo "$DEPS" | grep -q '^@bugsnag/js$\|^bugsnag$' && FRAMEWORKS="${FRAMEWORKS}Bugsnag,"
  echo "$DEPS" | grep -q '^@highlight-run/node$\|^highlight.run$' && FRAMEWORKS="${FRAMEWORKS}Highlight,"
  echo "$DEPS" | grep -q '^@honeybadger-io/js$' && FRAMEWORKS="${FRAMEWORKS}Honeybadger,"
  # Multi-tenancy (JS/TS) — SaaS architecture
  echo "$DEPS" | grep -q '^@propelauth' && FRAMEWORKS="${FRAMEWORKS}PropelAuth,"
  echo "$DEPS" | grep -q '^@stytch' && FRAMEWORKS="${FRAMEWORKS}Stytch,"
  # Internationalization (JS/TS) — beyond i18n
  echo "$DEPS" | grep -q '^@formatjs/intl$\|^react-intl$' && FRAMEWORKS="${FRAMEWORKS}FormatJS,"
  echo "$DEPS" | grep -q '^@lingui/core$\|^@lingui/react$' && FRAMEWORKS="${FRAMEWORKS}Lingui,"
  # Email templating (JS/TS) — transactional email design
  echo "$DEPS" | grep -q '^@react-email/components$\|^react-email$' && FRAMEWORKS="${FRAMEWORKS}React-Email,"
  echo "$DEPS" | grep -q '^mjml$' && FRAMEWORKS="${FRAMEWORKS}MJML,"
  # Video / Streaming (JS/TS) — OTT, live streaming, video editing
  echo "$DEPS" | grep -q '^hls.js$' && FRAMEWORKS="${FRAMEWORKS}HLS.js,"
  echo "$DEPS" | grep -q '^video.js$\|^@videojs' && FRAMEWORKS="${FRAMEWORKS}Video.js,"
  echo "$DEPS" | grep -q '^@remotion/player$\|^remotion$' && FRAMEWORKS="${FRAMEWORKS}Remotion,"
  # Crypto / Security (JS/TS) — encryption, hashing
  echo "$DEPS" | grep -q '^bcrypt$\|^bcryptjs$' && FRAMEWORKS="${FRAMEWORKS}bcrypt,"
  echo "$DEPS" | grep -q '^helmet$' && FRAMEWORKS="${FRAMEWORKS}Helmet,"
  echo "$DEPS" | grep -q '^@node-rs/argon2$\|^argon2$' && FRAMEWORKS="${FRAMEWORKS}Argon2,"
  echo "$DEPS" | grep -q '^cors$' && FRAMEWORKS="${FRAMEWORKS}CORS,"
  echo "$DEPS" | grep -q '^csurf$\|^@nestjs/csrf$' && FRAMEWORKS="${FRAMEWORKS}CSRF,"
  # Payments — additional (JS/TS)
  echo "$DEPS" | grep -q '^@coinbase/coinbase-sdk$\|^coinbase-pro-node$' && FRAMEWORKS="${FRAMEWORKS}Coinbase,"
  echo "$DEPS" | grep -q '^@mercadopago/sdk-js$\|^mercadopago$' && FRAMEWORKS="${FRAMEWORKS}MercadoPago,"
  echo "$DEPS" | grep -q '^iyzipay$' && FRAMEWORKS="${FRAMEWORKS}Iyzico,"
  echo "$DEPS" | grep -q '^@wise/api$\|^wise$' && FRAMEWORKS="${FRAMEWORKS}Wise,"
  echo "$DEPS" | grep -q '^flutterwave-node$\|^flutterwave-node-v3$' && FRAMEWORKS="${FRAMEWORKS}Flutterwave,"
fi

# FIX 7: Monorepo child package.json scan — root package.json of a monorepo often has ZERO
# framework deps (they live in child services). Scan up to 50 child packages for key frameworks.
# Uses $MONOREPO flag (set early) — works for pnpm-workspace.yaml, npm workspaces, Nx, etc.
if [ "$MONOREPO" = "true" ] && [ -f "package.json" ]; then
  WORKSPACE_DEPS=$(find . -maxdepth 4 -name 'package.json' \
    -not -path '*/node_modules/*' -not -path '*/.claude/*' \
    -not -path '*/dist/*' -not -path '*/.git/*' \
    -not -path '*/.*/*' \
    2>/dev/null | head -50 | xargs -IFILE jq -r \
    '(.dependencies // {} | keys[]) , (.devDependencies // {} | keys[])' FILE 2>/dev/null | sort -u || true)
  echo "$WORKSPACE_DEPS" | grep -q '^@nestjs/core' && ! echo "$FRAMEWORKS" | grep -q 'NestJS' && FRAMEWORKS="${FRAMEWORKS}NestJS,"
  echo "$WORKSPACE_DEPS" | grep -q '^next$' && ! echo "$FRAMEWORKS" | grep -q 'Next.js' && FRAMEWORKS="${FRAMEWORKS}Next.js,"
  echo "$WORKSPACE_DEPS" | grep -q '^react$\|^react-dom$' && ! echo "$FRAMEWORKS" | grep -q 'React' && FRAMEWORKS="${FRAMEWORKS}React,"
  echo "$WORKSPACE_DEPS" | grep -q '^express$' && ! echo "$FRAMEWORKS" | grep -q 'Express' && FRAMEWORKS="${FRAMEWORKS}Express,"
  echo "$WORKSPACE_DEPS" | grep -q '^fastify$' && ! echo "$FRAMEWORKS" | grep -q 'Fastify' && FRAMEWORKS="${FRAMEWORKS}Fastify,"
  echo "$WORKSPACE_DEPS" | grep -q '^kafkajs$' && ! echo "$FRAMEWORKS" | grep -q 'Kafka' && FRAMEWORKS="${FRAMEWORKS}Kafka,"
  echo "$WORKSPACE_DEPS" | grep -q '^vue$' && ! echo "$FRAMEWORKS" | grep -q 'Vue' && FRAMEWORKS="${FRAMEWORKS}Vue,"
  echo "$WORKSPACE_DEPS" | grep -q '^nuxt$' && ! echo "$FRAMEWORKS" | grep -q 'Nuxt' && FRAMEWORKS="${FRAMEWORKS}Nuxt,"
  echo "$WORKSPACE_DEPS" | grep -q '^@angular/core' && ! echo "$FRAMEWORKS" | grep -q 'Angular' && FRAMEWORKS="${FRAMEWORKS}Angular,"
  echo "$WORKSPACE_DEPS" | grep -q '^graphql$\|^@apollo' && ! echo "$FRAMEWORKS" | grep -q 'GraphQL' && FRAMEWORKS="${FRAMEWORKS}GraphQL,"
fi
if [ -f "deno.json" ] || [ -f "deno.jsonc" ]; then
  FRAMEWORKS="${FRAMEWORKS}Deno,"
  [ -f "deno.json" ] && grep -q 'fresh' deno.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Fresh,"
  [ -f "deno.json" ] && grep -q 'oak' deno.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Oak,"
fi

# ── Python ──
if [ -f "pyproject.toml" ]; then
  grep -qi 'django' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Django,"
  grep -qi 'fastapi' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}FastAPI,"
  grep -qi 'flask' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Flask,"
  grep -qi 'starlette' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Starlette,"
  grep -qi 'tornado' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Tornado,"
  grep -qi 'aiohttp' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}aiohttp,"
  grep -qi 'sanic' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sanic,"
  grep -qi 'litestar' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Litestar,"
  grep -qi 'celery' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Celery,"
  grep -qi 'sqlalchemy' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SQLAlchemy,"
  grep -qi 'pydantic' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pydantic,"
  grep -qi 'alembic' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Alembic,"
  grep -qi 'streamlit' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Streamlit,"
  grep -qi 'gradio' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Gradio,"
  grep -qi 'langchain' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}LangChain,"
  grep -qi 'transformers' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Transformers,"
  grep -qi 'torch\|pytorch' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PyTorch,"
  grep -qi 'tensorflow' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}TensorFlow,"
  # Cloud SDKs (parity with requirements.txt detection)
  grep -qi 'boto3\|botocore' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}AWS-SDK,"
  grep -qiE 'google-cloud|google-api-python-client' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GCP-SDK,"
  grep -qi 'azure-' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Azure-SDK,"
  grep -qiE 'openstacksdk|keystoneauth' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OpenStackClient,"
  # AWS specific Python products
  grep -qi 'aws-lambda-powertools' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}AWS-Lambda-Powertools,"
  grep -qi 'aws-cdk' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}AWS-CDK-Python,"
  grep -qi 'moto' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Moto,"
  # GCP specific Python products
  grep -qi 'google-cloud-pubsub' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GCP-PubSub,"
  grep -qi 'google-cloud-bigquery' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GCP-BigQuery,"
  grep -qi 'google-cloud-storage' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GCP-Storage,"
  grep -qi 'google-cloud-firestore' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GCP-Firestore,"
  grep -qi 'functions-framework' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GCP-Functions,"
  # Azure specific Python products
  grep -qi 'azure-servicebus' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Azure-ServiceBus,"
  grep -qi 'azure-cosmos' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Azure-CosmosDB,"
  grep -qi 'azure-storage-blob' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Azure-Blob,"
  grep -qi 'azure-functions' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Azure-Functions,"
  grep -qi 'azure-identity' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Azure-Identity,"
  # Auth providers (Python)
  grep -qi 'auth0' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Auth0,"
  grep -qi 'python-social-auth\|social-auth' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Social-Auth,"
  # Additional Python frameworks
  grep -qi 'scrapy' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Scrapy,"
  grep -qi 'pandas' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pandas,"
  grep -qi 'numpy' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}NumPy,"
  grep -qi 'polars' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Polars,"
  grep -qi 'httpx' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}httpx,"
  grep -qi 'click' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Click,"
  grep -qi 'typer' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Typer,"
  grep -qi 'dbt-' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}dbt,"
  grep -qi 'robotframework' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}RobotFramework,"
  # Django ecosystem additions
  grep -qi 'djangorestframework\|rest_framework' pyproject.toml 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'DRF' && FRAMEWORKS="${FRAMEWORKS}DRF,"
  grep -qi 'django-channels\|^channels' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Django-Channels,"
  grep -qi 'django-ninja' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Django-Ninja,"
  # Python GraphQL
  grep -qi 'strawberry-graphql' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Strawberry-GraphQL,"
  grep -qiE 'graphene|graphene-django' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Graphene,"
  grep -qi 'ariadne' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ariadne,"
  # ASGI / WSGI servers
  grep -qi 'uvicorn' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Uvicorn,"
  grep -qi 'gunicorn' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Gunicorn,"
  grep -qi 'hypercorn' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Hypercorn,"
  # Job queues / Task processing
  grep -qi '^rq\b\|python-rq\|redis-queue' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}RQ,"
  grep -qi 'dramatiq' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Dramatiq,"
  grep -qi 'huey' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Huey,"
  # ML / Data Science (additional)
  grep -qi 'scikit-learn\|sklearn' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}scikit-learn,"
  grep -qi 'scipy' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SciPy,"
  grep -qi 'matplotlib' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Matplotlib,"
  grep -qi 'plotly' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Plotly,"
  grep -qi 'seaborn' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Seaborn,"
  grep -qi 'keras' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Keras,"
  # Orchestration / Pipelines
  grep -qi 'prefect' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Prefect,"
  grep -qi 'dagster' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Dagster,"
  grep -qi 'apache-airflow\|airflow' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Airflow,"
  grep -qi 'luigi' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Luigi,"
  # Redis / Caching
  grep -qi 'redis' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Redis-Py,"
  # Observability
  grep -qi 'opentelemetry' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OpenTelemetry,"
  grep -qi 'sentry-sdk' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sentry,"
  # Docker
  grep -qi 'docker' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Docker-Py,"
  # Auth
  grep -qi 'PyJWT\|python-jose' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PyJWT,"
  grep -qi 'authlib' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Authlib,"
  # Payments / Billing (Python)
  grep -qi '^stripe' pyproject.toml 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Stripe' && FRAMEWORKS="${FRAMEWORKS}Stripe,"
  grep -qi 'mollie-api-python' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mollie,"
  grep -qi 'gocardless.pro\|gocardless_pro' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GoCardless,"
  grep -qi 'adyen' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Adyen,"
  grep -qi 'braintree' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Braintree,"
  grep -qi 'squareup\|square' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Square,"
  grep -qi 'chargebee' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Chargebee,"
  grep -qi 'recurly' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Recurly,"
  grep -qi 'paystack\|paystackapi' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Paystack,"
  grep -qi 'razorpay' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Razorpay,"
  grep -qi 'paypalrestsdk\|paypal-checkout' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PayPal,"
  grep -qi '^plaid' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Plaid,"
  # Communication (Python)
  grep -qi '^twilio' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Twilio,"
  grep -qi 'sendgrid' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SendGrid,"
  grep -qi '^resend' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Resend,"
  grep -qi 'postmarker\|postmark' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Postmark,"
  grep -qi 'mailgun' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mailgun,"
  # Feature Flags (Python)
  grep -qi 'launchdarkly-server-sdk' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}LaunchDarkly,"
  grep -qi '^flagsmith' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Flagsmith,"
  grep -qi '^posthog' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PostHog,"
  # Product Analytics (Python)
  grep -qi 'analytics-python\|segment-analytics' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Segment,"
  grep -qi 'amplitude-analytics' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Amplitude,"
  grep -qi '^mixpanel' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mixpanel,"
  # Tax Compliance (Python)
  grep -qi '^taxjar' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}TaxJar,"
  # Vector DB / RAG / AI Infra (Python) — retrieval-augmented generation, semantic search, AI-native apps
  grep -qi 'pinecone-client\|pinecone' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pinecone,"
  grep -qi 'chromadb' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ChromaDB,"
  grep -qi 'weaviate-client' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Weaviate,"
  grep -qi 'qdrant-client' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Qdrant,"
  grep -qi 'llama-index\|llama_index' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}LlamaIndex,"
  grep -qi 'haystack-ai\|farm-haystack' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Haystack,"
  grep -qi 'milvus\|pymilvus' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Milvus,"
  # LLM / AI SDKs (Python) — the AI development epicenter
  grep -qi '^anthropic' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Anthropic,"
  grep -qi '^cohere' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Cohere,"
  grep -qi '^replicate' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Replicate,"
  grep -qi 'together\b' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Together-AI,"
  grep -qi 'instructor' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Instructor,"
  grep -qi 'crewai' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}CrewAI,"
  grep -qi 'autogen\|pyautogen' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}AutoGen,"
  grep -qi 'guidance' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Guidance,"
  grep -qi 'litellm' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}LiteLLM,"
  # NLP (Python) — text processing, entity recognition, language understanding
  grep -qi '^spacy' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}spaCy,"
  grep -qi '^nltk' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}NLTK,"
  grep -qi 'gensim' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Gensim,"
  # MLOps (Python) — experiment tracking, model registry, data versioning
  grep -qi 'mlflow' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}MLflow,"
  grep -qi 'wandb' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Weights-Biases,"
  grep -qi '^dvc' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}DVC,"
  grep -qi 'optuna' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Optuna,"
  grep -qi '^ray\b\|ray\[' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ray,"
  grep -qi 'bentoml' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}BentoML,"
  # CMS (Python) — content management platforms
  grep -qi 'wagtail' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Wagtail,"
  grep -qi 'django-cms' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Django-CMS,"
  # E-commerce (Python) — marketplace, D2C backends
  grep -qi 'django-oscar\|oscar' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Django-Oscar,"
  grep -qi 'saleor' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Saleor,"
  # Geospatial (Python) — logistics, mapping, spatial analysis
  grep -qi 'geopandas' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GeoPandas,"
  grep -qi 'shapely' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Shapely,"
  grep -qi 'fiona' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Fiona,"
  grep -qi 'rasterio' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Rasterio,"
  grep -qi 'folium' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Folium,"
  # PDF / Document Generation (Python) — invoicing, contracts, reports
  grep -qi 'reportlab' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ReportLab,"
  grep -qi 'weasyprint' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}WeasyPrint,"
  grep -qi 'fpdf2\|fpdf' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}FPDF,"
  grep -qi 'python-docx\|docx' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}python-docx,"
  grep -qi 'openpyxl' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}openpyxl,"
  # Image Processing (Python) — user content, CV, thumbnails
  grep -qi 'Pillow\|PIL' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pillow,"
  grep -qi 'opencv-python\|cv2' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OpenCV,"
  # Gaming (Python) — game prototyping, educational games
  grep -qi 'pygame' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pygame,"
  grep -qi 'arcade' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Arcade,"
  # Desktop GUI (Python) — desktop applications, internal tools
  grep -qi 'PyQt5\|PyQt6' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PyQt,"
  grep -qi 'PySide6\|PySide2' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PySide,"
  grep -qi 'kivy' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Kivy,"
  grep -qi 'textual' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Textual,"
  grep -qi 'flet' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Flet,"
  # Blockchain / Web3 (Python) — smart contracts, DeFi analytics
  grep -qi 'web3' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Web3.py,"
  grep -qi 'brownie' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Brownie,"
  grep -qi 'ape\b\|ape-' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ape,"
  # IoT / MQTT (Python) — sensor networks, industrial IoT
  grep -qi 'paho-mqtt' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Paho-MQTT,"
  # Async (Python) — high-performance async I/O
  grep -qi 'asyncpg' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}asyncpg,"
  grep -qi 'aioredis\|redis\[async\]' pyproject.toml 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'aioredis' && FRAMEWORKS="${FRAMEWORKS}aioredis,"
  grep -qi 'aiofiles' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}aiofiles,"
  grep -qi 'aiohttp' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}aiohttp,"
  # Web Scraping (Python) — data extraction, competitive intelligence
  grep -qi 'beautifulsoup4\|bs4' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}BeautifulSoup,"
  grep -qi 'selenium' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Selenium,"
  grep -qi 'playwright' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Playwright,"
  # Testing (Python) — advanced testing tools
  grep -qi 'hypothesis' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Hypothesis,"
  grep -qi 'factory.boy\|factory-boy' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}FactoryBoy,"
  grep -qi 'locust' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Locust,"
  grep -qi 'responses' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Responses,"
  grep -qi 'vcrpy\|vcrpy' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}VCR.py,"
  # Scheduling (Python) — recurring jobs beyond Celery
  grep -qi 'apscheduler' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}APScheduler,"
  grep -qi 'schedule' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Schedule,"
  # Security / Crypto (Python) — encryption, hashing, signing
  grep -qi 'cryptography' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Cryptography,"
  grep -qi 'passlib' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Passlib,"
  grep -qi 'bcrypt' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}bcrypt,"
  grep -qi 'python-multipart' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}python-multipart,"
  # DB Drivers (Python) — database connectivity
  grep -qi 'psycopg2\|psycopg\[binary\]' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Psycopg,"
  grep -qi 'mysqlclient\|pymysql' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PyMySQL,"
  grep -qi 'pymongo' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PyMongo,"
  grep -qi 'motor' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Motor,"
  grep -qi 'cassandra-driver' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Cassandra-Driver,"
  grep -qi 'neo4j' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Neo4j,"
  # Data Engineering (Python) — ETL, data lake, warehousing
  grep -qi 'apache-spark\|pyspark' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PySpark,"
  grep -qi 'dask' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Dask,"
  grep -qi 'vaex' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Vaex,"
  grep -qi 'great-expectations\|great_expectations' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Great-Expectations,"
  grep -qi 'delta-spark\|deltalake' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Delta-Lake,"
  grep -qi 'pyarrow' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PyArrow,"
  grep -qi 'sqlmodel' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SQLModel,"
  # Config (Python) — environment/config management
  grep -qi 'pydantic-settings\|python-dotenv' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}python-dotenv,"
  grep -qi 'dynaconf' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Dynaconf,"
  grep -qi 'hydra-core' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Hydra,"
  # Serialization (Python) — beyond Pydantic
  grep -qi 'marshmallow' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Marshmallow,"
  grep -qi 'cattrs\|attrs' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}attrs,"
  # API Clients / Tools (Python)
  grep -qi 'grpcio\|grpcio-tools' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}gRPC-Python,"
  grep -qi 'requests' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Requests,"
  grep -qi 'tenacity' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Tenacity,"
  grep -qi 'pika' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pika-RabbitMQ,"
  grep -qi 'nats-py\|nats\.py' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}NATS,"
  # ML Deployment (Python) — model serving
  grep -qi 'fastapi-users' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}FastAPI-Users,"
  grep -qi 'onnxruntime\|onnx' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ONNX,"
  grep -qi 'triton' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Triton,"
  grep -qi 'vllm' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}vLLM,"
  grep -qi 'trl\|peft' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}HF-PEFT,"
  # Computer Vision (Python) — beyond OpenCV
  grep -qi 'ultralytics\|yolov' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}YOLO,"
  grep -qi 'detectron2' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Detectron2,"
  # Audio (Python) — speech-to-text, audio processing
  grep -qi 'whisper\|openai-whisper' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Whisper,"
  grep -qi 'librosa' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Librosa,"
  grep -qi 'pydub' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pydub,"
  # Monitoring (Python) — additional
  grep -qi 'prometheus-client\|prometheus_client' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Prometheus,"
  grep -qi 'structlog' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}structlog,"
  grep -qi 'loguru' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Loguru,"
  # Infrastructure as Code (Python)
  grep -qi 'pulumi' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pulumi-Python,"
  grep -qi 'troposphere' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Troposphere,"
  # Time Series (Python) — financial data, forecasting
  grep -qi 'prophet\|neuralprophet' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Prophet,"
  grep -qi 'statsmodels' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Statsmodels,"
  grep -qi 'tslearn\|stumpy' pyproject.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}TimeSeries-ML,"
fi
# Fallback: requirements.txt
if [ -f "requirements.txt" ]; then
  if grep -qi 'django' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Django'; then FRAMEWORKS="${FRAMEWORKS}Django,"; fi
  if grep -qi 'fastapi' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'FastAPI'; then FRAMEWORKS="${FRAMEWORKS}FastAPI,"; fi
  if grep -qi 'flask' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Flask'; then FRAMEWORKS="${FRAMEWORKS}Flask,"; fi
  if grep -qi 'celery' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Celery'; then FRAMEWORKS="${FRAMEWORKS}Celery,"; fi
  if grep -qi 'sqlalchemy' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'SQLAlchemy'; then FRAMEWORKS="${FRAMEWORKS}SQLAlchemy,"; fi
  # Cloud / infrastructure tooling
  if grep -qiE 'openstacksdk|python-openstackclient|keystoneauth' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}OpenStackClient,"; fi
  if grep -qi 'boto3\|botocore' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}AWS-SDK,"; fi
  if grep -qi 'google-cloud\|google-api-python-client' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}GCP-SDK,"; fi
  if grep -qi 'azure-' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Azure-SDK,"; fi
  if grep -qi 'kubernetes' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Kubernetes-Python,"; fi
  if grep -qi 'ansible' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Ansible'; then FRAMEWORKS="${FRAMEWORKS}Ansible,"; fi
  if grep -qi 'pulumi' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Pulumi'; then FRAMEWORKS="${FRAMEWORKS}Pulumi-Python,"; fi
  # ML / data science
  if grep -qi 'torch\|pytorch' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}PyTorch,"; fi
  if grep -qi 'tensorflow' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}TensorFlow,"; fi
  if grep -qi 'langchain' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}LangChain,"; fi
  if grep -qi 'transformers' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Transformers,"; fi
  if grep -qi 'streamlit' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Streamlit,"; fi
  if grep -qi 'djangorestframework' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'DRF'; then FRAMEWORKS="${FRAMEWORKS}DRF,"; fi
  if grep -qi 'strawberry-graphql' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Strawberry'; then FRAMEWORKS="${FRAMEWORKS}Strawberry-GraphQL,"; fi
  if grep -qiE 'graphene' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Graphene'; then FRAMEWORKS="${FRAMEWORKS}Graphene,"; fi
  # Auth
  if grep -qi 'auth0' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Auth0,"; fi
  if grep -qi 'PyJWT\|python-jose' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}PyJWT,"; fi
  # AWS specific
  if grep -qi 'aws-lambda-powertools' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}AWS-Lambda-Powertools,"; fi
  # GCP specific
  if grep -qi 'google-cloud-pubsub' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}GCP-PubSub,"; fi
  if grep -qi 'google-cloud-bigquery' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}GCP-BigQuery,"; fi
  if grep -qi 'google-cloud-storage' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}GCP-Storage,"; fi
  # Azure specific
  if grep -qi 'azure-servicebus' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Azure-ServiceBus,"; fi
  if grep -qi 'azure-cosmos' requirements.txt 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Azure-CosmosDB,"; fi
  # Payments / Billing (requirements.txt)
  if grep -qi '^stripe' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Stripe'; then FRAMEWORKS="${FRAMEWORKS}Stripe,"; fi
  if grep -qi 'mollie-api-python' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Mollie'; then FRAMEWORKS="${FRAMEWORKS}Mollie,"; fi
  if grep -qi 'gocardless.pro\|gocardless_pro' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'GoCardless'; then FRAMEWORKS="${FRAMEWORKS}GoCardless,"; fi
  if grep -qi 'braintree' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Braintree'; then FRAMEWORKS="${FRAMEWORKS}Braintree,"; fi
  if grep -qi 'squareup\|square' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Square'; then FRAMEWORKS="${FRAMEWORKS}Square,"; fi
  if grep -qi 'chargebee' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Chargebee'; then FRAMEWORKS="${FRAMEWORKS}Chargebee,"; fi
  if grep -qi 'paystack\|paystackapi' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Paystack'; then FRAMEWORKS="${FRAMEWORKS}Paystack,"; fi
  if grep -qi 'razorpay' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Razorpay'; then FRAMEWORKS="${FRAMEWORKS}Razorpay,"; fi
  # Communication (requirements.txt)
  if grep -qi '^twilio' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Twilio'; then FRAMEWORKS="${FRAMEWORKS}Twilio,"; fi
  if grep -qi 'sendgrid' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'SendGrid'; then FRAMEWORKS="${FRAMEWORKS}SendGrid,"; fi
  if grep -qi '^resend' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Resend'; then FRAMEWORKS="${FRAMEWORKS}Resend,"; fi
  # Feature Flags (requirements.txt)
  if grep -qi 'launchdarkly-server-sdk' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'LaunchDarkly'; then FRAMEWORKS="${FRAMEWORKS}LaunchDarkly,"; fi
  if grep -qi '^flagsmith' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Flagsmith'; then FRAMEWORKS="${FRAMEWORKS}Flagsmith,"; fi
  if grep -qi '^posthog' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'PostHog'; then FRAMEWORKS="${FRAMEWORKS}PostHog,"; fi
  # Vector DB / AI (requirements.txt)
  if grep -qi 'pinecone-client\|pinecone' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Pinecone'; then FRAMEWORKS="${FRAMEWORKS}Pinecone,"; fi
  if grep -qi 'chromadb' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'ChromaDB'; then FRAMEWORKS="${FRAMEWORKS}ChromaDB,"; fi
  if grep -qi 'weaviate-client' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Weaviate'; then FRAMEWORKS="${FRAMEWORKS}Weaviate,"; fi
  if grep -qi 'qdrant-client' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Qdrant'; then FRAMEWORKS="${FRAMEWORKS}Qdrant,"; fi
  if grep -qi 'llama-index\|llama_index' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'LlamaIndex'; then FRAMEWORKS="${FRAMEWORKS}LlamaIndex,"; fi
  # LLM SDKs (requirements.txt)
  if grep -qi '^anthropic' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Anthropic'; then FRAMEWORKS="${FRAMEWORKS}Anthropic,"; fi
  if grep -qi '^cohere' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Cohere'; then FRAMEWORKS="${FRAMEWORKS}Cohere,"; fi
  if grep -qi '^replicate' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Replicate'; then FRAMEWORKS="${FRAMEWORKS}Replicate,"; fi
  if grep -qi 'crewai' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'CrewAI'; then FRAMEWORKS="${FRAMEWORKS}CrewAI,"; fi
  if grep -qi 'litellm' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'LiteLLM'; then FRAMEWORKS="${FRAMEWORKS}LiteLLM,"; fi
  # NLP (requirements.txt)
  if grep -qi '^spacy' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'spaCy'; then FRAMEWORKS="${FRAMEWORKS}spaCy,"; fi
  if grep -qi '^nltk' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'NLTK'; then FRAMEWORKS="${FRAMEWORKS}NLTK,"; fi
  # MLOps (requirements.txt)
  if grep -qi 'mlflow' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'MLflow'; then FRAMEWORKS="${FRAMEWORKS}MLflow,"; fi
  if grep -qi 'wandb' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Weights-Biases'; then FRAMEWORKS="${FRAMEWORKS}Weights-Biases,"; fi
  if grep -qi '^dvc' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'DVC'; then FRAMEWORKS="${FRAMEWORKS}DVC,"; fi
  if grep -qi 'optuna' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Optuna'; then FRAMEWORKS="${FRAMEWORKS}Optuna,"; fi
  # Geospatial (requirements.txt)
  if grep -qi 'geopandas' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'GeoPandas'; then FRAMEWORKS="${FRAMEWORKS}GeoPandas,"; fi
  if grep -qi 'shapely' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Shapely'; then FRAMEWORKS="${FRAMEWORKS}Shapely,"; fi
  # PDF / Docs (requirements.txt)
  if grep -qi 'reportlab' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'ReportLab'; then FRAMEWORKS="${FRAMEWORKS}ReportLab,"; fi
  if grep -qi 'weasyprint' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'WeasyPrint'; then FRAMEWORKS="${FRAMEWORKS}WeasyPrint,"; fi
  if grep -qi 'openpyxl' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'openpyxl'; then FRAMEWORKS="${FRAMEWORKS}openpyxl,"; fi
  # Image (requirements.txt)
  if grep -qi 'Pillow\|PIL' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Pillow'; then FRAMEWORKS="${FRAMEWORKS}Pillow,"; fi
  if grep -qi 'opencv-python' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'OpenCV'; then FRAMEWORKS="${FRAMEWORKS}OpenCV,"; fi
  # Web3 (requirements.txt)
  if grep -qi 'web3' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Web3'; then FRAMEWORKS="${FRAMEWORKS}Web3.py,"; fi
  # IoT (requirements.txt)
  if grep -qi 'paho-mqtt' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Paho-MQTT'; then FRAMEWORKS="${FRAMEWORKS}Paho-MQTT,"; fi
  # Testing (requirements.txt)
  if grep -qi 'hypothesis' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Hypothesis'; then FRAMEWORKS="${FRAMEWORKS}Hypothesis,"; fi
  if grep -qi 'locust' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Locust'; then FRAMEWORKS="${FRAMEWORKS}Locust,"; fi
  # Desktop (requirements.txt)
  if grep -qi 'PyQt5\|PyQt6' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'PyQt'; then FRAMEWORKS="${FRAMEWORKS}PyQt,"; fi
  if grep -qi 'textual' requirements.txt 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Textual'; then FRAMEWORKS="${FRAMEWORKS}Textual,"; fi
fi

# ── Rust ──
if [ -f "Cargo.toml" ]; then
  grep -q 'actix' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Actix,"
  grep -q 'axum' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Axum,"
  grep -q 'rocket' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Rocket,"
  grep -q 'warp' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Warp,"
  grep -q 'tokio' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Tokio,"
  grep -q 'diesel' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Diesel,"
  grep -q 'sea-orm\|seaorm' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SeaORM,"
  grep -q 'sqlx' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SQLx,"
  grep -q 'serde' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Serde,"
  grep -q 'tauri' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Tauri,"
  grep -q 'leptos' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Leptos,"
  grep -q 'yew' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Yew,"
  grep -q 'clap' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Clap,"
  grep -q 'tonic' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Tonic-gRPC,"
  grep -q 'tracing' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Tracing,"
  grep -q 'tower' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Tower,"
  grep -q 'reqwest' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Reqwest,"
  grep -q 'bevy' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Bevy,"
  grep -q 'poem' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Poem,"
  grep -q 'async-graphql' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}async-graphql,"
  grep -q 'rdkafka' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}rdkafka,"
  grep -q 'lapin' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Lapin,"
  grep -q 'deadpool' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Deadpool,"
  grep -q 'tera\|askama' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Template-Engine,"
  grep -q 'eframe\|egui' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}egui,"
  grep -q 'dioxus' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Dioxus,"
  grep -q 'opentelemetry' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OpenTelemetry,"
  # WASM (Rust) — WebAssembly is a killer use case for Rust
  grep -q 'wasm-bindgen' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}wasm-bindgen,"
  grep -q 'web-sys' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}web-sys,"
  grep -q 'js-sys' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}js-sys,"
  grep -q 'wasm-pack\|wasm-wasi' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}wasm-pack,"
  # Embedded (Rust) — embedded-hal ecosystem for microcontrollers
  grep -q 'embedded-hal' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}embedded-hal,"
  grep -q 'cortex-m' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}cortex-m,"
  grep -q 'embassy' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Embassy,"
  grep -q 'esp-hal\|esp-idf' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ESP-HAL,"
  grep -q 'nrf-hal\|nrf-softdevice' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}nRF-HAL,"
  # Blockchain (Rust) — Solana, Ethereum, Substrate chains
  grep -q 'ethers' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ethers-rs,"
  grep -q 'alloy' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Alloy,"
  grep -q 'solana-sdk\|anchor-lang' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Solana,"
  grep -q 'substrate\|frame-support' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Substrate,"
  # GPU / Graphics (Rust) — rendering, compute shaders, game engines
  grep -q 'wgpu' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}wgpu,"
  grep -q 'vulkano' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Vulkano,"
  grep -q 'ash' Cargo.toml 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Ash' && FRAMEWORKS="${FRAMEWORKS}Ash-Vulkan,"
  # Gaming (Rust) — beyond Bevy
  grep -q 'ggez' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ggez,"
  grep -q 'macroquad' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}macroquad,"
  grep -q 'fyrox' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Fyrox,"
  # Async (Rust) — async-std alternative runtime
  grep -q 'async-std' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}async-std,"
  # PDF (Rust) — document generation
  grep -q 'printpdf' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}printpdf,"
  grep -q 'genpdf' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}genpdf,"
  # Networking / Crypto (Rust) — TLS, crypto primitives, P2P
  grep -q 'rustls' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Rustls,"
  grep -q 'ring\b' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ring-crypto,"
  grep -q 'libp2p' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}libp2p,"
  grep -q 'quinn' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Quinn-QUIC,"
  # Database (Rust) — additional drivers/ORMs
  grep -q 'rusqlite' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}rusqlite,"
  grep -q 'mongodb' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}MongoDB-Rust,"
  grep -q 'redis-rs\|redis =' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Redis-rs,"
  grep -q 'sled' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sled,"
  grep -q 'rocksdb' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}RocksDB,"
  # Testing (Rust) — property testing, mocking
  grep -q 'proptest' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Proptest,"
  grep -q 'mockall' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mockall,"
  grep -q 'insta' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Insta,"
  grep -q 'criterion' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Criterion,"
  # Serialization (Rust) — beyond Serde
  grep -q 'bincode' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Bincode,"
  grep -q 'prost' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Prost-Protobuf,"
  # CLI (Rust) — terminal UI and CLI frameworks
  grep -q 'ratatui\|tui-rs' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ratatui,"
  grep -q 'dialoguer\|inquire' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Dialoguer,"
  grep -q 'indicatif' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Indicatif,"
  # Error Handling (Rust) — idiomatic error patterns
  grep -q 'anyhow' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Anyhow,"
  grep -q 'thiserror' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Thiserror,"
  grep -q 'color-eyre\|eyre' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Eyre,"
  # Config (Rust) — configuration management
  grep -q 'config\b' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Config-rs,"
  grep -q 'figment' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Figment,"
  # Observability (Rust) — beyond tracing
  grep -q 'metrics\b' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Metrics-rs,"
  grep -q 'prometheus\b' Cargo.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Prometheus,"
fi

# ── Go ──
if [ -f "go.mod" ]; then
  grep -q 'gin-gonic' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Gin,"
  grep -q 'labstack/echo' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Echo,"
  grep -q 'gofiber/fiber' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Fiber,"
  grep -q 'go-chi/chi' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Chi,"
  grep -q 'gorilla/mux' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Gorilla,"
  grep -q 'grpc' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}gRPC,"
  grep -q 'gorm.io' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GORM,"
  grep -q 'ent.' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ent,"
  grep -q 'sqlc' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}sqlc,"
  grep -q 'cobra' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Cobra,"
  grep -q 'viper' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Viper,"
  grep -q 'zerolog\|zap\|logrus' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}structured-logging,"
  grep -q 'stretchr/testify' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Testify,"
  grep -q 'uber-go/fx\|uber.org/fx' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Uber-FX,"
  grep -q 'google/wire' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Wire,"
  grep -q 'bufbuild/buf\|buf.build' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Buf,"
  grep -q 'cosmtrek/air\|air' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Air,"
  grep -q 'connectrpc\|connect-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ConnectRPC,"
  grep -q 'pressly/goose' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Goose,"
  grep -q '99designs/gqlgen\|graphql-go/graphql' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GraphQL-Go,"
  grep -q 'go.opentelemetry.io' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OpenTelemetry,"
  grep -q 'nats-io/nats' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}NATS,"
  grep -q 'temporalio/sdk-go\|temporal-sdk-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Temporal,"
  grep -q 'jackc/pgx' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}pgx,"
  grep -q 'redis/go-redis\|gomodule/redigo' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Go-Redis,"
  grep -q 'golang-migrate/migrate' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Go-Migrate,"
  grep -q 'swaggo/swag' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Swag,"
  grep -q 'hashicorp/consul' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Consul,"
  grep -q 'hashicorp/vault' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Vault,"
  grep -q 'elastic/go-elasticsearch' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Elasticsearch,"
  grep -q 'minio/minio-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}MinIO,"
  grep -q 'segmentio/kafka-go\|Shopify/sarama' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Kafka,"
  grep -q 'aws/aws-sdk-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}AWS-SDK,"
  grep -q 'cloud.google.com/go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GCP-SDK,"
  grep -q 'Azure/azure-sdk-for-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Azure-SDK,"
  # Payments / Communication (Go) — high-performance fintech backends (Monzo, Square use Go)
  grep -q 'stripe/stripe-go\|stripe-go' go.mod 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Stripe' && FRAMEWORKS="${FRAMEWORKS}Stripe,"
  grep -q 'adyen-go\|github.com/adyen' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Adyen,"
  grep -q 'braintree-go\|lionelbarrow/braintree-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Braintree,"
  grep -q 'mollie/mollie-go\|go-mollie' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mollie,"
  grep -q 'square/square-go-sdk\|square.go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Square,"
  grep -q 'paystack\|rpagliuca/paystackk' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Paystack,"
  grep -q 'razorpay/razorpay-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Razorpay,"
  grep -q 'plaid/plaid-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Plaid,"
  grep -q 'twilio/twilio-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Twilio,"
  grep -q 'sendgrid/sendgrid-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SendGrid,"
  grep -q 'resend/resend-go\|resendlabs/resend-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Resend,"
  grep -q 'launchdarkly/go-server-sdk' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}LaunchDarkly,"
  grep -q 'unleash-client-go\|Unleash/unleash-client-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Unleash,"
  grep -q 'posthog-go\|PostHog/posthog-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PostHog,"
  grep -q 'segmentio/analytics-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Segment,"
  # Kubernetes operators / controllers (Go) — Go is THE language for K8s controllers
  grep -q 'sigs.k8s.io/controller-runtime' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}controller-runtime,"
  grep -q 'k8s.io/client-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}client-go,"
  grep -q 'operator-framework\|operator-sdk' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Operator-SDK,"
  # Observability (Go) — Prometheus is built in Go
  grep -q 'prometheus/client_golang' go.mod 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Prometheus' && FRAMEWORKS="${FRAMEWORKS}Prometheus,"
  grep -q 'getsentry/sentry-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sentry,"
  # Scheduling / Cron (Go) — recurring job management
  grep -q 'robfig/cron' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}robfig-cron,"
  # Validation (Go) — struct validation
  grep -q 'go-playground/validator' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Validator,"
  # MQTT / IoT (Go) — high-performance MQTT brokers/clients
  grep -q 'eclipse/paho.mqtt.golang' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Paho-MQTT,"
  # Blockchain (Go) — go-ethereum is the reference implementation
  grep -q 'ethereum/go-ethereum' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Geth,"
  grep -q 'cosmos-sdk\|cosmos/cosmos-sdk' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Cosmos-SDK,"
  # Event sourcing / messaging (Go)
  grep -q 'ThreeDotsLabs/watermill' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Watermill,"
  grep -q 'EventStore/EventStore-Client-Go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}EventStoreDB,"
  # Testing (Go) — BDD-style testing
  grep -q 'onsi/ginkgo' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ginkgo,"
  grep -q 'onsi/gomega' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Gomega,"
  grep -q 'testcontainers/testcontainers-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Testcontainers,"
  # PDF (Go) — document generation
  grep -q 'jung-kurt/gofpdf\|go-pdf\|unidoc' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GoPDF,"
  # Config (Go) — environment-based config
  grep -q 'kelseyhightower/envconfig\|caarlos0/env' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Envconfig,"
  # Embedded / IoT (Go)
  grep -q 'gobot.io\|periph.io' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Gobot,"
  # Auth / Security (Go) — OAuth, OIDC, JWT
  grep -q 'golang-jwt/jwt\|dgrijalva/jwt-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}JWT-Go,"
  grep -q 'ory/fosite\|coreos/go-oidc' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OIDC-Go,"
  grep -q 'casbin/casbin' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Casbin,"
  # HTTP / Web (Go) — additional frameworks and tools
  grep -q 'go-kit/kit\|go-kit/log' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Go-Kit,"
  grep -q 'go-resty/resty' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Resty,"
  grep -q 'go-playground/form\|gorilla/schema' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Gorilla-Schema,"
  grep -q 'gin-contrib/cors' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Gin-CORS,"
  grep -q 'gorilla/websocket\|nhooyr.io/websocket' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}WebSocket-Go,"
  # Database (Go) — additional drivers and tools
  grep -q 'go.mongodb.org/mongo-driver' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}MongoDB-Go,"
  grep -q 'dgraph-io/badger' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}BadgerDB,"
  grep -q 'cockroachdb/pebble\|etcd-io/bbolt' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}BoltDB,"
  grep -q 'jmoiron/sqlx' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}sqlx-Go,"
  grep -q 'go-gorm/datatypes' go.mod 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'GORM' && FRAMEWORKS="${FRAMEWORKS}GORM,"
  grep -q 'uptrace/bun' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Bun-Go,"
  # CLI (Go) — additional CLI tools
  grep -q 'urfave/cli' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}urfave-cli,"
  grep -q 'charmbracelet/bubbletea' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}BubbleTea,"
  grep -q 'charmbracelet/lipgloss' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Lipgloss,"
  grep -q 'charmbracelet/glamour' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Glamour,"
  # File storage (Go) — object storage abstractions
  grep -q 'graymeta/stow\|rclone' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Stow,"
  # Networking (Go) — DNS, proxy, tunneling
  grep -q 'miekg/dns' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}DNS-Go,"
  grep -q 'quic-go/quic-go' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}QUIC-Go,"
  # Config (Go) — additional config management
  grep -q 'joho/godotenv' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}godotenv,"
  grep -q 'knadh/koanf' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Koanf,"
  # Testing (Go) — additional testing tools
  grep -q 'cucumber/godog' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Godog,"
  grep -q 'vektra/mockery\|stretchr/mockery' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mockery,"
  grep -q 'DATA-DOG/go-sqlmock' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}go-sqlmock,"
  # API / Documentation (Go) — additional
  grep -q 'getkin/kin-openapi\|go-openapi' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OpenAPI-Go,"
  # Service mesh (Go) — Envoy, Istio extensions
  grep -q 'envoyproxy/go-control-plane' go.mod 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Envoy-Control-Plane,"
fi

# ── Java / Kotlin / Scala ──
# Scan root pom.xml AND child pom.xml files (monorepos have Java modules nested)
_POM_FILES=""
[ -f "pom.xml" ] && _POM_FILES="pom.xml"
_CHILD_POMS=$(find . -maxdepth 4 -name 'pom.xml' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/target/*' 2>/dev/null | head -10)
_POM_FILES="${_POM_FILES} ${_CHILD_POMS}"

for _pom in $_POM_FILES; do
  [ -f "$_pom" ] || continue
  if grep -q 'spring-boot' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Spring-Boot'; then FRAMEWORKS="${FRAMEWORKS}Spring-Boot,"; fi
  if grep -q 'spring-cloud' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Spring-Cloud'; then FRAMEWORKS="${FRAMEWORKS}Spring-Cloud,"; fi
  if grep -q 'spring-security' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Spring-Security'; then FRAMEWORKS="${FRAMEWORKS}Spring-Security,"; fi
  if grep -q 'quarkus' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Quarkus'; then FRAMEWORKS="${FRAMEWORKS}Quarkus,"; fi
  if grep -q 'micronaut' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Micronaut'; then FRAMEWORKS="${FRAMEWORKS}Micronaut,"; fi
  if grep -qE 'vertx|vert\.x' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Vert.x'; then FRAMEWORKS="${FRAMEWORKS}Vert.x,"; fi
  if grep -q 'hibernate' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Hibernate'; then FRAMEWORKS="${FRAMEWORKS}Hibernate,"; fi
  if grep -q 'mybatis' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'MyBatis'; then FRAMEWORKS="${FRAMEWORKS}MyBatis,"; fi
  if grep -q 'kafka' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Kafka'; then FRAMEWORKS="${FRAMEWORKS}Kafka,"; fi
  if grep -q 'lombok' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Lombok'; then FRAMEWORKS="${FRAMEWORKS}Lombok,"; fi
  if grep -q 'jaxb' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'JAXB'; then FRAMEWORKS="${FRAMEWORKS}JAXB,"; fi
  if grep -q 'flyway' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Flyway'; then FRAMEWORKS="${FRAMEWORKS}Flyway,"; fi
  if grep -q 'liquibase' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Liquibase'; then FRAMEWORKS="${FRAMEWORKS}Liquibase,"; fi
  if grep -q 'mapstruct' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'MapStruct'; then FRAMEWORKS="${FRAMEWORKS}MapStruct,"; fi
  if grep -qiE 'grpc-java|protobuf-java|io\.grpc' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'gRPC-Java'; then FRAMEWORKS="${FRAMEWORKS}gRPC-Java,"; fi
  if grep -qiE 'reactor-core|spring-webflux' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Reactor'; then FRAMEWORKS="${FRAMEWORKS}Reactor,"; fi
  if grep -qiE 'springdoc|springfox|swagger' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'OpenAPI'; then FRAMEWORKS="${FRAMEWORKS}OpenAPI,"; fi
  if grep -qiE 'netflix.*dgs|dgs-framework|com\.netflix\.graphql' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'DGS'; then FRAMEWORKS="${FRAMEWORKS}DGS,"; fi
  if grep -qi 'spring-graphql' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Spring-GraphQL'; then FRAMEWORKS="${FRAMEWORKS}Spring-GraphQL,"; fi
  if grep -qi 'micrometer' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Micrometer'; then FRAMEWORKS="${FRAMEWORKS}Micrometer,"; fi
  if grep -qi 'opentelemetry' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'OpenTelemetry'; then FRAMEWORKS="${FRAMEWORKS}OpenTelemetry,"; fi
  if grep -qi 'jooq' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'jOOQ'; then FRAMEWORKS="${FRAMEWORKS}jOOQ,"; fi
  if grep -qi 'testcontainers' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Testcontainers'; then FRAMEWORKS="${FRAMEWORKS}Testcontainers,"; fi
  if grep -qi 'resilience4j' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Resilience4j'; then FRAMEWORKS="${FRAMEWORKS}Resilience4j,"; fi
  if grep -qi 'caffeine' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Caffeine'; then FRAMEWORKS="${FRAMEWORKS}Caffeine,"; fi
  if grep -qi 'camel' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Camel'; then FRAMEWORKS="${FRAMEWORKS}Apache-Camel,"; fi
  if grep -qi 'spring-batch' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Spring-Batch'; then FRAMEWORKS="${FRAMEWORKS}Spring-Batch,"; fi
  if grep -qi 'keycloak' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Keycloak'; then FRAMEWORKS="${FRAMEWORKS}Keycloak,"; fi
  if grep -qi 'jackson' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Jackson'; then FRAMEWORKS="${FRAMEWORKS}Jackson,"; fi
  if grep -qi 'spring-data-redis\|jedis\|lettuce' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Redis'; then FRAMEWORKS="${FRAMEWORKS}Redis,"; fi
  if grep -qiE 'aws-java-sdk|software\.amazon\.awssdk' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'AWS-SDK'; then FRAMEWORKS="${FRAMEWORKS}AWS-SDK,"; fi
  if grep -qi 'spring-cloud-aws\|aws-lambda-java' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'AWS-Lambda'; then FRAMEWORKS="${FRAMEWORKS}AWS-Lambda-Java,"; fi
  if grep -qiE 'google-cloud|gcloud|com\.google\.cloud' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'GCP-SDK'; then FRAMEWORKS="${FRAMEWORKS}GCP-SDK,"; fi
  if grep -qiE 'azure-spring|com\.azure' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Azure-SDK'; then FRAMEWORKS="${FRAMEWORKS}Azure-SDK,"; fi
  if grep -qi 'auth0' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Auth0'; then FRAMEWORKS="${FRAMEWORKS}Auth0,"; fi
  if grep -qi 'cognito' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Cognito'; then FRAMEWORKS="${FRAMEWORKS}AWS-Cognito,"; fi
  # Payments / Communication (Java/Kotlin)
  if grep -qi 'stripe' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Stripe'; then FRAMEWORKS="${FRAMEWORKS}Stripe,"; fi
  if grep -qi 'adyen' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Adyen'; then FRAMEWORKS="${FRAMEWORKS}Adyen,"; fi
  if grep -qi 'braintree' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Braintree'; then FRAMEWORKS="${FRAMEWORKS}Braintree,"; fi
  if grep -qi 'paypal.*checkout\|paypal-checkout\|com.paypal' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'PayPal'; then FRAMEWORKS="${FRAMEWORKS}PayPal,"; fi
  if grep -qi 'chargebee' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Chargebee'; then FRAMEWORKS="${FRAMEWORKS}Chargebee,"; fi
  if grep -qi 'net\.authorize\|authorizenet' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Authorize.net'; then FRAMEWORKS="${FRAMEWORKS}Authorize.net,"; fi
  if grep -qi 'worldpay\|vantiv' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Worldpay'; then FRAMEWORKS="${FRAMEWORKS}Worldpay,"; fi
  if grep -qi 'twilio' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Twilio'; then FRAMEWORKS="${FRAMEWORKS}Twilio,"; fi
  if grep -qi 'sendgrid' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'SendGrid'; then FRAMEWORKS="${FRAMEWORKS}SendGrid,"; fi
  if grep -qi 'launchdarkly' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'LaunchDarkly'; then FRAMEWORKS="${FRAMEWORKS}LaunchDarkly,"; fi
  if grep -qi 'unleash.*client\|io\.getunleash' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Unleash'; then FRAMEWORKS="${FRAMEWORKS}Unleash,"; fi
  # Template engines (Java/Kotlin) — server-side rendering in enterprise apps
  if grep -qi 'thymeleaf' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Thymeleaf'; then FRAMEWORKS="${FRAMEWORKS}Thymeleaf,"; fi
  if grep -qi 'freemarker' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Freemarker'; then FRAMEWORKS="${FRAMEWORKS}Freemarker,"; fi
  # Workflow / CQRS / Event Sourcing (Java/Kotlin) — enterprise process orchestration
  if grep -qi 'camunda\|zeebe' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Camunda'; then FRAMEWORKS="${FRAMEWORKS}Camunda,"; fi
  if grep -qi 'axonframework\|axon-spring' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Axon'; then FRAMEWORKS="${FRAMEWORKS}Axon,"; fi
  if grep -qi 'jbpm' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'jBPM'; then FRAMEWORKS="${FRAMEWORKS}jBPM,"; fi
  if grep -qi 'flowable' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Flowable'; then FRAMEWORKS="${FRAMEWORKS}Flowable,"; fi
  if grep -qi 'temporal-sdk\|io\.temporal' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Temporal'; then FRAMEWORKS="${FRAMEWORKS}Temporal,"; fi
  # PDF / Reporting (Java/Kotlin) — enterprise reporting and invoicing
  if grep -qi 'itext\|itextpdf' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'iText'; then FRAMEWORKS="${FRAMEWORKS}iText,"; fi
  if grep -qi 'pdfbox' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'PDFBox'; then FRAMEWORKS="${FRAMEWORKS}PDFBox,"; fi
  if grep -qi 'jasperreports\|jasper' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'JasperReports'; then FRAMEWORKS="${FRAMEWORKS}JasperReports,"; fi
  # Testing (Java/Kotlin) — enterprise testing ecosystem
  if grep -qi 'mockito' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Mockito'; then FRAMEWORKS="${FRAMEWORKS}Mockito,"; fi
  if grep -qi 'wiremock' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'WireMock'; then FRAMEWORKS="${FRAMEWORKS}WireMock,"; fi
  if grep -qi 'assertj' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'AssertJ'; then FRAMEWORKS="${FRAMEWORKS}AssertJ,"; fi
  if grep -qi 'archunit' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'ArchUnit'; then FRAMEWORKS="${FRAMEWORKS}ArchUnit,"; fi
  # Blockchain (Java) — enterprise DLT
  if grep -qi 'web3j' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Web3j'; then FRAMEWORKS="${FRAMEWORKS}Web3j,"; fi
  # Big Data (Java) — Beam / Hadoop
  if grep -qi 'apache.*beam\|beam-sdks' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Beam'; then FRAMEWORKS="${FRAMEWORKS}Apache-Beam,"; fi
  if grep -qi 'hadoop' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Hadoop'; then FRAMEWORKS="${FRAMEWORKS}Hadoop,"; fi
  # Messaging (Java) — JMS, Pulsar, additional queues
  if grep -qi 'activemq\|artemis' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'ActiveMQ'; then FRAMEWORKS="${FRAMEWORKS}ActiveMQ,"; fi
  if grep -qi 'pulsar-client\|apache.*pulsar' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Pulsar'; then FRAMEWORKS="${FRAMEWORKS}Apache-Pulsar,"; fi
  if grep -qi 'spring-amqp\|spring-rabbit' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'RabbitMQ'; then FRAMEWORKS="${FRAMEWORKS}RabbitMQ,"; fi
  if grep -qi 'nats-io\|nats-client' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'NATS'; then FRAMEWORKS="${FRAMEWORKS}NATS,"; fi
  # Security (Java) — advanced security frameworks
  if grep -qi 'shiro' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Shiro'; then FRAMEWORKS="${FRAMEWORKS}Apache-Shiro,"; fi
  if grep -qi 'bouncycastle\|bcprov' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'BouncyCastle'; then FRAMEWORKS="${FRAMEWORKS}BouncyCastle,"; fi
  # Serialization (Java) — beyond Jackson
  if grep -qi 'protobuf-java' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Protobuf'; then FRAMEWORKS="${FRAMEWORKS}Protobuf,"; fi
  if grep -qi 'avro' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Avro'; then FRAMEWORKS="${FRAMEWORKS}Apache-Avro,"; fi
  # Search (Java) — Lucene, Solr
  if grep -qi 'lucene\|apache.*solr' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Lucene'; then FRAMEWORKS="${FRAMEWORKS}Lucene,"; fi
  if grep -qi 'elasticsearch-java\|co\.elastic' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Elasticsearch'; then FRAMEWORKS="${FRAMEWORKS}Elasticsearch,"; fi
  # Cloud-native (Java) — Spring Cloud components
  if grep -qi 'spring-cloud-stream' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Spring-Cloud-Stream'; then FRAMEWORKS="${FRAMEWORKS}Spring-Cloud-Stream,"; fi
  if grep -qi 'spring-cloud-gateway' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Spring-Cloud-Gateway'; then FRAMEWORKS="${FRAMEWORKS}Spring-Cloud-Gateway,"; fi
  if grep -qi 'spring-cloud-config' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Spring-Cloud-Config'; then FRAMEWORKS="${FRAMEWORKS}Spring-Cloud-Config,"; fi
  # Scheduling (Java) — Quartz scheduler
  if grep -qi 'quartz' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Quartz'; then FRAMEWORKS="${FRAMEWORKS}Quartz,"; fi
  # Caching (Java) — additional
  if grep -qi 'hazelcast' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Hazelcast'; then FRAMEWORKS="${FRAMEWORKS}Hazelcast,"; fi
  if grep -qi 'ehcache' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'EhCache'; then FRAMEWORKS="${FRAMEWORKS}EhCache,"; fi
  # Data validation (Java)
  if grep -qi 'javax.validation\|jakarta.validation\|hibernate-validator' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Bean-Validation'; then FRAMEWORKS="${FRAMEWORKS}Bean-Validation,"; fi
  # Reactive (Java) — additional
  if grep -qi 'rxjava\|io\.reactivex' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'RxJava'; then FRAMEWORKS="${FRAMEWORKS}RxJava,"; fi
  # API Gateway (Java) — Zuul, Kong
  if grep -qi 'zuul\|spring-cloud-netflix' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Zuul'; then FRAMEWORKS="${FRAMEWORKS}Zuul,"; fi
  # Service Discovery (Java)
  if grep -qi 'eureka' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Eureka'; then FRAMEWORKS="${FRAMEWORKS}Eureka,"; fi
  if grep -qi 'consul' "$_pom" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Consul'; then FRAMEWORKS="${FRAMEWORKS}Consul,"; fi
done
if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
  GRADLE_FILE=""; for _f in build.gradle build.gradle.kts; do [ -f "$_f" ] && GRADLE_FILE="$_f" && break; done
  grep -q 'spring-boot' "$GRADLE_FILE" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Spring-Boot' && FRAMEWORKS="${FRAMEWORKS}Spring-Boot,"
  grep -q 'quarkus' "$GRADLE_FILE" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Quarkus' && FRAMEWORKS="${FRAMEWORKS}Quarkus,"
  grep -q 'ktor' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ktor,"
  grep -q 'android' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Android,"
  grep -q 'flyway' "$GRADLE_FILE" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Flyway' && FRAMEWORKS="${FRAMEWORKS}Flyway,"
  grep -q 'liquibase' "$GRADLE_FILE" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Liquibase' && FRAMEWORKS="${FRAMEWORKS}Liquibase,"
  grep -q 'kotlinx-coroutines' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Coroutines,"
  grep -q 'arrow-' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Arrow,"
  grep -q 'compose' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Jetpack-Compose,"
  grep -q 'koin' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Koin,"
  grep -q 'hilt' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Hilt,"
  grep -q 'room' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Room,"
  grep -q 'retrofit' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Retrofit,"
  grep -q 'multiplatform\|KMP' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}KMP,"
  # Kotlin ecosystem (additional)
  grep -q 'exposed\|org.jetbrains.exposed' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Exposed,"
  grep -q 'ktor-client\|ktor-server' "$GRADLE_FILE" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Ktor' && FRAMEWORKS="${FRAMEWORKS}Ktor,"
  grep -q 'sqldelight\|app.cash.sqldelight' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SQLDelight,"
  grep -q 'ksp\|devtools.ksp' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}KSP,"
  grep -q 'detekt' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Detekt,"
  grep -q 'mockk' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}MockK,"
  grep -q 'kotest' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Kotest,"
  # Android (additional)
  grep -q 'navigation\|androidx.navigation' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Navigation,"
  grep -q 'work-runtime\|WorkManager' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}WorkManager,"
  grep -q 'paging\|androidx.paging' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Paging,"
  grep -q 'datastore\|DataStore' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}DataStore,"
  grep -q 'coil' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Coil,"
  grep -q 'glide' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Glide,"
  grep -q 'okhttp' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OkHttp,"
  grep -q 'moshi' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Moshi,"
  grep -q 'timber' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Timber,"
fi

# ── Ruby ──
if [ -f "Gemfile" ]; then
  grep -q 'rails' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Rails,"
  grep -q 'sinatra' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sinatra,"
  grep -q 'hanami' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Hanami,"
  grep -q 'grape' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Grape,"
  grep -q 'sidekiq' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sidekiq,"
  grep -q 'resque' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Resque,"
  grep -q 'devise' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Devise,"
  grep -q 'jekyll' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Jekyll,"
  grep -q 'pundit' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pundit,"
  grep -q 'cancancan' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}CanCanCan,"
  grep -q 'capybara' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Capybara,"
  grep -q 'factory_bot' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}FactoryBot,"
  grep -q 'faker' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Faker,"
  grep -q 'sorbet' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sorbet,"
  grep -q 'dry-' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}dry-rb,"
  grep -q 'graphql-ruby\|graphql' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GraphQL-Ruby,"
  grep -q 'hotwire-rails\|turbo-rails' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Hotwire,"
  grep -q 'stimulus-rails\|stimulus' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Stimulus,"
  grep -q 'good_job' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GoodJob,"
  grep -q 'doorkeeper' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Doorkeeper,"
  grep -q 'redis' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Redis,"
  grep -q 'active_model_serializers\|jsonapi-serializer' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}AMS,"
  grep -q 'rspec' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}RSpec,"
  grep -q 'omniauth' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OmniAuth,"
  grep -q 'aws-sdk' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}AWS-SDK,"
  # Payments / Communication (Ruby)
  grep -q 'stripe' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Stripe,"
  grep -q 'mollie' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mollie,"
  grep -q 'gocardless-pro' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GoCardless,"
  grep -q 'braintree' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Braintree,"
  grep -q 'square' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Square,"
  grep -q 'chargebee' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Chargebee,"
  grep -q 'recurly' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Recurly,"
  grep -q 'paypal' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PayPal,"
  grep -q 'active_merchant' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ActiveMerchant,"
  grep -q 'shopify_api' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Shopify-API,"
  grep -q 'twilio-ruby\|twilio' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Twilio,"
  grep -q 'sendgrid' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SendGrid,"
  grep -q 'postmark' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Postmark,"
  grep -q 'mailgun' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mailgun,"
  grep -q 'ldclient-rb\|launchdarkly' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}LaunchDarkly,"
  # E-commerce (Ruby) — Shopify ecosystem, marketplaces, D2C
  grep -q 'solidus' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Solidus,"
  grep -q 'spree' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Spree,"
  grep -q 'shopify_app' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Shopify-App,"
  # PDF / Document (Ruby) — invoicing, contracts
  grep -q 'prawn' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Prawn,"
  grep -q 'wicked_pdf' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}WickedPDF,"
  grep -q 'grover' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Grover,"
  # Search (Ruby) — Elasticsearch/Meilisearch wrappers
  grep -q 'searchkick' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Searchkick,"
  grep -q 'ransack' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ransack,"
  grep -q 'pg_search' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PgSearch,"
  # Admin (Ruby) — admin panels
  grep -q 'activeadmin' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ActiveAdmin,"
  grep -q 'administrate' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Administrate,"
  # File uploads (Ruby)
  grep -q 'shrine' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Shrine,"
  grep -q 'carrierwave' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}CarrierWave,"
  # Background jobs (Ruby) — additional
  grep -q 'delayed_job' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}DelayedJob,"
  # Testing (Ruby)
  grep -q 'webmock' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}WebMock,"
  grep -q 'vcr' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}VCR,"
  grep -q 'shoulda' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Shoulda,"
  grep -q 'simplecov' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SimpleCov,"
  # API / Serialization (Ruby) — additional
  grep -q 'grape-entity' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Grape-Entity,"
  grep -q 'alba\|oj' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Oj,"
  grep -q 'pagy' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pagy,"
  # Caching / Performance (Ruby)
  grep -q 'dalli' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Memcached,"
  grep -q 'rack-attack' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Rack-Attack,"
  # Deployment (Ruby)
  grep -q 'capistrano' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Capistrano,"
  grep -q 'kamal\|mrsk' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Kamal,"
  # Auth (Ruby) — additional
  grep -q 'rodauth' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Rodauth,"
  grep -q 'warden' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Warden,"
  # State machines (Ruby) — business process management
  grep -q 'aasm' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}AASM,"
  grep -q 'statesman' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Statesman,"
  # Monitoring (Ruby)
  grep -q 'skylight' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Skylight,"
  grep -q 'scout_apm\|sentry-ruby' Gemfile 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sentry,"
fi

# ── PHP ──
if [ -f "composer.json" ]; then
  grep -q 'laravel' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Laravel,"
  grep -q 'symfony' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Symfony,"
  grep -q 'slim/slim' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Slim,"
  grep -q 'livewire' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Livewire,"
  grep -q 'filament' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Filament,"
  grep -q 'doctrine' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Doctrine,"
  grep -q 'wordpress\|wp-' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}WordPress,"
  grep -q 'drupal' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Drupal,"
  grep -q 'yiisoft/yii2' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Yii,"
  grep -q 'cakephp' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}CakePHP,"
  grep -q 'inertiajs' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Inertia,"
  grep -q 'pestphp' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pest,"
  grep -q 'phpunit' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PHPUnit,"
  grep -q 'api-platform' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}API-Platform,"
  grep -q 'laravel/sanctum' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sanctum,"
  grep -q 'laravel/horizon' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Horizon,"
  grep -q 'laravel/socialite' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Socialite,"
  grep -q 'spatie/' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Spatie,"
  grep -q 'guzzlehttp' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Guzzle,"
  grep -q 'league/oauth2' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OAuth2-Server,"
  grep -q 'auth0' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Auth0,"
  grep -q 'aws/aws-sdk-php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}AWS-SDK,"
  grep -q 'google/cloud' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GCP-SDK,"
  # Payments / Billing (PHP) — huge in WooCommerce/Laravel/Magento e-commerce
  grep -q 'stripe/stripe-php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Stripe,"
  grep -q 'mollie/mollie-api-php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mollie,"
  grep -q 'gocardless/payments-api-client-php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GoCardless,"
  grep -q 'adyen/php-http-client' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Adyen,"
  grep -q 'braintree/braintree_php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Braintree,"
  grep -q 'square/square' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Square,"
  grep -q 'chargebee/chargebee-php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Chargebee,"
  grep -q 'recurly/recurly-client' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Recurly,"
  grep -q 'paypal/paypal-checkout-sdk\|paypal/rest-api-sdk-php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PayPal,"
  grep -q 'authorizenet/sdk-php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Authorize.net,"
  grep -q 'omnipay/omnipay' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Omnipay,"
  # Communication (PHP)
  grep -q 'twilio/sdk' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Twilio,"
  grep -q 'sendgrid/sendgrid' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SendGrid,"
  grep -q 'mailgun/mailgun-php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mailgun,"
  grep -q 'postmark/postmark-php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Postmark,"
  # Feature Flags (PHP)
  grep -q 'launchdarkly/server-sdk' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}LaunchDarkly,"
  grep -q 'unleash/client-sdk-php\|php-unleash/client' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Unleash,"
  # E-commerce platforms (PHP) — WooCommerce, Magento, PrestaShop dominate global e-commerce
  grep -q 'magento' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Magento,"
  grep -q 'prestashop' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PrestaShop,"
  grep -q 'woocommerce\|automattic/woocommerce' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}WooCommerce,"
  grep -q 'sylius' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sylius,"
  grep -q 'bagisto' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Bagisto,"
  # CMS additions (PHP)
  grep -q 'statamic' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Statamic,"
  grep -q 'october\|octobercms' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OctoberCMS,"
  grep -q 'craftcms' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}CraftCMS,"
  # Static analysis (PHP)
  grep -q 'phpstan/phpstan' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PHPStan,"
  grep -q 'vimeo/psalm' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Psalm,"
  grep -q 'rector/rector' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Rector,"
  # PDF (PHP) — invoicing, document generation
  grep -q 'dompdf/dompdf' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}DomPDF,"
  grep -q 'mpdf/mpdf' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}mPDF,"
  grep -q 'tecnickcom/tcpdf' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}TCPDF,"
  # Search (PHP)
  grep -q 'meilisearch/meilisearch-php' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Meilisearch,"
  grep -q 'elasticsearch/elasticsearch' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Elasticsearch,"
  grep -q 'algolia/algoliasearch' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Algolia,"
  # Messaging (PHP) — queue systems beyond Horizon
  grep -q 'php-amqplib/php-amqplib' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}RabbitMQ,"
  # Admin panels (PHP) — backend admin interfaces
  grep -q 'nova\|laravel/nova' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Nova,"
  grep -q 'backpack' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Backpack,"
  grep -q 'easyadmin\|EasyCorp' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}EasyAdmin,"
  # Laravel ecosystem (PHP) — additional packages
  grep -q 'laravel/breeze' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Breeze,"
  grep -q 'laravel/jetstream' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Jetstream,"
  grep -q 'laravel/cashier' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Cashier,"
  grep -q 'laravel/scout' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Scout,"
  grep -q 'laravel/octane' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Octane,"
  grep -q 'laravel/pennant' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pennant,"
  grep -q 'laravel/pulse' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pulse,"
  grep -q 'laravel/reverb' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Reverb,"
  # Testing (PHP) — additional
  grep -q 'mockery/mockery' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mockery,"
  grep -q 'laravel/dusk' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Dusk,"
  # Observability (PHP) — monitoring
  grep -q 'sentry/sentry-laravel\|sentry/sentry' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Sentry,"
  grep -q 'bugsnag/bugsnag-laravel\|bugsnag' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Bugsnag,"
  # Auth (PHP) — additional
  grep -q 'lcobucci/jwt' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}JWT-PHP,"
  grep -q 'firebase/php-jwt' composer.json 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'JWT-PHP' && FRAMEWORKS="${FRAMEWORKS}JWT-PHP,"
  # Deployment (PHP)
  grep -q 'deployer/deployer' composer.json 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Deployer,"
fi
# WordPress: also detect by wp-config.php / wp-includes presence
if ! echo "$FRAMEWORKS" | grep -q 'WordPress'; then
  if [ -f "wp-config.php" ] || [ -d "wp-includes" ]; then FRAMEWORKS="${FRAMEWORKS}WordPress,"; fi
fi
# Magento: also detect by app/etc/env.php or Magento module registration
if ! echo "$FRAMEWORKS" | grep -q 'Magento'; then
  if [ -f "app/etc/env.php" ] || [ -f "app/etc/config.php" ]; then FRAMEWORKS="${FRAMEWORKS}Magento,"; fi
fi

# ── .NET / C# ──
for csproj in $(find . -maxdepth 3 -name '*.csproj' 2>/dev/null | head -5); do
  grep -q 'Microsoft.AspNetCore\|aspnetcore' "$csproj" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ASP.NET,"
  grep -q 'Microsoft.EntityFrameworkCore' "$csproj" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}EF-Core,"
  grep -q 'Blazor' "$csproj" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Blazor,"
  grep -q 'MAUI' "$csproj" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}MAUI,"
  if grep -q 'MediatR' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'MediatR'; then FRAMEWORKS="${FRAMEWORKS}MediatR,"; fi
  if grep -q 'SignalR' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'SignalR'; then FRAMEWORKS="${FRAMEWORKS}SignalR,"; fi
  if grep -q 'Serilog' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Serilog'; then FRAMEWORKS="${FRAMEWORKS}Serilog,"; fi
  if grep -q 'AutoMapper' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'AutoMapper'; then FRAMEWORKS="${FRAMEWORKS}AutoMapper,"; fi
  if grep -q 'Hangfire' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Hangfire'; then FRAMEWORKS="${FRAMEWORKS}Hangfire,"; fi
  if grep -q 'Dapper' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Dapper'; then FRAMEWORKS="${FRAMEWORKS}Dapper,"; fi
  if grep -q 'xunit\|NUnit\|MSTest' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'xUnit\|NUnit'; then FRAMEWORKS="${FRAMEWORKS}xUnit/NUnit,"; fi
  if grep -q 'FluentValidation' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'FluentValidation'; then FRAMEWORKS="${FRAMEWORKS}FluentValidation,"; fi
  if grep -q 'HotChocolate' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'HotChocolate'; then FRAMEWORKS="${FRAMEWORKS}HotChocolate,"; fi
  if grep -qiE 'GraphQL.NET|graphql-dotnet' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'GraphQL.NET'; then FRAMEWORKS="${FRAMEWORKS}GraphQL.NET,"; fi
  if grep -q 'Carter' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Carter'; then FRAMEWORKS="${FRAMEWORKS}Carter,"; fi
  if grep -q 'FastEndpoints' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'FastEndpoints'; then FRAMEWORKS="${FRAMEWORKS}FastEndpoints,"; fi
  if grep -q 'Rebus' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Rebus'; then FRAMEWORKS="${FRAMEWORKS}Rebus,"; fi
  if grep -qi 'OpenTelemetry' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'OpenTelemetry'; then FRAMEWORKS="${FRAMEWORKS}OpenTelemetry,"; fi
  if grep -q 'MassTransit' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'MassTransit'; then FRAMEWORKS="${FRAMEWORKS}MassTransit,"; fi
  if grep -q 'Polly' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Polly'; then FRAMEWORKS="${FRAMEWORKS}Polly,"; fi
  if grep -qiE 'Swashbuckle|NSwag' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Swagger'; then FRAMEWORKS="${FRAMEWORKS}Swagger,"; fi
  if grep -q 'StackExchange.Redis' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Redis'; then FRAMEWORKS="${FRAMEWORKS}Redis,"; fi
  if grep -q 'Wolverine' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Wolverine'; then FRAMEWORKS="${FRAMEWORKS}Wolverine,"; fi
  if grep -q 'AspNetCore.HealthChecks\|HealthChecks' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'HealthChecks'; then FRAMEWORKS="${FRAMEWORKS}HealthChecks,"; fi
  if grep -q 'Auth0' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Auth0'; then FRAMEWORKS="${FRAMEWORKS}Auth0,"; fi
  if grep -q 'AWSSDK\|Amazon\.' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'AWS-SDK'; then FRAMEWORKS="${FRAMEWORKS}AWS-SDK,"; fi
  if grep -q 'Google.Cloud' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'GCP-SDK'; then FRAMEWORKS="${FRAMEWORKS}GCP-SDK,"; fi
  if grep -q 'Azure\.' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Azure-SDK'; then FRAMEWORKS="${FRAMEWORKS}Azure-SDK,"; fi
  # Payments / Billing (.NET) — dominant in enterprise Windows/SaaS/healthcare fintech
  if grep -q 'Stripe.net\|Stripe\.Abstractions' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Stripe'; then FRAMEWORKS="${FRAMEWORKS}Stripe,"; fi
  if grep -q 'Braintree' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Braintree'; then FRAMEWORKS="${FRAMEWORKS}Braintree,"; fi
  if grep -q 'Adyen\.api-library' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Adyen'; then FRAMEWORKS="${FRAMEWORKS}Adyen,"; fi
  if grep -q 'AuthorizeNet\|net\.authorize' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Authorize.net'; then FRAMEWORKS="${FRAMEWORKS}Authorize.net,"; fi
  if grep -q 'PayPalCheckoutSdk\|PayPalHttp' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'PayPal'; then FRAMEWORKS="${FRAMEWORKS}PayPal,"; fi
  if grep -q 'Square\.Connect\|square\.connect' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Square'; then FRAMEWORKS="${FRAMEWORKS}Square,"; fi
  if grep -q 'ChargeBee.Net\|ChargeBee\.net' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Chargebee'; then FRAMEWORKS="${FRAMEWORKS}Chargebee,"; fi
  # Communication (.NET)
  if grep -q 'Twilio' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Twilio'; then FRAMEWORKS="${FRAMEWORKS}Twilio,"; fi
  if grep -q 'SendGrid' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'SendGrid'; then FRAMEWORKS="${FRAMEWORKS}SendGrid,"; fi
  if grep -q 'Mailgun' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Mailgun'; then FRAMEWORKS="${FRAMEWORKS}Mailgun,"; fi
  # Feature Flags (.NET)
  if grep -qi 'LaunchDarkly' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'LaunchDarkly'; then FRAMEWORKS="${FRAMEWORKS}LaunchDarkly,"; fi
  if grep -q 'Unleash\.Client' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Unleash'; then FRAMEWORKS="${FRAMEWORKS}Unleash,"; fi
  # Desktop GUI (.NET) — WPF, WinForms, Avalonia cross-platform
  if grep -q 'Microsoft.WindowsDesktop.App.WPF\|UseWPF' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'WPF'; then FRAMEWORKS="${FRAMEWORKS}WPF,"; fi
  if grep -q 'UseWindowsForms\|WindowsFormsApp' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'WinForms'; then FRAMEWORKS="${FRAMEWORKS}WinForms,"; fi
  if grep -q 'Avalonia' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Avalonia'; then FRAMEWORKS="${FRAMEWORKS}Avalonia,"; fi
  # PDF / Reporting (.NET) — enterprise document generation
  if grep -q 'QuestPDF' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'QuestPDF'; then FRAMEWORKS="${FRAMEWORKS}QuestPDF,"; fi
  if grep -q 'PdfSharp\|MigraDoc' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'PdfSharp'; then FRAMEWORKS="${FRAMEWORKS}PdfSharp,"; fi
  if grep -q 'iTextSharp\|itext' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'iText'; then FRAMEWORKS="${FRAMEWORKS}iText,"; fi
  # Testing (.NET) — enterprise testing ecosystem
  if grep -q 'FluentAssertions' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'FluentAssertions'; then FRAMEWORKS="${FRAMEWORKS}FluentAssertions,"; fi
  if grep -q 'Moq' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Moq'; then FRAMEWORKS="${FRAMEWORKS}Moq,"; fi
  if grep -q 'NSubstitute' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'NSubstitute'; then FRAMEWORKS="${FRAMEWORKS}NSubstitute,"; fi
  if grep -q 'Bogus' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Bogus'; then FRAMEWORKS="${FRAMEWORKS}Bogus,"; fi
  if grep -q 'Testcontainers' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Testcontainers'; then FRAMEWORKS="${FRAMEWORKS}Testcontainers,"; fi
  # gRPC (.NET)
  if grep -q 'Grpc.AspNetCore\|Grpc.Net.Client' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'gRPC'; then FRAMEWORKS="${FRAMEWORKS}gRPC,"; fi
  # Workflow (.NET) — long-running process orchestration
  if grep -q 'Elsa' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Elsa'; then FRAMEWORKS="${FRAMEWORKS}Elsa,"; fi
  if grep -q 'Temporal' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Temporal'; then FRAMEWORKS="${FRAMEWORKS}Temporal,"; fi
  # Search (.NET)
  if grep -q 'NEST\|Elastic.Clients' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Elasticsearch'; then FRAMEWORKS="${FRAMEWORKS}Elasticsearch,"; fi
  # Orleans (.NET) — Microsoft's virtual actor framework
  if grep -q 'Orleans' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Orleans'; then FRAMEWORKS="${FRAMEWORKS}Orleans,"; fi
  # Dapr (.NET) — distributed application runtime
  if grep -q 'Dapr' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Dapr'; then FRAMEWORKS="${FRAMEWORKS}Dapr,"; fi
  # Identity (additional .NET) — Duende IdentityServer
  if grep -q 'Duende.IdentityServer\|IdentityServer' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'IdentityServer'; then FRAMEWORKS="${FRAMEWORKS}IdentityServer,"; fi
  # CQRS (.NET) — command query separation
  if grep -q 'EventFlow' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'EventFlow'; then FRAMEWORKS="${FRAMEWORKS}EventFlow,"; fi
  if grep -q 'Marten' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Marten'; then FRAMEWORKS="${FRAMEWORKS}Marten,"; fi
  # Database (.NET) — additional providers
  if grep -q 'Npgsql' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Npgsql'; then FRAMEWORKS="${FRAMEWORKS}Npgsql,"; fi
  if grep -q 'MongoDB.Driver' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'MongoDB'; then FRAMEWORKS="${FRAMEWORKS}MongoDB,"; fi
  if grep -q 'MySqlConnector\|MySql.Data' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'MySQL'; then FRAMEWORKS="${FRAMEWORKS}MySQL,"; fi
  # Job scheduling (.NET) — additional
  if grep -q 'Quartz' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Quartz'; then FRAMEWORKS="${FRAMEWORKS}Quartz,"; fi
  # Caching (.NET) — distributed caching
  if grep -q 'Microsoft.Extensions.Caching.StackExchangeRedis' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Redis'; then FRAMEWORKS="${FRAMEWORKS}Redis,"; fi
  # HTTP (.NET) — REST clients
  if grep -q 'RestSharp' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'RestSharp'; then FRAMEWORKS="${FRAMEWORKS}RestSharp,"; fi
  if grep -q 'Refit' "$csproj" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Refit'; then FRAMEWORKS="${FRAMEWORKS}Refit,"; fi
done

# ── Elixir ──
if [ -f "mix.exs" ]; then
  grep -q 'phoenix' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Phoenix,"
  grep -q 'ecto' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ecto,"
  grep -q 'absinthe' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Absinthe,"
  grep -q 'oban' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Oban,"
  grep -q 'broadway' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Broadway,"
  grep -q 'commanded' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Commanded,"
  grep -q 'nx' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Nx-ML,"
  grep -q 'ash' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ash,"
  grep -q 'nerves' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Nerves,"
  grep -q 'phoenix_live_view' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}LiveView,"
  # Payments / Communication (Elixir) — Phoenix fintech apps, telecoms billing
  grep -q 'stripity_stripe\|stripe' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Stripe,"
  grep -q 'ex_twilio\|twilio' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Twilio,"
  grep -q 'ex_money\|money' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ExMoney,"
  grep -q 'bamboo' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Bamboo,"
  grep -q 'swoosh' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Swoosh,"
  grep -q 'fun_with_flags\|feature_flagger' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}FunWithFlags,"
  # Media processing (Elixir) — real-time media pipelines
  grep -q 'membrane' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Membrane,"
  # Clustering / Distribution (Elixir) — Elixir's native strength
  grep -q 'libcluster' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}libcluster,"
  grep -q 'horde' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Horde,"
  # Auth (Elixir) — authentication frameworks
  grep -q 'guardian' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Guardian,"
  grep -q 'pow' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pow,"
  grep -q 'ueberauth' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ueberauth,"
  # HTTP (Elixir) — client libraries
  grep -q 'tesla' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Tesla,"
  grep -q 'finch\|req' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Finch,"
  # Testing (Elixir) — additional
  grep -q 'mox\|ex_machina' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ExMachina,"
  grep -q 'wallaby' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Wallaby,"
  # Config / Env (Elixir)
  grep -q 'vapor' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Vapor-Config,"
  # JSON (Elixir) — serialization
  grep -q 'jason' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Jason,"
  # PDF (Elixir)
  grep -q 'pdf_generator\|chromic_pdf' mix.exs 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ChromicPDF,"
fi

# ── Scala ──
if [ -f "build.sbt" ]; then
  grep -qi 'akka\|pekko' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Akka,"
  grep -qi 'play' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Play,"
  grep -qi 'zio' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ZIO,"
  grep -qi 'cats' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Cats,"
  grep -qi 'http4s' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}http4s,"
  grep -qi 'spark' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Spark,"
  grep -qi 'doobie' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Doobie,"
  grep -qi 'slick' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Slick,"
  grep -qi 'tapir' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Tapir,"
  grep -qi 'circe' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Circe,"
  grep -qi 'flink' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Flink,"
  grep -qi 'caliban' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Caliban,"
  grep -qi 'fs2' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}fs2,"
  grep -qi 'kafka-streams\|kafka\.streams' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Kafka-Streams,"
  grep -qi 'scio' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Scio,"
  grep -qi 'delta' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Delta-Lake,"
  grep -qi 'chimney' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Chimney,"
  grep -qi 'quill' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Quill,"
  grep -qi 'ce3\|cats-effect' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Cats-Effect,"
  grep -qi 'sttp' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}sttp,"
  grep -qi 'refined' build.sbt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Refined,"
fi

# ── C / C++ ──
if [ "$PRIMARY_LANG" = "c" ] || [ "$PRIMARY_LANG" = "cpp" ]; then
  # Build system
  if [ -f "CMakeLists.txt" ]; then
    FRAMEWORKS="${FRAMEWORKS}CMake,"
    grep -qi 'qt' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Qt,"
    grep -qi 'boost' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Boost,"
    grep -qi 'openssl' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OpenSSL,"
    grep -qi 'opencv' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OpenCV,"
    grep -qi 'sdl' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SDL,"
    grep -qi 'sfml' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SFML,"
    grep -qi 'grpc' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}gRPC-C++,"
    grep -qi 'protobuf' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}protobuf,"
    grep -qi 'abseil\|absl' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Abseil,"
  fi
  if { [ -f "Makefile" ] || [ -f "GNUmakefile" ]; } && ! echo "$FRAMEWORKS" | grep -q 'CMake'; then FRAMEWORKS="${FRAMEWORKS}Make,"; fi
  if [ -f "meson.build" ]; then FRAMEWORKS="${FRAMEWORKS}Meson,"; fi
  # Package managers
  if [ -f "conanfile.txt" ] || [ -f "conanfile.py" ]; then FRAMEWORKS="${FRAMEWORKS}Conan,"; fi
  if [ -f "vcpkg.json" ] || [ -d "vcpkg" ]; then FRAMEWORKS="${FRAMEWORKS}vcpkg,"; fi
  # GPU / CUDA (C/C++) — HPC, ML training, scientific computing
  if find . -maxdepth 3 -name '*.cu' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}CUDA,"; fi
  if [ -f "CMakeLists.txt" ]; then
    grep -qi 'vulkan' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Vulkan,"
    grep -qi 'glfw' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GLFW,"
    grep -qi 'imgui' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Dear-ImGui,"
    grep -qi 'opengl' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OpenGL,"
    grep -qi 'catch2\|Catch2' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Catch2,"
    grep -qi 'gtest\|googletest' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GoogleTest,"
    grep -qi 'benchmark\|google.*benchmark' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Google-Benchmark,"
    grep -qi 'doctest' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Doctest,"
    # Networking (C/C++) — HTTP, async I/O
    grep -qi 'asio\|boost.asio' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Asio,"
    grep -qi 'cpp-httplib\|cpr' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}CPR,"
    grep -qi 'libcurl\|curl' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}libcurl,"
    grep -qi 'websocketpp\|websocket++' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}WebSocket++,"
    # JSON (C/C++) — serialization
    grep -qi 'nlohmann_json\|nlohmann/json' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}nlohmann-json,"
    grep -qi 'rapidjson' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}RapidJSON,"
    # Scientific / Math (C/C++)
    grep -qi 'eigen\|eigen3' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Eigen,"
    grep -qi 'armadillo' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Armadillo,"
    # Logging (C/C++)
    grep -qi 'spdlog' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}spdlog,"
    grep -qi 'fmt\b' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}fmt,"
    # GUI (C/C++) — beyond Qt
    grep -qi 'wxwidgets\|wxWidgets' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}wxWidgets,"
    grep -qi 'fltk' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}FLTK,"
    # Audio / Multimedia (C/C++)
    grep -qi 'portaudio\|rtaudio' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PortAudio,"
    grep -qi 'ffmpeg\|libav' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}FFmpeg,"
    # Database (C/C++)
    grep -qi 'sqlite\|sqlite3' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SQLite,"
    grep -qi 'libpq\|pqxx' CMakeLists.txt 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}libpq,"
  fi
  # Robotics (C/C++) — ROS/ROS2 ecosystem
  if [ -f "package.xml" ] && grep -q 'catkin\|ament\|rosidl' package.xml 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}ROS,"; fi
  # Unreal Engine
  if [ -f "*.uproject" ] 2>/dev/null || find . -maxdepth 1 -name '*.uproject' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Unreal-Engine,"; fi
fi

# ── Haskell ──
if [ "$PRIMARY_LANG" = "hs" ]; then
  _CABAL_F=$(find . -maxdepth 1 -name '*.cabal' 2>/dev/null | head -1)
  if [ -n "$_CABAL_F" ]; then
    grep -qi 'servant' "$_CABAL_F" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Servant,"
    grep -qi 'yesod' "$_CABAL_F" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Yesod,"
    grep -qi 'scotty' "$_CABAL_F" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Scotty,"
    grep -qi 'conduit' "$_CABAL_F" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Conduit,"
    grep -qi 'lens' "$_CABAL_F" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Lens,"
    grep -qi 'aeson' "$_CABAL_F" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Aeson,"
    grep -qi 'persistent' "$_CABAL_F" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Persistent,"
  fi
  [ -f "stack.yaml" ] && FRAMEWORKS="${FRAMEWORKS}Stack,"
  [ -f "cabal.project" ] && ! echo "$FRAMEWORKS" | grep -q 'Stack' && FRAMEWORKS="${FRAMEWORKS}Cabal,"
fi

# ── OCaml ──
if [ "$PRIMARY_LANG" = "ml" ]; then
  [ -f "dune-project" ] && FRAMEWORKS="${FRAMEWORKS}Dune,"
  if find . -maxdepth 1 -name '*.opam' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}opam,"; fi
  if [ -f "dune-project" ] && grep -qi 'dream' dune-project 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Dream,"; fi
  if [ -f "dune-project" ] && grep -qi 'cohttp' dune-project 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}CoHTTP,"; fi
fi

# ── Clojure ──
if [ "$PRIMARY_LANG" = "clj" ]; then
  if [ -f "project.clj" ]; then
    FRAMEWORKS="${FRAMEWORKS}Leiningen,"
    grep -qi 'ring' project.clj 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ring,"
    grep -qi 'compojure' project.clj 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Compojure,"
    grep -qi 'pedestal' project.clj 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pedestal,"
    grep -qi 'luminus' project.clj 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Luminus,"
    grep -qi 'datomic' project.clj 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Datomic,"
    grep -qi 'next.jdbc' project.clj 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}next.jdbc,"
  fi
  if [ -f "deps.edn" ]; then
    FRAMEWORKS="${FRAMEWORKS}deps.edn,"
    if grep -qi 'ring' deps.edn 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Ring'; then FRAMEWORKS="${FRAMEWORKS}Ring,"; fi
    if grep -qi 'reitit' deps.edn 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Reitit,"; fi
  fi
fi

# ── R ──
if [ "$PRIMARY_LANG" = "r" ]; then
  [ -f "DESCRIPTION" ] && FRAMEWORKS="${FRAMEWORKS}R-package,"
  if [ -f "app.R" ] || find . -maxdepth 2 -name 'server.R' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Shiny,"; fi
  if [ -f "plumber.R" ]; then FRAMEWORKS="${FRAMEWORKS}Plumber,"; fi
  if [ -f "renv.lock" ]; then FRAMEWORKS="${FRAMEWORKS}renv,"; fi
  # Tidyverse ecosystem (R) — the standard R data science stack
  if [ -f "DESCRIPTION" ]; then
    grep -qi 'tidyverse\|dplyr\|tidyr' DESCRIPTION 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}tidyverse,"
    grep -qi 'ggplot2' DESCRIPTION 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ggplot2,"
    grep -qi 'targets' DESCRIPTION 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}targets,"
    grep -qi 'golem' DESCRIPTION 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}golem,"
    grep -qi 'caret\|tidymodels' DESCRIPTION 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}tidymodels,"
    # Bioinformatics (R) — Bioconductor ecosystem
    grep -qi 'BiocManager\|bioconductor\|GenomicRanges\|DESeq2' DESCRIPTION 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Bioconductor,"
  fi
  if [ -f "renv.lock" ]; then
    grep -qi 'tidyverse' renv.lock 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'tidyverse' && FRAMEWORKS="${FRAMEWORKS}tidyverse,"
    grep -qi 'ggplot2' renv.lock 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'ggplot2' && FRAMEWORKS="${FRAMEWORKS}ggplot2,"
  fi
fi

# ── Lua ──
if [ "$PRIMARY_LANG" = "lua" ]; then
  if { [ -f "*.rockspec" ] 2>/dev/null || find . -maxdepth 1 -name '*.rockspec' 2>/dev/null | head -1 | grep -q '.'; }; then FRAMEWORKS="${FRAMEWORKS}LuaRocks,"; fi
  if find . -maxdepth 3 -name 'init.lua' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Neovim-plugin,"; fi
  if grep -qr 'require.*lapis\|lapis' . 2>/dev/null --include='*.lua' | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Lapis,"; fi
  if grep -qr 'require.*kong\|kong' . 2>/dev/null --include='*.lua' | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Kong-plugin,"; fi
  # Gaming (Lua) — LÖVE is the dominant Lua game framework
  if [ -f "conf.lua" ] && grep -q 'love' conf.lua 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}LOVE2D,"; fi
  if [ -f "game.project" ] && grep -q 'defold' game.project 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Defold,"; fi
  # OpenResty (Lua) — Nginx scripting
  if grep -qr 'require.*resty\|ngx\.' . 2>/dev/null --include='*.lua' | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}OpenResty,"; fi
  # Hammerspoon (Lua) — macOS automation
  if [ -f "init.lua" ] && grep -q 'hs\.\|hammerspoon' init.lua 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Hammerspoon,"; fi
fi

# ── Perl ──
if [ "$PRIMARY_LANG" = "pl" ]; then
  [ -f "Makefile.PL" ] && FRAMEWORKS="${FRAMEWORKS}ExtUtils-MakeMaker,"
  [ -f "Build.PL" ] && FRAMEWORKS="${FRAMEWORKS}Module-Build,"
  [ -f "cpanfile" ] && FRAMEWORKS="${FRAMEWORKS}cpanfile,"
  if find . -maxdepth 3 -name '*.pm' -not -path '*/.git/*' 2>/dev/null | xargs grep -l 'Moose\|Moo\b' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Moose,"; fi
  if find . -maxdepth 3 -name '*.pm' -not -path '*/.git/*' 2>/dev/null | xargs grep -l 'Catalyst\|Mojolicious\|Dancer' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Perl-web-fw,"; fi
fi

# ── Swift ──
if [ -f "Package.swift" ]; then
  grep -q 'Vapor' Package.swift 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Vapor,"
  grep -q 'Hummingbird' Package.swift 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Hummingbird,"
  grep -q 'ComposableArchitecture\|TCA' Package.swift 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}TCA,"
  grep -q 'Alamofire' Package.swift 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Alamofire,"
  grep -q 'SwiftNIO' Package.swift 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SwiftNIO,"
  # Payments / Communication (Swift SPM) — iOS/macOS apps use payment SDKs
  grep -q 'StripeIOS\|stripe-ios\|Stripe' Package.swift 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Stripe,"
  grep -q 'Braintree' Package.swift 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Braintree,"
  grep -q 'PayPalCheckout\|PayPalNativeCheckout' Package.swift 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PayPal,"
  grep -q 'SquarePointOfSaleSDK\|Square' Package.swift 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Square,"
fi
# Swift via Podfile (CocoaPods) — iOS payment pods
if [ -f "Podfile" ]; then
  grep -q 'Stripe\|StripeUICore' Podfile 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Stripe' && FRAMEWORKS="${FRAMEWORKS}Stripe,"
  grep -q 'Braintree' Podfile 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Braintree' && FRAMEWORKS="${FRAMEWORKS}Braintree,"
  grep -q 'AdyenComponents\|Adyen' Podfile 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Adyen' && FRAMEWORKS="${FRAMEWORKS}Adyen,"
  grep -q 'PayPal' Podfile 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'PayPal' && FRAMEWORKS="${FRAMEWORKS}PayPal,"
fi
# SwiftUI: detected from any .swift source file containing SwiftUI import
if [ "$PRIMARY_LANG" = "swift" ] && find . -maxdepth 5 -name '*.swift' -not -path '*/.git/*' 2>/dev/null | xargs grep -l 'import SwiftUI' 2>/dev/null | head -1 | grep -q '.'; then
  FRAMEWORKS="${FRAMEWORKS}SwiftUI,"
fi

# ── Dart / Flutter ──
if [ -f "pubspec.yaml" ]; then
  grep -q 'flutter:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Flutter,"
  grep -qi 'flutter_bloc\|bloc:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Bloc,"
  grep -qi 'riverpod' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Riverpod,"
  grep -qi 'provider:' pubspec.yaml 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Riverpod' && FRAMEWORKS="${FRAMEWORKS}Provider,"
  grep -qi 'get:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GetX,"
  grep -qi 'freezed' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Freezed,"
  grep -qi 'drift:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Drift,"
  grep -qi 'hive:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Hive,"
  grep -qi 'isar:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Isar,"
  grep -qi 'dio:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Dio,"
  grep -qi 'chopper:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Chopper,"
  grep -qi 'shelf:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Shelf,"
  grep -qi 'dart_frog' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Dart-Frog,"
  grep -qi 'serverpod' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Serverpod,"
  grep -qi 'flame:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Flame,"
  grep -qi 'go_router' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GoRouter,"
  grep -qi 'auto_route' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}AutoRoute,"
  grep -qi 'firebase_core' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Firebase,"
  grep -qi 'supabase' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Supabase,"
  # Payments / Communication (Flutter/Dart) — cross-platform mobile commerce
  grep -qi 'flutter_stripe\|stripe_sdk' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Stripe,"
  grep -qi 'razorpay_flutter' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Razorpay,"
  grep -qi 'paystack_payment\|paystack_flutter' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Paystack,"
  grep -qi '^  pay:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}PayPlugin,"
  grep -qi 'braintree' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Braintree,"
  grep -qi 'paytm_allinonesdk\|paytm' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Paytm,"
  grep -qi 'flutter_twilio\|twilio_programmable' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Twilio,"
  grep -qi 'onesignal_flutter\|onesignal' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}OneSignal,"
  grep -qi 'firebase_messaging' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}FCM,"
  # Testing (Dart/Flutter) — additional
  grep -qi 'mockito\|mocktail' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Mockito,"
  grep -qi 'integration_test\|flutter_test' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Flutter-Test,"
  grep -qi 'patrol' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Patrol,"
  # State management (Dart/Flutter) — additional
  grep -qi 'mobx:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}MobX,"
  grep -qi 'redux:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Redux,"
  grep -qi 'signals:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Signals,"
  # Networking (Dart) — additional
  grep -qi 'retrofit:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Retrofit,"
  grep -qi 'graphql_flutter\|graphql:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}GraphQL,"
  # UI (Dart/Flutter) — additional
  grep -qi 'flutter_hooks\|hooks_riverpod' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Flutter-Hooks,"
  grep -qi 'cached_network_image' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}CachedImage,"
  # Storage (Dart) — additional
  grep -qi 'sqflite\|floor:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}SQFlite,"
  grep -qi 'objectbox\|objectbox:' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}ObjectBox,"
  grep -qi 'appwrite' pubspec.yaml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Appwrite,"
fi

# ── Julia ──
if [ "$PRIMARY_LANG" = "jl" ] || [ -f "Project.toml" ]; then
  if [ -f "Project.toml" ]; then
    FRAMEWORKS="${FRAMEWORKS}Julia,"
    grep -qi 'Flux' Project.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Flux.jl,"
    grep -qi 'DataFrames' Project.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}DataFrames.jl,"
    grep -qi 'Plots\|Makie' Project.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Plots.jl,"
    grep -qi 'DifferentialEquations' Project.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}DiffEq.jl,"
    grep -qi 'Genie' Project.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Genie,"
    grep -qi 'Pluto' Project.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Pluto.jl,"
    grep -qi 'JuMP' Project.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}JuMP,"
    grep -qi 'Knet\|Lux' Project.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Lux.jl,"
    grep -qi 'Turing' Project.toml 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Turing.jl,"
  fi
fi

# ── Zig ──
if [ "$PRIMARY_LANG" = "zig" ] || [ -f "build.zig" ]; then
  FRAMEWORKS="${FRAMEWORKS}Zig,"
  if [ -f "build.zig.zon" ]; then FRAMEWORKS="${FRAMEWORKS}Zig-Build-System,"; fi
fi

# ── Infrastructure / DevOps markers ──
if [ -d "helm" ] || find . -maxdepth 2 -name 'Chart.yaml' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Helm,"; fi
if [ -f "helmfile.yaml" ] || [ -f "helmfile.yml" ]; then FRAMEWORKS="${FRAMEWORKS}Helmfile,"; fi
# M7: Terraform: check for any *.tf file, not just terraform.tf
if find . -maxdepth 3 -name '*.tf' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Terraform,"; fi
if { [ -f ".terraform/terraform.tfstate" ] || [ -d ".terraform" ]; } && ! echo "$FRAMEWORKS" | grep -q 'Terraform'; then FRAMEWORKS="${FRAMEWORKS}Terraform,"; fi
if [ -f "pulumi.yaml" ]; then FRAMEWORKS="${FRAMEWORKS}Pulumi,"; fi
if [ -f "serverless.yml" ] || [ -f "serverless.yaml" ]; then FRAMEWORKS="${FRAMEWORKS}Serverless,"; fi
if [ -f "cdk.json" ]; then FRAMEWORKS="${FRAMEWORKS}AWS-CDK,"; fi
if [ -f "fly.toml" ]; then FRAMEWORKS="${FRAMEWORKS}Fly.io,"; fi
if [ -f "vercel.json" ]; then FRAMEWORKS="${FRAMEWORKS}Vercel,"; fi
if [ -f "netlify.toml" ]; then FRAMEWORKS="${FRAMEWORKS}Netlify,"; fi
if [ -f "ansible.cfg" ] || [ -f "inventory" ] || find . -maxdepth 2 -name 'playbook*.yml' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Ansible,"; fi
if [ -f "skaffold.yaml" ] || [ -f "skaffold.yml" ]; then FRAMEWORKS="${FRAMEWORKS}Skaffold,"; fi
if [ -f "Tiltfile" ] || [ -f "tilt.yaml" ]; then FRAMEWORKS="${FRAMEWORKS}Tilt,"; fi
# Build systems (cross-language)
if [ -f "BUILD" ] || [ -f "WORKSPACE" ] || [ -f "BUILD.bazel" ] || [ -f "WORKSPACE.bazel" ]; then FRAMEWORKS="${FRAMEWORKS}Bazel,"; fi
if [ -f "flake.nix" ] || [ -f "default.nix" ] || [ -f "shell.nix" ]; then FRAMEWORKS="${FRAMEWORKS}Nix,"; fi
if [ -f "Earthfile" ]; then FRAMEWORKS="${FRAMEWORKS}Earthly,"; fi
if [ -f "dagger.json" ] || [ -d "dagger" ]; then FRAMEWORKS="${FRAMEWORKS}Dagger,"; fi
# K8s deployment tools
if find . -maxdepth 3 -name 'kustomization.yaml' -o -name 'kustomization.yml' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Kustomize,"; fi
if find . -maxdepth 3 -name 'Application.yaml' 2>/dev/null | xargs grep -l 'argoproj.io' 2>/dev/null | head -1 | grep -q '.' 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}ArgoCD,"; fi
# Game engines (cross-language)
if [ -f "project.godot" ]; then FRAMEWORKS="${FRAMEWORKS}Godot,"; fi
# Unity (.NET game engine — detect by ProjectSettings or Assembly-CSharp)
if [ -d "ProjectSettings" ] && [ -f "ProjectSettings/ProjectVersion.txt" ]; then FRAMEWORKS="${FRAMEWORKS}Unity,"; fi
# Static site generators (cross-language)
if [ -f "hugo.toml" ] || [ -f "hugo.yaml" ] || [ -f "config.toml" ] && grep -q 'baseURL' config.toml 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Hugo,"; fi
if [ -f "mkdocs.yml" ]; then FRAMEWORKS="${FRAMEWORKS}MkDocs,"; fi
if [ -f "docusaurus.config.js" ] || [ -f "docusaurus.config.ts" ]; then FRAMEWORKS="${FRAMEWORKS}Docusaurus,"; fi
# SST (Serverless Stack)
if [ -f "sst.config.ts" ] || [ -f "sst.config.js" ]; then FRAMEWORKS="${FRAMEWORKS}SST,"; fi
# Nx monorepo (cross-language)
if [ -f "nx.json" ]; then FRAMEWORKS="${FRAMEWORKS}Nx,"; fi
# Turborepo
if [ -f "turbo.json" ]; then FRAMEWORKS="${FRAMEWORKS}Turborepo,"; fi
# Observability / Monitoring (cross-language) — SaaS products
if [ -f "grafana" ] || find . -maxdepth 3 -name 'grafana*.json' -o -name 'grafana*.yaml' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Grafana,"; fi
if find . -maxdepth 3 -name 'prometheus*.yml' -o -name 'prometheus*.yaml' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Prometheus,"; fi
if find . -maxdepth 3 -name 'jaeger*' -o -name 'zipkin*' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Distributed-Tracing,"; fi
# Secret management (cross-language)
if [ -f ".sops.yaml" ] || find . -maxdepth 2 -name '*.enc.yaml' -o -name '*.enc.yml' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}SOPS,"; fi
if find . -maxdepth 2 -name 'vault*.hcl' -o -name 'vault*.yaml' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Vault,"; fi
# Container tools (cross-language)
if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] || [ -f "compose.yaml" ]; then FRAMEWORKS="${FRAMEWORKS}Docker-Compose,"; fi
if [ -f "devcontainer.json" ] || [ -d ".devcontainer" ]; then FRAMEWORKS="${FRAMEWORKS}DevContainers,"; fi
if [ -f "Vagrantfile" ]; then FRAMEWORKS="${FRAMEWORKS}Vagrant,"; fi
# API specs (cross-language)
if find . -maxdepth 2 -name 'openapi*.yaml' -o -name 'openapi*.json' -o -name 'swagger*.yaml' -o -name 'swagger*.json' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}OpenAPI-Spec,"; fi
if find . -maxdepth 2 -name '*.proto' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Protobuf,"; fi
if find . -maxdepth 2 -name '*.graphql' -o -name '*.gql' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}GraphQL-Schema,"; fi
if find . -maxdepth 2 -name '*.avsc' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Avro-Schema,"; fi
# Documentation (cross-language)
if [ -f "book.toml" ]; then FRAMEWORKS="${FRAMEWORKS}mdBook,"; fi
if [ -f "_config.yml" ] && grep -q 'jekyll\|theme' _config.yml 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Jekyll,"; fi
if [ -f "sphinx" ] || [ -f "conf.py" ] && grep -q 'sphinx\|extensions' conf.py 2>/dev/null; then FRAMEWORKS="${FRAMEWORKS}Sphinx,"; fi
if [ -f "antora.yml" ] || [ -f "antora-playbook.yml" ]; then FRAMEWORKS="${FRAMEWORKS}Antora,"; fi
# Feature flags (cross-language) — config file presence
if [ -f "flagr.yaml" ] || [ -f "feature-flags.yaml" ] || [ -f ".featureflags" ]; then FRAMEWORKS="${FRAMEWORKS}Feature-Flags,"; fi
# Monorepo tools (cross-language) — additional
if [ -f "moon.yml" ] || [ -f ".moon/workspace.yml" ]; then FRAMEWORKS="${FRAMEWORKS}Moon,"; fi
if [ -f "rush.json" ]; then FRAMEWORKS="${FRAMEWORKS}Rush,"; fi
if [ -f "pants.toml" ] || [ -f "pants.ini" ]; then FRAMEWORKS="${FRAMEWORKS}Pants,"; fi
if [ -f "buck2" ] || [ -f ".buckconfig" ]; then FRAMEWORKS="${FRAMEWORKS}Buck2,"; fi
# IaC (cross-language) — additional
if [ -f "crossplane.yaml" ] || find . -maxdepth 3 -name 'crossplane*.yaml' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Crossplane,"; fi
if find . -maxdepth 2 -name '*.bicep' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Bicep,"; fi
if [ -f "cdktf.json" ]; then FRAMEWORKS="${FRAMEWORKS}CDKTF,"; fi
# GitOps (cross-language) — additional
if find . -maxdepth 3 -name 'flux-system' -type d 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}FluxCD,"; fi

# Deduplicate (in case of cross-file overlap)
FRAMEWORKS=$(echo "$FRAMEWORKS" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/^,//;s/,$//')
emit "FRAMEWORKS" "$FRAMEWORKS"

echo ""

# ─── Claude Code Plugins ──────────────────────────────────────────

echo "# --- Plugins ---"
PLUGINS_DIR="$HOME/.claude/plugins"
PLUGIN_LIST="" HAS_CLAUDE_MEM="false"
CLAUDE_MEM_WORKER="false"

# Detect installed plugins from filesystem
if [ -d "$PLUGINS_DIR" ]; then
  for plugin_dir in "$PLUGINS_DIR"/*/; do
    [ -d "$plugin_dir" ] || continue
    plugin_name=$(basename "$plugin_dir")
    PLUGIN_LIST="${PLUGIN_LIST}${plugin_name},"
    case "$plugin_name" in
      *claude-mem*|*thedotmack*) HAS_CLAUDE_MEM="true" ;;
    esac
  done
  PLUGIN_LIST="${PLUGIN_LIST%,}"
fi

# Also try `claude plugin list` if available (more reliable)
if command -v claude &>/dev/null; then
  CLAUDE_PLUGIN_OUTPUT=$(claude plugin list 2>/dev/null || true)
  if echo "$CLAUDE_PLUGIN_OUTPUT" | grep -qi 'claude-mem' 2>/dev/null; then
    HAS_CLAUDE_MEM="true"
  fi
fi

# Detect claude-mem worker status
if $HAS_CLAUDE_MEM; then
  if curl -sf http://localhost:37777/health >/dev/null 2>&1; then
    CLAUDE_MEM_WORKER="running"
  elif pgrep -f 'claude-mem.*worker-service' >/dev/null 2>&1; then
    CLAUDE_MEM_WORKER="process-found"
  else
    CLAUDE_MEM_WORKER="not-running"
  fi
fi

emit "PLUGINS" "$PLUGIN_LIST"
emit "HAS_CLAUDE_MEM" "$HAS_CLAUDE_MEM"
emit "CLAUDE_MEM_WORKER" "$CLAUDE_MEM_WORKER"

echo ""
echo "# ============================================="
echo "# End of Discovery"
echo "# ============================================="

