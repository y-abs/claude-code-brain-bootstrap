---
description: Unified project status dashboard — CLAUDE.md budget, placeholders, plugins, hooks, lessons size
agent: "agent"
tools:
  - run_in_terminal
  - file_search
  - grep_search
  - read_file
---


# Project Status Dashboard

Give me a one-glance status report of the Claude Code setup for this repo.

Run these checks in order and report each as ✅ / ⚠️ / ❌:

## 1. CLAUDE.md line budget
```bash
wc -l < CLAUDE.md 2>/dev/null || echo "MISSING"
```
- ✅ ≤ 200 lines · ⚠️ 201–240 · ❌ > 240 or missing

## 2. Unfilled placeholders
```bash
grep -rEc '\{\{[A-Z_]+\}\}' CLAUDE.md claude/ .claude/ 2>/dev/null | awk -F: '{s+=$2} END {print s+0}'
```
- ✅ 0 (end-user repo) · ⚠️ > 0 (bootstrap still has unfilled slots)

## 3. Lessons file size
```bash
wc -l < claude/tasks/lessons.md 2>/dev/null || echo "0"
```
- ✅ ≤ 400 lines · ⚠️ 401–500 · ❌ > 500 (archive to `claude/tasks/lessons-archive-YYYY.md`)

## 4. Hooks executability
```bash
for h in .claude/hooks/*.sh; do test -x "$h" || echo "NOT_EXEC: $h"; done
echo "HOOKS_DONE"
```
- ✅ all executable · ❌ any NOT_EXEC line

## 5. jq availability (3 safety hooks depend on it)
```bash
command -v jq &>/dev/null && echo "PRESENT" || echo "MISSING"
```
- ✅ present · ⚠️ missing — `brew install jq`

## 6. Plugin states
Check each binary/tool and report installed/missing:
```bash
echo "rtk:$(command -v rtk &>/dev/null && echo installed || echo missing)"
echo "codebase-memory-mcp:$(command -v codebase-memory-mcp &>/dev/null && echo installed || echo missing)"
echo "ccc:$(command -v ccc &>/dev/null && echo installed || echo missing)"
echo "code-review-graph:$(command -v code-review-graph &>/dev/null && echo installed || echo missing)"
echo "graphify:$(command -v graphify &>/dev/null && echo installed || echo missing)"
```
- ✅ installed · ⚠️ missing (run `bash claude/scripts/setup-plugins.sh` to install)

Also check claude-mem if the `claude` CLI is available:
```bash
command -v claude &>/dev/null && (claude plugin list 2>/dev/null | grep -qi 'claude-mem' && echo "claude-mem:installed" || echo "claude-mem:missing") || echo "claude-mem:no-cli"
```

## 7. Knowledge graph
```bash
test -f graphify-out/GRAPH_REPORT.md && echo "PRESENT" || echo "MISSING"
```
- ✅ present · ⚠️ missing — run `/graphify .` to build (first run ~5 min)

## 8. MCP servers reachability
Parse `.mcp.json` and verify each declared binary exists:
```bash
jq -r '.mcpServers | to_entries[] | "\(.key):\(.value.command)"' .mcp.json 2>/dev/null || echo "NO_MCP_JSON"
```
For each entry, check `command -v <binary>`.

## Report format

Print a compact table:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Project Status — <repo>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLAUDE.md budget    ✅ 187 / 200 lines
  Placeholders        ✅ 0 unfilled
  Lessons file        ✅ 312 / 500 lines
  Hooks               ✅ 15/15 executable
  jq                  ✅ present
  rtk                 ✅ installed
  codebase-memory-mcp ✅ installed
  cocoindex (ccc)     ⚠️ missing — run setup-plugins.sh
  code-review-graph   ✅ installed
  graphify            ✅ installed
  claude-mem          ✅ installed (disabled — quota protection)
  Knowledge graph     ⚠️ missing — run /graphify .
  MCP servers         ✅ 4/4 reachable
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Overall: ✅ healthy (1 warning)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

After the table, list any ⚠️/❌ items with one-line fix instructions.
