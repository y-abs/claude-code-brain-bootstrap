---
description: Verify Claude Code configuration health — hooks, rules, settings, secrets scan
agent: "agent"
tools:
  - run_in_terminal
  - read_file
  - file_search
  - grep_search
---


# Health Check — Configuration Validation

Verify that the Claude Code configuration is healthy and complete.

## Steps

1. **CLAUDE.md** — verify it exists, is not empty, and contains key sections (Build, Stack, Architecture, Conventions)
2. **settings.json** — verify `.claude/settings.json` exists and is valid JSON (`jq . .claude/settings.json`)
3. **Hooks** — verify all `.claude/hooks/*.sh` files exist and are executable (`test -x`)
4. **Rules frontmatter** — verify all `.claude/rules/*.md` files have `globs:` or `paths:` in frontmatter (except `_template*` and `domain/_template*`)
5. **Error log** — verify `claude/tasks/CLAUDE_ERRORS.md` exists (warn if missing)
6. **Secrets scan** — grep for common secret patterns in tracked files:
   ```bash
   git ls-files | xargs grep -l 'BEGIN.*PRIVATE KEY\|password\s*=\s*["\x27][^"\x27]\{8,\}' 2>/dev/null | head -10
   ```
   Report any matches as ⚠️ warnings
7. **MCP server binaries** — verify each server declared in `.mcp.json` has its binary in PATH:
   ```bash
   jq -r '.mcpServers | to_entries[] | "\(.key):\(.value.command)"' .mcp.json 2>/dev/null || echo "NO_MCP_JSON"
   ```
   For each `key:command` pair, run `command -v <command>` and report ✅/⚠️.
   Known binary mapping for this project:
   - `codebase-memory-mcp` → binary `codebase-memory-mcp`
   - `cocoindex-code` → binary `ccc`
   - `code-review-graph` → binary `uvx` (via uv/pipx runner)
   Any missing binary means that MCP server is silently unavailable to Claude.
8. **Report** — summarize: ✅ healthy / ⚠️ warnings / ❌ problems with actionable fixes
