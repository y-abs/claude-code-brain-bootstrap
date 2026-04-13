#!/usr/bin/env bash
# _platform.sh — Portable shell helpers for Brain Bootstrap
# Sourced by scripts that need platform-specific behavior. Never executed directly.
# Usage: source "$(dirname "$0")/_platform.sh"

# ─── Platform detection ───────────────────────────────────────────
case "$(uname -s)" in
  Darwin*)              BRAIN_PLATFORM="macos" ;;
  MINGW*|MSYS*|CYGWIN*) BRAIN_PLATFORM="windows" ;;
  *)                    BRAIN_PLATFORM="linux" ;;
esac

# ─── Portable sed -i ──────────────────────────────────────────────
if [ "$BRAIN_PLATFORM" = "macos" ]; then
  sed_inplace() { sed -i '' "$@"; }
else
  sed_inplace() { sed -i "$@"; }
fi

# ─── Portable pgrep (falls back to ps+awk on Git Bash/Windows) ───
safe_pgrep() {
  local pattern="$1"
  if command -v pgrep &>/dev/null; then
    pgrep -f "$pattern" 2>/dev/null || true
  else
    ps aux 2>/dev/null | awk -v pat="$pattern" '$0 ~ pat && !/awk/ {print $2}' || true
  fi
}

# ─── Require a tool or print actionable install instructions ──────
require_tool() {
  local tool="$1" purpose="${2:-required}"
  if command -v "$tool" &>/dev/null; then return 0; fi
  echo "❌ '$tool' is required ($purpose) but not found." >&2
  case "$BRAIN_PLATFORM" in
    macos)   echo "   Install: brew install $tool" >&2 ;;
    windows) echo "   Install: scoop install $tool  OR  choco install $tool" >&2 ;;
    linux)   echo "   Install: sudo apt install $tool  OR  sudo dnf install $tool" >&2 ;;
  esac
  return 1
}

# ─── Unicode/emoji support detection ──────────────────────────────
supports_unicode() {
  case "${LANG:-}${LC_ALL:-}" in
    *UTF-8*|*utf-8*|*utf8*) return 0 ;;
  esac
  # Windows Terminal and modern macOS Terminal support Unicode even without LANG
  [ "$BRAIN_PLATFORM" = "macos" ] && return 0
  [ -n "${WT_SESSION:-}" ] && return 0  # Windows Terminal
  return 1
}

# ─── Emoji symbols with graceful fallback ─────────────────────────
# shellcheck disable=SC2034  # exported/consumed by scripts that source this file
if supports_unicode; then
  PASS_SYM="✅"; FAIL_SYM="❌"; WARN_SYM="⚠️"
else
  PASS_SYM="[OK]"; FAIL_SYM="[FAIL]"; WARN_SYM="[WARN]"
fi

# ─── Windows path normalization ───────────────────────────────────
if [ "$BRAIN_PLATFORM" = "windows" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR//\\//}"
fi
