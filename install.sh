#!/bin/bash
# install.sh — Smart installer for ᗺB Brain Bootstrap
# Safely handles FRESH installs, Brain upgrades, AND pre-existing Claude configs.
#
# Usage:
#   git clone https://github.com/y-abs/claude-code-brain-bootstrap.git /tmp/brain
#   bash /tmp/brain/install.sh /path/to/your-repo
#   rm -rf /tmp/brain
#
# FRESH mode:  No Claude-related files exist → copies entire template.
# UPGRADE mode: ANY Claude-related file exists → smart merge:
#   - NEVER overwrites user files (knowledge, config, tasks, custom docs)
#   - Updates Brain infrastructure (scripts, bootstrap process, reference docs)
#   - Adds missing Brain components (commands, hooks, agents, skills, rules)
#   - Preserves user-only files even in infrastructure directories

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ install.sh must be EXECUTED, not sourced." >&2
  echo "   Wrong:  source install.sh /path/to/repo" >&2
  echo "   Right:  bash install.sh /path/to/repo" >&2
  return 1 2>/dev/null || exit 1
fi

set -euo pipefail

# ── Platform helpers ───────────────────────────────────────────────
source "$(dirname "$0")/claude/scripts/_platform.sh"

# ── Pre-flight check mode ─────────────────────────────────────────
if [ "${1:-}" = "--check" ]; then
  echo ""
  echo "🔍 Brain Bootstrap — Pre-flight Check"
  echo ""
  echo "  Platform: $BRAIN_PLATFORM"
  require_tool git "required for repo detection" && echo "  ✅ git $(git --version 2>/dev/null | head -1)" || true
  if command -v jq &>/dev/null; then
    echo "  ✅ jq $(jq --version 2>/dev/null)"
  else
    echo "  ❌ jq not found — STRONGLY RECOMMENDED"
    echo "     Without jq: safety hooks (config protection, terminal safety gate,"
    echo "     commit quality) silently pass through. JS/TS discovery is degraded."
    case "$BRAIN_PLATFORM" in
      macos)   echo "     Install: brew install jq" ;;
      windows) echo "     Install: scoop install jq  OR  choco install jq" ;;
      linux)   echo "     Install: sudo apt install jq  OR  sudo dnf install jq" ;;
    esac
  fi
  bash_ver="${BASH_VERSINFO[0]:-0}"
  if [ "$bash_ver" -ge 4 ]; then
    echo "  ✅ bash $BASH_VERSION (≥4 — full support)"
  else
    echo "  ⚠️  bash $BASH_VERSION (<4 — discover.sh and populate-templates.sh need Bash 4+)"
    echo "     macOS: brew install bash"
  fi
  # Python 3.10+ (required for graphify knowledge graph — optional but recommended)
  PY_FOUND=false
  for py_cmd in python3 python; do
    if command -v "$py_cmd" &>/dev/null; then
      PY_VER=$("$py_cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
      PY_MAJOR="${PY_VER%%.*}"
      PY_MINOR="${PY_VER##*.}"
      if [ "${PY_MAJOR:-0}" -ge 3 ] && [ "${PY_MINOR:-0}" -ge 10 ]; then
        echo "  ✅ $py_cmd $PY_VER (≥3.10 — graphify knowledge graph ready)"
        PY_FOUND=true
        break
      else
        echo "  ⚠️  $py_cmd $PY_VER (<3.10 — graphify needs 3.10+)"
      fi
    fi
  done
  if [ "$PY_FOUND" = "false" ]; then
    echo "  ⚠️  Python 3.10+ not found — graphify knowledge graph won't be available"
    echo "     graphify turns your codebase into a queryable knowledge graph (architecture map,"
    echo "     cross-module connections, community detection). Optional but highly recommended."
    case "$BRAIN_PLATFORM" in
      macos)   echo "     Install: brew install python@3.12" ;;
      windows) echo "     Install: winget install Python.Python.3.12" ;;
      linux)   echo "     Install: sudo apt install python3  OR  sudo dnf install python3" ;;
    esac
  fi
  echo ""
  exit 0
fi

# ── Resolve paths ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:?Usage: bash install.sh /path/to/your-repo}"

# ── Git repo root guard ───────────────────────────────────────────
# Brain files belong at the ROOT of a git repository.
# Prevents accidentally dumping 100+ files into /tmp, ~, or a subdirectory.
# Three checks: (1) target exists, (2) is inside a git repo, (3) IS the root.

# Check 1: Target directory must exist — never create directories for the user
if [ ! -d "$TARGET" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  ᗺB  Brain Bootstrap — Smart Installer               ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "  Target:  $TARGET"
  echo ""
  echo "❌ ERROR: Target directory does not exist."
  echo "   Brain Bootstrap must be installed at the root of an existing git repo."
  echo ""
  echo "   Create and initialize your project first:"
  echo "     mkdir -p $TARGET"
  echo "     git init $TARGET"
  echo "     bash $0 $TARGET"
  echo ""
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

# Check 2: Must be inside a git repository (handles .git dir, .git file for worktrees, bare repos)
if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  ᗺB  Brain Bootstrap — Smart Installer               ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "  Target:  $TARGET"
  echo ""
  echo "❌ ERROR: Target is not inside a git repository."
  echo "   Brain Bootstrap must be installed at the root of a git repo."
  echo ""
  echo "   Initialize git first:"
  echo "     git init $TARGET"
  echo "     bash $0 $TARGET"
  echo ""
  exit 1
fi

# Check 3: Must be the REPO ROOT, not a subdirectory
# Use --show-cdup (empty at root) instead of comparing --show-toplevel paths.
# Path string comparison breaks on macOS (symlinks: /var vs /private/var) and
# Windows (MSYS vs native paths: /tmp vs C:/Users/...).
GIT_CDUP="$(git -C "$TARGET" rev-parse --show-cdup 2>/dev/null)" || true
if [ -n "$GIT_CDUP" ]; then
  GIT_ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || true)"
  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  ᗺB  Brain Bootstrap — Smart Installer               ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "  Target:     $TARGET"
  echo "  Repo root:  $GIT_ROOT"
  echo ""
  echo "❌ ERROR: Target is a subdirectory of a git repo, not the root."
  echo "   Brain Bootstrap must be installed at the REPOSITORY ROOT."
  echo ""
  echo "   Use the repo root instead:"
  echo "     bash $0 $GIT_ROOT"
  echo ""
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ᗺB  Brain Bootstrap — Smart Installer               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Source:    $SCRIPT_DIR"
echo "  Target:    $TARGET"
echo "  Platform:  $BRAIN_PLATFORM"
echo ""

# ── Self-bootstrap guard ──────────────────────────────────────────
if [ -f "$TARGET/CONTRIBUTING.md" ]; then
  if grep -q 'claude-code-brain-bootstrap' "$TARGET/CONTRIBUTING.md" 2>/dev/null; then
    echo "❌ ERROR: Target appears to be the Brain Bootstrap template repo itself."
    echo "   Install into your PROJECT repo, not into the template."
    echo "   Usage: bash install.sh /path/to/your-actual-project"
    exit 1
  fi
fi

# ── Detect mode ───────────────────────────────────────────────────
# PRINCIPLE: If Brain Bootstrap-related content exists, it's UPGRADE.
# .mcp.json is a general Claude Code config — excluded by design.
# FRESH only happens when absolutely nothing Brain-related is present.

has_claude_content() {
  # Any CLAUDE.md (regardless of content — could be hand-crafted, Brain, or template)
  [ -f "$TARGET/CLAUDE.md" ] && return 0

  # Any .claude/ directory with files
  if [ -d "$TARGET/.claude" ]; then
    local count
    count=$(find "$TARGET/.claude" -type f 2>/dev/null | head -1)
    [ -n "$count" ] && return 0
  fi

  # Any claude/ directory with real files (not just .gitkeep)
  if [ -d "$TARGET/claude" ]; then
    local count
    count=$(find "$TARGET/claude" -type f ! -name '.gitkeep' 2>/dev/null | head -1)
    [ -n "$count" ] && return 0
  fi

  # Any .claudeignore
  [ -f "$TARGET/.claudeignore" ] && return 0

  # NOTE: .mcp.json intentionally excluded — it is a Claude Code tool config (MCP servers),
  # not a Brain Bootstrap artifact. A user's personal .mcp.json must not trigger UPGRADE.

  # NOTE: We intentionally do NOT check root tasks/ or .tasks/ here.
  # A root tasks/ folder could be anything (Gulp tasks, Makefile targets, project management).
  # Old-layout detection is discover.sh's job — it runs inside the AI context
  # where it can reason about file content. install.sh stays in its lane.

  return 1
}

if has_claude_content; then
  MODE="UPGRADE"
else
  MODE="FRESH"
fi

echo "  Mode:    $MODE"
echo ""

# ── Helpers ────────────────────────────────────────────────────────

# Copy file only if target does not exist. Returns 0 if copied, 1 if skipped.
copy_if_missing() {
  local src="$1" dest="$2"
  if [ ! -e "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    return 0
  fi
  return 1
}

# Recursively add only files that don't exist in dest. Never overwrites.
# Echoes the count of files added.
add_missing_files() {
  local src_dir="$1" dest_dir="$2"
  local added=0
  [ -d "$src_dir" ] || { echo 0; return; }
  mkdir -p "$dest_dir"
  local _tmplist
  _tmplist=$(mktemp)
  find "$src_dir" -type f > "$_tmplist" 2>/dev/null
  while IFS= read -r src_file; do
    [ -z "$src_file" ] && continue
    local rel="${src_file#"$src_dir/"}"
    local dest_file="$dest_dir/$rel"
    if [ ! -e "$dest_file" ]; then
      mkdir -p "$(dirname "$dest_file")"
      cp "$src_file" "$dest_file"
      added=$((added + 1))
    fi
  done < "$_tmplist"
  rm -f "$_tmplist"
  echo "$added"
}

# Smart sync: update files that exist in BOTH source and dest (template-originated),
# add files that exist only in source (new template files),
# PRESERVE files that exist only in dest (user-created files — never touched).
# Echoes "updated:added:preserved" counts.
sync_dir() {
  local src_dir="$1" dest_dir="$2"
  local updated=0 added=0 preserved=0
  [ -d "$src_dir" ] || { echo "0:0:0"; return; }
  mkdir -p "$dest_dir"

  # Pass 1: Sync from template → dest (update existing + add new)
  local _tmplist1
  _tmplist1=$(mktemp)
  find "$src_dir" -type f > "$_tmplist1" 2>/dev/null
  while IFS= read -r src_file; do
    [ -z "$src_file" ] && continue
    local rel="${src_file#"$src_dir/"}"
    local dest_file="$dest_dir/$rel"
    mkdir -p "$(dirname "$dest_file")"
    if [ -e "$dest_file" ]; then
      if ! diff -q "$src_file" "$dest_file" >/dev/null 2>&1; then
        cp "$src_file" "$dest_file"
        updated=$((updated + 1))
      fi
    else
      cp "$src_file" "$dest_file"
      added=$((added + 1))
    fi
  done < "$_tmplist1"
  rm -f "$_tmplist1"

  # Pass 2: Count user-only files (exist in dest but not in source — NEVER touched)
  if [ -d "$dest_dir" ]; then
    local _tmplist2
    _tmplist2=$(mktemp)
    find "$dest_dir" -type f > "$_tmplist2" 2>/dev/null
    while IFS= read -r dest_file; do
      [ -z "$dest_file" ] && continue
      local rel="${dest_file#"$dest_dir/"}"
      local src_file="$src_dir/$rel"
      if [ ! -e "$src_file" ]; then
        preserved=$((preserved + 1))
      fi
    done < "$_tmplist2"
    rm -f "$_tmplist2"
  fi

  echo "$updated:$added:$preserved"
}

# ── FRESH: Copy everything ────────────────────────────────────────
if [ "$MODE" = "FRESH" ]; then
  echo "📦 Fresh install — copying full template..."
  echo ""

  # Root files
  for f in CLAUDE.md CLAUDE.local.md.example .claudeignore .mcp.json .graphifyignore; do
    if [ -f "$SCRIPT_DIR/$f" ]; then
      cp "$SCRIPT_DIR/$f" "$TARGET/$f"
      echo "  ✅ $f"
    fi
  done

  # claude/ directory
  cp -r "$SCRIPT_DIR/claude" "$TARGET/claude"
  echo "  ✅ claude/ (full)"

  # .claude/ directory
  cp -r "$SCRIPT_DIR/.claude" "$TARGET/.claude"
  echo "  ✅ .claude/ (full)"

  # .github/ — only Copilot config (not PR/issue templates or workflows)
  mkdir -p "$TARGET/.github/instructions" "$TARGET/.github/prompts"
  if [ -f "$SCRIPT_DIR/.github/copilot-instructions.md" ]; then
    cp "$SCRIPT_DIR/.github/copilot-instructions.md" "$TARGET/.github/copilot-instructions.md"
    echo "  ✅ .github/copilot-instructions.md"
  fi
  for f in "$SCRIPT_DIR/.github/instructions/"*.instructions.md; do
    [ -f "$f" ] && cp "$f" "$TARGET/.github/instructions/"
  done
  echo "  ✅ .github/instructions/"
  for f in "$SCRIPT_DIR/.github/prompts/"*.prompt.md; do
    [ -f "$f" ] && cp "$f" "$TARGET/.github/prompts/"
  done
  echo "  ✅ .github/prompts/"

  # Make scripts executable
  chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true
  chmod +x "$TARGET/claude/scripts/"*.sh 2>/dev/null || true

  total=$(find "$TARGET/claude" "$TARGET/.claude" -type f 2>/dev/null | wc -l)
  echo ""
  echo "✅ Fresh install complete! $total files installed."
  echo ""
  echo "👉 Next step:"
  echo "   Open Claude Code and run /bootstrap"
  echo ""
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# UPGRADE MODE — Smart merge: never lose user data
# ══════════════════════════════════════════════════════════════════
echo "🔄 Upgrade detected — smart merge in progress..."
echo "   Existing Claude configuration found. Every user file will be preserved."
echo ""

PRESERVED_COUNT=0
UPDATED_COUNT=0
ADDED_COUNT=0

# ── Pre-upgrade backup ─────────────────────────────────────────────
# Safety snapshot taken BEFORE any file is modified — covers both install.sh
# and the AI's /bootstrap Phase 2. The bootstrap can skip its own backup.
# Restore: tar xzf claude/tasks/.pre-upgrade-backup.tar.gz
mkdir -p "$TARGET/claude/tasks"
if (cd "$TARGET" && tar czf "claude/tasks/.pre-upgrade-backup.tar.gz" \
  CLAUDE.md .claudeignore .claude/ claude/ .github/ 2>/dev/null); then
  true
fi
echo "  💾 Safety backup → claude/tasks/.pre-upgrade-backup.tar.gz"
echo "     Restore: tar xzf claude/tasks/.pre-upgrade-backup.tar.gz"
echo ""

# ── Phase A: Inventory & protect ALL user content ─────────────────
# Dynamically scans everything the user has. No hardcoded file lists.
# This is REPORTING only — preservation is enforced structurally by
# sync_dir (preserves user-only files) and copy_if_missing (never overwrites).

echo "🛡️  Phase A — Inventorying your data (NEVER overwritten):"

# Root files
for f in CLAUDE.md CLAUDE.local.md .claudeignore .mcp.json .graphifyignore; do
  if [ -f "$TARGET/$f" ]; then
    echo "  🔒 $f"
    PRESERVED_COUNT=$((PRESERVED_COUNT + 1))
  fi
done

# ALL user files in claude/ EXCEPT infrastructure dirs
# (infrastructure dirs handled by sync_dir in Phase B — user-only files preserved there too)
if [ -d "$TARGET/claude" ]; then
  _tmpinv1=$(mktemp)
  find "$TARGET/claude" -type f ! -name '.gitkeep' > "$_tmpinv1" 2>/dev/null
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#"$TARGET/"}"
    # Skip infrastructure dirs — Phase B handles them with sync_dir
    case "$rel" in
      claude/bootstrap/*|claude/scripts/*|claude/docs/*|claude/_examples/*) continue ;;
    esac
    case "$rel" in
      claude/tasks/lessons.md|claude/tasks/todo.md|claude/tasks/CLAUDE_ERRORS.md)
        echo "  🔒 $rel (sacred — never modified)" ;;
      *)
        echo "  🔒 $rel" ;;
    esac
    PRESERVED_COUNT=$((PRESERVED_COUNT + 1))
  done < "$_tmpinv1"
  rm -f "$_tmpinv1"
fi

# ALL user files in .claude/
if [ -d "$TARGET/.claude" ]; then
  _tmpinv2=$(mktemp)
  find "$TARGET/.claude" -type f > "$_tmpinv2" 2>/dev/null
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#"$TARGET/"}"
    case "$rel" in
      .claude/settings.json)
        echo "  🔒 $rel (config — deep-merged by /bootstrap)" ;;
      *)
        echo "  🔒 $rel" ;;
    esac
    PRESERVED_COUNT=$((PRESERVED_COUNT + 1))
  done < "$_tmpinv2"
  rm -f "$_tmpinv2"
fi

# .github/ Copilot files
if [ -f "$TARGET/.github/copilot-instructions.md" ]; then
  echo "  🔒 .github/copilot-instructions.md"
  PRESERVED_COUNT=$((PRESERVED_COUNT + 1))
fi
for dir in "$TARGET/.github/instructions" "$TARGET/.github/prompts"; do
  [ -d "$dir" ] || continue
  _tmpinv3=$(mktemp)
  find "$dir" -type f > "$_tmpinv3" 2>/dev/null
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    echo "  🔒 ${f#"$TARGET/"}"
    PRESERVED_COUNT=$((PRESERVED_COUNT + 1))
  done < "$_tmpinv3"
  rm -f "$_tmpinv3"
done

echo ""
echo "  → $PRESERVED_COUNT existing files protected"
echo ""

# ── Phase B: Sync infrastructure dirs ─────────────────────────────
# Uses sync_dir: updates template files, adds new template files,
# PRESERVES user-only files. No rm -rf. No data loss. Ever.

echo "⬆️  Phase B — Updating Brain infrastructure (user-only files preserved):"

for dir_pair in \
  "claude/bootstrap:bootstrap process" \
  "claude/scripts:discovery & build tools" \
  "claude/docs:reference documentation" \
  "claude/_examples:domain examples"; do

  dir_name="${dir_pair%%:*}"
  dir_label="${dir_pair#*:}"
  src="$SCRIPT_DIR/$dir_name"
  dest="$TARGET/$dir_name"

  if [ -d "$src" ]; then
    result=$(sync_dir "$src" "$dest")
    u="${result%%:*}"; rest="${result#*:}"; a="${rest%%:*}"; p="${rest#*:}"
    UPDATED_COUNT=$((UPDATED_COUNT + u))
    ADDED_COUNT=$((ADDED_COUNT + a))

    status=""
    [ "$u" -gt 0 ] && status="${status}${u} updated"
    [ "$a" -gt 0 ] && status="${status:+$status, }${a} added"
    [ "$p" -gt 0 ] && status="${status:+$status, }${p} user files kept"
    [ -z "$status" ] && status="up to date"

    echo "  ⬆️  $dir_name/ → $status ($dir_label)"
  fi
done

# Make scripts executable
chmod +x "$TARGET/claude/scripts/"*.sh 2>/dev/null || true

echo ""

# ── Phase C: Add missing .claude/ components ──────────────────────
# Existing files are NEVER overwritten. Only missing files are added.
# User's custom commands, hooks, agents, skills, rules are untouched.

echo "➕ Phase C — Adding missing Brain components (existing untouched):"

for dir_pair in \
  ".claude/commands:commands" \
  ".claude/hooks:hooks" \
  ".claude/agents:agents" \
  ".claude/skills:skills" \
  ".claude/rules:rules"; do

  dir_name="${dir_pair%%:*}"
  dir_label="${dir_pair#*:}"
  src="$SCRIPT_DIR/$dir_name"
  dest="$TARGET/$dir_name"

  if [ -d "$src" ]; then
    n=$(add_missing_files "$src" "$dest")
    ADDED_COUNT=$((ADDED_COUNT + n))
    if [ "$n" -gt 0 ]; then
      echo "  ➕ $n new $dir_label added to $dir_name/"
    else
      echo "  ✅ $dir_name/ — all present"
    fi
  fi
done

# Make hooks executable
chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true

echo ""

# ── Phase D: Add missing individual files ─────────────────────────
# Root files, knowledge docs, task templates, Copilot config.
# ALL add-if-missing. NEVER overwrites existing files.

echo "➕ Phase D — Adding missing files:"

phase_d_added=0

# Root files
for f in CLAUDE.md CLAUDE.local.md.example .claudeignore .mcp.json .graphifyignore; do
  if [ -f "$SCRIPT_DIR/$f" ] && copy_if_missing "$SCRIPT_DIR/$f" "$TARGET/$f"; then
    echo "  ➕ $f (new)"
    phase_d_added=$((phase_d_added + 1))
  fi
done

# Knowledge docs in claude/ root (add missing only)
mkdir -p "$TARGET/claude"
for f in "$SCRIPT_DIR/claude/"*.md; do
  [ -f "$f" ] || continue
  fname="$(basename "$f")"
  if copy_if_missing "$f" "$TARGET/claude/$fname"; then
    echo "  ➕ claude/$fname (new)"
    phase_d_added=$((phase_d_added + 1))
  fi
done

# Task template files (add missing — NEVER overwrite)
# Uses find instead of glob to catch dotfiles (.gitignore, .gitkeep)
mkdir -p "$TARGET/claude/tasks"
_tmptasks=$(mktemp)
find "$SCRIPT_DIR/claude/tasks" -maxdepth 1 -type f > "$_tmptasks" 2>/dev/null
while IFS= read -r f; do
  [ -z "$f" ] && continue
  fname="$(basename "$f")"
  if copy_if_missing "$f" "$TARGET/claude/tasks/$fname"; then
    echo "  ➕ claude/tasks/$fname (new)"
    phase_d_added=$((phase_d_added + 1))
  fi
done < "$_tmptasks"
rm -f "$_tmptasks"

# .claude/settings.json — add if missing; if exists, merge permissions.allow NOW
# Why: Claude Code loads permissions at session start. Phase 2's deep-merge runs
# DURING the session — new permissions don't take effect until the NEXT session.
# By merging permissions.allow here, /bootstrap runs with full permissions immediately.
if [ -f "$SCRIPT_DIR/.claude/settings.json" ]; then
  if copy_if_missing "$SCRIPT_DIR/.claude/settings.json" "$TARGET/.claude/settings.json"; then
    echo "  ➕ .claude/settings.json (new)"
    phase_d_added=$((phase_d_added + 1))
  elif command -v jq >/dev/null 2>&1; then
    # Merge permissions.allow from template into existing settings.json
    # Union + deduplicate. User's deny rules and all other settings are untouched.
    TEMPLATE_SETTINGS="$SCRIPT_DIR/.claude/settings.json"
    USER_SETTINGS="$TARGET/.claude/settings.json"
    BEFORE=$(jq '.permissions.allow | length' "$USER_SETTINGS" 2>/dev/null || echo 0)
    MERGED=$(jq --slurpfile tmpl "$TEMPLATE_SETTINGS" '
      .permissions.allow = ([.permissions.allow // [], $tmpl[0].permissions.allow // []] | add | unique)
    ' "$USER_SETTINGS" 2>/dev/null) || true
    if [ -n "$MERGED" ] && echo "$MERGED" | jq . >/dev/null 2>&1; then
      echo "$MERGED" > "$USER_SETTINGS"
      AFTER=$(jq '.permissions.allow | length' "$USER_SETTINGS" 2>/dev/null || echo 0)
      DIFF=$((AFTER - BEFORE))
      if [ "$DIFF" -gt 0 ]; then
        echo "  🔑 .claude/settings.json → $DIFF new permission(s) merged (active immediately)"
      else
        echo "  ✅ .claude/settings.json — permissions up to date"
      fi
    else
      echo "  ⚠️  .claude/settings.json — jq merge failed (Phase 2 will handle it)"
    fi
  else
    echo "  ⚠️  .claude/settings.json exists, jq not found — Phase 2 will merge permissions"
  fi
fi
if [ -f "$SCRIPT_DIR/.claude/settings.local.json.example" ]; then
  if copy_if_missing "$SCRIPT_DIR/.claude/settings.local.json.example" "$TARGET/.claude/settings.local.json.example"; then
    echo "  ➕ .claude/settings.local.json.example (new)"
    phase_d_added=$((phase_d_added + 1))
  fi
fi

# .github/ Copilot files (add only missing)
mkdir -p "$TARGET/.github/instructions" "$TARGET/.github/prompts"
if [ -f "$SCRIPT_DIR/.github/copilot-instructions.md" ]; then
  if copy_if_missing "$SCRIPT_DIR/.github/copilot-instructions.md" "$TARGET/.github/copilot-instructions.md"; then
    echo "  ➕ .github/copilot-instructions.md (new)"
    phase_d_added=$((phase_d_added + 1))
  fi
fi
for f in "$SCRIPT_DIR/.github/instructions/"*.instructions.md; do
  [ -f "$f" ] || continue
  fname="$(basename "$f")"
  if copy_if_missing "$f" "$TARGET/.github/instructions/$fname"; then
    echo "  ➕ .github/instructions/$fname (new)"
    phase_d_added=$((phase_d_added + 1))
  fi
done
for f in "$SCRIPT_DIR/.github/prompts/"*.prompt.md; do
  [ -f "$f" ] || continue
  fname="$(basename "$f")"
  if copy_if_missing "$f" "$TARGET/.github/prompts/$fname"; then
    echo "  ➕ .github/prompts/$fname (new)"
    phase_d_added=$((phase_d_added + 1))
  fi
done

ADDED_COUNT=$((ADDED_COUNT + phase_d_added))

if [ "$phase_d_added" -eq 0 ]; then
  echo "  ✅ All files present — nothing to add"
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅  Smart merge complete!                           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  🔒 Preserved:  $PRESERVED_COUNT user files (knowledge, tasks, config)"
echo "  ⬆️  Updated:    $UPDATED_COUNT infrastructure files"
echo "  ➕ Added:      $ADDED_COUNT new Brain components"
echo ""
echo "  Every file you created — lessons, architecture docs, domain"
echo "  knowledge, custom commands, settings — is exactly as you left it."
echo ""
echo "┌──────────────────────────────────────────────────────┐"
echo "│  👉 Next step:                                       │"
echo "│                                                      │"
echo "│  Open Claude Code and run /bootstrap                 │"
echo "│     Phase 2 (Smart Merge) will:                      │"
echo "│     • Enhance CLAUDE.md with new template sections   │"
echo "│     • Deep-merge settings.json (your values win)     │"
echo "│     • Union-merge .claudeignore patterns             │"
echo "│     All additive. Never destructive.                 │"
echo "└──────────────────────────────────────────────────────┘"

if ! command -v jq &>/dev/null; then
  echo ""
  echo "⚠️  jq is not installed — safety hooks will be degraded."
  echo "   Without jq, config-protection, terminal-safety-gate, and commit-quality"
  echo "   hooks cannot parse Claude Code's JSON input and will silently pass through."
  echo "   JS/TS project discovery (package.json parsing) will also be incomplete."
  echo ""
  case "$BRAIN_PLATFORM" in
    macos)   echo "   Install now:  brew install jq" ;;
    windows) echo "   Install now:  scoop install jq  OR  choco install jq" ;;
    linux)   echo "   Install now:  sudo apt install jq  OR  sudo dnf install jq" ;;
  esac
  echo ""
fi
echo ""

