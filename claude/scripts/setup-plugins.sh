#!/bin/bash
# setup-plugins.sh — All-in-one plugin management for bootstrap
# Handles: strategy selection → per-plugin install/skip → verify → update CLAUDE.md
# Usage: bash claude/scripts/setup-plugins.sh [FLAGS] [project-dir]
#   --lite             Skip heavy plugins (graphify, cocoindex, code-review-graph ~1-3 GB total)
#   --yes              Non-interactive, auto-accept all plugins (ideal for CI and AI orchestration)
#   --interactive      Prompt user for plugin strategy + per-plugin confirmation (default when TTY)
#   --non-interactive  Never prompt; respect SKIP_* env vars (default in CI / piped input / Claude Code)
#   --strategy=none|full|all|recommended|personalize  Pre-set strategy (skips strategy prompt)
#   --skip=plugin1,plugin2  Skip specific plugins (names: claude-mem, graphify, rtk, cocoindex/coco,
#                           crg/code-review-graph, cbm/codebase-memory, playwright, codeburn, caveman, serena)
# Auto-detects Claude Code environment and forces non-interactive mode (no hanging on prompts).
# Safe: no error breaks the flow. Exits cleanly if claude CLI not available.

# ─── Source guard — prevent env corruption if sourced ─────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ setup-plugins.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

# NOTE: no set -e — we guard every failing command with || true
# so that no error path breaks the plugin installation flow.
set -o pipefail

# ─── Argument parsing ──────────────────────────────────────────────
LITE_MODE=""
INTERACTIVE_FLAG=""   # "", "interactive", or "non-interactive"
PLUGIN_STRATEGY=""    # "", "none", "full", "recommended", "personalize"
SKIP_LIST=""          # comma-separated plugin names to skip (e.g., --skip=graphify,cocoindex)
PROJECT_DIR=""

for arg in "$@"; do
  case "$arg" in
    --lite)                 LITE_MODE=1 ;;
    --yes)                  INTERACTIVE_FLAG="non-interactive" ;;
    --interactive)          INTERACTIVE_FLAG="interactive" ;;
    --non-interactive)      INTERACTIVE_FLAG="non-interactive" ;;
    --strategy=none)        PLUGIN_STRATEGY="none" ;;
    --strategy=full)        PLUGIN_STRATEGY="full" ;;
    --strategy=all)         PLUGIN_STRATEGY="full" ;;  # alias
    --strategy=recommended) PLUGIN_STRATEGY="recommended" ;;
    --strategy=personalize) PLUGIN_STRATEGY="personalize" ;;
    --strategy=*)           echo "⚠️  Unknown strategy: $arg (valid: none, full, all, recommended, personalize)" >&2 ;;
    --skip=*)               SKIP_LIST="${arg#--skip=}" ;;
    -*)                     echo "⚠️  Unknown flag: $arg" >&2 ;;
    *)                      PROJECT_DIR="$arg" ;;
  esac
done
PROJECT_DIR="${PROJECT_DIR:-.}"
cd "$PROJECT_DIR" || exit 1

# ─── Apply --skip= list (maps names to SKIP_* env vars) ───────────
if [ -n "$SKIP_LIST" ]; then
  IFS=',' read -ra _SKIP_ITEMS <<< "$SKIP_LIST"
  for _item in "${_SKIP_ITEMS[@]}"; do
    case "$_item" in
      claude-mem|claudemem|mem)          SKIP_CLAUDE_MEM=1 ;;
      graphify)                          SKIP_GRAPHIFY=1 ;;
      rtk)                               SKIP_RTK=1 ;;
      cocoindex|coco)                    SKIP_COCOINDEX=1 ;;
      code-review-graph|crg)             SKIP_CRG=1 ;;
      codebase-memory|codebase-memory-mcp|cbm) SKIP_CBM=1 ;;
      playwright|playwright-mcp)         SKIP_PLAYWRIGHT=1 ;;
      codeburn)                          SKIP_CODEBURN=1 ;;
      caveman)                           SKIP_CAVEMAN=1 ;;
      serena)                            SKIP_SERENA=1 ;;
      *) echo "⚠️  Unknown plugin in --skip: $_item" >&2 ;;
    esac
  done
fi

# ─── Interactive mode detection ────────────────────────────────────
# Default: interactive when stdin is a TTY, not in CI, and not inside an AI agent.
# Both Claude Code and VS Code provide a TTY but have NO human on the
# other end to respond to interactive prompts — detect them and force non-interactive.
AI_AGENT_ENV=""
# Claude Code detection
if [ -n "${CLAUDE_CODE:-}" ] || [ -n "${CLAUDE_CODE_ENTRYPOINT:-}" ] \
   || [ -n "${ANTHROPIC_MODEL:-}" ] || [ -n "${CLAUDE_CONVERSATION_ID:-}" ]; then
  AI_AGENT_ENV="claude-code"
fi
# VS Code detection (TERM_PROGRAM=vscode, VSCODE_* env vars)
if [ -z "$AI_AGENT_ENV" ]; then
  if [ "${TERM_PROGRAM:-}" = "vscode" ] || [ -n "${VSCODE_GIT_ASKPASS_MAIN:-}" ] \
     || [ -n "${VSCODE_GIT_IPC_HANDLE:-}" ] || [ -n "${VSCODE_INJECTION:-}" ]; then
    AI_AGENT_ENV="vscode"
  fi
fi
# JetBrains terminal detection (IntelliJ, WebStorm, PyCharm, etc.)
if [ -z "$AI_AGENT_ENV" ]; then
  case "${TERMINAL_EMULATOR:-}" in
    JetBrains-*) AI_AGENT_ENV="jetbrains" ;;
  esac
fi

if [ "$INTERACTIVE_FLAG" = "interactive" ]; then
  INTERACTIVE_MODE=1
elif [ "$INTERACTIVE_FLAG" = "non-interactive" ]; then
  INTERACTIVE_MODE=""
elif [ -n "$AI_AGENT_ENV" ]; then
  # Inside AI agent (Claude Code or VS Code) — never prompt
  INTERACTIVE_MODE=""
  if [ -z "$PLUGIN_STRATEGY" ]; then
    echo "ℹ️  Detected $AI_AGENT_ENV environment — using recommended strategy (override with --strategy=)" >&2
    PLUGIN_STRATEGY="recommended"
  fi
elif [ -t 0 ] && [ -z "${CI:-}" ]; then
  INTERACTIVE_MODE=1
else
  INTERACTIVE_MODE=""
fi

# ─── safe_read — read with timeout (prevents hanging in non-human terminals) ──
# Usage: safe_read VARNAME TIMEOUT_SEC DEFAULT_VALUE
# Returns 0 on success, 1 on timeout/failure (VARNAME set to DEFAULT_VALUE)
safe_read() {
  local _var="$1" _timeout="$2" _default="$3"
  local _answer
  if read -t "$_timeout" -r _answer </dev/tty 2>/dev/null; then
    eval "$_var=\"\$_answer\""
    return 0
  else
    eval "$_var=\"\$_default\""
    return 1
  fi
}

# ─── Plugin opt-out — set any of these before running to skip that plugin ──
# export SKIP_CLAUDE_MEM=1   # Skip claude-mem (requires claude CLI)
# export SKIP_GRAPHIFY=1     # Skip graphify knowledge graph (Python 3.10+)
# export SKIP_RTK=1          # Skip rtk command optimizer (requires cargo)
# export SKIP_COCOINDEX=1    # Recommended for slow networks (~1 GB download)
# export SKIP_CRG=1          # Skip code-review-graph (Python 3.10+)
# export SKIP_CBM=1          # Skip codebase-memory-mcp (C binary)
# export SKIP_PLAYWRIGHT=1   # Skip Playwright MCP browser automation (~300 MB Chromium)
# export SKIP_CODEBURN=1    # Skip codeburn token observability dashboard (Node.js 18+)
# export SKIP_CAVEMAN=1     # Skip caveman response-text compression (Node.js required)
# export SKIP_SERENA=1      # Skip serena LSP refactoring MCP server (Python 3.11+ / uvx)
SKIP_CLAUDE_MEM="${SKIP_CLAUDE_MEM:-}"
SKIP_GRAPHIFY="${SKIP_GRAPHIFY:-}"
SKIP_RTK="${SKIP_RTK:-}"
SKIP_COCOINDEX="${SKIP_COCOINDEX:-}"
SKIP_CRG="${SKIP_CRG:-}"
SKIP_CBM="${SKIP_CBM:-}"
SKIP_PLAYWRIGHT="${SKIP_PLAYWRIGHT:-}"
SKIP_CODEBURN="${SKIP_CODEBURN:-}"
SKIP_CAVEMAN="${SKIP_CAVEMAN:-}"
SKIP_SERENA="${SKIP_SERENA:-}"

# ─── --lite auto-skips heavy plugins ───────────────────────────────
if [ -n "$LITE_MODE" ]; then
  echo "⚡ Lite mode — skipping heavy plugins (graphify, cocoindex, code-review-graph)"
  SKIP_GRAPHIFY=1
  SKIP_COCOINDEX=1
  SKIP_CRG=1
fi

# ─── ask_plugin — interactive yes/no prompt with full context ──────
# Usage: ask_plugin SKIP_VAR "Plugin Name" TIER INSTALL_TIME TOKEN_COST "what it does" "manual install later"
# TIER: RECOMMENDED | OPTIONAL | HEAVY
# TOKEN_COST: token/runtime cost description
# Sets SKIP_VAR=1 if the user answers no.
# In non-personalize strategies, this is a no-op (decisions already made by apply_strategy).
ask_plugin() {
  local var_name="$1"
  local plugin_name="$2"
  local tier="$3"
  local install_time="$4"
  local token_cost="$5"
  local description="$6"
  local manual_later="$7"

  # If already opted out via env var or strategy, skip the prompt
  local current_val
  current_val="$(eval echo "\${$var_name:-}")"
  if [ -n "$current_val" ]; then
    return 0
  fi

  # Only show interactive card in personalize mode
  if [ "$PLUGIN_STRATEGY" != "personalize" ]; then
    return 0
  fi

  echo ""
  echo "  ┌─────────────────────────────────────────────────────────"
  echo "  │ 🔌 $plugin_name"
  echo "  │"
  echo "  │ $description"
  echo "  │"
  case "$tier" in
    RECOMMENDED) echo "  │ 📋 Recommendation : ✅ RECOMMENDED — core productivity tool" ;;
    OPTIONAL)    echo "  │ 📋 Recommendation : 💡 OPTIONAL — useful but not essential" ;;
    HEAVY)       echo "  │ 📋 Recommendation : ⚠️  HEAVY — large download, skip on slow networks" ;;
  esac
  echo "  │ ⏱️  Install time   : $install_time"
  echo "  │ 🪙 Token cost     : $token_cost"
  echo "  │"
  echo "  │ 📌 Install later:"
  echo "  │    $manual_later"
  echo "  └─────────────────────────────────────────────────────────"

  local answer=""
  printf "  Install %s? [Y/n] " "$plugin_name"
  if ! safe_read answer 10 ""; then
    echo ""
    echo "  ⏱️  No response (timeout) — installing $plugin_name (default: yes)"
    answer=""
  fi
  case "$answer" in
    [Nn]*) eval "$var_name=1"; echo "  ⏭️  $plugin_name skipped — install later with the command above" ;;
    *)     echo "  ✅ $plugin_name will be installed" ;;
  esac
  echo ""
}

# ─── add_mcp_entry — idempotently add a server to .mcp.json ──────
# Usage: add_mcp_entry "server-name" '{"command":"cmd","args":["a"]}'
# Creates .mcp.json if missing. Skips if entry already exists. Uses jq if available, else sed.
MCP_JSON=".mcp.json"
add_mcp_entry() {
  local name="$1" config="$2"
  # Create minimal .mcp.json if missing
  if [ ! -f "$MCP_JSON" ]; then
    printf '{\n  "mcpServers": {}\n}\n' > "$MCP_JSON"
  fi
  # Skip if entry already exists
  if command -v jq &>/dev/null; then
    if jq -e ".mcpServers.\"$name\"" "$MCP_JSON" &>/dev/null; then
      return 0
    fi
    # Add entry via jq
    local tmp
    tmp=$(jq --arg n "$name" --argjson c "$config" '.mcpServers[$n] = $c' "$MCP_JSON") || return 1
    printf '%s\n' "$tmp" > "$MCP_JSON"
  else
    # Fallback: sed-based insert before closing brace (no jq available)
    if grep -q "\"$name\"" "$MCP_JSON" 2>/dev/null; then
      return 0
    fi
    # Detect if mcpServers is empty ({}) or has existing entries
    if grep -q '"mcpServers": {}' "$MCP_JSON" 2>/dev/null; then
      # Empty — replace {} with the entry
      local entry
      entry=$(printf '{\n    "%s": %s\n  }' "$name" "$config")
      sed -i.bak "s|\"mcpServers\": {}|\"mcpServers\": $entry|" "$MCP_JSON" && rm -f "$MCP_JSON.bak"
    else
      # Has entries — insert before the last closing brace of mcpServers
      local entry
      entry=$(printf ',\n    "%s": %s' "$name" "$config")
      # Insert before the line containing only "  }" (closing mcpServers)
      sed -i.bak "/^  }/i\\
$entry" "$MCP_JSON" && rm -f "$MCP_JSON.bak"
    fi
  fi
}


# ═════════════════════════════════════════════════════════════════
# STRATEGY GATE — Top-level plugin choice (interactive only)
# ═════════════════════════════════════════════════════════════════

# Plugin tier catalog (used by strategy routing)
PLUGIN_TIER_RECOMMENDED="SKIP_CLAUDE_MEM SKIP_CBM"
PLUGIN_TIER_OPTIONAL="SKIP_RTK SKIP_PLAYWRIGHT SKIP_CODEBURN SKIP_CAVEMAN SKIP_SERENA"
PLUGIN_TIER_HEAVY="SKIP_GRAPHIFY SKIP_COCOINDEX SKIP_CRG"

apply_strategy() {
  local strategy="$1"
  case "$strategy" in
    none)
      # Skip ALL plugins
      for v in $PLUGIN_TIER_RECOMMENDED $PLUGIN_TIER_OPTIONAL $PLUGIN_TIER_HEAVY; do
        eval "$v=1"
      done
      echo "  ⏭️  All plugins skipped. Each section below shows how to install later."
      ;;
    full)
      # Install ALL (respect --lite and env var overrides only)
      echo "  ✅ Installing all plugins (env var overrides and --lite still apply)"
      ;;
    recommended)
      # Install RECOMMENDED only, skip OPTIONAL and HEAVY
      for v in $PLUGIN_TIER_OPTIONAL $PLUGIN_TIER_HEAVY; do
        eval "$v=1"
      done
      echo "  ✅ Installing recommended plugins only (claude-mem, codebase-memory-mcp)"
      echo "  ⏭️  rtk requires cargo compile (3-7 min) — install later: cargo install rtk"
      echo "  ⏭️  Optional/heavy plugins skipped — install later with the commands shown below"
      ;;
    personalize)
      echo "  🎯 Cherry-pick mode — you'll choose each plugin individually"
      ;;
  esac
}

if [ -n "$INTERACTIVE_MODE" ] && [ -z "$PLUGIN_STRATEGY" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🔌 Plugin Setup"
  echo ""
  echo "  Brain Bootstrap includes 10 optional plugins that extend"
  echo "  Claude Code with memory, code graphs, token savings, and more."
  echo ""
  echo "  How would you like to proceed?"
  echo ""
  echo "    [0] NO          — Skip all plugins (install any later, instructions provided)"
  echo "    [1] FULL        — Install everything (~10-20 min, ~2 GB disk)"
  echo "    [2] RECOMMENDED — Install core 2 only: claude-mem, codebase-memory-mcp (~30s)"
  echo "    [3] PERSONALIZE — Cherry-pick: review each plugin and decide"
  echo ""
  if [ -n "$LITE_MODE" ]; then
    echo "  ⚡ Lite mode active: graphify, cocoindex, code-review-graph pre-skipped"
    echo ""
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  Your choice [0/1/2/3] (default: 2 — recommended): "
  if ! safe_read STRATEGY_CHOICE 10 ""; then
    echo ""
    echo "  ⏱️  No response (timeout) — using recommended strategy"
  fi
  case "$STRATEGY_CHOICE" in
    0|[Nn]*)  PLUGIN_STRATEGY="none" ;;
    1|[Ff]*)  PLUGIN_STRATEGY="full" ;;
    3|[Pp]*)  PLUGIN_STRATEGY="personalize" ;;
    *)        PLUGIN_STRATEGY="recommended" ;;  # default = recommended (Enter or 2)
  esac
  echo ""
  apply_strategy "$PLUGIN_STRATEGY"
  echo ""
elif [ -n "$PLUGIN_STRATEGY" ]; then
  # Strategy set via --strategy= CLI flag
  apply_strategy "$PLUGIN_STRATEGY"
elif [ -z "$INTERACTIVE_MODE" ] && [ -z "$PLUGIN_STRATEGY" ]; then
  # Non-interactive without explicit strategy: default to recommended (safe default)
  PLUGIN_STRATEGY="recommended"
fi

# ─── Portable helpers (sed_inplace, safe_pgrep, platform detection)
# shellcheck disable=SC1091
source "$(dirname "$0")/_platform.sh"

# ═════════════════════════════════════════════════════════════════
# SECTION 1: claude-mem (Claude Code plugin)
# ═════════════════════════════════════════════════════════════════

if [ -n "$INTERACTIVE_MODE" ]; then
  ask_plugin SKIP_CLAUDE_MEM "claude-mem" RECOMMENDED "~30 sec" \
    "LOW at rest (disabled by default) · HIGH when enabled (~48% API quota from PostToolUse hooks)" \
    "Persistent cross-session memory (SQLite + ChromaDB). Remembers what Claude learns across sessions.
  │ Disabled by default after install (quota protection — re-enable: bash claude/scripts/toggle-claude-mem.sh on)." \
    "claude plugin install claude-mem@thedotmack && claude plugin disable claude-mem@thedotmack"
fi

if [ -n "$SKIP_CLAUDE_MEM" ]; then
  echo "⏭️  claude-mem skipped (SKIP_CLAUDE_MEM set)"
  CLAUDE_MEM_STATUS="skipped (opt-out)"
elif ! command -v claude &>/dev/null; then
  echo "✅ claude-mem setup skipped (claude CLI not available — non-Claude Code environment)"
  # Still update CLAUDE.md placeholder even without plugin
  if [ -f "CLAUDE.md" ] && grep -q '{{INSTALLED_PLUGINS}}' "CLAUDE.md" 2>/dev/null; then
    sed_inplace $'s|<!-- {{INSTALLED_PLUGINS}}.*-->|- **claude-mem** — install manually: `claude plugin install claude-mem@thedotmack` then disable for quota protection|' "CLAUDE.md"
  fi
  CLAUDE_MEM_STATUS="skipped (no claude CLI)"
else
  echo "🔌 Plugin Setup — claude-mem..."

  # 1. Check if installed; if not, try synchronous install once
  # run_with_timeout guards against TUI hangs in non-TTY environments (Claude Code, VS Code, CI)
  run_with_timeout 15 claude plugin list > claude/tasks/.plugin-list.log 2>&1 || true
  if ! sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r//g' claude/tasks/.plugin-list.log 2>/dev/null | grep -qi 'claude-mem'; then
    echo "  ⏳ Installing claude-mem..."
    run_with_timeout 60 claude plugin install claude-mem@thedotmack > claude/tasks/.plugin-install.log 2>&1 || true
  fi

  # 4. Disable claude-mem (quota protection — PostToolUse(*) uses ~48% API quota)
  run_with_timeout 15 claude plugin disable claude-mem@thedotmack > claude/tasks/.plugin-disable.log 2>&1 || true

  # 5. Kill any running worker process
  # [c] = anti-self-match pattern (prevents pgrep from matching its own command line)
  WORKER_PIDS=$(safe_pgrep '[c]laude-mem.*worker-service')
  if [ -n "$WORKER_PIDS" ]; then kill "$WORKER_PIDS" 2>/dev/null || true; fi

  # 6. Verify final state
  run_with_timeout 15 claude plugin list > claude/tasks/.plugin-list.log 2>&1 || true
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
if [ -n "$INTERACTIVE_MODE" ] && [ -z "$LITE_MODE" ]; then
  ask_plugin SKIP_GRAPHIFY "graphify" HEAVY "~3-5 min (first run)" \
    "ZERO runtime (offline graph build) · ~5 min first build, then incremental (~10s) on commit" \
    "Knowledge graph over your codebase — reveals god nodes, community structure, and hidden connections.
  │ Installs a /graphify slash command. Git hooks auto-rebuild the graph on every commit." \
    "pip install graphifyy && graphify install && graphify hook install"
fi

if [ -n "$SKIP_GRAPHIFY" ]; then
  echo "⏭️  graphify skipped (SKIP_GRAPHIFY set)"
  GRAPHIFY_STATUS="skipped (opt-out)"
else
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
fi  # end SKIP_GRAPHIFY

# ═════════════════════════════════════════════════════════════════
# SECTION 3: rtk (token optimizer — Rust binary, installed via cargo)
# ═════════════════════════════════════════════════════════════════

echo ""
if [ -n "$INTERACTIVE_MODE" ]; then
  ask_plugin SKIP_RTK "rtk" OPTIONAL "~3-7 min (compiles from source, needs cargo — may fail on Rust <1.85 edition 2024)" \
    "HIGH savings (60-90% fewer output tokens) · ZERO runtime cost (rewrites tool output before Claude sees it)" \
    "Token optimizer — transparently rewrites Claude's bash commands for 60-90% output token savings.
  │ No-op if absent. Requires Rust/cargo. Hook is already registered in .claude/settings.json." \
    "cargo install rtk"
fi

if [ -n "$SKIP_RTK" ]; then
  echo "⏭️  rtk skipped (SKIP_RTK set)"
  RTK_STATUS="skipped (opt-out)"
else
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
  # cargo found — install rtk (compiles from source, typically 3-7 min)
  echo "  ⏳ Installing rtk via cargo (compiling from source — typically 3-7 min, please wait)..."
  if run_with_timeout 600 cargo install rtk 2>&1 | tail -8; then
    RTK_VERSION=$(rtk --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
    echo "  ✅ rtk $RTK_VERSION installed"
    echo "  ✅ rtk-rewrite hook active (.claude/settings.json already wired)"
    RTK_STATUS="$RTK_VERSION installed · hook active"
  else
    RTK_EXIT=$?
    if [ "$RTK_EXIT" -eq 124 ]; then
      echo "  ⚠️  cargo install rtk timed out (>10 min) — install manually: cargo install rtk"
      echo "     The hook in .claude/settings.json is ready — rtk activates once installed."
      RTK_STATUS="install timed out — manual: cargo install rtk"
    else
      echo "  ⚠️  cargo install rtk failed — install manually: cargo install rtk"
      RTK_STATUS="install failed — manual: cargo install rtk"
    fi
  fi

else
  # No cargo — inform user, hook remains a no-op until they install
  echo "  ℹ️  rtk not installed (cargo not found)"
  echo "     Hook is registered and ready — install Rust + rtk to activate:"
  echo "     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  echo "     cargo install rtk"
  RTK_STATUS="not installed (hook registered, no-op — needs cargo)"
fi
fi  # end SKIP_RTK

echo "  ✅ rtk: ${RTK_STATUS:-not installed}"

# ═════════════════════════════════════════════════════════════════
# SECTION 4: codebase-memory-mcp (C binary — zero runtime deps)
# ═════════════════════════════════════════════════════════════════

echo ""
if [ -n "$INTERACTIVE_MODE" ]; then
  ask_plugin SKIP_CBM "codebase-memory-mcp" RECOMMENDED "~10 sec" \
    "LOW (14 MCP tools, structured results — 120x fewer tokens than file exploration)" \
    "Live structural graph of your codebase — 14 MCP tools for call tracing, blast radius detection,
  │ dead code hunting, and architecture queries. Uses 120x fewer tokens than file exploration." \
    "curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash -s -- --skip-config"
fi

if [ -n "$SKIP_CBM" ]; then
  echo "⏭️  codebase-memory-mcp skipped (SKIP_CBM set)"
  CBM_STATUS="skipped (opt-out)"
else

echo "🔌 Plugin Setup — codebase-memory-mcp (structural graph)..."

if command -v codebase-memory-mcp &>/dev/null; then
  CBM_VERSION=$(codebase-memory-mcp --version 2>/dev/null | head -1 | awk '{print $NF}' || echo "unknown")
  echo "  ✅ codebase-memory-mcp $CBM_VERSION already installed"
  add_mcp_entry "codebase-memory-mcp" '{"command":"codebase-memory-mcp","args":[]}'
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
    add_mcp_entry "codebase-memory-mcp" '{"command":"codebase-memory-mcp","args":[]}'
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

fi  # end SKIP_CBM

# ═════════════════════════════════════════════════════════════════
# SECTION 5: cocoindex-code (semantic vector search — Python 3.11+)
# ═════════════════════════════════════════════════════════════════

echo ""
if [ -n "$INTERACTIVE_MODE" ] && [ -z "$LITE_MODE" ]; then
  ask_plugin SKIP_COCOINDEX "cocoindex-code" HEAVY "~5-15 min (~1 GB — sentence-transformers + torch)" \
    "ZERO API cost (local embeddings) · ~30s index build · LOW per-query token cost" \
    "Semantic vector search — find code by meaning, not exact names. No API key needed (local embeddings).
  │ Run 'ccc index' to build the initial index, then search with mcp__cocoindex-code__search." \
    "pip install 'cocoindex-code[full]'"
fi

if [ -n "$SKIP_COCOINDEX" ]; then
  echo "⏭️  cocoindex-code skipped (SKIP_COCOINDEX set)"
  COCO_STATUS="skipped (opt-out)"
else
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
  add_mcp_entry "cocoindex-code" '{"type":"stdio","command":"ccc","args":["mcp"]}'
  COCO_STATUS="$CCC_VERSION installed"

else
  echo "  ⏳ Installing cocoindex-code[full] (local embeddings — ~1 GB first install)..."
  # [full] = sentence-transformers + torch for local embedding, no API key needed
  if "$COCO_PYTHON" -m pip install 'cocoindex-code[full]' 2>/dev/null \
     || "$COCO_PYTHON" -m pip install 'cocoindex-code[full]' --break-system-packages 2>/dev/null; then
    CCC_VERSION=$(ccc --version 2>/dev/null | head -1 || echo "unknown")
    echo "  ✅ cocoindex-code $CCC_VERSION installed"
    add_mcp_entry "cocoindex-code" '{"type":"stdio","command":"ccc","args":["mcp"]}'
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
fi  # end SKIP_COCOINDEX

echo "  ✅ cocoindex-code: ${COCO_STATUS:-skipped}"

# ═════════════════════════════════════════════════════════════════
# SECTION 6: code-review-graph (change risk analysis — Python 3.10+)
# ═════════════════════════════════════════════════════════════════

echo ""
if [ -n "$INTERACTIVE_MODE" ] && [ -z "$LITE_MODE" ]; then
  ask_plugin SKIP_CRG "code-review-graph" HEAVY "~3-5 min" \
    "LOW per-query (29 MCP tools, structured) · ~2s incremental re-index on commit (git hook)" \
    "Change risk analysis — risk score 0-100, blast radius, breaking changes before any PR.
  │ 29 MCP tools. Git post-commit hook for incremental re-index. Pre-PR safety gate." \
    "pip install 'code-review-graph[communities]'"
fi

if [ -n "$SKIP_CRG" ]; then
  echo "⏭️  code-review-graph skipped (SKIP_CRG set)"
  CRG_STATUS="skipped (opt-out)"
else
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
  add_mcp_entry "code-review-graph" '{"type":"stdio","command":"uvx","args":["code-review-graph","serve"]}'
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
    add_mcp_entry "code-review-graph" '{"type":"stdio","command":"uvx","args":["code-review-graph","serve"]}'
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
fi  # end SKIP_CRG

echo "  ✅ code-review-graph: ${CRG_STATUS:-skipped}"

# ═════════════════════════════════════════════════════════════════
# SECTION 7: playwright-mcp (browser automation — Node.js/npx)
# ═════════════════════════════════════════════════════════════════

echo ""
if [ -n "$INTERACTIVE_MODE" ]; then
  ask_plugin SKIP_PLAYWRIGHT "playwright-mcp" OPTIONAL "~2-3 min (~300 MB Chromium download)" \
    "LOW-MEDIUM (structured accessibility snapshots, not pixels — no vision model needed)" \
    "Browser automation MCP — navigate, click, fill, snapshot web pages via accessibility tree.
  │ No vision model needed. Use for: UI testing, doc scraping, OAuth flows, web research.
  │ This step installs Chromium browsers and registers the MCP server." \
    "npx playwright install chromium"
fi

if [ -n "$SKIP_PLAYWRIGHT" ]; then
  echo "⏭️  playwright-mcp skipped (SKIP_PLAYWRIGHT set)"
  PLAYWRIGHT_STATUS="skipped (opt-out)"
else
echo "🔌 Plugin Setup — playwright-mcp (browser automation)..."

NODE_VERSION=$(node --version 2>/dev/null | sed 's/v//' || echo "0")
NODE_MAJOR="${NODE_VERSION%%.*}"

if ! command -v npx &>/dev/null || [ "${NODE_MAJOR:-0}" -lt 18 ]; then
  echo "  ⚠️  playwright-mcp skipped — Node.js 18+ required (found: ${NODE_VERSION:-none})"
  echo "     Upgrade: brew install node  OR  nvm install 18"
  echo "     Then run: npx playwright install chromium"
  PLAYWRIGHT_STATUS="skipped (Node.js ${NODE_VERSION:-not found}, needs 18+)"
else
  # Check if Chromium is already installed by playwright
  PLAYWRIGHT_CACHE=""
  case "$(uname -s)" in
    Darwin) PLAYWRIGHT_CACHE="$HOME/Library/Caches/ms-playwright" ;;
    Linux)  PLAYWRIGHT_CACHE="$HOME/.cache/ms-playwright" ;;
    *)      PLAYWRIGHT_CACHE="$HOME/.cache/ms-playwright" ;;
  esac

  if ls "$PLAYWRIGHT_CACHE"/chromium* &>/dev/null 2>&1; then
    echo "  ✅ Playwright Chromium already installed ($PLAYWRIGHT_CACHE)"
    add_mcp_entry "playwright" '{"type":"stdio","command":"npx","args":["@playwright/mcp@latest"]}'
    echo "  ✅ MCP server ready (command: npx @playwright/mcp@latest)"
    PLAYWRIGHT_STATUS="chromium installed · MCP registered"
  else
    echo "  ⏳ Installing Playwright Chromium (~300 MB download)..."
    if NO_COLOR=1 npx playwright install chromium 2>&1 | tail -4; then
      echo "  ✅ Playwright Chromium installed"
      add_mcp_entry "playwright" '{"type":"stdio","command":"npx","args":["@playwright/mcp@latest"]}'
      echo "  ✅ MCP server registered"
      PLAYWRIGHT_STATUS="chromium installed · MCP registered"
    else
      echo "  ⚠️  Chromium install failed — run manually: npx playwright install chromium"
      # Register MCP anyway — npx will work once browsers are installed
      add_mcp_entry "playwright" '{"type":"stdio","command":"npx","args":["@playwright/mcp@latest"]}'
      echo "  ℹ️  MCP server registered — will work once browsers are installed"
      PLAYWRIGHT_STATUS="MCP registered · browsers not installed (run: npx playwright install chromium)"
    fi
  fi
fi
fi  # end SKIP_PLAYWRIGHT

echo "  ✅ playwright-mcp: ${PLAYWRIGHT_STATUS:-skipped}"

# ═════════════════════════════════════════════════════════════════
# SECTION 8: codeburn (token observability — Node.js/npm)
# ═════════════════════════════════════════════════════════════════

echo ""
if [ -n "$INTERACTIVE_MODE" ]; then
  ask_plugin SKIP_CODEBURN "codeburn" OPTIONAL "~10 sec" \
    "ZERO (reads ~/.claude/projects/ locally — no API calls, no hooks, no runtime overhead)" \
    "Token cost observability dashboard — see WHERE tokens go: by task type (13 categories), model,
  │ one-shot rate, and USD cost. Complements rtk: rtk reduces tokens; codeburn shows which tasks to optimize." \
    "npm install -g codeburn"
fi

if [ -n "$SKIP_CODEBURN" ]; then
  echo "⏭️  codeburn skipped (SKIP_CODEBURN set)"
  CODEBURN_STATUS="skipped (opt-out)"
else
echo "🔌 Plugin Setup — codeburn (token observability)..."

NODE_VERSION_CB=$(node --version 2>/dev/null | sed 's/v//' || echo "0")
NODE_MAJOR_CB="${NODE_VERSION_CB%%.*}"

if ! command -v npm &>/dev/null || [ "${NODE_MAJOR_CB:-0}" -lt 18 ]; then
  echo "  ⚠️  codeburn skipped — Node.js 18+ required (found: ${NODE_VERSION_CB:-none})"
  echo "     Upgrade: brew install node  OR  nvm install 18"
  echo "     Then run: npm install -g codeburn"
  CODEBURN_STATUS="skipped (Node.js ${NODE_VERSION_CB:-not found}, needs 18+)"
elif command -v codeburn &>/dev/null; then
  CB_VERSION=$(codeburn --version 2>/dev/null | head -1 | awk '{print $NF}' || echo "unknown")
  echo "  ✅ codeburn $CB_VERSION already installed"
  CODEBURN_STATUS="$CB_VERSION installed"
else
  echo "  ⏳ Installing codeburn..."
  if npm install -g codeburn 2>&1 | tail -3; then
    CB_VERSION=$(codeburn --version 2>/dev/null | head -1 | awk '{print $NF}' || echo "unknown")
    echo "  ✅ codeburn $CB_VERSION installed — run: codeburn"
    echo "  ℹ️  Try: codeburn today  OR  codeburn report -p 30days"
    CODEBURN_STATUS="$CB_VERSION installed"
  else
    echo "  ⚠️  npm install failed — try manually: npm install -g codeburn"
    echo "     Or one-shot: npx codeburn"
    CODEBURN_STATUS="install failed — manual: npm install -g codeburn"
  fi
fi
fi  # end SKIP_CODEBURN

echo "  ✅ codeburn: ${CODEBURN_STATUS:-skipped}"

# ═════════════════════════════════════════════════════════════════
# SECTION 9: caveman (response-text compression — hooks only)
# ═════════════════════════════════════════════════════════════════

echo ""
if [ -n "$INTERACTIVE_MODE" ]; then
  ask_plugin SKIP_CAVEMAN "caveman" OPTIONAL "~10 sec" \
    "HIGH savings (65-87% fewer response tokens) · installs hooks in ~/.claude/settings.json (user-level)" \
    "Response-text compression — makes Claude reply in terse caveman speak (65-87% fewer response tokens).
  │ Covers token surface #2 (response text), complementing rtk (#1 tool outputs).
  │ Adds: /caveman, /caveman-commit, /caveman-review, /caveman:compress <file>." \
    "bash <(curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/install.sh)"
fi

if [ -n "$SKIP_CAVEMAN" ]; then
  echo "⏭️  caveman skipped (SKIP_CAVEMAN set)"
  CAVEMAN_STATUS="skipped (opt-out)"
else
echo "🔌 Plugin Setup — caveman (response-text compression)..."

# caveman install.sh requires node (any version) for JSON merge
if ! command -v node &>/dev/null; then
  echo "  ⚠️  caveman skipped — node not found (required for settings.json merge)"
  echo "     Install Node.js, then run:"
  echo "     bash <(curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/install.sh)"
  CAVEMAN_STATUS="skipped (node not found)"
elif ! command -v curl &>/dev/null; then
  echo "  ⚠️  caveman skipped — curl not found"
  echo "     Install curl, then run:"
  echo "     bash <(curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/install.sh)"
  CAVEMAN_STATUS="skipped (curl not found)"
else
  # Check if already installed (idempotent — install.sh reports "already installed" and exits 0)
  CLAUDE_USER_SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  ALREADY_CAVEMAN=0
  if [ -f "$CLAUDE_USER_SETTINGS" ]; then
    if grep -q 'caveman-activate' "$CLAUDE_USER_SETTINGS" 2>/dev/null; then
      ALREADY_CAVEMAN=1
    fi
  fi

  if [ "$ALREADY_CAVEMAN" -eq 1 ]; then
    echo "  ✅ caveman hooks already installed in ~/.claude/settings.json"
    CAVEMAN_STATUS="installed (hooks active)"
  else
    echo "  ⏳ Installing caveman hooks..."
    if bash <(curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/install.sh) 2>&1; then
      echo "  ✅ caveman installed — restart Claude Code to activate"
      echo "  ℹ️  Commands: /caveman, /caveman-commit, /caveman-review, /caveman:compress <file>"
      echo "  ℹ️  Token surface map: rtk=tool outputs, caveman=response text, caveman:compress=input context"
      CAVEMAN_STATUS="installed (restart required)"
    else
      echo "  ⚠️  caveman install failed — install manually:"
      echo "     bash <(curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/install.sh)"
      CAVEMAN_STATUS="install failed — manual required"
    fi
  fi
fi
fi  # end SKIP_CAVEMAN

echo "  ✅ caveman: ${CAVEMAN_STATUS:-skipped}"

# ═════════════════════════════════════════════════════════════════
# SECTION 10: serena (LSP refactoring MCP server — uvx / Python 3.11+)
# ═════════════════════════════════════════════════════════════════

echo ""
if [ -n "$INTERACTIVE_MODE" ]; then
  ask_plugin SKIP_SERENA "serena" OPTIONAL "~30 sec (uvx auto-downloads on first use)" \
    "LOW (MCP tools return structured symbol data — no large file reads needed)" \
    "LSP-backed symbol refactoring — rename/move/inline across the entire codebase atomically.
  │ Type-aware, 100% recall. Rename a symbol in 50 files in one call.
  │ Fills gap: cocoindex/codebase-memory find code; serena transforms it." \
    "uvx serena-agent --project . (setup-plugins registers the MCP server automatically)"
fi

if [ -n "$SKIP_SERENA" ]; then
  echo "⏭️  serena skipped (SKIP_SERENA set)"
  SERENA_STATUS="skipped (opt-out)"
else
echo "🔌 Plugin Setup — serena (LSP refactoring MCP)..."

# serena runs via uvx (isolated environment — avoids pip dependency conflicts)
# uvx is part of the uv toolchain; check for it or fall back to pipx/pip
SERENA_RUNNER=""
if command -v uvx &>/dev/null; then
  SERENA_RUNNER="uvx"
elif command -v uv &>/dev/null; then
  SERENA_RUNNER="uv tool run"
fi

if [ -z "$SERENA_RUNNER" ]; then
  echo "  ⚠️  serena skipped — uvx not found (install uv: curl -LsSf https://astral.sh/uv/install.sh | sh)"
  echo "     After installing uv, serena MCP entry in .mcp.json activates automatically"
  SERENA_STATUS="skipped (uvx not found — install uv)"
else
  # Detect Python 3.11+ (serena requires it, same as cocoindex-code)
  SERENA_PYTHON=""
  for py_cmd in python3 python; do
    if command -v "$py_cmd" &>/dev/null; then
      PY_VER=$("$py_cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
      PY_MAJOR="${PY_VER%%.*}"
      PY_MINOR="${PY_VER##*.}"
      if [ "${PY_MAJOR:-0}" -ge 3 ] && [ "${PY_MINOR:-0}" -ge 11 ]; then
        SERENA_PYTHON="$py_cmd"
        break
      fi
    fi
  done

  if [ -z "$SERENA_PYTHON" ]; then
    echo "  ⚠️  serena skipped — Python 3.11+ not found"
    echo "     Install: brew install python@3.11"
    SERENA_STATUS="skipped (Python 3.11+ not found)"
  else
    # Verify serena-agent is available (uvx downloads on first use — this is a dry-run check)
    add_mcp_entry "serena" '{"type":"stdio","command":"uvx","args":["serena-agent","--project","."]}'
    echo "  ✅ serena MCP entry registered (command: uvx serena-agent)"
    echo "  ℹ️  Language servers auto-install on first use (~30s for pyright/typescript-language-server)"
    echo "  ℹ️  Project config: .serena/project.yml (edit to add/remove languages)"
    echo "  ℹ️  Key tools: find_symbol, find_references, rename_symbol, move_symbol, inline_symbol"
    SERENA_STATUS="MCP registered (uvx serena-agent — lazy-downloads on first use)"
  fi
fi
fi  # end SKIP_SERENA

echo "  ✅ serena: ${SERENA_STATUS:-skipped}"

# ═════════════════════════════════════════════════════════════════
# SUMMARY (compact — avoids Claude Code UI collapse at ≥4 lines)
# ═════════════════════════════════════════════════════════════════

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔌 Plugin Setup Complete — Strategy: ${PLUGIN_STRATEGY:-auto}"
echo ""
echo "  claude-mem   : ${CLAUDE_MEM_STATUS:-skipped}"
echo "  graphify     : ${GRAPHIFY_STATUS:-skipped}"
echo "  rtk          : ${RTK_STATUS:-skipped}"
echo "  cbm          : ${CBM_STATUS:-skipped}"
echo "  cocoindex    : ${COCO_STATUS:-skipped}"
echo "  crg          : ${CRG_STATUS:-skipped}"
echo "  playwright   : ${PLAYWRIGHT_STATUS:-skipped}"
echo "  codeburn     : ${CODEBURN_STATUS:-skipped}"
echo "  caveman      : ${CAVEMAN_STATUS:-skipped}"
echo "  serena       : ${SERENA_STATUS:-skipped}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "claude/tasks/.bootstrap-plan.txt" ]; then echo "P4 $(date +%H:%M:%S)" >> "claude/tasks/.bootstrap-progress.txt" 2>/dev/null; fi

