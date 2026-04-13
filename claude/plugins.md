# Claude Code Plugins — Configuration & Reference

> **When to read:** Any task involving plugins, claude-mem, hook coexistence, API quota, persistent memory, or the obsidian-mind knowledge vault.

## Overview

This configuration ships with **one Claude Code plugin** installed and configured by the bootstrap:

| Plugin | Purpose | Default State | Token Impact |
|--------|---------|:------------:|:------------:|
| **claude-mem** | Automatic machine memory — captures every tool interaction across sessions | ⚠️ **Disabled** (quota protection) | ~48% of API quota when enabled |

Claude Code plugins are **global extensions** installed at `~/.claude/plugins/`. They add lifecycle hooks, skills, MCP tools, and commands that fire **alongside** your project-level configuration — never replacing it.

**Key principle:** Plugin hooks and project hooks are **independent systems** — registered via separate mechanisms (`plugin/hooks/hooks.json` vs `.claude/settings.json`), fired in parallel on the same lifecycle events, addressing different concerns with **zero conflicts**.

## claude-mem — Persistent Cross-Session Memory

**Purpose:** Automatic machine memory — captures observations from every tool use, compressed and stored in SQLite + ChromaDB. Searchable across sessions. Think of it as a **system event log** that remembers what happened across all your sessions.

**Default state:** ⚠️ **Disabled** — the bootstrap disables claude-mem after install to protect your API quota. Enable it when you want cross-session recall.

**Toggle on/off:**
```bash
bash claude/scripts/toggle-claude-mem.sh on       # Enable (activates next session)
bash claude/scripts/toggle-claude-mem.sh off      # Disable + kill worker — saves quota
bash claude/scripts/toggle-claude-mem.sh status   # Check current state
```

**What it provides:**
- **Persistent memory** — observations captured from every tool use, stored in SQLite (`~/.claude-mem/claude-mem.db`) + ChromaDB vectors (`~/.claude-mem/chroma/`)
- **Worker service** — Express API on `localhost:37777` with web viewer UI
- **MCP search tools** — `search`, `timeline`, `get_observations` for querying past sessions (3-layer progressive disclosure)
- **7 skills** — `mem-search`, `make-plan`, `do`, `knowledge-agent`, `smart-explore`, `timeline-report`, `version-bump`
- **6 lifecycle hooks** — `Setup`, `SessionStart`, `UserPromptSubmit`, `PostToolUse(*)`, `Stop`, `SessionEnd`

**Usage:** When enabled, memory is automatic — no manual intervention. Use `/mem-search` to query past work.

**Health check:** `curl -sf http://localhost:37777/health`

**⚠️ Token cost warning:** claude-mem's `PostToolUse(*)` hook fires after EVERY tool call, generating observation API requests. In a 45-min session, this can consume **~48% of API quota**. This is why it's disabled by default.

**Best practice:** Toggle OFF during batch work (large refactors, dependency upgrades, heavy file editing). Toggle ON during exploratory sessions where cross-session recall adds value.

**Manual install (if bootstrap couldn't auto-install):**
```bash
# Requires Bun (JS runtime) — install if missing:
curl -fsSL https://bun.sh/install | bash
# Then install via Claude Code plugin manager:
claude plugin install claude-mem@thedotmack
# Disable by default:
claude plugin disable claude-mem@thedotmack
```

## obsidian-mind — Companion Knowledge Vault (not a plugin)

**obsidian-mind is an Obsidian vault template, not a Claude Code plugin.** It cannot be installed via `claude plugin install`. Instead, you clone it as a Git repository and open it in Obsidian:

```bash
git clone https://github.com/breferrari/obsidian-mind.git ~/my-knowledge-vault
# Then open ~/my-knowledge-vault as an Obsidian vault
# And run Claude Code from inside it: cd ~/my-knowledge-vault && claude
```

**Purpose:** Curated human knowledge — structured Markdown notes (decisions, patterns, people, projects) organized as an Obsidian vault with wikilinks and backlinks. Think of it as a **curated wiki** that captures what matters, in context, with narrative.

**What it provides:**
- **Knowledge vault** — structured notes with wikilinks across `brain/`, `work/`, `org/`, `perf/`, `reference/`
- **18+ slash commands** — all prefixed `/om-*` (standup, dump, wrap-up, weekly review, etc.)
- **9 specialized subagents** — vault-librarian, cross-linker, brag-spotter, review-prep, etc.
- **SessionStart hooks** — auto-injects North Star goals, active projects, and recent context
- **Multi-agent support** — works with Claude Code, Codex CLI, and Gemini CLI

**Works standalone** — run Claude Code from inside the cloned vault directory. The vault's own `.claude/settings.json` + hooks provide all the AI-agent wiring.

## Why Both? — Complementary, Not Competing

| Question | Answered by | Example |
|----------|------------|---------|
| *"How did we fix the auth bug last Tuesday?"* | **claude-mem** — searches observations for exact tool calls and file changes | Factual reconstruction from event log |
| *"What's our authentication architecture pattern?"* | **obsidian-mind** — reads curated vault notes with context and reasoning | Conceptual understanding from knowledge graph |

| Aspect | claude-mem | obsidian-mind |
|--------|-----------|---------------|
| **What gets stored** | Every tool invocation (file reads, edits, bash commands) | Curated knowledge (decisions, patterns, meeting takeaways) |
| **Who decides** | Automatic — no human in the loop | Intentional — user or Claude explicitly writes |
| **Retrieval** | "What did I do?" (factual) | "What do I know?" (conceptual) |
| **Analogy** | Git reflog — complete forensic trail | Git commits — meaningful, narrated changes |
| **Storage** | SQLite + ChromaDB (`~/.claude-mem/`) — global | Plain Markdown vault — per-vault directory |
| **Install method** | `claude plugin install claude-mem@thedotmack` | `git clone https://github.com/breferrari/obsidian-mind.git` |

**Synergy:** claude-mem captures raw material → obsidian-mind curates it into durable knowledge. A `timeline-report` from claude-mem can feed `/om-dump` to create structured vault notes.

## Hook Coexistence — Zero Conflict Proof

Plugin hooks fire **in parallel** with project hooks on the same lifecycle event. They are architecturally independent — plugins register via `plugin/hooks/hooks.json`, project via `.claude/settings.json`. Claude Code merges them at runtime.

| Lifecycle Event | Project Hook | claude-mem | Conflict? |
|----------------|-------------|-----------|:---------:|
| `SessionStart(startup)` | session-start.sh | ✅ (memory injection) | ✅ Additive |
| `SessionStart(resume)` | session-start.sh | — | ✅ None |
| `SessionStart(clear)` | session-start.sh | ✅ | ✅ Additive |
| `SessionStart(compact)` | on-compact.sh | ✅ | ✅ Additive |
| `PreCompact` | pre-compact.sh | — | ✅ None |
| `UserPromptSubmit` | identity-reinjection.sh | ✅ (context capture) | ✅ None |
| `PreToolUse(Bash)` | terminal-safety-gate.sh | — | ✅ None |
| `PreToolUse(Write\|Edit)` | config-protection.sh | — | ✅ None |
| `PostToolUse(*)` | edit-accumulator.sh (Edit\|Write only) | ✅ (**every** tool) | ✅ Different concerns |
| `Stop` | stop-batch-format.sh, exit-nudge.sh | ✅ (session summary) | ✅ Additive |
| `SubagentStop` | subagent-stop.sh | — | ✅ None |
| `SessionEnd` | — | ✅ (drain observations) | ✅ None |

**Zero conflicts across all 12 lifecycle events.** Verified via complete hook configuration analysis.

## MCP Servers — Model Context Protocol

MCP servers extend Claude Code with external tools (database access, web search, file systems, APIs). They are configured in `.mcp.json` at the project root and are **separate from plugins** — MCP is a protocol for tool access, plugins are for lifecycle hooks.

### Tool Invocation Format

Once servers are configured in `.mcp.json`, invoke their tools using:
```
mcp__SERVER_KEY__TOOL_FUNCTION_NAME
```
- **`SERVER_KEY`**: the key in `.mcp.json` under `mcpServers` (e.g., `github`, `postgres`)
- **`TOOL_FUNCTION_NAME`**: the specific function (e.g., `query`, `create_pull_request`)

### Discovering MCP Servers

- **Smithery Registry**: Browse [registry.smithery.ai](https://registry.smithery.ai) for community MCP servers
- **Use `/mcp list`** to see currently configured servers and their available tools
- **Use `/mcp add <server>`** to add a new server from the registry

### Common MCP Servers

| Server | Use Case | Example Tool |
|--------|----------|-------------|
| `github` | PR management, issues, commits | `mcp__github__create_pull_request` |
| `postgres` | Read-only DB queries | `mcp__postgres__query` |
| `web-search` | Documentation lookup, research | `mcp__web-search__search` |
| `filesystem` | File access beyond project root | `mcp__filesystem__read_file` |

### Security Best Practices

- **NEVER** hardcode API keys in `.mcp.json` — use env var placeholders
- For database tools: prefer **read-only** access unless write is explicitly required
- Review `allowedTools` in `.claude/settings.json` — grant minimum required permissions
- Add `.mcp.json` to `.gitignore` if it contains sensitive env vars

## Adding Other Plugins

Claude Code plugins are installed globally at `~/.claude/plugins/`. They coexist with project configuration automatically:

1. Install: `claude plugin install <name>@<author>`
2. Verify no hook conflicts: `claude plugin list` — check which lifecycle events it hooks
3. If it hooks `PostToolUse(*)`, monitor API quota (like claude-mem)
4. Document in this file for team awareness

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| API quota draining fast | claude-mem `PostToolUse(*)` is enabled | `bash claude/scripts/toggle-claude-mem.sh off` |
| Worker not responding | claude-mem worker crashed | Restart Claude Code session (worker auto-starts) |
| Hooks firing twice on same event | Plugin + project both hook same event | Expected behavior — they serve different purposes |
| Plugin not activating | Installed but disabled | `claude plugin enable <name>` |
| claude-mem not capturing after restart | Worker didn't start | `bash claude/scripts/toggle-claude-mem.sh status` to check; re-enable if needed |
| obsidian-mind `/om-*` commands missing | Vault not cloned / not running from vault dir | `git clone https://github.com/breferrari/obsidian-mind.git` then `cd` into it |
