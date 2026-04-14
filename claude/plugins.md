# Claude Code Plugins — Configuration & Reference

> **When to read:** Any task involving plugins, claude-mem, hook coexistence, API quota, persistent memory, or the obsidian-mind knowledge vault.

## Overview

The bootstrap installs and configures **two tools** that give your AI persistent intelligence beyond the session boundary:

| Tool | Purpose | Default State | Token Impact |
|------|---------|:------------:|:------------:|
| **claude-mem** | 🧠 Persistent cross-session memory — captures every tool interaction (SQLite + ChromaDB) | ⚠️ **Disabled** (quota protection) | ~48% of API quota when enabled |
| **graphify** | 🗺️ Knowledge graph — turns your codebase into a queryable architecture map with **71.5× fewer tokens** per query vs reading raw files | ✅ **Installed** (graph built on demand) | Saves tokens on every file search |

Claude Code plugins are **global extensions** installed at `~/.claude/plugins/`. Graphify is a Python tool that integrates via a global skill + PreToolUse hook + git hooks. Both fire **alongside** your project-level configuration — never replacing it.

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

## graphify — Knowledge Graph Engine (strongly recommended)

**Purpose:** Turn your codebase into a queryable knowledge graph — architecture map, cross-module connections, community clusters, god nodes, and an honest audit trail. Uses tree-sitter AST (deterministic, 23 languages) + Claude extraction (semantic) + Leiden community detection (topology-based, no embeddings).

**Why it matters:** Without graphify, your AI reads raw files to understand architecture — expensive, slow, and lossy. With graphify, it reads a compact graph report: **71.5× fewer tokens per query** on a 52-file corpus. The savings compound with codebase size. On a 200-file monorepo, the difference between "grep everything" and "navigate the graph" is measured in minutes and thousands of tokens per question.

**Requires:** Python 3.10+ (installed automatically by `setup-plugins.sh` if Python is available). Without Python, graphify is skipped gracefully — everything else works normally.

**What it provides:**
- **`graphify-out/GRAPH_REPORT.md`** — plain-language architecture map: god nodes (highest-degree concepts), surprising connections, community clusters, suggested questions. Claude reads this before searching files.
- **`graphify-out/graph.json`** — persistent queryable graph. Survives sessions, context resets, everything.
- **`graphify-out/graph.html`** — interactive visualization (click nodes, search, filter by community)
- **SHA256 cache** — re-runs only process changed files. First run ~5 min, subsequent runs seconds.
- **Git hooks** — post-commit + post-checkout auto-rebuild the code graph (AST only, no LLM, instant)
- **PreToolUse hook** — fires before every Glob/Grep. When graph exists, reminds Claude to consult GRAPH_REPORT.md before searching raw files. Zero cost when no graph.
- **Every edge tagged** — `EXTRACTED` (found in source), `INFERRED` (reasonable guess with confidence score), `AMBIGUOUS` (flagged for review). You always know what's real.

**Setup (automatic during bootstrap):**
```bash
# setup-plugins.sh handles all of this:
pip install graphifyy            # Python package
graphify install                 # Global skill → ~/.claude/skills/graphify/SKILL.md
graphify hook install            # Git hooks → .git/hooks/post-commit + post-checkout
```

**Usage:**
```bash
/graphify .                      # Build full knowledge graph (first run ~5 min)
/graphify . --update             # Incremental — re-extract only changed files
/graphify . --no-viz             # Skip HTML, just report + JSON (faster)
/graphify . --wiki               # Also generate agent-crawlable wiki
/graphify . --watch              # Auto-rebuild on file changes (background)
graphify query "auth flow"       # BFS traversal from terminal (no AI needed)
graphify path "AuthModule" "DB"  # Shortest path between two concepts
graphify explain "UserService"   # Plain-language node explanation
```

**Token savings:** **71.5× fewer tokens per query** vs reading raw files (on a 52-file corpus). Token reduction scales with corpus size — 6 files fit in a context window anyway, but at 50+ files the graph becomes the critical efficiency layer. The graph IS the compressed context. First run extracts and builds (~5 min); every subsequent query reads the compact graph instead of raw files — that's where the savings compound.

**When to use:**
- **New to a codebase** — run `/graphify .` before your first session. GRAPH_REPORT.md becomes your architecture briefing.
- **After major refactors** — run `/graphify . --update` to refresh the graph.
- **Daily work** — git hooks keep it current automatically. The PreToolUse hook means Claude always navigates by structure, not by grepping through every file.

**MCP server mode** (advanced — persistent graph access for repeated queries):
```bash
# Add to .mcp.json for structured graph access:
python3 -m graphify.serve graphify-out/graph.json
```

**Manual install (if bootstrap couldn't auto-install):**
```bash
pip install graphifyy                # or: pip install graphifyy --break-system-packages
graphify install                     # global skill
graphify claude install              # project CLAUDE.md section + PreToolUse hook
graphify hook install                # git hooks
```

**Uninstall:**
```bash
graphify claude uninstall            # remove CLAUDE.md section + hook
graphify hook uninstall              # remove git hooks
pip uninstall graphifyy              # remove package
```

## The Three-Tool Memory Stack — claude-mem × graphify × obsidian-mind

Three tools, three layers of intelligence. Each answers a fundamentally different question:

| Question | Answered by | Layer | Example |
|----------|------------|-------|---------|
| *"How did we fix the auth bug last Tuesday?"* | **claude-mem** | 📝 Event log | Exact tool calls, file paths, terminal commands — forensic reconstruction |
| *"How is auth connected to the database layer?"* | **graphify** | 🗺️ Code structure | God nodes, community clusters, cross-module edges — navigate by architecture |
| *"What's our authentication philosophy and why?"* | **obsidian-mind** | 🧠 Human knowledge | Curated decisions, rationale, people context — understand the *why* |

| Aspect | claude-mem | graphify | obsidian-mind |
|--------|-----------|----------|---------------|
| **What gets stored** | Every tool invocation (file reads, edits, commands) | Code structure (AST), cross-module relationships, design rationale | Curated knowledge (decisions, patterns, meetings, people) |
| **Who decides** | Automatic — no human in the loop | Automatic — tree-sitter AST + Claude extraction | Intentional — user or Claude explicitly writes |
| **Retrieval** | *"What did I do?"* (factual) | *"How is it connected?"* (structural) | *"What do I know?"* (conceptual) |
| **Token impact** | ~48% API quota when enabled | **71.5× fewer tokens** vs reading raw files | ~2K tokens session start |
| **Analogy** | Git reflog — forensic trail | Architecture diagram — structural map | Wiki — curated narrative |
| **Storage** | SQLite + ChromaDB (`~/.claude-mem/`) | `graphify-out/` (JSON graph + HTML + report) | Plain Markdown vault |
| **Persistence** | Global, across all projects | Per-project, survives sessions/compactions | Per-vault directory |
| **Install method** | `claude plugin install claude-mem@thedotmack` | `pip install graphifyy && graphify install` | `git clone https://github.com/breferrari/obsidian-mind.git` |

### The Synergy Pipeline

```
   claude-mem                  graphify                    obsidian-mind
   ──────────                  ────────                    ─────────────
   📝 Captures raw events      🗺️ Maps code structure       🧠 Curates knowledge
   "I edited AuthService.ts"   "AuthService → DB → Cache"  "Auth uses JWT because..."
         │                           │                            │
         └── timeline-report ──→ graph query ──→ /om-dump ──→ vault note
             (what happened)    (how connected)   (why it matters)
```

**Each tool is most powerful when the others exist:**
- **graphify + obsidian-mind** — graphify discovers *what* your code does structurally; obsidian-mind captures *why* those decisions were made. Together: complete architectural understanding.
- **claude-mem + graphify** — claude-mem records what you changed; graphify shows how those changes ripple through the architecture. Together: impact analysis.
- **claude-mem + obsidian-mind** — claude-mem captures raw events; obsidian-mind curates them into lasting knowledge. Together: automated institutional memory.

### Ordering: Bootstrap First, Then Graph

**Why this order matters:** Bootstrap creates the knowledge docs (`claude/architecture.md`, domain docs, `CLAUDE.md`) — these are the files graphify will index. Running graphify on an empty repo produces a useless graph. After bootstrap populates real domain knowledge, graphify indexes *meaningful content*.

The bootstrap flow:
1. **Phase 4** — `setup-plugins.sh` **installs** graphify (pip package + global skill + git hooks). Fast, automatic, ~5s.
2. **Phase 5** — Report is generated and shown to the user.
3. **After report** — The AI **asks the user**: "🗺️ Want me to build the knowledge graph now?" This is the one permission-ask in the entire bootstrap — the graph build takes ~5 min and costs tokens, so the user chooses when.
4. **If yes** → `/graphify .` runs. When it finishes, `graphify-out/GRAPH_REPORT.md` exists and the PreToolUse hook activates automatically.
5. **If no** → The user runs `/graphify .` anytime later. Everything else works without it.

### Using All Three

```bash
# 1. Bootstrap creates knowledge docs (always first)
/bootstrap

# 2. Graphify maps your code structure (recommended — ~5 min first run)
/graphify .

# 3. Claude-mem captures session history (enable when you want recall)
bash claude/scripts/toggle-claude-mem.sh on

# 4. Obsidian-mind for human knowledge (optional — clone separately)
git clone https://github.com/breferrari/obsidian-mind.git ~/my-knowledge-vault
```

**You don't need all three.** Graphify alone gives massive value (71.5× token savings, architecture visibility). Add claude-mem for cross-session recall. Add obsidian-mind for human knowledge management. Each layer compounds the others.

## Hook Coexistence — Zero Conflict Proof

Plugin hooks fire **in parallel** with project hooks on the same lifecycle event. They are architecturally independent — plugins register via `plugin/hooks/hooks.json`, project via `.claude/settings.json`. Claude Code merges them at runtime.

| Lifecycle Event | Project Hook | claude-mem | graphify | Conflict? |
|----------------|-------------|-----------|----------|:---------:|
| `SessionStart(startup)` | session-start.sh | ✅ (memory injection) | — | ✅ Additive |
| `SessionStart(resume)` | session-start.sh | — | — | ✅ None |
| `SessionStart(clear)` | session-start.sh | ✅ | — | ✅ Additive |
| `SessionStart(compact)` | on-compact.sh | ✅ | — | ✅ Additive |
| `PreCompact` | pre-compact.sh | — | — | ✅ None |
| `UserPromptSubmit` | identity-reinjection.sh | ✅ (context capture) | — | ✅ None |
| `PreToolUse(Bash)` | terminal-safety-gate.sh | — | — | ✅ None |
| `PreToolUse(Write\|Edit)` | config-protection.sh | — | — | ✅ None |
| `PreToolUse(Glob\|Grep)` | — | — | ✅ (graph hint) | ✅ None |
| `PostToolUse(*)` | edit-accumulator.sh (Edit\|Write only) | ✅ (**every** tool) | — | ✅ Different concerns |
| `Stop` | stop-batch-format.sh, exit-nudge.sh | ✅ (session summary) | — | ✅ Additive |
| `SubagentStop` | subagent-stop.sh | — | — | ✅ None |
| `SessionEnd` | — | ✅ (drain observations) | — | ✅ None |

**Zero conflicts across all 13 lifecycle events.** graphify's PreToolUse(Glob\|Grep) hook is a no-op when no graph exists (`[ -f graphify-out/graph.json ]` returns false).

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
| graphify `GRAPH_REPORT.md` empty/missing | Graph not built yet | Run `/graphify .` — first build takes ~5 min |
| graphify PreToolUse hook not firing | `graphify-out/graph.json` doesn't exist | Run `/graphify .` — hook is a no-op until graph exists |
| Python not available for graphify | No Python 3.10+ | Install Python; graphify is skipped gracefully without it |
