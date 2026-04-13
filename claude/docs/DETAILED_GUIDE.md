<p align="center">
  <h1 align="center">ᗺB · Brain Bootstrap — The Complete Guide</h1>
  <p align="center"><em>by <a href="https://github.com/y-abs">y-abs</a></em></p>
  <p align="center"><strong>Everything you need to know, nothing you don't.<br>From "what is this?" to "I want to build my own hooks."</strong></p>
  <p align="center">
    <a href="#-the-big-picture">Big Picture</a> · <a href="#-get-started">Get Started</a> · <a href="#-the-architecture-tour">Architecture</a> · <a href="#-every-file-explained">Files</a> · <a href="#-deep-dives">Deep Dives</a> · <a href="#-make-it-yours">Customize</a> · <a href="#-faq">FAQ</a>
  </p>
  <p align="center">
    <a href="../../LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"></a>
    <a href="#"><img src="https://img.shields.io/badge/100+_files-10_categories-blueviolet" alt="100+ files"></a>
    <a href="#"><img src="https://img.shields.io/badge/26_commands-14_hooks-brightgreen" alt="Automation"></a>
  </p>
</p>

---

> 📖 **This is the deep reference.** Looking for the quick pitch? → [README.md](../../README.md)
>
> **Reading time:** ~15 minutes cover to cover. Or jump to what you need — every section is self-contained.

---

## 📑 Table of Contents

- [🗺️ The Big Picture](#-the-big-picture)
- [🚀 Get Started](#-get-started)
- [🏛️ The Architecture Tour](#-the-architecture-tour)
  - [🎯 The Three-Tier Token Strategy](#-the-three-tier-token-strategy)
- [📂 Every File, Explained](#-every-file-explained)
  - [🏠 Root Files (7)](#-root-files-7)
  - [🧠 Bootstrap Scaffolding — `claude/bootstrap/`](#-bootstrap-scaffolding--claudebootstrap-3-files-auto-deleted)
  - [📚 Knowledge Docs — `claude/`](#-knowledge-docs--claude-13-files)
  - [⚡ Slash Commands — `.claude/commands/`](#-slash-commands--claudecommands-26-files)
  - [🪝 Lifecycle Hooks — `.claude/hooks/`](#-lifecycle-hooks--claudehooks-14-files)
  - [🤖 AI Subagents — `.claude/agents/`](#-ai-subagents--claudeagents-5-files)
  - [🎓 Skills — `.claude/skills/`](#-skills--claudeskills-5-files)
  - [📏 Path-Scoped Rules — `.claude/rules/`](#-path-scoped-rules--clauderules-13-files)
  - [🤝 GitHub Copilot — `.github/`](#-github-copilot--github-8-files)
  - [🧠 Memory — `claude/tasks/`](#-memory--claudetasks-5-files)
  - [🔧 Scripts — `claude/scripts/`](#-scripts--claudescripts-12-files)
- [🔬 Deep Dives](#-deep-dives)
  - [📂 The 10 Configuration Categories](#-the-10-configuration-categories)
  - [🔄 Bootstrap: How It Actually Works](#-bootstrap-how-it-actually-works)
  - [♻️ Upgrading an Existing Config](#-upgrading-an-existing-config)
- [🏷️ Placeholder Reference](#-placeholder-reference)
- [🌍 Stack-Specific Examples](#-stack-specific-examples)
- [🎨 Make It Yours](#-make-it-yours)
- [📐 Best Practices](#-best-practices)
- [❓ FAQ](#-faq)
- [🔌 Plugin Ecosystem — Deep Dive](#-plugin-ecosystem--deep-dive)
- [🧬 From Instructions to Guarantees](#-from-instructions-to-guarantees)
- [🤝 Contributing](#-contributing)
  - [🔄 CI Pipeline](#-ci-pipeline)
- [⚖️ License](#-license)

---

## 🗺️ The Big Picture

Claude Code Brain is **100+ files** organized into **10 categories** that turn your AI coding assistant from a talented stranger into a senior engineer who knows your codebase inside out.

Here's the mental model:

```
  🧠  Your Brain (CLAUDE.md)
   │   "Here's how we work, here's what matters, here's what never to touch"
   │
   ├── 📚  Knowledge (claude/*.md)
   │       "Here's our architecture, our build system, our auth patterns..."
   │
   ├── ⚡  Automation (.claude/commands/)
   │       "Here's a shortcut for every workflow you'll ever need"
   │
   ├── 🪝  Guardrails (.claude/hooks/)
   │       "Here's what you're NOT allowed to do, enforced in code"
   │
   ├── 🤖  Delegation (.claude/agents/)
   │       "Here's your team — research, review, challenge"
   │
    ├── 🎓  Discipline (.claude/skills/)
    │       "Here's how to write tests, trace bugs, stay safe"
    │
    ├── 🔌  Extensions (plugins)
    │       "Here's your persistent memory and knowledge graph"
    │
    └── 🧠  Memory (claude/tasks/)
            "Here's everything we've learned together"
```

**26 slash commands. 14 lifecycle hooks. 5 AI subagents. 5 skills. 1 plugin. 120 validation checks. 8 domain-detection greps. Zero setup friction.**

> 💡 Battle-tested. Works with **any language, any framework, any repo**.

---

## 🚀 Get Started

### Step 1 — Install the template

```bash
git clone https://github.com/y-abs/claude-code-brain-bootstrap.git /tmp/brain
bash /tmp/brain/install.sh your-repo/
rm -rf /tmp/brain
```

The install script auto-detects FRESH vs UPGRADE mode. If you have an existing Claude config (from a previous bootstrap or hand-crafted), it preserves all your files and adds only what's missing. See `install.sh --help` or the README for details.

### Step 2 — Let the AI configure itself

Open Claude Code in your repo and run:

```
/bootstrap
```

The AI will:
1. 🔍 **Discover** your tech stack (language, framework, package manager, linter, test runner, DB, CI…)
2. 🏗️ **Analyze** your architecture (services, domains, patterns, aliases)
3. 📝 **Populate** all `{{PLACEHOLDER}}` values across every template file
4. 🧠 **Generate** domain-specific knowledge docs (adaptive depth — 8 domain greps, mandatory when ≥3 domains found)
5. 🔌 **Install** plugin (claude-mem)
6. ✅ **Validate** everything works (`claude/scripts/validate.sh` — 120 checks)

> 💡 **No Claude Code?** Paste `claude/bootstrap/PROMPT.md` into any AI chat — it works with any LLM.

### Step 3 — Validate and commit

```bash
bash claude/scripts/validate.sh
git add CLAUDE.md .claudeignore claude/ .claude/ .github/
git commit -m "chore: add Claude Code configuration"
```

> 🤝 **TEAM mode (default)** — commit everything, share the AI context with your whole team. Every developer gets the same experience. Or switch to **SOLO mode** (personal, not committed): `echo -e '\nCLAUDE.md\nclaude/\n.claude/\n.claudeignore\n.mcp.json' >> .gitignore` — `.github/` stays committed for Copilot.

### Step 4 — Ship code with superpowers

```
/plan implement user authentication
/build
/test all
/review
/mr JIRA-123
```

That's it. You now have a brain. 🧠

---

## 🏛️ The Architecture Tour

Here's how all 100+ files fit together:

```
Your repo
├── 📋 CLAUDE.md                    ← The brain (auto-loaded every conversation)
│   ├── @import architecture.md     ← Always knows your project layout
│   └── @import rules.md            ← Always knows your golden rules
│
├── ⚙️ .claude/
│   ├── settings.json               ← Permissions, hooks, env vars
│   ├── settings.local.json.example ← Personal overrides template
│   ├── commands/  (26 files)       ← /build, /test, /review, /mr...
│   ├── hooks/     (14 files)       ← Safety, quality, recovery
│   ├── agents/    (5 files)        ← research, reviewer, plan-challenger, session-reviewer, security-auditor
│   ├── skills/    (5 files)        ← TDD, root-cause, changelog, careful, cross-layer
│   └── rules/     (13 files)       ← Path-scoped auto-loading rules
│
├── 📚 claude/
│   ├── architecture.md  ✅         ← Auto-loaded (via @import)
│   ├── rules.md         ✅         ← Auto-loaded (via @import)
│   ├── build.md         📖         ← On-demand (when building)
│   ├── terminal-safety  📖         ← On-demand (always-loaded rule too)
│   ├── <your-domains>   📖         ← On-demand (when task involves domain)
│   └── tasks/                      ← Persistent memory across sessions
│       ├── lessons.md              ← "Never make this mistake again"
│       ├── todo.md                 ← "Here's where I left off"
│       └── session-logs/           ← Auto-backed up transcripts
│
├── 🤖 .github/
│   ├── copilot-instructions.md     ← GitHub Copilot root config
│   ├── instructions/               ← Scoped rules (auto-loaded by glob)
│   └── prompts/                    ← Reusable prompts (one-click)
│
└── 🚫 .claudeignore                ← "Don't even look at these files"
```

### 🎯 The Three-Tier Token Strategy

Your AI shouldn't drown in 50K tokens when you ask it to fix a typo. So the system loads knowledge in three layers:

| Layer | What loads | When | Token cost |
|:------|:-----------|:-----|:----------:|
| 🟢 **Always on** | `CLAUDE.md` + `@import`s (architecture, rules) | Every conversation | ~3-4K |
| 🟡 **Auto-loaded** | `.claude/rules/*.md` with `paths:` globs | When editing matching files | ~200-400 each |
| 🔵 **On-demand** | `claude/*.md` domain docs (build, auth, DB…) | When the task requires it | ~1-2K each |

> 🎯 **Result:** Minimal cost for simple tasks, deep context exactly when needed.

---

## 📂 Every File, Explained

### 🏠 Root Files (7)

| File | What it does |
|:-----|:------------|
| 📋 `CLAUDE.md` | The brain — operating protocol, exit checklist, critical patterns, lookup table |
| 👤 `CLAUDE.local.md.example` | Your personal overrides (gitignored in use) |
| 🚫 `.claudeignore` | Keeps binaries, lock files, and build artifacts out of context |
| 📖 `README.md` | The pitch + quick start |
| ⚖️ `LICENSE` | MIT |
| 🔌 `.mcp.json` | MCP server configuration template for tool integrations |
| 🐚 `.shellcheckrc` | ShellCheck configuration for script linting |

### 🧠 Bootstrap Scaffolding — `claude/bootstrap/` (3 files, auto-deleted)

> These files exist only during bootstrap. They are automatically deleted after Phase 5 cleanup. For future upgrades, re-clone the template.

| File | What it does |
|:-----|:------------|
| 🪄 `PROMPT.md` | Paste into any AI to auto-configure — works with any LLM |
| 📖 `REFERENCE.md` | Report templates for Phase 5 — kept separate to save working context |
| 🔄 `UPGRADE_GUIDE.md` | Smart Merge guide (Phase 2) — loaded only for UPGRADE mode |

### 📚 Knowledge Docs — `claude/` (13 files)

These are the AI's textbooks. Some load automatically, others on-demand:

| File | What it teaches | Auto-loaded? |
|:-----|:---------------|:------------:|
| `architecture.md` | Workspace layout, services, packages, aliases | ✅ `@import` |
| `rules.md` | 24 golden rules — the non-negotiables | ✅ `@import` |
| `terminal-safety.md` | Shell anti-patterns that hang sessions | 🔒 Via rule |
| `build.md` | Build, test, lint, CI commands and gotchas | 📖 On-demand |
| `templates.md` | MR/ticket templates, context management | 📖 On-demand |
| `cve-policy.md` | CVE decision tree, override checklist | 📖 On-demand |
| `plugins.md` | Plugin config — claude-mem, quota management, obsidian-mind vault guide | 📖 On-demand |
| `decisions.md` | Architectural decision log — settled choices with rationale | 📖 On-demand |
| `README.md` | Meta-docs: how to extend the knowledge base | 📖 Reference |
| `docs/DETAILED_GUIDE.md` | Complete guide — architecture, all files, deep dives, FAQ | 📖 Reference |
| `_examples/api-domain.md` | Worked example: REST API domain | 🗑️ Delete after use |
| `_examples/database-domain.md` | Worked example: Database domain | 🗑️ Delete after use |
| `_examples/messaging-domain.md` | Worked example: Event-driven domain | 🗑️ Delete after use |

> 💡 **The examples are training wheels.** Study them → create your own → delete them.

### ⚡ Slash Commands — `.claude/commands/` (26 files)

Every command you'll reach for, pre-built and ready:

| Command | What it does | ✨ Special sauce |
|:--------|:------------|:----------------|
| `/plan` | Structure a task before coding | 🧠 `ultrathink` for deep reasoning |
| `/review` | Full 10-point MR review | 📊 Auto-fetches git diff |
| `/mr` | Generate MR description | 🧠 `ultrathink` + pre-fetches git data |
| `/ticket` | Create issue/ticket description | High-effort reasoning |
| `/build` | Build services | Side-effect safe |
| `/test` | Run tests by scope | Auto-diagnoses failures |
| `/lint` | Lint and format | Formatter-aware |
| `/debug` | Investigate failures | 🧠 `ultrathink` for root cause |
| `/serve` | Start services locally | Background-aware |
| `/migrate` | Database migrations | Safety checklist |
| `/db` | Query the database | Non-interactive enforced |
| `/context` | Load all relevant domain docs | High-effort research |
| `/docker` | Docker build, scan, compose | Scanner-integrated |
| `/deps` | Upgrade dependencies, fix CVEs | Decision tree |
| `/diff` | Analyze branch differences | Pre-fetches git data |
| `/git` | Git workflow helpers | Pre-fetches status |
| `/cleanup` | Clean workspace artifacts | Safe defaults |
| `/maintain` | Audit knowledge docs for drift | Full maintenance cycle |
| `/checkpoint` | Save session state | Pre-fetches branch/task |
| `/resume` | Pick up where you left off | Re-loads all context |
| `/bootstrap` | Auto-configure from repo | 🧠 `ultrathink` + 5-phase process |
| `/mcp` | Manage MCP servers | List, add, configure integrations |
| `/squad-plan` | Parallel workstream plan | Claude Squad ACTION_PLAN.md |
| `/research` | Research questions + knowledge | Targeted exploration |
| `/update-code-index` | Scan exports → CODE_INDEX.md | Check before writing new functions |
| `/health` | Config health check | CLAUDE.md, settings, hooks, secrets |

> 🎯 **Unused commands cost zero tokens** — they only load when invoked. Keep them all or delete what you don't need.

### 🪝 Lifecycle Hooks — `.claude/hooks/` (14 files)

These are your guardrails. They run automatically — no tokens, no AI reasoning, just deterministic protection:

| Hook | Fires on | What it does | ⏱️ |
|:-----|:---------|:------------|:---:|
| 🏁 `session-start.sh` | Startup / resume / clear | Injects branch, task state, reminders | 10s |
| 💾 `on-compact.sh` | After compaction | Re-injects context (you never lose track) | 10s |
| 📸 `pre-compact.sh` | Before compaction | Backs up transcript to session-logs | 10s |
| 🔒 `config-protection.sh` | File write/edit | Blocks editing `biome.json`, `tsconfig.json`… | 5s |
| 🚧 `terminal-safety-gate.sh` | Bash command | Blocks pagers, `vi`, unbounded output | 5s |
| 🧹 `pre-commit-quality.sh` | Bash command (git) | Catches `debugger`, secrets, `console.log` | 30s |
| 💡 `suggest-compact.sh` | Any tool use | Nudges `/compact` when context is growing | 5s |
| 🪪 `identity-reinjection.sh` | User prompt | Periodic identity refresh (prevents drift) | 5s |
| 📓 `subagent-stop.sh` | Subagent completes | Logs completion + quality nudge | 5s |
| 🎨 `stop-batch-format.sh` | Session end | Auto-formats all edited files | 120s |
| 📝 `edit-accumulator.sh` | After file edit | Tracks edited files for batch format | 5s |
| 👋 `exit-nudge.sh` | Session end | 6-item exit checklist reminder | 5s |
| 🔐 `permission-denied.sh` | Permission denied | Audit trail — logs denied operations | 5s |
| 🧪 `warn-missing-test.sh` | After file write | Warns on source files without tests (strict profile) | 5s |

> 🛡️ **Hooks are not suggestions — they're enforcement.** A blocked action returns an error message explaining what to do instead.

### 🤖 AI Subagents — `.claude/agents/` (5 files)

Your AI has a team. Each subagent runs in an **isolated context window** — research doesn't pollute your main conversation:

| Agent | Model | What it does | Max turns |
|:------|:------|:------------|:---------:|
| 🔍 **research** | Sonnet | Deep codebase exploration (read-only) — explores 20+ files without touching your context | 20 |
| 📋 **reviewer** | Opus | Expert 10-point MR review with severity classification | 30 |
| ⚔️ **plan-challenger** | Opus | Adversarial plan review — finds real risks before you write code | 20 |
| 📊 **session-reviewer** | Sonnet | Conversation pattern analysis — detects corrections, frustrations, recurring issues | 15 |
| 🔐 **security-auditor** | Opus | Security scanning — secrets, auth gaps, injection, CVEs, DEPLOY/HOLD/BLOCK verdict | 20 |

### 🎓 Skills — `.claude/skills/` (5 files)

Skills are specialized knowledge that activates at the right moment:

| Skill | Type | When it kicks in |
|:------|:-----|:----------------|
| 🧪 **TDD** | Background | Auto-loads when you edit `*.test.*` or `*.spec.*` — enforces test-first discipline |
| 🔎 **Root Cause Trace** | Invocable | 5-step systematic error investigation — no more guessing |
| 📝 **Changelog** | Invocable | Generates release notes from git commits (runs in isolated context) |
| ⚠️ **Careful** | Invocable | Activates safety guards — blocks dangerous commands during sensitive ops |
| 🔍 **Cross-Layer Check** | Invocable | Verifies a symbol exists across all monorepo layers (bundled script) |

### 📏 Path-Scoped Rules — `.claude/rules/` (13 files)

Short, sharp rules that auto-load when the AI touches matching files:

| Rule | Loads on | Key patterns |
|:-----|:---------|:------------|
| 🚧 `terminal-safety.md` | _(always — no paths)_ | Never pager, never interactive, output limits |
| 📏 `quality-gates.md` | _(always — no paths)_ | Function/file size limits, nesting depth, test coverage |
| 🔧 `self-maintenance.md` | Knowledge files | Consistency checks, DRY, quality limits |
| 🧠 `memory.md` | _(always — globs: `**/*`)_ | Read CLAUDE_ERRORS.md before code, memory layers |
| 📖 `domain-learning.md` | _(always — globs: `**/*`)_ | Persist business facts to `.claude/rules/domain/` |
| 💡 `practice-capture.md` | _(always — globs: `**/*`)_ | Capture lessons on workarounds/backtracks |
| 🤖 `agents.md` | _(always — globs: `**/*`)_ | Delegation tree, agent teams, model routing |
| 📘 `typescript.md` | `**/*.ts`, `**/*.tsx` | Strict mode, Zod at boundaries, no barrel re-exports |
| 🐍 `python.md` | `**/*.py` | Type hints, Pydantic, pytest, ruff, pathlib |
| 🖥️ `nodejs-backend.md` | `src/api/**`, `routes/**` | Repository pattern, typed routes, async middleware |
| ⚛️ `react.md` | `**/*.tsx`, `**/*.jsx` | TanStack Query, stable keys, custom hook extraction |
| 📂 `domain/_template.md` | _(template)_ | Business domain template — copy for each domain |
| 📄 `_template-domain-rule.md` | _(template)_ | Copy → customize → profit |

### 🤝 GitHub Copilot — `.github/` (8 files)

Same brain, different interface. Copilot gets its own optimized config:

| File | What it does |
|:-----|:------------|
| `copilot-instructions.md` | Root Copilot instructions (mirrors CLAUDE.md essentials) |
| `instructions/general.instructions.md` | Global style/arch/safety rules (`**/*`) |
| `instructions/terminal-safety.instructions.md` | Terminal safety for all files (`**/*`) |
| `instructions/testing.instructions.md` | Test file rules (`**/*.{test,spec}.*`) |
| `instructions/_template.instructions.md` | Template for new scoped instructions |
| `prompts/generate-tests.prompt.md` | One-click test generation |
| `prompts/review-rules.prompt.md` | One-click code review against project rules |
| `prompts/_template.prompt.md` | Template for new prompts |

### 🧠 Memory — `claude/tasks/` (5 files)

The AI's persistent memory across sessions:

| File | What it stores |
|:-----|:--------------|
| 📓 `lessons.md` | Accumulated wisdom — mistakes, corrections, discoveries. Read at every session start. |
| 📝 `todo.md` | Current task plan with checkable items. Survives compaction. |
| 🐛 `CLAUDE_ERRORS.md` | Structured error log — promotes to rules after 3+ recurrences. |
| `.gitkeep` | Ensures directory is tracked in git |
| `.gitignore` | Excludes temp files (counters, accumulators) from git tracking |

### 🔧 Scripts — `claude/scripts/` (12 files)

The automation backbone — pure bash, zero token cost:

| Script | What it does | Speed |
|:-------|:------------|:-----:|
| 🔍 `discover.sh` | Single-pass repo scanner — detects stack, frameworks, commands (replaces 15+ manual commands) | ~2s |
| 📝 `populate-templates.sh` | Batch fills ~70 `{{PLACEHOLDER}}` values + generates per-service `CLAUDE.md` stubs for monorepo services | ~3s |
| ✅ `post-bootstrap-validate.sh` | Unified validation — runs validate + canary + auto-fix | ~10s |
| 🔎 `validate.sh` | 120-check template validator — file existence, hook executability, JSON validity, placeholder integrity | ~5s |
| 🏥 `canary-check.sh` | LIVE config health — token budget, stale refs, rule count, @imports | ~2s |
| 🛡️ `phase2-verify.sh` | Phase 2 data-integrity check — confirms lessons/todo/settings survived Smart Merge | ~1s |
| 📂 `generate-service-claudes.sh` | Auto-generates per-service `CLAUDE.md` stubs for each monorepo service directory | ~2s |
| 🐙 `generate-copilot-docs.sh` | Mirrors `claude/*.md` → `.github/copilot/` for GitHub Copilot users | ~2s |
| 🔌 `toggle-claude-mem.sh` | Toggle claude-mem plugin on/off — saves API quota | instant |
| 🔌 `setup-plugins.sh` | All-in-one bootstrap plugin management — install, disable, verify, update CLAUDE.md | ~5s |
| ✅ `check-creative-work.sh` | Creative work gate check — architecture, placeholders, domain docs, IDE section | ~1s |
| 🔁 `tdd-loop-check.sh` | TDD enforcement Stop hook — fails the loop if tests were skipped after code changes | ~1s |

---

## 🔬 Deep Dives

### 📂 The 10 Configuration Categories

Every file in the Brain belongs to one of these categories. Here's what each one does and why it matters:

#### 1. 📋 Root Instructions (`CLAUDE.md`)

The brain of the brain. Auto-loaded every conversation. Contains:
- **Operating Protocol** (8 rules) — plan first, delegate, prove it works, fix bugs yourself
- **Exit Checklist** (6 items) — the secret weapon against knowledge drift
- **Token Cost Strategy** (9 optimizations) — subagents, effort levels, on-demand loading
- **Terminal Rules** — universal safety patterns
- **Critical Patterns** — your project's non-negotiable rules
- **Review Protocol** — 10-point checklist before any MR

#### 2. 📚 Domain Knowledge (`claude/`)

On-demand deep knowledge. A lookup table in `CLAUDE.md` tells the AI which file to read:

```
Task about building?   → Read claude/build.md
Task about security?   → Read claude/cve-policy.md
Task about auth?       → Read claude/keycloak.md
```

**Adding a new domain?** Create `claude/<domain>.md` → add to lookup table → done.

#### 3. 📏 Path-Scoped Rules (`.claude/rules/`)

Short (≤40 lines) rules that auto-load when the AI touches matching files:

```yaml
---
paths:
  - "core/auth/**"
  - "**/keycloak*"
---
# Auth Domain Rules
- Never store tokens in localStorage — use httpOnly cookies
- Always validate JWT expiry before trusting claims
```

> 🎯 **This is where specificity shines.** Global rules in `CLAUDE.md`, domain rules in path-scoped files.

#### 4. ⚡ Slash Commands (`.claude/commands/`)

Pre-built commands with YAML frontmatter for effort level, tool permissions, and dynamic context:

```yaml
---
description: Run tests for services
disable-model-invocation: true
effort: low
argument-hint: "[all|service-name|ci|coverage]"
---
```

#### 5. 🤖 AI Subagents (`.claude/agents/`)

Isolated context windows for expensive operations. Your main conversation stays clean:
- **Research** — explore 20+ files without polluting main context
- **Reviewer** — 10-point code review with severity classification
- **Plan-Challenger** — find real risks before writing a single line

#### 6. 🎓 Skills (`.claude/skills/`)

Background and invocable knowledge:
- **TDD** — auto-loads on test files, enforces write-test-first
- **Root Cause Trace** — 5-step systematic error investigation
- **Changelog** — generate release notes from git
- **Careful** — block dangerous commands during sensitive ops
- **Cross-Layer Check** — verify a symbol exists across all monorepo layers

#### 7. 🪝 Lifecycle Hooks (`.claude/hooks/`)

Deterministic automation — zero token cost. 14 hooks across 8 lifecycle events:
- 🏁 **Session start** — inject branch, task state, reminders
- 💾 **Compaction** — backup transcript, re-inject context
- 🔒 **Config protection** — block editing linter/compiler configs
- 🚧 **Terminal safety** — block `vi`, pagers, unbounded output
- 🧹 **Commit quality** — catch debugger statements, secrets
- 🎨 **Batch format** — format all edited files on session end
- 👋 **Exit checklist** — 6-item reminder before yielding

#### 8. ⚙️ Settings (`.claude/settings.json`)

Centralized project config:
- **Tool permissions** — allow/deny patterns for commands
- **Hook registration** — all 14 hooks with unique IDs and timeouts
- **Environment** — autocompact threshold, token limits, bash timeouts
- **Status line** — branch display in Claude Code UI

#### 9. 🤝 GitHub Copilot (`.github/`)

Parallel config for Copilot users:
- **Scoped instructions** — different rules for different file types
- **Reusable prompts** — one-click test generation, code review

#### 10. 🔌 Plugin Ecosystem

One plugin is auto-installed by bootstrap:

| Plugin | Purpose | Default state |
|:-------|:--------|:------------:|
| 🧠 **claude-mem** | Persistent cross-session memory (SQLite + ChromaDB) | ⚠️ Disabled (quota protection) |

Plugin hooks fire **in parallel** with project hooks — independent systems, zero conflicts. See `claude/plugins.md` for the full coexistence matrix and the optional obsidian-mind vault companion.

---

### 🔄 Bootstrap: How It Actually Works

The bootstrap runs in **5 optimized phases**. Scripts handle the grunt work; the AI focuses on what requires reasoning.

#### Phase 1: Discovery + Mode Detection (~2s) 🔍

Runs `claude/scripts/discover.sh` — a single script that replaces 15+ individual detection commands:

- Detects existing config → chooses **FRESH** or **UPGRADE** mode
- Scans for languages (with file counts), package manager, runtime
- Detects formatter/linter with config files, style rules, static analyzers
- Detects test frameworks (unit + E2E), 1100+ frameworks across all ecosystems
- Derives build/test/lint/serve/migrate/db/deps commands
- Outputs structured KEY=VALUE pairs to `claude/tasks/.discovery.env`

> 🆕 **FRESH mode** — no existing config → install everything from template
>
> ♻️ **UPGRADE mode** — existing config detected → smart merge, preserve your stuff

#### Phase 2: Smart Merge (UPGRADE only) 🔀

The most important phase when upgrading. Your stuff is **sacred**:

| What | Strategy | Guarantee |
|:-----|:---------|:----------|
| 📓 `lessons.md` | **NEVER TOUCH** | Your accumulated wisdom is untouchable |
| 📝 `todo.md` | **NEVER TOUCH** | Your active task state is untouchable |
| 📚 Domain docs | **PRESERVE** existing, add missing | Your knowledge stays intact |
| ⚙️ `settings.json` | **DEEP MERGE** by hook ID | Your settings win on conflict |
| ⚡ Commands | **ADD MISSING** | Your commands kept, new ones added |
| 🪝 Hooks | **ADD MISSING** | Your hooks kept, new ones added |
| 📋 `CLAUDE.md` | **ENHANCE** | Missing sections appended with markers |
| 🚫 `.claudeignore` | **UNION** | Your exclusions kept, new ones added |
| 🤝 `.github/` | **ADD MISSING** | Your Copilot config kept, new ones added |

#### Phase 3: Template Population (~3s mechanical + ~1-2m creative) 📝

**Step 1 — Batch mechanical** (`populate-templates.sh`):
Reads discovery output → replaces ~70 `{{PLACEHOLDER}}` values across all files in one pass. Also generates per-service `CLAUDE.md` stubs for each monorepo service directory.

**Step 2 — Creative** (AI reasoning, **adaptive depth**):
Fills what machines can't: architecture docs, domain analysis, critical patterns specific to *your* codebase.

The AI runs **8 domain-detection greps** to identify domains present in the codebase:

| Domain grep detects | → Creates |
|:--------------------|:---------|
| Kafka / RabbitMQ / SQS / NATS | `claude/messaging.md` + `.claude/rules/kafka-safety.md` |
| Knex / DataSource / multi-DB | `claude/database.md` + `.claude/rules/database.md` |
| StatusEnum / state machine | `claude/lifecycle.md` + `.claude/rules/lifecycle.md` |
| Keycloak / Auth0 / JWT | `claude/auth.md` + `.claude/rules/auth.md` |
| Webhook delivery / idempotent | `claude/webhooks.md` + `.claude/rules/webhooks.md` |
| Adapter factory / integrations | `claude/adapters.md` + `.claude/rules/adapters.md` |
| Report / analytics / XSLT | `claude/reporting.md` + `.claude/rules/reporting.md` |
| Signup / registration / onboarding | `claude/enrollment.md` + `.claude/rules/enrollment.md` |

**Adaptive escalation**: If ≥3 domain docs are created, domain rules (`.claude/rules/<domain>.md`) and domain skills (`.claude/skills/<domain>/SKILL.md`) automatically become **mandatory** — not optional. The more complex your codebase, the deeper the bootstrap goes.

#### Phase 3.5: MCP Server Configuration (auto-suggest only) 🔌

The AI scans the discovery output and adds **MCP server suggestions** to the final report — no user input required:
- `DATABASE` detected → suggest `postgres` or `mysql` MCP server
- CI/GitHub detected → suggest `github` MCP server
- Web frontend detected → suggest `web-search` MCP server
- Docker/K8s detected → suggest `filesystem` MCP server

Users configure their chosen servers post-bootstrap: `/mcp add <server>` · Registry: [registry.smithery.ai](https://registry.smithery.ai)

#### Phase 4: Plugin Installation 🔌

Installs **claude-mem** (disabled by default for quota protection). If installation fails, the report includes the manual install command.

#### Phase 5: Validate + Report + Cleanup (~10s) ✅

Runs `post-bootstrap-validate.sh`:
- ✅ 120 validation checks
- 🏥 Live health check (canary)
- 🔧 Auto-fixes common issues (hook permissions, JSON trailing commas)
- 🔍 Checks for remaining `{{PLACEHOLDER}}` values

**Report:** FRESH shows what was installed. UPGRADE shows what was **preserved** vs **added** — so you know exactly what changed. Both include TEAM/SOLO mode instructions and MCP suggestions.

**Cleanup:** After the report, bootstrap scaffolding (`claude/bootstrap/`) is deleted — it's single-use. Future upgrades: re-clone the template and run `/bootstrap` again.

---

### ♻️ Upgrading an Existing Config

Already have a Brain? Here's how to upgrade safely:

```bash
# 1. Stage the template
git clone https://github.com/y-abs/claude-code-brain-bootstrap.git .claude-upgrade
rm -rf .claude-upgrade/.git

# 2. Run bootstrap — it detects UPGRADE mode automatically
# /bootstrap

# 3. Review changes
# Upgraded sections are marked: <!-- Added by template upgrade [date] -->

# 4. Commit
git add CLAUDE.md .claudeignore claude/ .claude/ .github/
git commit -m "chore: upgrade Claude Code configuration"
```

**What the upgrade preserves (sacred):**
- `claude/tasks/lessons.md` + `todo.md` — never touched
- Your domain docs — kept as-is, enriched only if shallow
- Your custom commands, hooks, rules — kept, new ones added alongside

**What the upgrade adds:**
- Missing commands, hooks, agents, rules from template
- Enhanced `CLAUDE.md` sections (new ones appended with upgrade markers)
- Deep-merged `settings.json` (your hooks kept, new hook IDs added)

**Gap scan (new in UPGRADE mode):** The upgrade automatically runs 8 domain-detection greps and compares results against existing `claude/*.md` files. Missing domain docs get flagged as mandatory to create — so upgrading an old bootstrap never leaves knowledge gaps.

The `.claude-upgrade/` staging directory is cleaned up automatically.

---

## 🏷️ Placeholder Reference

The bootstrap replaces every `{{PLACEHOLDER}}`. Here's the full inventory:

<details>
<summary><strong>📋 All 35+ placeholders (click to expand)</strong></summary>

| Placeholder | Category | Example |
|:------------|:---------|:--------|
| `{{PROJECT_NAME}}` | Identity | "Acme API", "my-saas-app" |
| `{{PROJECT_DESCRIPTION}}` | Identity | "Event-driven platform for..." |
| `{{PACKAGE_MANAGER}}` | Build | pnpm, npm, yarn, pip, cargo, go |
| `{{RUNTIME}}` | Build | "Node ≥22", "Python ≥3.11", "Go 1.22" |
| `{{FORMATTER}}` | Style | Biome, Prettier, Ruff, rustfmt, gofmt |
| `{{LINTER}}` | Style | Biome, ESLint, Ruff, clippy, golangci-lint |
| `{{LINTER_CONFIG_FILE}}` | Style | biome.json, .eslintrc, pyproject.toml |
| `{{STYLE_RULES}}` | Style | "Single quotes, 2-space indent, 120 chars" |
| `{{TEST_FRAMEWORK}}` | Testing | Vitest, Jest, Mocha, pytest, JUnit, cargo test |
| `{{BUILD_CMD_ALL}}` | Build | "pnpm build", "cargo build --release" |
| `{{BUILD_CMD_SINGLE}}` | Build | "pnpm nx run @scope/service:build" |
| `{{TEST_CMD_ALL}}` | Testing | "pnpm test", "pytest", "cargo test" |
| `{{TEST_CMD_SINGLE}}` | Testing | "pnpm nx run @scope/service:test" |
| `{{TEST_CMD_CI}}` | Testing | "pnpm ci:test", "pytest --ci" |
| `{{TEST_CMD_COVERAGE}}` | Testing | "pnpm test --coverage" |
| `{{LINT_CHECK_CMD}}` | Quality | "pnpm lint", "ruff check" |
| `{{LINT_FIX_CMD}}` | Quality | "pnpm lint:write", "ruff check --fix" |
| `{{FORMAT_CMD}}` | Quality | "pnpm format", "ruff format" |
| `{{FORMATTER_COMMAND}}` | Hooks | "biome check --write", "ruff format" |
| `{{FORMATTABLE_EXTENSIONS}}` | Hooks | ".js\|.ts\|.tsx", ".py" |
| `{{SOURCE_EXTENSIONS}}` | Hooks | ".js\|.ts\|.tsx\|.jsx" |
| `{{SCANNER_TOOL}}` | Security | Trivy, Snyk, Dependabot, npm audit |
| `{{SCAN_COMMAND}}` | Security | "pnpm audit", "trivy fs ." |
| `{{SERVE_CMD_ALL}}` | Dev | "pnpm serve", "docker compose up" |
| `{{SERVE_CMD_FRONTEND}}` | Dev | "pnpm dev", "npm run dev" |
| `{{SERVE_CMD_BACKEND}}` | Dev | "pnpm nx run server:serve" |
| `{{MIGRATE_UP_CMD}}` | Database | "npx knex migrate:latest" |
| `{{MIGRATE_DOWN_CMD}}` | Database | "npx knex migrate:rollback" |
| `{{DB_QUERY_CMD}}` | Database | "psql -c", "mysql -e" |
| `{{DOMAIN_N}}` | Knowledge | "api", "auth", "database", "messaging" |
| `{{DIR_N}}` | Architecture | "src/", "core/", "packages/", "lib/" |
| `{{SERVICE_NAME}}` | Architecture | "api-gateway", "auth-service" |
| `{{CRITICAL_PATTERN_N}}` | Rules | "Never emit side effects in transactions" |
| `{{PROTECTED_FILE_N}}` | Hooks | "biome.json", "pyproject.toml" |
| `{{LAYER_N}}` | Testing | "frontend", "backend", "shared" |

</details>

---

## 🌍 Stack-Specific Examples

The Brain works with any stack. Here's what detection + population looks like for the most common ones:

<details>
<summary><strong>🟦 Node.js / TypeScript (NestJS, React, Vite)</strong></summary>

```
Package Manager: pnpm 10+
Runtime:         Node ≥22
Formatter:       Biome
Test:            Vitest (frontend), Mocha (backend)
Build:           pnpm nx run-many --target=build
Monorepo:        Nx + pnpm workspaces
```
</details>

<details>
<summary><strong>🐍 Python (Django, FastAPI)</strong></summary>

```
Package Manager: uv / pip
Runtime:         Python ≥3.11
Formatter:       Ruff
Test:            pytest
Build:           uv build / python -m build
```
</details>

<details>
<summary><strong>🦀 Rust</strong></summary>

```
Package Manager: cargo
Runtime:         Rust stable
Formatter:       rustfmt
Linter:          clippy
Test:            cargo test
Build:           cargo build --release
```
</details>

<details>
<summary><strong>☕ Java (Spring Boot, Maven)</strong></summary>

```
Package Manager: Maven / Gradle
Runtime:         Java 21
Formatter:       google-java-format / spotless
Test:            JUnit 5
Build:           mvn clean package / gradle build
```
</details>

<details>
<summary><strong>🐹 Go</strong></summary>

```
Package Manager: go mod
Runtime:         Go 1.22+
Formatter:       gofmt / goimports
Linter:          golangci-lint
Test:            go test ./...
Build:           go build ./...
```
</details>

---

## 🎨 Make It Yours

Extending the Brain is simple — one file, one registration:

| To add… | Create… | Registration |
|:--------|:--------|:------------|
| 📚 Domain knowledge | `claude/<domain>.md` | Add row to `CLAUDE.md` lookup table |
| 📏 Path-scoped rule | `.claude/rules/<domain>.md` | Automatic (matched by file path) |
| ⚡ Slash command | `.claude/commands/<name>.md` | Automatic (discovered by Claude Code) |
| 🪝 Lifecycle hook | `.claude/hooks/<name>.sh` | Register in `.claude/settings.json` |
| 🤖 Subagent | `.claude/agents/<name>.md` | Automatic |
| 🎓 Skill | `.claude/skills/<name>.md` | Automatic (matched by `paths:` globs) |
| 🔌 Plugin | `claude plugin install <name>` | Document in `claude/plugins.md` |
| 🤝 Copilot instruction | `.github/instructions/<name>.instructions.md` | Automatic (matched by glob) |
| 💬 Copilot prompt | `.github/prompts/<name>.prompt.md` | Automatic |

Three worked examples in `claude/_examples/` — study them, then delete them.

<details>
<summary><strong>📚 Adding a new domain doc</strong></summary>

1. Create `claude/<domain>.md` (see `claude/_examples/` for the pattern)
2. Add a row to the lookup table in `CLAUDE.md`
3. Create `.claude/rules/<domain>.md` with critical patterns (≤40 lines)
4. Update `claude/README.md` inventory
</details>

<details>
<summary><strong>⚡ Adding a new slash command</strong></summary>

1. Create `.claude/commands/<name>.md` with YAML frontmatter:
   ```yaml
   ---
   description: What this command does (≤127 chars)
   disable-model-invocation: true  # for side-effect commands
   effort: low                      # low = quick, high = deep reasoning
   allowed-tools: Bash(command *)   # pre-approve specific tools
   argument-hint: "[expected args]"
   ---
   ```
2. Add `## Instructions` section with step-by-step actions
3. For live data injection: `` !`git branch --show-current` ``
4. For deep reasoning: include the word `ultrathink` in the body
5. Update `claude/README.md` commands table
</details>

<details>
<summary><strong>🪝 Adding a new hook</strong></summary>

1. Create `.claude/hooks/<name>.sh`
   - Must `exit 0` by default (non-zero blocks the action)
   - `exit 2` = block with message
   - Use `${CLAUDE_PROJECT_DIR:-.}` for paths
2. Make executable: `chmod +x .claude/hooks/<name>.sh`
3. Register in `.claude/settings.json` with unique ID + timeout
4. Update `claude/README.md` hooks table
</details>

<details>
<summary><strong>📏 Adding a new path-scoped rule</strong></summary>

1. Copy `.claude/rules/_template-domain-rule.md`
2. Set `paths:` to match your target files (glob patterns)
3. Keep ≤40 lines — reference full `claude/*.md` doc for details
4. Update `claude/README.md` rules table
</details>

<details>
<summary><strong>🤖 Adding a new subagent</strong></summary>

1. Create `.claude/agents/<name>.md` with YAML frontmatter
2. Set `model:` to the optimal model for the task (e.g., `opus` for security/review). Omit it for lightweight agents (research, pattern matching) — they inherit the session model. Agents fall back gracefully when the declared model is unavailable (local LLMs, alternative providers).
3. Keep `allowed-tools:` minimal — read-only for research agents
4. Set `maxTurns:` to prevent runaway (recommend: 20-30)
5. Include anti-hallucination protocol (grep before claiming)
</details>

<details>
<summary><strong>🎓 Adding a new skill</strong></summary>

1. Create `.claude/skills/<name>.md` with YAML frontmatter:
   ```yaml
   ---
   description: What this skill teaches
   user-invocable: false  # true = slash-invokable, false = background auto-load
   paths:
     - "src/auth/**"
     - "**/security*"
   ---
   ```
2. **Background skills** (`user-invocable: false`) — auto-load when the AI touches files matching `paths:`. Keep focused on one domain.
3. **Invocable skills** (`user-invocable: true`) — the user triggers them explicitly (e.g., `/root-cause-trace`). Can run in `context: fork` to isolate from main conversation.
4. Update `claude/README.md` skills table
</details>

<details>
<summary><strong>🔌 Adding a new plugin</strong></summary>

1. Install the plugin globally:
   ```bash
   claude plugin install <plugin-name>@<author>
   ```
2. Plugin hooks fire **in parallel** with project hooks — no registration needed in `settings.json`
3. Document in `claude/plugins.md`: purpose, default state, quota impact, toggle commands
4. If the plugin has high API cost (e.g., `PostToolUse(*)` hooks), add a toggle script to `claude/scripts/`
5. Test hook coexistence: verify project hooks still fire correctly alongside plugin hooks
</details>

---

## 📐 Best Practices

The wisdom from hundreds of sessions, distilled:

| Practice | Guideline | Why |
|:---------|:----------|:----|
| 📋 **CLAUDE.md size** | ≤200 lines | Loaded every conversation — bigger = more expensive |
| 🎯 **Always-on budget** | <10K tokens | CLAUDE.md + @imports should stay lean |
| 📏 **Rule count** | ≤150 total | AI starts deprioritizing above ~150 |
| 📄 **Path-scoped rules** | ≤40 lines each | Summary format — point to full docs for details |
| ⏱️ **Hook timeouts** | 5s quick / 30s git / 120s format | Prevent hangs |
| 📁 **Hook paths** | `${CLAUDE_PROJECT_DIR:-.}` | Handles empty env vars at startup |
| 📓 **Lessons file** | Archive when >500 lines | Too long = AI skims it |
| 📁 **Temp files** | `./claude/tasks/` only | Survives across tools and sessions |
| ✍️ **Command descriptions** | ≤127 chars, front-loaded | Gets truncated above 127 |
| 🔧 **Knowledge maintenance** | `/maintain` + exit checklist | Prevents docs from rotting |
| 🤖 **Subagent threshold** | 5+ files to explore → use `research` | Saves main context tokens |
| 📋 **Exit checklist** | 6 items, every turn | The #1 mechanism for continuous improvement |

---

## ❓ FAQ

<details>
<summary><strong>🤝 Does this work with GitHub Copilot?</strong></summary>

Yes! The `.github/` directory contains Copilot-native config: `copilot-instructions.md` (root), `instructions/` (scoped by glob), and `prompts/` (reusable). The `.claude/` directory is Claude Code specific. `claude/bootstrap/PROMPT.md` works with any AI.
</details>

<details>
<summary><strong>🤝 Is this solo or team-friendly?</strong></summary>

Both! **TEAM mode** (default): commit everything — every developer gets the same AI experience. Knowledge improvements from one session benefit everyone on the next `git pull`.

**SOLO mode**: personal config, not committed. Add `CLAUDE.md`, `claude/`, `.claude/`, `.claudeignore`, `.mcp.json` to `.gitignore`. The `.github/` Copilot config stays committed — it benefits the whole team. Switch modes at any time.
</details>

<details>
<summary><strong>🏢 Does this support monorepos?</strong></summary>

Designed for them. Battle-tested on monorepos with 50+ services. Bootstrap detects workspace structure (Nx, Turborepo, pnpm workspaces, Cargo workspaces) and:
- Generates per-service `CLAUDE.md` stubs for each service directory (auto-loaded when working in that service)
- Derives service-scoped build/test commands
- Escalates domain depth: with ≥3 domains detected, rules and skills become mandatory
</details>

<details>
<summary><strong>💰 What's the token cost?</strong></summary>

~3-4K tokens always-loaded. Domain docs load on-demand (~1-2K each). Subagents run in isolated context — research doesn't eat your main window. The three-tier architecture means you're not paying for context you don't need.
</details>

<details>
<summary><strong>🗑️ Can I delete the examples?</strong></summary>

Absolutely. `claude/_examples/` is training material — delete them once you've created your own domain docs. They're not used at runtime.
</details>

<details>
<summary><strong>♻️ How do I update from the template?</strong></summary>

Update hooks, settings, and commands (generic layer). Don't overwrite your `claude/*.md` domain docs (project-specific). Or use `/bootstrap` — it detects upgrade mode and merges intelligently.
</details>

<details>
<summary><strong>⚡ What if I don't use all 26 commands?</strong></summary>

No cost for unused commands — they only load when invoked. Delete what you don't need, or keep them around for the day you do.
</details>

<details>
<summary><strong>💻 Does this work with VS Code?</strong></summary>

Yes. Claude Code runs in any terminal. VS Code users get the full `.claude/` experience. The `.github/` integration works with GitHub Copilot in VS Code too.
</details>

<details>
<summary><strong>🔐 Can the AI push to main?</strong></summary>

No. `git push` is blocked by default (deny rule + terminal-safety hook). The AI presents a summary and waits for your confirmation. Config-protection blocks editing linter configs. Commit-quality catches secrets and debugger statements.
</details>

<details>
<summary><strong>🔌 Are plugins installed automatically?</strong></summary>

Yes — Phase 4 installs **claude-mem** (disabled by default, quota protection). If installation fails, the report provides the manual install command.

> **obsidian-mind** is a companion Obsidian vault — not a Claude Code plugin. It's cloned separately: `git clone https://github.com/breferrari/obsidian-mind.git`
</details>

<details>
<summary><strong>⏭️ Can I skip plugin installation?</strong></summary>

If the plugin fails to install (network, auth), it's documented in the report with the manual command. The rest of the config works perfectly without it. Install later anytime:
```bash
claude plugin install claude-mem@thedotmack
```
</details>

---

## 🔌 Plugin Ecosystem — Deep Dive

The bootstrap installs **one Claude Code plugin**. Additionally, [obsidian-mind](https://github.com/breferrari/obsidian-mind) is an optional companion Obsidian vault (cloned separately) that pairs well with claude-mem:

| | Type | Answers | Analogy | Default |
|:|:-----|:--------|:--------|:-------:|
| 🧠 **[claude-mem](https://github.com/thedotmack/claude-mem)** | Claude Code plugin | *"What did I do across sessions?"* | git reflog — automatic forensic trail | ⚠️ Disabled |
| 📖 **[obsidian-mind](https://github.com/breferrari/obsidian-mind)** | Obsidian vault (clone separately) | *"What do I know about this?"* | git commits — curated knowledge graph | Optional |

**The synergy:** claude-mem captures raw material → obsidian-mind curates it into durable knowledge.

```bash
# claude-mem eats API quota (PostToolUse(*) fires after EVERY tool call)
bash claude/scripts/toggle-claude-mem.sh on       # Enable for exploratory sessions
bash claude/scripts/toggle-claude-mem.sh off      # Disable for heavy batch work
bash claude/scripts/toggle-claude-mem.sh status   # Check current state

# obsidian-mind — clone as a separate Obsidian vault
git clone https://github.com/breferrari/obsidian-mind.git ~/my-knowledge-vault
```

> 📚 **Full plugin reference:** [claude/plugins.md](../plugins.md) — hook coexistence matrix, quota management, obsidian-mind setup guide.

### Adding other plugins

Claude Code plugins are installed globally (`~/.claude/plugins/`). They coexist with project config without modification. If a plugin adds hooks for the same lifecycle events, both fire.

---

## 🧬 From Instructions to Guarantees

Every AI coding tool reads instructions. None of them can enforce those instructions on themselves.

You write *"never edit tsconfig.json"* in your config. The AI reads it. Then context pressure builds, and it edits `tsconfig.json` anyway. You write *"always use --no-pager."* It triggers a pager and hangs your terminal. You correct it — it apologizes. Next session? Same mistake, same apology.

**This isn't a bug. It's an architectural gap.** Instructions are text. Text is advisory. Advisory gets overridden.

Brain replaces advisory text with real mechanisms:

| What you get | How it actually works |
|:---|:---|
| 🔒 **Dangerous actions are blocked, not just discouraged** | Safety hooks intercept *before* execution — blocking dangerous commands before they run. 14 lifecycle hooks total across all events: bash scripts, deterministic, zero-token, unforgeable |
| 🧠 **The AI never makes the same mistake twice** | `lessons.md` persists across sessions, compactions, restarts — read at every session start, impossible to skip |
| 🔄 **Knowledge never goes stale** | Exit checklist catches drift every turn · `/maintain` audits all docs · self-maintenance rule fires on every knowledge edit |
| ⚡ **One command replaces 15 min of prompt engineering** | `/review` runs a 10-point protocol · `/mr` generates descriptions · `/debug` traces root causes — 26 commands, pre-built, consistent |
| 🔍 **Your entire stack understood in 2 seconds, zero tokens** | `discover.sh` — 25+ languages, 1100+ frameworks, 21 package managers — pure bash, runs before the AI even wakes up |
| 🤖 **Research doesn't eat your context window** | 5 subagents run in isolated contexts — explore 20+ files, review code, challenge plans — your main conversation stays clean |
| 🤝 **One brain, three AI tools** | Write knowledge once → Claude Code, GitHub Copilot, and any LLM all read it — switch tools without starting over |

> 🎯 **100+ files isn't complexity. It's the minimum architecture where instructions become guarantees.**

### 📊 The Numbers

| Metric | Count |
|:-------|------:|
| 📂 Files | 100+ |
| ⚡ Slash commands | 26 |
| 🪝 Lifecycle hooks | 14 |
| 📏 Golden rules | 24 |
| 🎓 Skills | 5 |
| ✅ Validation checks | 120 |
| 🏷️ Configurable placeholders | 35+ |
| 🔄 Bootstrap phases | 5 |
| 🤖 AI subagents | 5 |
| 🔌 Plugins | 1 |
| 📋 Exit checklist items | 6 |
| 🔍 Domain-detection greps | 8 |
| 🐚 Shell scripts (ShellCheck CI) | 28 |

---

## 🤝 Contributing

We love contributions! The most impactful areas:

| Area | Difficulty | Example |
|:-----|:----------:|:--------|
| 🔍 **Stack detection** | 🟢 Easy | New language/framework in `discover.sh` |
| 📚 **Documentation** | 🟢 Easy | Typo fix, better examples, clearer explanations |
| ⚡ **Slash commands** | 🟡 Medium | New workflow command for any project |
| 📏 **Path-scoped rules** | 🟡 Medium | New domain rule in `.claude/rules/` |
| 🪝 **Lifecycle hooks** | 🟠 Advanced | Safety patterns, quality gates |
| 🤖 **Agents / Skills** | 🟠 Advanced | New subagent or skill |

All contributions must be **domain-agnostic** — no project-specific content.

👉 **[Full step-by-step guide → CONTRIBUTING.md](../../CONTRIBUTING.md)** — fork, branch, validate, submit. Includes walkthrough examples for adding a language, a command, and a hook.

🐛 **Found a bug?** → [Open an issue](https://github.com/y-abs/claude-code-brain-bootstrap/issues/new/choose) — structured templates for bug reports and feature requests.

📋 **PR template auto-loads** with a 9-point checklist when you submit.

### 🔄 CI Pipeline

Every push to `main` and every pull request runs **3 automated checks** via GitHub Actions:

| Job | What it verifies | Why it matters |
|:----|:----------------|:---------------|
| ✅ **Template Validation** | Runs `validate.sh` — 120 checks for file existence, hook executability, JSON validity, placeholder integrity, domain-free verification | If this fails, the template is broken. This is the test suite. |
| 🐚 **ShellCheck** | Lints all 28 `.sh` scripts (hooks, discover.sh, utilities) at `warning` severity | These scripts run on **end-user machines** during Claude Code sessions. A bug in `terminal-safety-gate.sh` silently skips protection. ShellCheck catches it before users do. |
| 🔗 **Documentation Links** | Checks all internal/relative links across every `.md` file (offline, including `#fragment` anchors) | README → CONTRIBUTING → DETAILED_GUIDE have 20+ cross-references. A broken link in the public README means a confused first-time user. |

All three must pass before a PR can be merged. The CI badge on the README shows the current status.

> 💡 **Run locally before pushing:** `bash claude/scripts/validate.sh` covers the template checks. Install [ShellCheck](https://github.com/koalaman/shellcheck#installing) for local script linting.

---

## ⚖️ License

MIT — see [LICENSE](../../LICENSE).

---

<p align="center">
  <strong>You made it to the end. You're ready. 🚀</strong><br>
  <em>Drop this into your repo. Run <code>/bootstrap</code>. Ship code 10× faster.</em>
</p>

