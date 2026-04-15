# Claude Code Plugins — Configuration & Reference

> **When to read:** Any task involving plugins, claude-mem, hook coexistence, API quota, persistent memory, or the obsidian-mind knowledge vault.

## Overview

The bootstrap installs and configures a **five-tool stack** — each tool occupies a distinct, non-overlapping niche. Together they cover every axis of codebase intelligence:

| Tool | Axis | Default State | Token Impact |
|------|------|:------------:|:------------:|
| **claude-mem** | 🧠 **Temporal memory** — cross-session event log (SQLite + ChromaDB) | ⚠️ **Disabled** (quota protection) | ~48% of API quota when enabled |
| **graphify** | 🗺️ **Architecture snapshot** — static knowledge graph, god nodes, community clusters | ✅ **On demand** (graph built via `/graphify .`) | **71.5× fewer tokens** per query |
| **rtk** | ⚡ **Command efficiency** — transparently rewrites Claude's bash commands for compressed output | ✅ **No-op** when absent; auto-active when installed | **60-90% output token savings** |
| **codebase-memory-mcp** | 🔍 **Live structural graph** — 14 MCP tools: call paths, blast radius, dead code (C binary, zero deps) | ✅ **Auto-installed** via curl | **120× fewer tokens** vs file exploration |
| **cocoindex-code** | 🔎 **Semantic search** — find code by meaning via local vector embeddings (no API key) | ✅ **Auto-installed** if Python 3.11+ | Finds what grep/AST tools miss |
| **code-review-graph** | 🔴 **Change risk analysis** — blast radius + risk score 0–100 + breaking changes from git diffs (29 MCP tools) | ✅ **Auto-installed** if Python 3.10+ | Pre-PR safety gate — catches cascading breakage |

**The complete picture — zero overlap, full coverage:**

```
Question                                    Tool                         Mechanism
──────────────────────────────────────────────────────────────────────────────────
"Show me the architecture"                  graphify                     GRAPH_REPORT.md
"Who calls AuthService.login()?"            codebase-memory-mcp          trace_path()
"Find code related to rate limiting"        cocoindex-code               search() — KNN vectors
"Is this PR safe to ship?"                  code-review-graph            detect_changes_tool() — risk 0–100
"What did I do last Tuesday?"               claude-mem                   /mem-search
"Why was JWT chosen over sessions?"         obsidian-mind (optional)     vault notes
──────────────────────────────────────────────────────────────────────────────────
Every bash command Claude runs              rtk                          transparent rewrite
```

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

## codebase-memory-mcp — Live Structural Graph

**Purpose:** Live queryable code knowledge graph. Single C binary, zero runtime dependencies, 66 languages, sub-1ms Cypher queries. Answers structural questions (call paths, blast radius, dead code, architecture) without reading any files.

**Install:** Auto-installed by `setup-plugins.sh` via curl. Binary at `~/.local/bin/codebase-memory-mcp`.

**Why NOT `codebase-memory-mcp install`:** The `install` command writes global hooks to `~/.claude/settings.json` — a `PreToolUse(Grep|Glob|Read|Search)` gate that blocks the first file search per session globally. This conflicts with the bootstrap's session flow. We install binary-only (`--skip-config`) and manage everything at project level.

**MCP tools (14):** `index_repository`, `list_projects`, `delete_project`, `index_status`, `search_graph`, `trace_path`, `detect_changes`, `query_graph`, `get_graph_schema`, `get_code_snippet`, `get_architecture`, `search_code`, `manage_adr`, `ingest_traces`.

**Usage:** See `/codebase-memory` skill for decision matrix. Key workflows:
- `detect_changes(base_branch="main")` — risk score before any PR
- `trace_path(function_name="X", direction="both")` — full call chain
- `search_graph(max_degree=0)` — dead code
- `query_graph` — Cypher subset for custom traversals

**Storage:** `~/.cache/codebase-memory-mcp/` (global, not project-local). No `.gitignore` change needed.

**Token impact:** **120× fewer tokens** vs file-by-file exploration (arXiv 2603.27277). Structural questions answered in <10ms via cached Cypher queries.

## rtk — Execution Efficiency Layer

**Purpose:** Transparent command rewriting — intercepts every bash command Claude runs, rewrites it using RTK's registry to produce compressed output, then auto-allows it. Claude sees the rewritten command result with 60-90% fewer tokens, without changing behavior.

**Why it's different from other plugins:** RTK is not a Claude Code plugin (`claude plugin install`). It's an external CLI binary that integrates via a PreToolUse(Bash) hook (`rtk-rewrite.sh`) registered in `.claude/settings.json`. The hook is self-guarding: exits 0 silently if `rtk` or `jq` are not installed — zero penalty when RTK is absent.

**Default state:** ✅ **Hook always registered** — no-op when rtk not installed; auto-active once installed.

**Install:**
```bash
# Automatic: setup-plugins.sh installs rtk via cargo if cargo is in PATH
# Manual fallback:
cargo install rtk           # Install the binary (~1-2 min compile)
# No rtk init needed — bootstrap's .claude/hooks/rtk-rewrite.sh + settings.json are pre-wired
```

**What it provides:**
- **`rtk rewrite`** — rewrites commands transparently at the `PreToolUse(Bash)` lifecycle event
- **`rtk gain`** — shows ROI for the current session (tokens saved, % reduction)
- **`rtk discover`** — shows commands not yet covered by the registry (coverage gaps)
- **60-90% output token savings** — most `gh`, `git`, `cargo`, `grep` commands produce compressed output
- **Exit code protocol**: 0=auto-allow rewrite, 1=no match pass-through, 2=deny pass-through, 3=rewrite + prompt user

**Hook ordering (critical):** RTK hook runs FIRST among Bash PreToolUse hooks — rewrites the command, then the safety gate and quality gate check the already-rewritten command. Order: `rtk-rewrite → pre-commit-quality → terminal-safety-gate`.

**Usage:**
```bash
rtk gain                    # Session ROI: how many tokens were saved
rtk discover                # Which commands have no RTK equivalent yet
rtk --version               # Current version
```

**When NOT installed:** The `rtk-rewrite.sh` hook exits 0 immediately — no error, no slowdown, no change to behavior. The hook slot is reserved so that installing RTK activates it instantly without config changes.

**Manual install of hook (if not using setup-plugins.sh):**
```bash
# Already done — .claude/hooks/rtk-rewrite.sh + settings.json entry exist
# Just install the binary:
cargo install rtk
```

## cocoindex-code — Semantic Vector Search

**Purpose:** Find code by meaning. Chunks source code, embeds chunks as float32 vectors using a local model (`Snowflake/snowflake-arctic-embed-xs` via sentence-transformers), answers semantic queries via KNN similarity. Answers "find all code related to X" without knowing exact names — the gap that grep, AST tools, and structural graphs all miss.

**Why local embeddings (`[full]`):** No network, no API key, works offline. ~1 GB first install (torch + transformers). Subsequent sessions load from disk in seconds. Model: `Snowflake/snowflake-arctic-embed-xs` — fast, small, good general-purpose code embedding.

**Requires:** Python **3.11+** (note: graphify needs 3.10+; cocoindex-code needs 3.11+ — separate detection in setup-plugins.sh).

**Install:** Auto-installed by `setup-plugins.sh` if Python 3.11+ found. Manual: `pip install 'cocoindex-code[full]'`

**Why NOT `ccc init`:** `ccc init` is interactive (questionary prompts) — hangs in non-TTY environments. `setup-plugins.sh` creates the YAML config files programmatically instead.

**One MCP tool:** `mcp__cocoindex-code__search(query, limit, refresh_index, languages, paths)` — returns code chunks with similarity scores.

**Project settings:** `.cocoindex_code/settings.yml` — **committed to repo** (team-shared include/exclude patterns). Index DBs (`target_sqlite.db`, `cocoindex.db`) are gitignored.

**ccc mcp startup requirement:** `ccc mcp` exits with code 1 if no `.cocoindex_code/settings.yml` exists. `setup-plugins.sh` creates it before starting. If missing: `ccc index` first, or recreate settings.yml from the template.

**Switching embedding models:**
- Better code model: `nomic-ai/CodeRankEmbed` (137M params, GPU recommended)
- Cloud: `voyage-code-3`, `text-embedding-3-small`, Ollama, any LiteLLM endpoint
- After switching: `ccc reset && ccc index` (vector dimensions are model-specific — incompatible across models)

**Troubleshooting:**
| Symptom | Fix |
|---------|-----|
| `ccc mcp` exits code 1 | Run `ccc index` or check `.cocoindex_code/settings.yml` exists |
| macOS SQLite extension error | Use `brew install python3` — macOS built-in Python ships without extension loading |
| Model downloading on first search | Normal — HuggingFace download ~200 MB, cached after first run |
| Slow path-filtered search | Use `languages` filter instead; `paths` triggers full table scan |

## code-review-graph — Change Risk Analysis

**Purpose:** Structural change safety gate. Builds a SHA-256 AST dependency graph from source code, then on any diff computes risk score (0–100), blast radius (all transitively affected nodes via BFS, 100% recall), breaking changes (signature-changed nodes), and impacted execution flows. Answers "is this change safe to ship?" without reading individual files.

**Why this matters for bootstrap:** Bootstrap is infrastructure — wrong changes silently break workflows for every downstream user. `detect_changes_tool` before any PR is a mandatory safety gate.

**Install:** Auto-installed by `setup-plugins.sh` if Python 3.10+ found. Manual: `pip install 'code-review-graph[communities]'`

**`[communities]` extra:** Leiden algorithm for community detection — improves blast radius clustering quality. Falls back to file-based grouping without it.

**29 MCP tools + 5 prompts:** via `fastmcp` stdio server (`uvx code-review-graph serve`).

**Crown jewel:** `mcp__code-review-graph__detect_changes_tool(base_branch="main")` — risk score + blast radius in one call.

**Storage:** `.code-review-graph/` (project-local SQLite, gitignored). Rebuilt from source on each machine.

**Incremental update:** SHA-256 content hashing → git post-commit hook → <2s re-index. No LLM calls.

**Why NOT `code-review-graph install --platform claude-code`:**
The `install` command writes a PostToolUse(Write|Edit|Bash) hook to `~/.claude/settings.json` (GLOBAL) — fires `code-review-graph update` after every file write and bash call. Same ~48% API quota drain as claude-mem. It also injects a section into CLAUDE.md that conflicts with our 4KB budget.
Solution: `postprocess --no-instructions --no-hooks` — git post-commit hook only (safe, fast, no quota drain).

**Relationship to other tools:**
- **graphify**: both build AST graphs, different outputs — graphify → LLM-synthesized architecture narrative; CRG → structural diff risk scores
- **codebase-memory-mcp**: both answer "what's connected to X?" — CBM is live (polling), CRG is commit-gated (post-commit hook)
- **cocoindex-code**: orthogonal — semantic search has no overlap with structural change risk

**Risk score interpretation:**
| Score | Action |
|-------|--------|
| 0–25 | Review and ship |
| 26–50 | Verify blast radius manually |
| 51–75 | Write tests for affected nodes |
| 76–100 | Full review + stakeholder sign-off |

**Troubleshooting:**
| Symptom | Fix |
|---------|-----|
| `uvx: command not found` | Install uv: `pip install uv` or `brew install uv` |
| MCP server exits (no graph.db) | Run `build_graph_tool` first, or `code-review-graph build .` |
| Communities detection unavailable | Install with `[communities]`: `pip install 'code-review-graph[communities]'` |
| Post-commit hook missing | `code-review-graph postprocess --no-instructions --no-hooks` |
| Graph stale after large refactor | `build_graph_tool(repo_path=".", force_rebuild=True)` |

## The Complete Tool Stack

Six tools, six axes of intelligence. Each answers a fundamentally different question:

| Question | Answered by | Layer | Mechanism |
|----------|------------|-------|-----------|
| *"How did we fix the auth bug last Tuesday?"* | **claude-mem** | 📝 Event log | SQLite + ChromaDB event capture — forensic session reconstruction |
| *"Show me the architecture"* | **graphify** | 🗺️ Architecture snapshot | AST + Claude extraction → GRAPH_REPORT.md — read once, survives sessions |
| *"Who calls `AuthService.login()`?"* | **codebase-memory-mcp** | 🔍 Live structural graph | Cypher query → <10ms, no file reads, 120× fewer tokens |
| *"Find code that handles rate limiting"* | **cocoindex-code** | 🔎 Semantic search | KNN over float32 vectors — finds by meaning, not names |
| *"Is this PR safe to ship?"* | **code-review-graph** | 🔴 Change risk | BFS traversal → risk score 0–100, blast radius, breaking changes |
| *"What's our authentication philosophy and why?"* | **obsidian-mind** | 🧠 Human knowledge | Curated vault notes — rationale, decisions, context |

**Each bash command Claude runs →** `rtk` rewrites it transparently for 60-90% fewer output tokens. Independent of all other tools — pure execution layer.

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

**All three MCP servers (codebase-memory-mcp, cocoindex-code, and code-review-graph) run as stdio servers, not hooks** — they register zero lifecycle events. They start on demand when Claude invokes an `mcp__*` tool and communicate via JSON-RPC 2.0 stdio. Index updates happen via background processes (git polling for CBM, `refresh_index` param for ccc, git post-commit hook for CRG). No hook registration, no conflict possible.

**rtk** integrates as a single `PreToolUse(Bash)` hook — first in the chain, rewrites commands before safety/quality gates check them. Self-guarding: exits 0 silently if rtk or jq absent.

| Lifecycle Event | Project Hook | claude-mem | graphify | rtk | codebase-memory-mcp | cocoindex-code | code-review-graph | Conflict? |
|----------------|-------------|-----------|----------|-----|---------------------|----------------|:-----------------:|:---------:|
| `SessionStart(startup)` | session-start.sh | ✅ memory | — | — | — | — | — | ✅ Additive |
| `SessionStart(resume)` | session-start.sh | — | — | — | — | — | — | ✅ None |
| `SessionStart(clear)` | session-start.sh | ✅ | — | — | — | — | — | ✅ Additive |
| `SessionStart(compact)` | on-compact.sh | ✅ | — | — | — | — | — | ✅ Additive |
| `PreCompact` | pre-compact.sh | — | — | — | — | — | — | ✅ None |
| `UserPromptSubmit` | identity-reinjection.sh | ✅ context | — | — | — | — | — | ✅ None |
| `PreToolUse(Bash)` | rtk-rewrite → safety-gate | — | — | ✅ first | — | — | — | ✅ Ordered |
| `PreToolUse(Write\|Edit)` | config-protection.sh | — | — | — | — | — | — | ✅ None |
| `PreToolUse(Glob\|Grep)` | — | — | ✅ graph hint | — | — | — | — | ✅ None |
| `PostToolUse(*)` | edit-accumulator.sh | ✅ every tool | — | — | — | — | — | ✅ Different |
| `Stop` | stop-batch-format.sh, exit-nudge.sh | ✅ summary | — | — | — | — | — | ✅ Additive |
| `SubagentStop` | subagent-stop.sh | — | — | — | — | — | — | ✅ None |
| `SessionEnd` | — | ✅ drain | — | — | — | — | — | ✅ None |
| _(background)_ | — | — | git post-commit | — | git polling 5–60s | refresh_index param | git post-commit | ✅ Independent |

**Zero conflicts across all 13 lifecycle events.** graphify's PreToolUse(Glob\|Grep) hook is a no-op when `graphify-out/graph.json` doesn't exist. codebase-memory-mcp, cocoindex-code, and code-review-graph never register Claude Code hooks (MCP only + git hooks). rtk is first in the Bash chain by design.

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
| rtk not active | Binary not installed | `cargo install rtk` — hook is pre-wired, activates on install |
| rtk rewriting wrong command | Old version (<0.23.0) | `cargo install rtk` to upgrade; version check cached in `~/.cache/rtk-hook-version-ok` |
| codebase-memory-mcp tools missing | Binary not in PATH | `export PATH="$HOME/.local/bin:$PATH"` then restart Claude Code |
| codebase-memory-mcp index stale | Large refactor since last poll | `index_repository(repo_path=".", mode="fast")` via MCP tool |
| `ccc mcp` exits immediately | No `.cocoindex_code/settings.yml` | Run `ccc index` first, or recreate settings.yml from `.cocoindex_code/settings.yml` template |
| cocoindex-code SQLite error on macOS | macOS Python lacks SQLite extension loading | `brew install python3` — Homebrew Python has extension loading enabled |
| cocoindex-code slow first search | Model downloading from HuggingFace | Normal — ~200 MB download, cached after first run |
| `uvx: command not found` (code-review-graph) | uv not installed | `pip install uv` or `brew install uv` |
| code-review-graph MCP exits immediately | `.code-review-graph/graph.db` missing | Run `mcp__code-review-graph__build_graph_tool` or `code-review-graph build .` |
| code-review-graph communities unavailable | Missing `[communities]` extra | `pip install 'code-review-graph[communities]'` |
| code-review-graph post-commit hook missing | `postprocess` not run | `code-review-graph postprocess --no-instructions --no-hooks` |
