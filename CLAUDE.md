# Claude Code — {{PROJECT_NAME}} Instructions

> **Non-negotiable.** Auto-injected every message. Budget: <4KB. Detail in `claude/*.md` — read via `read_file`.

<!-- Always-loaded imports: architecture overview + golden rules -->
@claude/architecture.md
@claude/rules.md

## ⚠️ Mandatory Reads — You MUST consult before acting

**Session start →** read **`claude/tasks/todo.md`** (current task state) + **`claude/tasks/lessons.md`** (accumulated wisdom from past sessions).

| If task involves… | YOU MUST read FIRST |
|---|---|
| _anything_ (first action) | `claude/tasks/todo.md` + `claude/tasks/lessons.md` + `claude/tasks/CLAUDE_ERRORS.md` + `claude/architecture.md` + `claude/rules.md` |
| build, test, CI, lint, format, migration, local dev | `claude/build.md` |
| MR, PR, ticket, context management | `claude/templates.md` |
| terminal, command, shell, subprocess, pager, interactive | `claude/terminal-safety.md` |
| CVE, dependency upgrade, security scan | `claude/cve-policy.md` |
| plugin, claude-mem, hook coexistence, API quota, obsidian-mind vault, rtk | `claude/plugins.md` |
| structural query, call trace, blast radius, dead code, architecture live, codebase-memory | `claude/plugins.md` |
| semantic search, find code by meaning, cocoindex, vector search | `claude/plugins.md` |
| change risk, blast radius, breaking changes, pre-PR safety, risk score | `claude/plugins.md` |
<!-- {{DOMAIN_LOOKUP_TABLE}} — Add rows for each domain in your project:
| domain-keyword-1, domain-keyword-2 | `claude/your-domain.md` |
-->

## Operating Protocol (always active)

1. **Plan first** — write plan to `claude/tasks/todo.md` before non-trivial tasks (3+ steps or architectural decisions).
2. **Use subagents** — offload research and exploration to subagents (saves main context window).
3. **Prove completion** — run tests, check logs, demonstrate correctness.
4. **No hacky solutions** — find the elegant way. Ask "is there a more elegant way?" before committing.
5. **Fix bugs autonomously** — don't ask, just fix. Zero context switching from the user.
6. **Mark progress** — check items in `claude/tasks/todo.md` as you go.
7. **Evidence-based** — verify before stating. Distinguish pre-existing issues from introduced ones.
8. **Maintain knowledge autonomously** — update `claude/*.md` when you discover stale info. Stale docs are bugs.

## Token Cost Strategy

- **Subagents** for exploration: `research` + `reviewer` + `plan-challenger` + `session-reviewer` + `security-auditor` run in isolated context — main stays clean. Quality-critical agents (reviewer, plan-challenger, security-auditor) declare their optimal model; lightweight agents (research, session-reviewer) inherit the session model for efficiency.
- **Effort levels**: quick commands (`/build`, `/lint`, `/test`) use `effort: low`; research (`/plan`, `/review`) use `effort: high`.
- **Compact-safe hooks**: `SessionStart` hooks inject project context on cold starts and after compaction.
- **Read domain docs on-demand** from the lookup table, not preemptively.
- **Discard after use**: tool outputs, file reads (re-readable), intermediate research. Keep only: decisions, corrections, test results.
- **`ultrathink`** on high-reasoning commands (`/plan`, `/review`, `/mr`, `/debug`) — extended thinking where it matters.
- **`!command` pre-fetching** on 6 commands — injects git/task data before Claude starts, eliminating setup tool calls.
- **`disable-model-invocation: true`** on side-effect commands — prevents accidental skill loading into context budget.
- **Short descriptions** — all command descriptions ≤127 chars. Front-loaded key use cases.

## Model Awareness

Agents declare their **optimal model** for maximum quality — and fall back to the session model when unavailable. This guarantees the best choice when multiple models are accessible (Anthropic API, Bedrock, Vertex), and full compatibility when only one model exists (Ollama, LM Studio, any local LLM).

| Agent | Declared model | Why |
|:------|:--------------:|:----|
| `research` | _(session)_ | Mechanical (grep, read, summarize) — lighter model = faster + cheaper |
| `reviewer` | opus | Deep reasoning, 10-point protocol — a missed bug costs 100× the token savings |
| `plan-challenger` | opus | Adversarial reasoning — subtle flaws require highest capability |
| `session-reviewer` | _(session)_ | Pattern matching in text — any model handles this |
| `security-auditor` | opus | Security demands highest capability — no compromise |

**Protocol auto-scales to model capability:**

| Capability | Full model (Opus/Sonnet) | Smaller/local model (Haiku, Ollama…) |
|:-----------|:------------------------|:-------------------------------------|
| Review protocol | Full 10-point checklist | Focus on items 1-4 (ticket, diff, cross-layer, enums) |
| Subagents | Use freely — isolated context | Prefer inline research to save overhead |
| Meta-cognition | Full sub-question decomposition | Direct approach, skip confidence scoring |
| Exit checklist | All 6 gates | Gates 1-3 only (corrections, knowledge, progress) |
| Domain docs | On-demand from lookup table | Read only the single most relevant doc |

**For smaller/local models:** Prioritize correctness over protocol completeness. Skip ceremony, keep substance.

## Meta-Cognition

Complex problems: break into sub-questions → confidence-weight each → combine → if overall confidence < 0.8, retry with more research.

## 🚨 Exit Checklist — BEFORE ending your turn (MANDATORY)

1. **User corrected me or revealed a missed pattern?** → Update `claude/tasks/lessons.md` + relevant `claude/*.md` NOW.
2. **Learned something new about codebase?** → Same.
3. **Open task in `claude/tasks/todo.md`?** → Mark progress.
4. **Did my work touch a domain?** → Verify relevant `claude/*.md` are still accurate (file paths, patterns, field names). Fix NOW.
5. **Any new pattern, pitfall, or convention discovered?** → Add to most relevant doc + `claude/tasks/lessons.md`. Don't wait to be asked.
6. **Used terminal commands this turn?** → Verify none triggered pagers, interactive mode, or unbounded output.

Do NOT yield until all six pass.

## Terminal Rules (CRITICAL — #1 cause of session hangs)

> Full reference: `claude/terminal-safety.md`. Always-loaded rule: `.claude/rules/terminal-safety.md`.

- **🚨 PIPE `|` — 5 ABSOLUTE RULES** (apply immediately, never analyze for 10 min):
  1. **Terminal regex**: `grep -E 'a|b'` ✅ — `grep -E "a|b"` ❌ — ALWAYS single quotes
  2. **Writing files**: use file-writing tool — NEVER heredoc in terminal (strips `|`)
  3. **Verifying files**: `grep -c '|' file` ✅ — `cat file` ❌ — terminal display STRIPS `|`
  4. **Markdown tables**: `\|` inside table cells — bare `|` outside tables
  5. **Shell scripts**: `case "$F" in *.js|*.ts)` ✅ — `grep -E '\.(js|ts)$'` ❌ — `case` is pipe-immune
- **NEVER** trigger a pager: always `git --no-pager` or `| cat` for git, helm, kubectl, man
- **NEVER** open interactive programs: no `vi`, `nano`, `psql` without `-c`, `node`/`python` REPL, `docker exec -it`
- **NEVER** `cd /path && command` — use absolute paths or run from project root
- **NEVER** dump unbounded output: always `| head -N`, `| tail -N`, `--tail 50`, or redirect to file
- **ALWAYS** `--color=never` / `NO_COLOR=1` — disable ANSI escape codes
- **ALWAYS** `2>&1` — capture stderr alongside stdout
- **Short-lived** (test, grep, git): foreground. **Long-running** (server, watch): background.
- **After any terminal issue** → update `claude/terminal-safety.md` + `claude/tasks/lessons.md` immediately

## Critical Patterns (memorize)

- **Learning loop is an EXIT GATE** — check before every response
- **Explore → Plan → Act** — investigate codebase (Grep/Read/LS) before coding, write failing tests before implementing, then TDD cycle
- **Temp files go in `./claude/tasks/`**, never `/tmp/` — clean them when obsolete
- **NEVER `git push` autonomously** — present summary + proposed command, wait for user confirmation
- **All proofs (build, test, scan) MUST pass** before generating any MR description
- **MCP tool invocation format:** `mcp__SERVER_KEY__TOOL_FUNCTION_NAME` — `SERVER_KEY` is from `.mcp.json`, use `/mcp list` to see available tools
- **`$ARGUMENTS` in commands** — user input placeholder; explain how it's used if not obvious; always validate before acting on it
<!-- {{CRITICAL_PATTERNS}} — Add your project-specific non-negotiable patterns here:
- Example: Never emit side effects inside a DB transaction — use deferred callbacks
- Example: Two DBs: `write` (mutations) + `read` (queries) — never mix
-->

## Key Decisions

> Settled architectural choices — do not re-litigate unless the user explicitly asks.
> Full rationale in `claude/decisions.md` — append new decisions there as they're made.

<!-- {{KEY_DECISIONS}} — Add settled choices once discovered during bootstrap/exploration:
- Example: [2026-01] PostgreSQL over MongoDB — relational data model, existing team expertise
- Example: [2026-02] REST over gRPC for public API — simpler client integration requirement
-->

## Review Protocol (Expert Architect / Expert Developer)

Before MR, perform a full review covering:

1. **Ticket re-read** — verify every scenario in the ticket is addressed
2. **Cross-layer consistency** — DTO → backend → frontend → tests: grep every new field across all layers
3. **Enum completeness** — verify `switch`/`case` handles all values of each enum
4. **Transaction safety** — trace every write caller; confirm read callers don't write
5. **Race condition analysis** — trace concurrent flows
6. **Test scenario completeness** — verify every new branch/case has a dedicated test
7. **Pre-existing vs introduced** — distinguish lint/type warnings that existed before from ones introduced by the change
8. **Cross-branch merge safety** — if another branch will merge first, verify changes still apply cleanly
9. **Security & side effects** — scan for new external calls, unintended data exposure, new permissions required, or unsafe defaults introduced
10. **100/100 confidence gate** — do not proceed to MR description until all above pass

## Hard Constraints (enforced unconditionally)

<!-- {{HARD_CONSTRAINTS}} — Add file types / patterns that should NEVER be loaded into context:
- **NEVER add `{{LARGE_FILE_PATTERN}}` files to context** — they consume the entire context budget
-->
- **NEVER modify IDE configuration files** (`.idea/`, `.vscode/settings.json`) unless the user explicitly asks

## Don't

> Explicit prohibitions — adding these prevents well-meaning but wrong "improvements".

<!-- {{DONT_LIST}} — Add project-specific prohibitions discovered during bootstrap/exploration:
- Example: NEVER add packages without first running `/update-code-index` to check for existing solutions
- Example: NEVER bypass the review checklist for "trivial" fixes — all MRs go through the full protocol
- Example: NEVER generate `git push` without explicit user confirmation
-->

## Compact Instructions

When compacting, focus on preserving: current task from `claude/tasks/todo.md` (title + unchecked steps), branch name + uncommitted files, which `claude/*.md` files were read, user corrections from this session, and test results. Discard verbose tool output, file read contents (re-readable), and intermediate research.

## Session Continuity Protocol

Before ending a session or when context is running low:
1. Write current state to `claude/tasks/todo.md` — title, checked/unchecked steps, next action, branch, loaded docs.
2. If the user corrected you, update `claude/tasks/lessons.md` NOW (Exit Checklist gate).
3. Tell the user: "Session state saved to `claude/tasks/todo.md`. Next session: run `/resume` to continue."

## Plugin Ecosystem

> Full reference: `claude/plugins.md`. Toggle script: `claude/scripts/toggle-claude-mem.sh`.

**Plugin hooks fire ALONGSIDE project hooks** — independent systems, zero conflicts. Registered via separate mechanisms (`plugin/hooks/hooks.json` vs `.claude/settings.json`), merged at runtime.

**Installed plugins:**
<!-- {{INSTALLED_PLUGINS}} — Auto-populated by bootstrap if plugins detected -->

**claude-mem** — persistent cross-session memory (SQLite + ChromaDB). Worker on `localhost:37777`. ⚠️ **Disabled by default** (quota protection — `PostToolUse(*)` fires after EVERY tool call, ~48% API quota in heavy sessions). Toggle:
```bash
bash claude/scripts/toggle-claude-mem.sh on       # Enable (next session)
bash claude/scripts/toggle-claude-mem.sh off      # Disable + kill worker
bash claude/scripts/toggle-claude-mem.sh status   # Check state
```

> **obsidian-mind** is a companion Obsidian vault (not a Claude Code plugin) — clone separately if you want AI-powered knowledge management: `git clone https://github.com/breferrari/obsidian-mind.git`. See `claude/plugins.md`.

**rtk** — execution efficiency layer. Transparently rewrites Claude's bash commands for 60-90% output token savings. Auto-installed by `setup-plugins.sh` if `cargo` is available. No-op when absent. ROI: `rtk gain` · Gaps: `rtk discover`.

**codebase-memory-mcp** — live structural graph (14 MCP tools). Auto-installed. `mcp__codebase-memory-mcp__trace_path` / `detect_changes` / `get_architecture`. **Use before reading files for structural questions.** See `claude/plugins.md`.

**cocoindex-code** — semantic vector search (1 MCP tool: `search`). Auto-installed if Python 3.11+. `mcp__cocoindex-code__search`. Find code by meaning when you don't know exact names. See `claude/plugins.md`.

**code-review-graph** — change risk analysis (29 MCP tools). Auto-installed if Python 3.10+. `mcp__code-review-graph__detect_changes_tool(base_branch="main")`. Pre-PR safety gate: risk score 0–100, blast radius, breaking changes. See `claude/plugins.md`.

## graphify — Knowledge Graph

> If `graphify-out/GRAPH_REPORT.md` exists, **read it before answering architecture questions** — it contains god nodes, community structure, and surprising cross-module connections the graph discovered.

**Rules (when graph exists):**
- Before searching files (Glob/Grep), consult `graphify-out/GRAPH_REPORT.md` for structure
- If `graphify-out/wiki/index.md` exists, navigate it instead of reading raw files
- Use `/graphify .` to build or rebuild the full graph (runs tree-sitter AST + Claude extraction)
- Use `graphify query "<question>"` for targeted graph traversal from terminal

**Git hooks auto-rebuild** the code graph on every commit and branch switch (AST only, no LLM, instant). Docs/images require `/graphify --update`.

> No graph yet? Run `/graphify .` — first run takes ~5 min, subsequent runs are incremental (SHA256 cache). See `claude/plugins.md` for details.

## Core Principles

Simplicity · No laziness (root cause, senior standards) · Surgical changes · Evidence-based

## IDE Integration

<!-- Uncomment the section matching your IDE:

### IntelliJ / JetBrains
- Claude Code runs from IntelliJ's integrated terminal via JetBrains plugin
- IDE diff viewer shows file diffs; selected code is auto-shared with Claude
- Diagnostic sharing: lint errors, TypeScript errors, SonarLint warnings visible to Claude

### VS Code
- Claude Code runs from VS Code's integrated terminal
- Copilot chat shares selected code context automatically
-->

> **Personal overrides:** Create `CLAUDE.local.md` at the repo root for personal instructions (auto-gitignored by Claude Code).

<!-- Generated by ᗺB Brain Bootstrap · https://github.com/y-abs/claude-code-brain-bootstrap · by y-abs -->
