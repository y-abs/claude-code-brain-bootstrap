#!/bin/bash
# setup-plugins.sh — All-in-one plugin management for bootstrap
# Handles: wait for bg install → disable claude-mem → kill worker → verify → update CLAUDE.md
#          + graphify knowledge graph: pip install → skill install → git hooks
# Usage: bash claude/scripts/setup-plugins.sh [project-dir]
# Safe: exits cleanly if claude CLI not available (non-Claude Code environments)

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ setup-plugins.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -eo pipefail
PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"


# ─── Portable helpers (sed_inplace, safe_pgrep, platform detection)
# shellcheck disable=SC1091
source "$(dirname "$0")/_platform.sh"

# ═════════════════════════════════════════════════════════════════
# SECTION 1: claude-mem (Claude Code plugin)
# ═════════════════════════════════════════════════════════════════

if ! command -v claude &>/dev/null; then
  echo "✅ claude-mem setup skipped (claude CLI not available — non-Claude Code environment)"
  # Still update CLAUDE.md placeholder even without plugin
  if [ -f "CLAUDE.md" ] && grep -q '{{INSTALLED_PLUGINS}}' "CLAUDE.md" 2>/dev/null; then
    sed_inplace $'s|<!-- {{INSTALLED_PLUGINS}}.*-->|- **claude-mem** — install manually: `claude plugin install claude-mem@thedotmack` then disable for quota protection|' "CLAUDE.md"
  fi
  CLAUDE_MEM_STATUS="skipped (no claude CLI)"
else
  echo "🔌 Plugin Setup — claude-mem..."

  # 1. Attempt to wait for any child bg processes (no-op if Phase 1 ran in a different shell)
  wait 2>/dev/null || true

  # 2. Show install log if exists
  if [ -f "claude/tasks/.plugin-install.log" ]; then
    sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r//g' claude/tasks/.plugin-install.log 2>/dev/null \
      | grep -v '^[[:space:]]*$' | tail -3 || true
  fi

  # 3. Check if installed; if not, try synchronous install once
  claude plugin list > claude/tasks/.plugin-list.log 2>&1 || true
  if ! sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r//g' claude/tasks/.plugin-list.log 2>/dev/null | grep -qi 'claude-mem'; then
    echo "  ⏳ Installing claude-mem..."
    claude plugin install claude-mem@thedotmack > claude/tasks/.plugin-install.log 2>&1 || true
  fi

  # 4. Disable claude-mem (quota protection — PostToolUse(*) uses ~48% API quota)
  claude plugin disable claude-mem@thedotmack > claude/tasks/.plugin-disable.log 2>&1 || true

  # 5. Kill any running worker process
  # [c] = anti-self-match pattern (prevents pgrep from matching its own command line)
  WORKER_PIDS=$(safe_pgrep '[c]laude-mem.*worker-service')
  if [ -n "$WORKER_PIDS" ]; then kill "$WORKER_PIDS" 2>/dev/null || true; fi

  # 6. Verify final state
  claude plugin list > claude/tasks/.plugin-list.log 2>&1 || true
  CLEAN_LIST=$(sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r//g' claude/tasks/.plugin-list.log 2>/dev/null | grep -v '^[[:space:]]*$' || true)
  if echo "$CLEAN_LIST" | grep -qi 'claude-mem'; then
    CLAUDE_MEM_STATUS="installed (disabled)"
  else
    CLAUDE_MEM_STATUS="not installed — user can run: claude plugin install claude-mem@thedotmack"
  fi

  # 7. Update CLAUDE.md — replace plugin placeholder with actual state
  if [ -f "CLAUDE.md" ] && grep -q '{{INSTALLED_PLUGINS}}' "CLAUDE.md" 2>/dev/null; then
    sed_inplace $'s|<!-- {{INSTALLED_PLUGINS}}.*-->|- **claude-mem** — persistent cross-session memory (SQLite + ChromaDB) — ⚠️ disabled by default (toggle: `bash claude/scripts/toggle-claude-mem.sh on`)|' "CLAUDE.md"
    echo "  ✅ CLAUDE.md plugin section updated"
  fi

  echo "  ✅ claude-mem: $CLAUDE_MEM_STATUS"
fi

# ═════════════════════════════════════════════════════════════════
# SECTION 2: graphify (knowledge graph — Python package + skill)
# ═════════════════════════════════════════════════════════════════

echo ""
echo "🔌 Plugin Setup — graphify..."

# Detect Python 3.10+ (required by graphify)
GRAPHIFY_PYTHON=""
for py_cmd in python3 python; do
  if command -v "$py_cmd" &>/dev/null; then
    PY_VER=$("$py_cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
    PY_MAJOR="${PY_VER%%.*}"
    PY_MINOR="${PY_VER##*.}"
    if [ "${PY_MAJOR:-0}" -ge 3 ] && [ "${PY_MINOR:-0}" -ge 10 ]; then
      GRAPHIFY_PYTHON="$py_cmd"
      break
    fi
  fi
done

if [ -z "$GRAPHIFY_PYTHON" ]; then
  echo "  ⚠️  graphify skipped — Python 3.10+ not found"
  echo "     Install Python 3.10+ and run: pip install graphifyy && graphify install && graphify hook install"
  GRAPHIFY_STATUS="skipped (Python 3.10+ not found)"
else
  # Check if graphify is already installed
  if "$GRAPHIFY_PYTHON" -c "import graphify" 2>/dev/null; then
    GRAPHIFY_INSTALLED=true
    GRAPHIFY_VER=$("$GRAPHIFY_PYTHON" -c "from importlib.metadata import version; print(version('graphifyy'))" 2>/dev/null || echo "unknown")
    echo "  ✅ graphify $GRAPHIFY_VER already installed"
  else
    echo "  ⏳ Installing graphify (pip install graphifyy)..."
    if "$GRAPHIFY_PYTHON" -m pip install graphifyy -q 2>/dev/null || "$GRAPHIFY_PYTHON" -m pip install graphifyy -q --break-system-packages 2>/dev/null; then
      GRAPHIFY_INSTALLED=true
      GRAPHIFY_VER=$("$GRAPHIFY_PYTHON" -c "from importlib.metadata import version; print(version('graphifyy'))" 2>/dev/null || echo "unknown")
      echo "  ✅ graphify $GRAPHIFY_VER installed"
    else
      GRAPHIFY_INSTALLED=false
      echo "  ⚠️  pip install graphifyy failed — try manually: pip install graphifyy"
    fi
  fi

  if [ "$GRAPHIFY_INSTALLED" = "true" ]; then
    # Install the global skill (graphify install — copies SKILL.md to ~/.claude/skills/)
    if command -v graphify &>/dev/null; then
      GRAPHIFY_CMD="graphify"
    else
      GRAPHIFY_CMD="$GRAPHIFY_PYTHON -m graphify"
    fi

    # Global skill install (one-time per machine)
    $GRAPHIFY_CMD install > claude/tasks/.graphify-install.log 2>&1 || true

    # Git hooks (post-commit + post-checkout — auto-rebuild graph on commit/branch switch)
    $GRAPHIFY_CMD hook install > claude/tasks/.graphify-hooks.log 2>&1 || true

    GRAPHIFY_STATUS="$GRAPHIFY_VER installed · skill registered · git hooks active"
    echo "  ✅ graphify skill registered + git hooks installed"
    echo "  👉 Run /graphify . to build the knowledge graph (first run ~5 min, then incremental)"
  else
    GRAPHIFY_STATUS="install failed — manual: pip install graphifyy && graphify install"
  fi
fi

# ═════════════════════════════════════════════════════════════════
# SECTION 3: rtk (token optimizer — Rust binary, installed via cargo)
# ═════════════════════════════════════════════════════════════════

echo ""
echo "🔌 Plugin Setup — rtk (token optimizer)..."

if command -v rtk &>/dev/null; then
  # Already installed — just verify and report
  RTK_VERSION=$(rtk --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
  echo "  ✅ rtk $RTK_VERSION already installed"

  SETTINGS_FILE=".claude/settings.json"
  if [ -f "$SETTINGS_FILE" ] && grep -q 'rtk-rewrite' "$SETTINGS_FILE" 2>/dev/null; then
    echo "  ✅ rtk-rewrite hook active in .claude/settings.json"
  else
    echo "  ⚠️  rtk-rewrite hook missing from .claude/settings.json"
  fi

  RTK_STATUS="$RTK_VERSION installed · hook active"

elif command -v cargo &>/dev/null; then
  # cargo available — auto-install rtk (same pattern as graphify via pip)
  echo "  ⏳ Installing rtk via cargo (this may take 1-2 min — compiling from source)..."
  if cargo install rtk --quiet 2>/dev/null; then
    RTK_VERSION=$(rtk --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
    echo "  ✅ rtk $RTK_VERSION installed"
    echo "  ✅ rtk-rewrite hook active (.claude/settings.json already wired)"
    RTK_STATUS="$RTK_VERSION installed · hook active"
  else
    echo "  ⚠️  cargo install rtk failed — install manually: cargo install rtk"
    RTK_STATUS="install failed — manual: cargo install rtk"
  fi

else
  # No cargo — inform user, hook remains a no-op until they install
  echo "  ℹ️  rtk not installed (cargo not found)"
  echo "     Hook is registered and ready — install Rust + rtk to activate:"
  echo "     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  echo "     cargo install rtk"
  RTK_STATUS="not installed (hook registered, no-op — needs cargo)"
fi

echo "  ✅ rtk: $RTK_STATUS"

# ═════════════════════════════════════════════════════════════════
# SECTION 4: codebase-memory-mcp (C binary — zero runtime deps)
# ═════════════════════════════════════════════════════════════════

echo ""
echo "🔌 Plugin Setup — codebase-memory-mcp (structural graph)..."

if command -v codebase-memory-mcp &>/dev/null; then
  CBM_VERSION=$(codebase-memory-mcp --version 2>/dev/null | head -1 | awk '{print $NF}' || echo "unknown")
  echo "  ✅ codebase-memory-mcp $CBM_VERSION already installed"
  CBM_STATUS="$CBM_VERSION installed"

elif command -v curl &>/dev/null; then
  echo "  ⏳ Installing codebase-memory-mcp via install.sh..."
  # --skip-config: binary only — we manage .mcp.json ourselves (avoids global settings.json hooks)
  if curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh \
       | bash -s -- --skip-config 2>/dev/null; then
    # Reload PATH — install script adds ~/.local/bin
    export PATH="$HOME/.local/bin:$PATH"
    CBM_VERSION=$(codebase-memory-mcp --version 2>/dev/null | head -1 | awk '{print $NF}' || echo "unknown")
    echo "  ✅ codebase-memory-mcp $CBM_VERSION installed"
    # Enable auto-index: index new projects automatically on MCP connection
    codebase-memory-mcp config set auto_index true 2>/dev/null || true
    echo "  ✅ auto_index enabled"
    CBM_STATUS="$CBM_VERSION installed · auto_index on"
  else
    echo "  ⚠️  install.sh failed — install manually:"
    echo "     curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash"
    CBM_STATUS="install failed — manual required"
  fi

else
  echo "  ⚠️  codebase-memory-mcp skipped — curl not found"
  CBM_STATUS="skipped (curl not found)"
fi

echo "  ✅ codebase-memory-mcp: $CBM_STATUS"

# ═════════════════════════════════════════════════════════════════
# SECTION 5: cocoindex-code (semantic vector search — Python 3.11+)
# ═════════════════════════════════════════════════════════════════

echo ""
echo "🔌 Plugin Setup — cocoindex-code (semantic search)..."

# Detect Python 3.11+ (cocoindex-code requires 3.11, vs graphify's 3.10)
COCO_PYTHON=""
for py_cmd in python3 python; do
  if command -v "$py_cmd" &>/dev/null; then
    PY_VER=$("$py_cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
    PY_MAJOR="${PY_VER%%.*}"
    PY_MINOR="${PY_VER##*.}"
    if [ "${PY_MAJOR:-0}" -ge 3 ] && [ "${PY_MINOR:-0}" -ge 11 ]; then
      COCO_PYTHON="$py_cmd"
      break
    fi
  fi
done

if [ -z "$COCO_PYTHON" ]; then
  echo "  ⚠️  cocoindex-code skipped — Python 3.11+ not found"
  echo "     (graphify uses 3.10+; cocoindex-code requires 3.11+)"
  echo "     Install: brew install python@3.11"
  COCO_STATUS="skipped (Python 3.11+ not found)"

elif command -v ccc &>/dev/null; then
  CCC_VERSION=$(ccc --version 2>/dev/null | head -1 || echo "unknown")
  echo "  ✅ cocoindex-code ($CCC_VERSION) already installed"
  COCO_STATUS="$CCC_VERSION installed"

else
  echo "  ⏳ Installing cocoindex-code[full] (local embeddings — ~1 GB first install)..."
  # [full] = sentence-transformers + torch for local embedding, no API key needed
  if "$COCO_PYTHON" -m pip install 'cocoindex-code[full]' -q 2>/dev/null \
     || "$COCO_PYTHON" -m pip install 'cocoindex-code[full]' -q --break-system-packages 2>/dev/null; then
    CCC_VERSION=$(ccc --version 2>/dev/null | head -1 || echo "unknown")
    echo "  ✅ cocoindex-code $CCC_VERSION installed"
    COCO_STATUS="$CCC_VERSION installed (local embeddings)"
  else
    echo "  ⚠️  pip install failed — try manually: pip install 'cocoindex-code[full]'"
    COCO_STATUS="install failed — manual: pip install 'cocoindex-code[full]'"
  fi
fi

# Create config files (non-interactive init bypass — ccc init hangs in non-TTY)
if [ -n "$COCO_PYTHON" ] && command -v ccc &>/dev/null; then
  # Global settings: embedding model selection
  GLOBAL_CFG_DIR="$HOME/.cocoindex_code"
  mkdir -p "$GLOBAL_CFG_DIR"
  if [ ! -f "$GLOBAL_CFG_DIR/global_settings.yml" ]; then
    cat > "$GLOBAL_CFG_DIR/global_settings.yml" <<'YAML'
embedding:
  provider: sentence-transformers
  model: Snowflake/snowflake-arctic-embed-xs
YAML
    echo "  ✅ Global settings created (~/.cocoindex_code/global_settings.yml)"
  fi

  # Project settings: committed to repo (team-shared file patterns)
  mkdir -p ".cocoindex_code"
  if [ ! -f ".cocoindex_code/settings.yml" ]; then
    cat > ".cocoindex_code/settings.yml" <<'YAML'
include_patterns:
  - "**/*.py"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.rs"
  - "**/*.go"
  - "**/*.java"
  - "**/*.sh"
  - "**/*.md"
  - "**/*.yml"
  - "**/*.yaml"
  - "**/*.json"
exclude_patterns:
  - "**/.*"
  - "**/node_modules/**"
  - "**/target/**"
  - "**/build/**"
  - "**/dist/**"
  - "**/__pycache__/**"
  - "**/graphify-out/**"
  - "**/.code-review-graph/**"
YAML
    echo "  ✅ Project settings created (.cocoindex_code/settings.yml)"
  fi

  # Gitignore: exclude index DBs (binary/large), keep settings.yml committed
  if ! grep -q '\.cocoindex_code' .gitignore 2>/dev/null; then
    printf '\n# cocoindex-code vector index (binary DBs — settings.yml is committed)\n.cocoindex_code/target_sqlite.db\n.cocoindex_code/cocoindex.db\n' >> .gitignore
    echo "  ✅ .gitignore updated (index DBs excluded, settings.yml committed)"
  fi

  echo "  ℹ️  Run 'ccc index' to build the initial semantic index (~30s first run)"
  echo "     Or: auto-builds on first 'ccc mcp' search call"
fi

echo "  ✅ cocoindex-code: $COCO_STATUS"

# ═════════════════════════════════════════════════════════════════
# SECTION 6: code-review-graph (change risk analysis — Python 3.10+)
# ═════════════════════════════════════════════════════════════════

echo ""
echo "🔌 Plugin Setup — code-review-graph (change risk analysis)..."

# Detect Python 3.10+ (same requirement as graphify)
CRG_PYTHON=""
for py_cmd in python3 python; do
  if command -v "$py_cmd" &>/dev/null; then
    PY_VER=$("$py_cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
    PY_MAJOR="${PY_VER%%.*}"
    PY_MINOR="${PY_VER##*.}"
    if [ "${PY_MAJOR:-0}" -ge 3 ] && [ "${PY_MINOR:-0}" -ge 10 ]; then
      CRG_PYTHON="$py_cmd"
      break
    fi
  fi
done

if [ -z "$CRG_PYTHON" ]; then
  echo "  ⚠️  code-review-graph skipped — Python 3.10+ not found"
  echo "     Install Python 3.10+: brew install python@3.10"
  CRG_STATUS="skipped (Python 3.10+ not found)"

elif command -v code-review-graph &>/dev/null; then
  CRG_VERSION=$(code-review-graph --version 2>/dev/null | head -1 || echo "unknown")
  echo "  ✅ code-review-graph ($CRG_VERSION) already installed"
  CRG_STATUS="$CRG_VERSION installed"

else
  echo "  ⏳ Installing code-review-graph..."
  # [communities] extra: Leiden algorithm for community detection (optional but recommended)
  if "$CRG_PYTHON" -m pip install 'code-review-graph[communities]' -q 2>/dev/null \
     || "$CRG_PYTHON" -m pip install 'code-review-graph[communities]' -q --break-system-packages 2>/dev/null \
     || "$CRG_PYTHON" -m pip install 'code-review-graph' -q 2>/dev/null \
     || "$CRG_PYTHON" -m pip install 'code-review-graph' -q --break-system-packages 2>/dev/null; then
    CRG_VERSION=$(code-review-graph --version 2>/dev/null | head -1 || echo "unknown")
    echo "  ✅ code-review-graph $CRG_VERSION installed"
    CRG_STATUS="$CRG_VERSION installed"
  else
    echo "  ⚠️  pip install failed — try manually:"
    echo "     pip install 'code-review-graph[communities]'"
    CRG_STATUS="install failed — manual: pip install 'code-review-graph[communities]'"
  fi
fi

# Post-install setup: git hook only (--no-instructions --no-hooks avoids global settings.json pollution)
if [ -n "$CRG_PYTHON" ] && command -v code-review-graph &>/dev/null; then
  # --no-instructions: skip CLAUDE.md injection (we manage CLAUDE.md ourselves — 4KB budget)
  # --no-hooks: skip PostToolUse(Write|Edit|Bash) settings.json hook (~48% quota drain)
  # postprocess: installs only git post-commit hook (SHA-256 re-index, no LLM, <2s)
  if code-review-graph postprocess --no-instructions --no-hooks > /dev/null 2>&1; then
    echo "  ✅ git post-commit hook installed (incremental re-index on commit)"
    CRG_STATUS="${CRG_STATUS} · git hook active"
  else
    echo "  ℹ️  postprocess failed — run manually: code-review-graph postprocess --no-instructions --no-hooks"
  fi

  echo "  ℹ️  Run 'code-review-graph build .' to build the initial graph"
  echo "     Or use MCP: mcp__code-review-graph__build_graph_tool"
fi

echo "  ✅ code-review-graph: $CRG_STATUS"

# ═════════════════════════════════════════════════════════════════
# SUMMARY (compact — avoids Claude Code UI collapse at ≥4 lines)
# ═════════════════════════════════════════════════════════════════

echo ""
echo "✅ Plugins: claude-mem ${CLAUDE_MEM_STATUS:-skipped} · graphify ${GRAPHIFY_STATUS:-skipped} · rtk ${RTK_STATUS:-skipped} · cbm ${CBM_STATUS:-skipped} · ccc ${COCO_STATUS:-skipped} · crg ${CRG_STATUS:-skipped}"
if [ -f "claude/tasks/.bootstrap-plan.txt" ]; then echo "P4 $(date +%H:%M:%S)" >> "claude/tasks/.bootstrap-progress.txt" 2>/dev/null; fi

