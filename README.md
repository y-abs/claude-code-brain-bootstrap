<p align="center">
  <a href="https://github.com/y-abs/claude-code-brain-bootstrap">
    <img src="https://img.shields.io/badge/ᗺB-Brain%20Bootstrap-6B21A8?style=for-the-badge&labelColor=1e1b4b" alt="ᗺB Brain Bootstrap" />
  </a>
</p>

<h1 align="center">ᗺB - Brain Bootstrap</h1>
<p align="center"><em>Give your AI coding assistant the one thing it's missing:<br>deep knowledge of your codebase.</em></p>
<p align="center"><sub>by <a href="https://github.com/y-abs">y-abs</a></sub></p>
<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"></a>
  <a href="https://github.com/y-abs/claude-code-brain-bootstrap/actions/workflows/ci.yml"><img src="https://github.com/y-abs/claude-code-brain-bootstrap/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="#"><img src="https://img.shields.io/badge/Claude_Code-Ready-blueviolet" alt="Claude Code"></a>
  <a href="#"><img src="https://img.shields.io/badge/GitHub_Copilot-Ready-brightgreen" alt="GitHub Copilot"></a>
  <a href="#-write-once-read-everywhere"><img src="https://img.shields.io/badge/Ollama_%7C_LM_Studio-Local_LLMs_Ready-ff6f00" alt="Local LLMs Ready"></a>
</p>

<p align="center">
  <a href="#-sound-familiar">The Problem</a> &nbsp;·&nbsp;
  <a href="#-what-changes-when-you-add-a-brain">What Changes</a> &nbsp;·&nbsp;
  <a href="#-get-started-in-5-minutes">Quick Start</a> &nbsp;·&nbsp;
  <a href="#-how-it-works-under-the-hood">How It Works</a> &nbsp;·&nbsp;
  <a href="#-whats-inside">What's Inside</a> &nbsp;·&nbsp;
  <a href="#-safety-defense-in-depth">Safety</a> &nbsp;·&nbsp;
  <a href="#-plugin-ecosystem">Plugins</a> &nbsp;·&nbsp;
  <a href="#-make-it-yours">Extend It</a> &nbsp;·&nbsp;
  <a href="#-faq">FAQ</a> &nbsp;·&nbsp;
  <a href="#-contributing">Contribute</a>
</p>

---

## 🤔 Sound Familiar?

You install Claude Code. You open your 50-service monorepo. You ask it to add a feature.

It doesn't know `yarn turbo build` is the right command, not `npm run build`, that you use Biome, not Prettier.
It doesn't know your `@company/utils` package already has a `formatDate()` — so it installs `date-fns` and writes a new one.
It doesn't know your team's rules. None.

**So, it guesses. It hallucinates.**

**It breaks conventions your team spent months establishing.**

You correct it. It says sorry, does it right this time.

And tomorrow?

**You correct it again. The exact same things.**

Every session starts from zero. Every correction you made: gone.

You become a full-time AI babysitter 🍼, repeating the same instructions, fixing the same mistakes, re-explaining the same architecture.

Session after session after session...

**What if you could teach it once, and it would remember forever?**

---

## ❗️ This is NOT another collection

GitHub is full of repos that give you a collection of slash commands, skills, and prompt templates to copy into your project.

The AI reads them if it feels like it — and forgets them when the session resets.

**Brain is an enforcement system, not a suggestion box.**

Corrections become permanent. Forbidden patterns get blocked _before_ they run.

The knowledge base updates itself as your codebase evolves.

You stop re-explaining your stack every morning. You stop fixing the same mistakes twice.

**You stop babysitting — the AI just knows.**

---

## ✨ What Changes When You Add a Brain

Every AI coding tool reads instructions. None of them enforce those instructions on themselves. You write _"never edit tsconfig.json"_ — it edits `tsconfig.json` anyway. You correct it — same mistake next session.

**Instructions are text. Text is advisory. Advisory gets overridden.** Brain replaces text with mechanisms — hooks that block before execution, memory that persists across sessions, knowledge that stays current:

| 🔁 Every session today                                                                            | 🧠 With Brain — once, forever                                                                                                                                                                                 |
| :------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| You repeat your conventions every session — package manager, build commands, code style           | Knows your entire toolchain from day one — conventions are documented, not repeated                                                                                                                           |
| You re-explain your architecture after every context reset                                        | `architecture.md` is auto-loaded — survives compaction, restarts, everything                                                                                                                                  |
| You correct a mistake, it apologizes, then does it again tomorrow                                 | Corrections are captured in `lessons.md` — read at every session start, never repeated                                                                                                                        |
| The AI modifies config files to "fix" issues — linter settings, compiler configs, toolchain files | **Config protection** hook blocks edits to any protected file — forces fixing source code, not bypassing the toolchain                                                                                        |
| A command opens a pager, launches an editor, or dumps unbounded output — session hangs            | **Terminal safety** hook intercepts dangerous patterns before they execute — pagers, `vi`, unbounded output, all blocked                                                                                      |
| Code reviews vary wildly depending on how you prompt                                              | `/review` runs a consistent 10-point protocol every time — same rigor, zero prompt engineering                                                                                                                |
| Research eats your main context window and you lose track                                         | `research` subagent explores in an **isolated** context — your main window stays clean                                                                                                                        |
| Knowledge docs slowly rot as the code evolves                                                     | Self-maintenance rule + `/maintain` command detect drift and fix stale references automatically                                                                                                               |
| You're locked into one model — switching to Haiku or a local LLM means reconfiguring everything   | Agents auto-select the **most efficient model** per task (opus for security, session model for research) — and **fall back gracefully** to whatever you're running: Haiku, Bedrock, Vertex, Ollama, LM Studio |
| You push a PR and discover too late that your change broke 14 other files                         | **code-review-graph** scores every diff 0–100 before you push — blast radius, breaking changes, risk verdict in seconds                                                                                       |

**After a few sessions, your AI will know things about your codebase that even some team members don't.**

> 🎯 **200+ files isn't complexity. It's the minimum architecture where instructions become guarantees.**

---

## 🚀 Get Started in 5 Minutes

### Step 1 — Install the template

**Prerequisites:** `git`, `bash` ≥ 3.2, and **`jq`** (safety hooks and JS/TS discovery depend on it):

```bash
# Check if jq is installed — if not, install it first:
jq --version || brew install jq        # macOS
jq --version || sudo apt install jq    # Ubuntu/Debian
jq --version || sudo dnf install jq    # Fedora/RHEL
# Git Bash (Windows): jq is included. WSL: use the Linux command above.
```

Then install:

```bash
git clone https://github.com/y-abs/claude-code-brain-bootstrap.git /tmp/brain
bash /tmp/brain/install.sh your-repo/
rm -rf /tmp/brain
```

> 🤝 **Copilot users:** add `--copilot` to also generate GitHub Copilot agents, hooks, and prompts:
> `bash /tmp/brain/install.sh --copilot your-repo/`

> 🔍 **Pre-flight check:** `bash /tmp/brain/install.sh --check` — verifies all prerequisites (git, bash, jq) before touching your repo. Runs in 1 second, no side effects.

The install script **auto-detects** whether your repo is a fresh install or an upgrade:

| Scenario                                                              | What happens                                                                                                                                                                      |
| :-------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Fresh repo** (nothing Claude-related)                               | Copies the full template — all 200+ files (198 without `--copilot`, 211 with)                                                                                                     |
| **Existing Brain** (previous bootstrap)                               | Updates infrastructure (scripts, bootstrap process), adds missing components — **never overwrites** your `CLAUDE.md`, `lessons.md`, architecture docs, settings, or any user file |
| **Hand-crafted config** (your own `CLAUDE.md`, `claude/`, `.claude/`) | Adds Brain structure **around** your existing files — every file you created stays untouched                                                                                      |

> 💡 **Your knowledge is sacred.** The installer never overwrites, never `rm -rf`, never guesses. It preserves every lesson, every domain doc, every custom rule — then adds only what's missing. See the output summary for exactly what was preserved vs. added.

> 🔒 **Pre-upgrade safety**: the installer auto-creates a full backup (`claude/tasks/.pre-upgrade-backup.tar.gz`) before touching anything. Restore at any time: `tar xzf claude/tasks/.pre-upgrade-backup.tar.gz`.

### Step 2 — Let the AI configure itself

<details>
<summary><strong>With Claude Code</strong> (recommended — full automation)</summary>

```
/bootstrap
```

The `/bootstrap` command runs the discovery engine (`discover.sh` — pure bash, zero tokens), detects your entire stack, fills 70+ placeholders, then has the AI write architecture docs and domain knowledge specific to your codebase. Fully automated, ~5 minutes.

</details>

<details>
<summary><strong>With GitHub Copilot</strong> (no Claude Code needed)</summary>

The `.github/` config works **immediately** after Step 1. No extra setup needed for basic usage.

For **full setup** (filling in architecture, build commands, project name): if you installed with `--copilot`, just type `/bootstrap` in Copilot Chat — same automated flow as Claude Code. Without `--copilot`, run `discover.sh` manually then paste the output prompt — see [DETAILED_GUIDE.md](claude/docs/DETAILED_GUIDE.md) for the step-by-step.

> 💡 `--copilot` also generates 5 custom agents, 37 slash commands, and 4 lifecycle hooks — all from the Claude equivalents.

</details>

<details>
<summary><strong>With any other LLM</strong> (Cursor, Windsurf, Aider, local models…)</summary>

The `claude/*.md` knowledge docs are plain Markdown — any AI can read them. Run `discover.sh`, then tell your AI to read `claude/tasks/.discovery.env` and fill the `{{PLACEHOLDERS}}` in `claude/architecture.md` + `claude/build.md`. Or skip discovery and let the AI infer from `package.json` / `pyproject.toml` / etc. See [DETAILED_GUIDE.md](claude/docs/DETAILED_GUIDE.md) for the full prompt.

</details>

That's it. The discovery engine — pure bash, zero tokens — detects 25+ languages, 1,100+ frameworks, 21 package managers in ~2 seconds. Then the AI fills in what requires _reasoning_: architecture docs, domain knowledge, critical patterns specific to _your_ codebase.

> 💡 **Already have a Claude Code config?** The installer detects it and enters **upgrade mode** — your knowledge is preserved. Only missing pieces are added.

---

## 🧠 How It Works Under the Hood

Claude Code Brain is **200+ files** of structured configuration that live in your repo, version-controlled alongside your code. It's not a wrapper, not a plugin, not a SaaS product — it's **a knowledge architecture** that teaches your AI assistant how your project actually works.

```
Your repo
├── 📋 CLAUDE.md                    ← Operating protocol (auto-loaded every conversation)
├── ⚙️ .claude/
│   ├── commands/                   ← 31 slash commands (/build, /test, /review, /mr, /health...)
│   ├── hooks/                      ← 16 lifecycle hooks (safety, quality, recovery, audit)
│   ├── agents/                     ← 5 AI subagents (research, reviewer, plan-challenger...)
│   ├── skills/                     ← 18 skills (TDD, triage, root-cause, code review, semantic search...)
│   ├── rules/                      ← 13 path-scoped rules (auto-load per file type)
│   └── settings.json               ← Tool permissions, hook registration
├── 📚 claude/
│   ├── architecture.md             ← Your project's architecture (auto-imported)
│   ├── rules.md                    ← 24 golden rules (auto-imported)
│   ├── build.md                    ← Build/test/lint/serve commands for your stack
│   ├── terminal-safety.md          ← Shell anti-patterns that cause session hangs
│   ├── cve-policy.md               ← Security decision tree
│   ├── plugins.md                  ← Plugin config (claude-mem + graphify + MCP)
│   ├── scripts/                    ← 22 bootstrap & maintenance scripts
│   ├── bootstrap/                  ← 🧠 Setup scaffolding (auto-deleted after bootstrap)
│   ├── tasks/lessons.md            ← 🧠 Accumulated wisdom (persists across sessions)
│   ├── tasks/todo.md               ← 📝 Current task plan (survives session boundaries)
│   └── tasks/CLAUDE_ERRORS.md      ← 🐛 Error log (promotes to rules after 3+ recurrences)
├── 🗺️ graphify-out/                ← Knowledge graph (built on demand via /graphify)
│   ├── GRAPH_REPORT.md             ← Architecture map — god nodes, communities, surprises
│   ├── graph.json                  ← Persistent queryable graph
│   └── graph.html                  ← Interactive visualization
├── 🤖 .github/
│   ├── copilot-instructions.md     ← GitHub Copilot root instructions
│   ├── instructions/               ← Scoped instructions (auto-loaded per file type)
│   ├── prompts/                    ← Reusable prompts (31+ auto-generated from Claude commands)
│   ├── agents/                     ← Custom Copilot agents (with --copilot)
│   └── hooks/                      ← Lifecycle hooks (with --copilot)
└── 🚫 .claudeignore                ← Context exclusions (lock files, binaries, etc.)
└── 🗺️ .graphifyignore              ← Graph exclusions (node_modules, dist, lockfiles...)
```

**Write your knowledge once. Every AI tool reads it.** ✍️

### 🎯 The Three-Layer Token Strategy

The system is designed to **minimize token cost** while maximizing context — your AI doesn't drown in 50K tokens when you ask it to fix a typo:

| Layer              | What                                                                 | When loaded                                |                   Cost                    |
| :----------------- | :------------------------------------------------------------------- | :----------------------------------------- | :---------------------------------------: |
| 🟢 **Always on**   | `CLAUDE.md` + imported rules — operating protocol, critical patterns | Every conversation                         |               ~3-4K tokens                |
| 🟡 **Auto-loaded** | Path-scoped rules — short do/don't lists per domain                  | When editing matching files                |               ~200-400 each               |
| 🔵 **On-demand**   | Full domain docs — architecture, build, auth, database               | When the task requires it                  |                ~1-2K each                 |
| 🗺️ **Graph**       | `GRAPH_REPORT.md` — architecture map, god nodes, communities         | Before file searches (via PreToolUse hook) | 71.5× fewer tokens than reading raw files |

---

## 📦 What's Inside

| Category                     | Count | Highlights                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| :--------------------------- | :---: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 📚 **Knowledge docs**        |  13   | 8 domain docs (architecture, rules, build, CVE policy, terminal safety, MR templates, plugin config, decisions) · knowledge base guide · full reference guide · 3 worked domain examples                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ⚡ **Slash commands**        |  31   | `/plan` `/build` `/test` `/lint` `/serve` `/review` `/mr` `/debug` `/diff` `/git` `/deps` `/docker` `/migrate` `/db` `/cleanup` `/maintain` `/checkpoint` `/resume` `/context` `/ticket` `/bootstrap` `/health` `/status` `/ask` `/mcp` `/squad-plan` `/research` `/update-code-index` `/worktree` `/worktree-status` `/clean-worktrees`                                                                                                                                                                                                                                                                                                                                                                            |
| 🪝 **Lifecycle hooks**       |  16   | Session recovery, config protection, terminal safety gate (3 profiles), commit quality, RTK token optimizer, batch formatting, exit checklist, compaction recovery, identity refresh, permission audit, test reminders                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| 🤖 **AI subagents**          |   5   | **research** (read-only exploration), **reviewer** (10-point MR review), **plan-challenger** (adversarial plan critique), **session-reviewer** (conversation pattern analysis), **security-auditor** (vulnerability scanning) — each declares its optimal model, falls back to session model for local/alternative providers                                                                                                                                                                                                                                                                                                                                                                                        |
| 🎓 **Skills**                |  18   | TDD, root-cause trace, changelog, careful (safety guards), cross-layer check, **codebase-memory** (structural graph), **cocoindex-code** (semantic search), **code-review-graph** (risk analysis), **playwright** (browser automation), **codeburn** (token observability), **serena** (LSP refactoring), **brainstorming**, **receiving-code-review**, **subagent-driven-development**, **writing-skills**, **repo-recap**, **pr-triage**, **issue-triage**                                                                                                                                                                                                                                                        |
| 🔧 **Brain scripts**         |  22   | `discover.sh` (3800-line stack detector), `populate-templates.sh`, `post-bootstrap-validate.sh`, `validate.sh`, `canary-check.sh`, `_platform.sh` (portable shell helpers — Linux/macOS/Windows), `portability-lint.sh` (GNU-only pattern detector), `integration-test.sh` (17 assertions: FRESH/UPGRADE/--check/3 guards, 3 platforms), `phase2-verify.sh`, `toggle-claude-mem.sh`, `generate-service-claudes.sh`, `generate-copilot-docs.sh`, `generate-copilot-prompts.sh`, `generate-copilot-agents.sh`, `setup-plugins.sh`, `check-creative-work.sh`, `dry-run.sh`, `merge-claude-md.sh`, `merge-claudeignore.sh`, `merge-settings.sh`, `migrate-tasks.sh`, `pre-creative-check.sh` — all in `claude/scripts/` |
| 🤝 **GitHub Copilot config** |  50+  | Root instructions, 3 scoped instruction files (+1 template), 37 reusable prompts (+1 template), 5 custom agents, 4 lifecycle hooks — opt-in via `--copilot` flag                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 📏 **Path-scoped rules**     |  13   | Terminal safety, self-maintenance, quality gates, memory policy, domain learning, practice capture, agent orchestration, language-specific rules, template for adding your own                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 🔌 **Plugins**               |  10   | **claude-mem** (cross-session memory) · **graphify** (architecture graph) · **rtk** (command optimizer) · **codebase-memory-mcp** (structural graph) · **cocoindex-code** (semantic search) · **code-review-graph** (risk analysis) · **playwright** (browser automation) · **codeburn** (token observability) · **caveman** (response compression) · **serena** (LSP refactoring)                                                                                                                                                                                                                                                                                                                                  |
| ✅ **Validation checks**     | 127+  | File existence, hook executability, placeholder detection, settings consistency, cross-reference integrity, self-bootstrap protection                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |

---

### 🔀 Write Once, Read Everywhere

| Tool                 | What it reads                                |               Depth                |
| :------------------- | :------------------------------------------- | :--------------------------------: |
| **Claude Code**      | `CLAUDE.md` + `.claude/` + `claude/*.md`     |           🟢 Everything            |
| **GitHub Copilot**   | `.github/` + `claude/*.md`                   | 🟡 + agents/hooks with `--copilot` |
| **Any AI assistant** | `claude/bootstrap/PROMPT.md` → `claude/*.md` |      🔵 Bootstrap → knowledge      |

Agents declare their optimal model (`model: opus` for review/security, session model for research). Falls back gracefully to whatever you're running — Ollama, LM Studio, Bedrock, any local endpoint.

---

## 🔄 It Gets Smarter Over Time

This isn't a static config that rots. It's a **living system** with six feedback loops:

1. 📋 **Exit checklist** — every turn ends by capturing corrections and new patterns
2. 🧠 **`lessons.md`** — accumulated wisdom, read at every session start — impossible to skip
3. 🐛 **`CLAUDE_ERRORS.md`** — after 3+ recurrences, error patterns promote to rules
4. 🔁 **Session hooks** — auto-inject task state on startup, resume, compaction — context survives everything
5. 🔍 **`/maintain`** — audits all docs for stale paths, dead references, drift
6. 🗺️ **graphify git hooks** — auto-rebuild knowledge graph on every commit and branch switch

---

## 🛡️ Safety: Defense in Depth

Security isn't one mechanism — it's **two layers** working together:

### 🚫 Layer 1: Permissions — What the AI Can't Even Attempt

`settings.json` defines hard boundaries on what Claude Code is allowed to do. Denied commands **cannot execute** — no amount of context pressure or reasoning overrides them:

| Rule                          | What it prevents                                                                    |
| :---------------------------- | :---------------------------------------------------------------------------------- |
| **Deny `git push`**           | The AI can never push code — it presents a summary and waits for your confirmation  |
| **Deny destructive commands** | `rm -rf /`, `DROP DATABASE`, deployment scripts — blocked at the permission layer   |
| **Allow-list patterns**       | Only explicitly permitted tool patterns can run — everything else requires approval |

> These aren't suggestions. They're **hard permission boundaries** enforced by Claude Code itself — before the AI even sees the command.

### 🪝 Layer 2: Hooks — What Gets Intercepted at Runtime

16 lifecycle hooks add runtime guardrails — deterministic bash scripts, zero tokens, zero AI reasoning:

| Hook                        | What it prevents                                                                                      |
| :-------------------------- | :---------------------------------------------------------------------------------------------------- |
| 🔒 **Config protection**    | Blocks editing `biome.json`, `tsconfig.json`, linter configs — forces fixing source code instead      |
| 🚧 **Terminal safety gate** | Blocks `vi`/`nano`, pagers, `docker exec -it`, unbounded output — 3 profiles: minimal/standard/strict |
| 🧹 **Commit quality**       | Catches `debugger`, `console.log`, hardcoded secrets, `TODO FIXME` in staged files                    |
| 🏁 **Session recovery**     | Injects branch, task state, and critical reminders on startup, resume, and compaction                 |
| 🎨 **Batch formatting**     | Auto-formats all edited files at session end using your project's formatter                           |
| 🧪 **Test reminder**        | Warns when creating source files without tests (strict profile — educational, never blocks)           |

Plus 8 more hooks for identity refresh, permission audit, subagent logging, exit checklist enforcement, and context budget management.

> 📚 **Full hook reference:** [claude/docs/DETAILED_GUIDE.md](claude/docs/DETAILED_GUIDE.md#-lifecycle-hooks--claudehooks-16-files) — all 16 hooks with triggers, timeouts, and detailed descriptions.

---

## 🔌 Plugin Ecosystem

The bootstrap auto-installs a **ten-tool stack** — each tool occupies a distinct, non-overlapping niche. Six core intelligence tools + four efficiency/automation tools:

| Tool                                                                                        | Axis                                                                                      |          Install           |               Impact                |
| :------------------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------------- | :------------------------: | :---------------------------------: |
| **[graphify](https://github.com/safishamsi/graphify)**                                      | 🗺️ Architecture snapshot — god nodes, community clusters, cross-module map                |    Auto (Python 3.10+)     |  **71.5× fewer tokens** per query   |
| **[codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp)**                  | 🔍 Live structural graph — call traces, blast radius, dead code, Cypher queries           |        Auto (curl)         | **120× fewer tokens** vs file reads |
| **[cocoindex-code](https://github.com/cocoindex/cocoindex-code)**                           | 🔎 Semantic search — find code by meaning via local vector embeddings (no API key)        |    Auto (Python 3.11+)     |      Finds what grep/AST miss       |
| **[code-review-graph](https://github.com/codebase-review/code-review-graph)**               | 🔴 Change risk analysis — risk score 0–100, blast radius, breaking changes from git diffs |    Auto (Python 3.10+)     |         Pre-PR safety gate          |
| **[rtk](https://github.com/codemod-com/rtk)**                                               | ⚡ Command efficiency — transparently rewrites bash commands for compressed output        |        Auto (cargo)        |   **60-90% output token savings**   |
| **[claude-mem](https://github.com/thedotmack/claude-mem)**                                  | 🧠 Cross-session memory — captures every interaction, searchable across sessions          |            Auto            | ⚠️ Disabled by default (~48% quota) |
| **[playwright](https://github.com/anthropics/anthropic-mcp/tree/main/packages/playwright)** | 🌐 Browser automation — navigate, click, fill, snapshot web pages                         |     Auto (Node.js 18+)     |        LOW-MEDIUM token cost        |
| **[codeburn](https://github.com/eastlondoner/codeburn)**                                    | 📊 Token observability — cost breakdown by task, model, USD                               | Optional CLI (Node.js 18+) |     Zero (reads session files)      |
| **[caveman](https://github.com/codemod-com/caveman)**                                       | 🗣️ Response compression — terse replies (65-87% savings) + input file compression         |     Optional (Node.js)     |    **Negative** — reduces tokens    |
| **[serena](https://github.com/codefuse-ai/serena)**                                         | 🔧 LSP symbol refactoring — rename/move/inline across entire codebase atomically          | Auto (uvx + Python 3.11+)  |           Low — on-demand           |

**Zero overlap. Full coverage.** Each question has exactly one right tool:

```
Question                                    Tool                         How
──────────────────────────────────────────────────────────────────────────────────
"Show me the architecture"                  graphify                     GRAPH_REPORT.md (read once)
"Who calls AuthService.login()?"            codebase-memory-mcp          trace_path() — <10ms, no file reads
"Find code related to rate limiting"        cocoindex-code               search() — KNN over float32 vectors
"Is this PR safe to ship?"                  code-review-graph            detect_changes_tool() — risk score 0–100
"What did I do last Tuesday?"               claude-mem                   /mem-search (toggle on first)
"Test this login form"                      playwright                   browser_snapshot() — accessibility tree
"Where did my tokens go?"                   codeburn                     codeburn report -p 7days
"Rename AuthService across all files"       serena                       rename_symbol() — atomic multi-file
Every bash command Claude runs              rtk                          transparent rewrite, no config needed
Every Claude reply (terse mode)             caveman                      SessionStart hook / /caveman prompt
──────────────────────────────────────────────────────────────────────────────────
```

**graphify vs codebase-memory-mcp:** graphify = static architecture report, read at session start ("how is the codebase structured?"). codebase-memory-mcp = live graph, queried on demand ("who calls X right now?"). Additive: orientation → navigation. **cocoindex-code** fills the gap both miss: semantic search finds code by meaning, not by name.

> 📚 **Full plugin reference:** [claude/plugins.md](claude/plugins.md) — usage examples, install commands, toggle scripts, hook coexistence matrix, token economics.

> 📖 **Human knowledge layer:** [obsidian-mind](https://github.com/breferrari/obsidian-mind) — companion Obsidian vault (clone separately) that adds the _"why was it built this way?"_ axis.

---

## ⚙️ Make It Yours

Extending the Brain is simple — one file, one registration:

| To add…                | Create…                                       | Registration                          |
| :--------------------- | :-------------------------------------------- | :------------------------------------ |
| 📚 Domain knowledge    | `claude/<domain>.md`                          | Add to `CLAUDE.md` lookup table       |
| 📏 Path-scoped rule    | `.claude/rules/<domain>.md`                   | Automatic (matched by file path)      |
| ⚡ Slash command       | `.claude/commands/<name>.md`                  | Automatic (discovered by Claude Code) |
| 🪝 Lifecycle hook      | `.claude/hooks/<name>.sh`                     | Register in `.claude/settings.json`   |
| 🤖 AI subagent         | `.claude/agents/<name>.md`                    | Automatic (discovered by Claude Code) |
| 🎓 Skill               | `.claude/skills/<name>.md`                    | Automatic (discovered by Claude Code) |
| 🤝 Copilot instruction | `.github/instructions/<name>.instructions.md` | Automatic (matched by glob)           |
| 💬 Copilot prompt      | `.github/prompts/<name>.prompt.md`            | Automatic (discovered by Copilot)     |

Three worked examples in `claude/_examples/` — API domain, database domain, messaging domain.

> 📚 **Full reference:** [claude/docs/DETAILED_GUIDE.md](claude/docs/DETAILED_GUIDE.md) — complete file inventory, architecture diagrams, all 31 commands, all 16 hooks, placeholder reference, stack-specific examples, FAQ.

---

## ❓ FAQ

<details>
<summary><strong>💻 Platforms, prerequisites, compatibility</strong></summary>

**Platforms:** Linux ✅, macOS ✅, Windows WSL2 ✅, Git Bash ✅, CMD/PowerShell ❌ (Claude Code requires a Unix shell).

**Prerequisites:** `git`, `bash` ≥ 3.2 (≥ 4 for `/bootstrap`), `jq`. Optional: Python 3.10+ for graphify.

**Languages:** 25+ — TypeScript, Python, Go, Rust, Java, Kotlin, Ruby, PHP, C#, C/C++, Swift, Dart, Elixir, and more. Knowledge docs are language-agnostic; stack-specific details are auto-detected.

macOS note: `discover.sh` requires Bash 4+ (`brew install bash`). Run `bash install.sh --check` to verify your environment.

</details>

<details>
<summary><strong>🔄 Existing config? Tokens? Local LLMs? Copilot-only?</strong></summary>

**Existing config:** The installer detects it and enters **upgrade mode** — only missing pieces are added, your knowledge is never overwritten.

**Token cost:** ~3-4K always-on, ~200-400 per auto-loaded rule, ~1-2K per on-demand doc. See the [Three-Layer Token Strategy](#-the-three-layer-token-strategy).

**Local LLMs / smaller models:** Agents fall back to session model when the declared model is unavailable — Ollama, LM Studio, Haiku, any provider. Auto-scales to model capability.

**Copilot-only:** Install with `--copilot` for 37 commands, 5 agents, 4 hooks. The `claude/*.md` docs are plain Markdown — any AI reads them.

</details>

<details>
<summary><strong>⚖️ What's the difference between this and cursor rules / .cursorrules?</strong></summary>

Scope. Cursor rules are a flat instruction file. This is a **multi-layered knowledge architecture** with lifecycle hooks, subagents, skills, session persistence, self-maintenance, and multi-tool support. It's the difference between a sticky note and an operating system.

</details>

<details>
<summary><strong>👥 Is this just for solo developers?</strong></summary>

Not at all! Version-controlled, shared across the team (**TEAM mode**, default). Not ready to share? **SOLO mode**: add `CLAUDE.md`, `claude/`, `.claude/` to `.gitignore` — `.github/` Copilot config stays committed for the team.

</details>

---

## 🤝 Contributing

PRs welcome! All contributions must be **domain-agnostic**.

👉 **[Full guide → CONTRIBUTING.md](CONTRIBUTING.md)** · 🐛 **[Report a bug](https://github.com/y-abs/claude-code-brain-bootstrap/issues/new/choose)** · CI runs 5 checks on every PR.

---

## 📄 License

MIT — see [LICENSE](LICENSE).
