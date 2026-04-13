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
  # Payments (additional)
  echo "$DEPS" | grep -q '^@paypal' && FRAMEWORKS="${FRAMEWORKS}PayPal,"
  # Caching
  echo "$DEPS" | grep -q '^cache-manager$' && FRAMEWORKS="${FRAMEWORKS}CacheManager,"
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
done
if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
  GRADLE_FILE=""; for _f in build.gradle build.gradle.kts; do [ -f "$_f" ] && GRADLE_FILE="$_f" && break; done
  grep -q 'spring-boot' "$GRADLE_FILE" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Spring-Boot' && FRAMEWORKS="${FRAMEWORKS}Spring-Boot,"
  grep -q 'quarkus' "$GRADLE_FILE" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Quarkus' && FRAMEWORKS="${FRAMEWORKS}Quarkus,"
  grep -q 'ktor' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Ktor,"
  grep -q 'android' "$GRADLE_FILE" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Android,"
  grep -q 'flyway' "$GRADLE_FILE" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Flyway' && FRAMEWORKS="${FRAMEWORKS}Flyway,"
  grep -q 'liquibase' "$GRADLE_FILE" 2>/dev/null && ! echo "$FRAMEWORKS" | grep -q 'Liquibase' && FRAMEWORKS="${FRAMEWORKS}Liquibase,"
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
fi
# WordPress: also detect by wp-config.php / wp-includes presence
if ! echo "$FRAMEWORKS" | grep -q 'WordPress'; then
  if [ -f "wp-config.php" ] || [ -d "wp-includes" ]; then FRAMEWORKS="${FRAMEWORKS}WordPress,"; fi
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
fi

# ── Lua ──
if [ "$PRIMARY_LANG" = "lua" ]; then
  if { [ -f "*.rockspec" ] 2>/dev/null || find . -maxdepth 1 -name '*.rockspec' 2>/dev/null | head -1 | grep -q '.'; }; then FRAMEWORKS="${FRAMEWORKS}LuaRocks,"; fi
  if find . -maxdepth 3 -name 'init.lua' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Neovim-plugin,"; fi
  if grep -qr 'require.*lapis\|lapis' . 2>/dev/null --include='*.lua' | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Lapis,"; fi
  if grep -qr 'require.*kong\|kong' . 2>/dev/null --include='*.lua' | head -1 | grep -q '.'; then FRAMEWORKS="${FRAMEWORKS}Kong-plugin,"; fi
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

