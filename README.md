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
  <a href="#-one-brain-three-ai-assistants--any-model"><img src="https://img.shields.io/badge/Ollama_%7C_LM_Studio-Local_LLMs_Ready-ff6f00" alt="Local LLMs Ready"></a>
</p>

<p align="center">
  <a href="#-sound-familiar">The Problem</a> &nbsp;·&nbsp;
  <a href="#-what-changes-when-you-add-a-brain">What Changes</a> &nbsp;·&nbsp;
  <a href="#-get-started-in-5-minutes">Quick Start</a> &nbsp;·&nbsp;
  <a href="#-from-instructions-to-guarantees">Why It Exists</a> &nbsp;·&nbsp;
  <a href="#-how-it-works-under-the-hood">How It Works</a> &nbsp;·&nbsp;
  <a href="#-whats-inside">What's Inside</a> &nbsp;·&nbsp;
  <a href="#-it-gets-smarter-over-time">Gets Smarter</a> &nbsp;·&nbsp;
  <a href="#-safety-defense-in-depth">Safety</a> &nbsp;·&nbsp;
  <a href="#-plugin-ecosystem">Plugins</a> &nbsp;·&nbsp;
  <a href="#-make-it-yours">Extend It</a> &nbsp;·&nbsp;
  <a href="#-faq">FAQ</a> &nbsp;·&nbsp;
  <a href="#-contributing">Contribute</a>
</p>

---

## 🤔 Sound Familiar?

You install Claude Code. You open your 50-service monorepo. You ask it to add a feature.

It doesn't know `yarn turbo build` is the right command, not `npm run build`. It doesn't know you use Biome, not Prettier — so it reformats files in a style that fails CI on every PR. It doesn't know your `@company/utils` package already has a `formatDate()` — so it installs `date-fns` and writes a new one. It doesn't know your team's rule: all DB access goes through repositories, never from controllers — so it writes a raw query, it passes review, and now it's in production setting the wrong precedent. It doesn't know your CI test command is `make test-ci`, not `npm test`.

**So it guesses. It hallucinates.**

It suggests `npm install` in a yarn monorepo. It runs `git log` without `--no-pager` and hangs your terminal forever. It modifies `tsconfig.json` to silence a type error instead of fixing it. It creates `UserUtils.ts` — the third one in the codebase, because the other two are in packages it never knew existed. **It breaks conventions your team spent months establishing.**

You correct it. *"No, we use yarn workspaces, not npm."* *"No, run make test-ci for tests."* *"No, always use --no-pager."* It says sorry, does it right this time.

And tomorrow?

**You correct it again. The exact same things.**

Every session starts from zero. Every correction you made yesterday — gone.

You become a full-time AI babysitter, repeating the same instructions, fixing the same mistakes, re-explaining the same architecture — session after session after session.

**What if you could teach it once, and it would remember forever?**

---

🚫 **GitHub is full of repos that give you a collection of slash commands, skills, and prompt templates to copy into your project. The AI reads them if it feels like it — and forgets them when the session resets.**

**Brain is an enforcement system, not a suggestion box.** Corrections become permanent. Forbidden patterns get blocked *before* they run. The knowledge base updates itself as your codebase evolves.

You stop re-explaining your stack every morning. You stop fixing the same mistakes twice. **You stop babysitting — the AI just knows.**

---

---

## ✨ What Changes When You Add a Brain

That's exactly what this does. You teach it once — it remembers, enforces, and improves:

| 🔁 Every session today | 🧠 With Brain — once, forever |
|:---|:---|
| You repeat your conventions every session — package manager, build commands, code style | Knows your entire toolchain from day one — conventions are documented, not repeated |
| You re-explain your architecture after every context reset | `architecture.md` is auto-loaded — survives compaction, restarts, everything |
| You correct a mistake, it apologizes, then does it again tomorrow | Corrections are captured in `lessons.md` — read at every session start, never repeated |
| The AI modifies config files to "fix" issues — linter settings, compiler configs, toolchain files | **Config protection** hook blocks edits to any protected file — forces fixing source code, not bypassing the toolchain |
| A command opens a pager, launches an editor, or dumps unbounded output — session hangs | **Terminal safety** hook intercepts dangerous patterns before they execute — pagers, `vi`, unbounded output, all blocked |
| Code reviews vary wildly depending on how you prompt | `/review` runs a consistent 10-point protocol every time — same rigor, zero prompt engineering |
| Research eats your main context window and you lose track | `research` subagent explores in an **isolated** context — your main window stays clean |
| Knowledge docs slowly rot as the code evolves | Self-maintenance rule + `/maintain` command detect drift and fix stale references automatically |
| You're locked into one model — switching to Haiku or a local LLM means reconfiguring everything | Agents auto-select the **most efficient model** per task (opus for security, session model for research) — and **fall back gracefully** to whatever you're running: Haiku, Bedrock, Vertex, Ollama, LM Studio |

**After a few sessions, your AI will know things about your codebase that even some team members don't.**

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

> 🔍 **Pre-flight check:** `bash /tmp/brain/install.sh --check` — verifies all prerequisites (git, bash, jq) before touching your repo. Runs in 1 second, no side effects.

The install script **auto-detects** whether your repo is a fresh install or an upgrade:

| Scenario | What happens |
|:---------|:------------|
| **Fresh repo** (nothing Claude-related) | Copies the full template — all 100+ files |
| **Existing Brain** (previous bootstrap) | Updates infrastructure (scripts, bootstrap process), adds missing components — **never overwrites** your `CLAUDE.md`, `lessons.md`, architecture docs, settings, or any user file |
| **Hand-crafted config** (your own `CLAUDE.md`, `claude/`, `.claude/`) | Adds Brain structure **around** your existing files — every file you created stays untouched |

> 💡 **Your knowledge is sacred.** The installer never overwrites, never `rm -rf`s, never guesses. It preserves every lesson, every domain doc, every custom rule — then adds only what's missing. See the output summary for exactly what was preserved vs. added.

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

The `.github/` config works **immediately** after Step 1 — Copilot reads `copilot-instructions.md`, scoped instructions, and reusable prompts automatically. No extra setup needed for basic usage.

For **full setup** (filling in the knowledge docs), run the discovery engine first, then ask Copilot to use the output:

```bash
# Run discovery (pure bash, 2 seconds, zero tokens)
bash your-repo/claude/scripts/discover.sh your-repo/ > your-repo/claude/tasks/.discovery.env
```

Then open Copilot Chat and paste:

```
I just ran our stack discovery engine. The results are in claude/tasks/.discovery.env (KEY=VALUE format).

Your tasks:
1. Read claude/tasks/.discovery.env to learn my stack
2. Read claude/architecture.md — replace every {{PLACEHOLDER}} with the real values from .discovery.env
   (PROJECT_NAME, STACK, RUNTIME, PACKAGE_MANAGER, etc.)
3. Read claude/build.md — replace every {{PLACEHOLDER}} with the real build/test/lint commands
   from .discovery.env (BUILD_CMD_ALL, TEST_CMD_ALL, LINT_FIX_CMD, etc.)
4. Read CLAUDE.md — replace {{PROJECT_NAME}} in the title
5. List any remaining {{PLACEHOLDERS}} you couldn't fill so I can provide them manually
```
</details>

<details>
<summary><strong>With any other LLM</strong> (Cursor, Windsurf, Aider, local models…)</summary>

The `claude/*.md` knowledge docs are plain Markdown — any AI can read them.

**Option A — With discovery engine** (recommended):
```bash
# Run discovery (pure bash, 2 seconds, zero tokens)
bash your-repo/claude/scripts/discover.sh your-repo/ > your-repo/claude/tasks/.discovery.env
```
Then tell your AI:
```
Read claude/tasks/.discovery.env (my detected stack). Then open claude/architecture.md and
claude/build.md — replace every {{PLACEHOLDER}} with the matching values. The env file has
all the answers: PROJECT_NAME, STACK, RUNTIME, PACKAGE_MANAGER, BUILD_CMD_ALL, TEST_CMD_ALL,
LINT_FIX_CMD, FORMAT_CMD, DEV_CMD, etc. List any you can't fill.
```

**Option B — Without discovery** (AI figures it out):
```
Scan this repo's package.json / pyproject.toml / Cargo.toml / go.mod (whichever exists).
Then open claude/architecture.md and claude/build.md — replace every {{PLACEHOLDER}} with
the real values for this project. There are ~20 placeholders: PROJECT_NAME, STACK, RUNTIME,
PACKAGE_MANAGER, BUILD_CMD_ALL, TEST_CMD_ALL, LINT_FIX_CMD, FORMAT_CMD, DEV_CMD, and more.
Infer from the actual config files. List any you're unsure about.
```
</details>

That's it. The discovery engine scans your repo in ~2 seconds — **pure bash, zero AI tokens** — and auto-detects your entire stack:

> 🔍 25+ languages · 📦 21 package managers · 🏗️ Monorepo tools (Nx, Turborepo, Lerna...) · 🎨 15+ formatters/linters · 🧪 Test frameworks · 🗄️ 12+ databases/ORMs · ⚙️ 13 CI systems · 🐳 Docker & Kubernetes · 🧩 1100+ frameworks

Then the AI fills in what requires *reasoning*: architecture docs, domain knowledge, critical patterns specific to *your* codebase.

The bootstrap is **adaptive** — it runs 8 domain-detection greps and automatically escalates depth when it finds complexity:
- **3+ domains detected** → domain rules and skills become mandatory (not optional)
- **Monorepo detected** → per-service `CLAUDE.md` stubs auto-generated for every service
- **Security scanner / linter / CI detected** → project-specific commands and rules auto-created
- **Docker / database / test framework detected** → matching build commands and domain docs populated

> 💡 **Already have a Claude Code config?** Bootstrap detects it and enters **upgrade mode** — your domain docs, lessons, tasks, and customizations are preserved. Only missing pieces are added.

---

## 🖥️ Platform Support

| Platform | Status | Shell | Notes |
|:---------|:-------|:------|:------|
| **Linux** | ✅ Native | bash 4+ | Zero configuration needed |
| **macOS** | ✅ Native | bash 3.2+ (system) / bash 5 (Homebrew) | `discover.sh` + `populate-templates.sh` require Bash 4+ (`brew install bash`) — all other scripts work with system bash |
| **Windows (WSL2)** | ✅ Recommended | bash 5 (Ubuntu) | Full Linux environment — everything works natively |
| **Windows (Git Bash)** | ✅ Supported | bash 4.4+ (MSYS2) | Works with default Git for Windows installation |
| **Windows (CMD/PowerShell)** | ❌ Not supported | — | Claude Code itself requires a Unix shell |

> **Required tools:** `git`, `bash` ≥ 3.2 (≥ 4 for `/bootstrap`), `jq` (safety hooks + discovery engine depend on it).
>
> Without `jq`: install works (settings merge skipped), but **lifecycle hooks can't parse Claude Code's JSON input** — config protection, terminal safety gate, and commit quality checks silently pass through. Discovery is degraded for JS/TS projects (can't read `package.json` fields). `awk` is POSIX-standard and always available.
>
> Install: `brew install jq` (macOS) · `sudo apt install jq` (Linux) · included in Git Bash (Windows).

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
| 🧠 **Best model per task — local LLMs included** | Agents declare their optimal model (opus for security audit, session model for research) and fall back gracefully. Works with Anthropic API, Bedrock, Vertex, **Ollama, LM Studio, any local endpoint**. Protocol auto-scales to model capability |
| 🤝 **One brain, three AI tools** | Write knowledge once → Claude Code, GitHub Copilot, and any LLM all read it — switch tools without starting over |

> 🎯 **100+ files isn't complexity. It's the minimum architecture where instructions become guarantees.**

---

## 🧪 The Discovery Engine: 3800+ Lines of Pure Bash

The discovery engine detects **25+ languages**, **21 package managers**, **1100+ frameworks**, **13 CI systems**, **12+ database/ORM tools**, and **15+ formatter/linter combinations**.
No token cost, runs in ~2 seconds, and is the foundation for all subsequent knowledge generation. It populates the initial `claude/architecture.md` and `claude/build.md` with accurate, repo-specific context.

**What the engine outputs (`claude/tasks/.discovery.env`):**
- Stack identity: languages, package manager, runtime, frameworks
- All build/test/lint/serve/migrate/db/deps commands — ready to use
- Detected tools: formatter, linter, security scanner, CI system
- Monorepo structure: workspace type (Nx, Turborepo, pnpm...), service count
- Install status: whether claude-mem is already installed
- Mode detection: FRESH vs UPGRADE, layout migration needed

Your stack not listed? [It takes one PR to add it](#-contributing). 🙌

---


## 🧠 How It Works Under the Hood

Claude Code Brain is **100+ files** of structured configuration that live in your repo, version-controlled alongside your code. It's not a wrapper, not a plugin, not a SaaS product — it's **a knowledge architecture** that teaches your AI assistant how your project actually works.

```
Your repo
├── 📋 CLAUDE.md                    ← Operating protocol (auto-loaded every conversation)
├── ⚙️ .claude/
│   ├── commands/                   ← 26 slash commands (/build, /test, /review, /mr, /health...)
│   ├── hooks/                      ← 14 lifecycle hooks (safety, quality, recovery, audit)
│   ├── agents/                     ← 5 AI subagents (research, reviewer, plan-challenger...)
│   ├── skills/                     ← 5 skills (TDD, root-cause, changelog, safety, cross-layer)
│   ├── rules/                      ← 13 path-scoped rules (auto-load per file type)
│   └── settings.json               ← Tool permissions, hook registration
├── 📚 claude/
│   ├── architecture.md             ← Your project's architecture (auto-imported)
│   ├── rules.md                    ← 24 golden rules (auto-imported)
│   ├── build.md                    ← Build/test/lint/serve commands for your stack
│   ├── terminal-safety.md          ← Shell anti-patterns that cause session hangs
│   ├── cve-policy.md               ← Security decision tree
│   ├── scripts/                    ← 15 bootstrap & maintenance scripts
│   ├── bootstrap/                  ← 🧠 Setup scaffolding (auto-deleted after bootstrap)
│   ├── tasks/lessons.md            ← 🧠 Accumulated wisdom (persists across sessions)
│   ├── tasks/todo.md               ← 📝 Current task plan (survives session boundaries)
│   └── tasks/CLAUDE_ERRORS.md      ← 🐛 Error log (promotes to rules after 3+ recurrences)
├── 🤖 .github/
│   ├── copilot-instructions.md     ← GitHub Copilot root instructions
│   ├── instructions/               ← Scoped instructions (auto-loaded per file type)
│   └── prompts/                    ← Reusable prompts
└── 🚫 .claudeignore                ← Context exclusions (lock files, binaries, etc.)
```

**Write your knowledge once. Every AI tool reads it.** ✍️

### 🎯 The Three-Layer Token Strategy

The system is designed to **minimize token cost** while maximizing context — your AI doesn't drown in 50K tokens when you ask it to fix a typo:

| Layer | What | When loaded | Cost |
|:------|:-----|:-----------|:----:|
| 🟢 **Always on** | `CLAUDE.md` + imported rules — operating protocol, critical patterns | Every conversation | ~3-4K tokens |
| 🟡 **Auto-loaded** | Path-scoped rules — short do/don't lists per domain | When editing matching files | ~200-400 each |
| 🔵 **On-demand** | Full domain docs — architecture, build, auth, database | When the task requires it | ~1-2K each |

---

## 📦 What's Inside

| Category | Count | Highlights |
|:---------|:-----:|:-----------|
| 📚 **Knowledge docs** | 13 | 8 domain docs (architecture, rules, build, CVE policy, terminal safety, MR templates, plugin config, decisions) · knowledge base guide · full reference guide · 3 worked domain examples |
| ⚡ **Slash commands** | 26 | `/plan` `/build` `/test` `/lint` `/serve` `/review` `/mr` `/debug` `/diff` `/git` `/deps` `/docker` `/migrate` `/db` `/cleanup` `/maintain` `/checkpoint` `/resume` `/context` `/ticket` `/bootstrap` `/health` `/mcp` `/squad-plan` `/research` `/update-code-index` |
| 🪝 **Lifecycle hooks** | 14 | Session recovery, config protection, terminal safety gate (3 profiles), commit quality, batch formatting, exit checklist, compaction recovery, identity refresh, permission audit, test reminders |
| 🤖 **AI subagents** | 5 | **research** (read-only exploration), **reviewer** (10-point MR review), **plan-challenger** (adversarial plan critique), **session-reviewer** (conversation pattern analysis), **security-auditor** (vulnerability scanning) — each declares its optimal model, falls back to session model for local/alternative providers |
| 🎓 **Skills** | 5 | TDD discipline (auto-loads on test files), root-cause trace, changelog generation, session safety guards, cross-layer consistency check |
| 🔧 **Brain scripts** | 15 | `discover.sh` (3800-line stack detector), `populate-templates.sh`, `post-bootstrap-validate.sh`, `validate.sh`, `canary-check.sh`, `_platform.sh` (portable shell helpers — Linux/macOS/Windows), `portability-lint.sh` (GNU-only pattern detector), `integration-test.sh` (17 assertions: FRESH/UPGRADE/--check/3 guards, 3 platforms), `phase2-verify.sh`, `toggle-claude-mem.sh`, `generate-service-claudes.sh`, `generate-copilot-docs.sh`, `setup-plugins.sh`, `check-creative-work.sh`, `tdd-loop-check.sh` — all in `claude/scripts/` |
| 🤝 **GitHub Copilot config** | 8 | Root instructions, 3 scoped instruction files (+1 template), 2 reusable prompts (+1 template) |
| 📏 **Path-scoped rules** | 13 | Terminal safety, self-maintenance, quality gates, memory policy, domain learning, practice capture, agent orchestration, language-specific rules, template for adding your own |
| 🔌 **Plugins** | 1 | **claude-mem** (persistent cross-session memory) — auto-installed, disabled by default (quota protection) |
| ✅ **Validation checks** | 120 | File existence, hook executability, placeholder detection, settings consistency, cross-reference integrity, self-bootstrap protection |

---

## 🔀 One Brain, Three AI Assistants — Any Model

The knowledge layer (`claude/*.md`) is the **single source of truth**. Each tool gets the depth it can handle — and agents auto-select the most efficient model per task, falling back to your session model when unavailable (Ollama, LM Studio, any local LLM):

```
              claude/*.md  (shared knowledge)
                   │
       ┌───────────┼───────────────┐
       ▼           ▼               ▼
  Claude Code   GitHub Copilot   Any LLM
  ───────────   ──────────────   ───────
  Full stack:   Instructions +   Bootstrap
  commands,     scoped rules,    prompt →
  hooks,        prompts,         generates
  agents,       knowledge        config from
  skills,       docs             knowledge
  rules,                         docs
  settings
```

**Model selection is enforced across both tools:**
- **Claude Code** — agents declare their optimal model (`model: opus` in frontmatter). Research agents use the session model (faster/cheaper); review and security agents request Opus (correctness matters more than cost). Falls back to session model when unavailable.
- **GitHub Copilot** — `copilot-instructions.md` enforces model selection via instructions: planning/review/architecture tasks **stop and warn** if the active model is a "mini"/"flash"/"lite" variant, requesting the user switch to the most capable model in the IDE model picker. Quick tasks (build, lint, test) run on any model.

| Tool | What it reads | Depth |
|:-----|:-------------|:-----:|
| **Claude Code** | `CLAUDE.md` + `.claude/` (full automation) + `claude/*.md` (knowledge) | 🟢 Everything |
| **GitHub Copilot** | `.github/copilot-instructions.md` + `.github/instructions/` + `.github/prompts/` + `claude/*.md` | 🟡 Instructions + knowledge |
| **Any AI assistant** | `claude/bootstrap/PROMPT.md` → reads `claude/*.md` | 🔵 Bootstrap → knowledge |

---

## 🔄 It Gets Smarter Over Time

This isn't a static config that rots. It's a **living system** with six feedback mechanisms:

1. 📋 **Exit checklist** — enforced at the end of every AI turn. Captures corrections, new patterns, and pitfalls before the AI yields.
2. 🧠 **`lessons.md`** — accumulated wisdom, read at every session start. The AI literally cannot make the same mistake twice.
3. 🐛 **`CLAUDE_ERRORS.md`** — structured error log with promotion lifecycle. After 3+ recurrences, patterns are promoted to rules — bugs become guardrails.
4. 🔁 **Session hooks** — auto-inject task state on startup, resume, and compaction. Context survives session boundaries and token budget resets.
5. 🔍 **`/maintain` command** — audits all knowledge docs for stale file paths, dead references, and drift from the actual codebase.
6. 🛠️ **Self-maintenance rule** — auto-loads when editing knowledge files. Enforces consistency invariants in real-time.

> 💡 After a few sessions, your AI will know things about your codebase that even some team members don't.

---

## 🛡️ Safety: Defense in Depth

Security isn't one mechanism — it's **two layers** working together:

### 🚫 Layer 1: Permissions — What the AI Can't Even Attempt

`settings.json` defines hard boundaries on what Claude Code is allowed to do. Denied commands **cannot execute** — no amount of context pressure or reasoning overrides them:

| Rule | What it prevents |
|:-----|:----------------|
| **Deny `git push`** | The AI can never push code — it presents a summary and waits for your confirmation |
| **Deny destructive commands** | `rm -rf /`, `DROP DATABASE`, deployment scripts — blocked at the permission layer |
| **Allow-list patterns** | Only explicitly permitted tool patterns can run — everything else requires approval |

> These aren't suggestions. They're **hard permission boundaries** enforced by Claude Code itself — before the AI even sees the command.

### 🪝 Layer 2: Hooks — What Gets Intercepted at Runtime

14 lifecycle hooks add runtime guardrails — deterministic bash scripts, zero tokens, zero AI reasoning:

| Hook | What it prevents |
|:-----|:----------------|
| 🔒 **Config protection** | Blocks editing `biome.json`, `tsconfig.json`, linter configs — forces fixing source code instead |
| 🚧 **Terminal safety gate** | Blocks `vi`/`nano`, pagers, `docker exec -it`, unbounded output — 3 profiles: minimal/standard/strict |
| 🧹 **Commit quality** | Catches `debugger`, `console.log`, hardcoded secrets, `TODO FIXME` in staged files |
| 🏁 **Session recovery** | Injects branch, task state, and critical reminders on startup, resume, and compaction |
| 🎨 **Batch formatting** | Auto-formats all edited files at session end using your project's formatter |
| 🧪 **Test reminder** | Warns when creating source files without tests (strict profile — educational, never blocks) |

Plus 8 more hooks for identity refresh, permission audit, subagent logging, exit checklist enforcement, and context budget management.

> 📚 **Full hook reference:** [claude/docs/DETAILED_GUIDE.md](claude/docs/DETAILED_GUIDE.md#-lifecycle-hooks--claudehooks-14-files) — all 14 hooks with triggers, timeouts, and detailed descriptions.

---

## 🔌 Plugin Ecosystem

The bootstrap installs **one Claude Code plugin** — no manual setup needed:

| Plugin | Purpose | Default |
|:-------|:--------|:-------:|
| **[claude-mem](https://github.com/thedotmack/claude-mem)** | 🧠 Persistent cross-session memory (SQLite + ChromaDB) — auto-captures every interaction, searchable across sessions | ⚠️ Disabled (quota protection) |

```bash
# claude-mem is disabled by default (PostToolUse(*) can use ~48% of API quota)
bash claude/scripts/toggle-claude-mem.sh on       # Enable for exploratory sessions
bash claude/scripts/toggle-claude-mem.sh off      # Disable for batch work
bash claude/scripts/toggle-claude-mem.sh status   # Check current state
```

> 📖 **Want an AI-powered knowledge vault?** [obsidian-mind](https://github.com/breferrari/obsidian-mind) is a companion Obsidian vault template (not a Claude Code plugin) — clone it separately for persistent knowledge graph features across sessions.

> 📚 **Full plugin reference:** [claude/plugins.md](claude/plugins.md) — hook coexistence, quota management, obsidian-mind setup guide.

---

## ⚙️ Make It Yours

Extending the Brain is simple — one file, one registration:

| To add… | Create… | Registration |
|:--------|:--------|:------------|
| 📚 Domain knowledge | `claude/<domain>.md` | Add to `CLAUDE.md` lookup table |
| 📏 Path-scoped rule | `.claude/rules/<domain>.md` | Automatic (matched by file path) |
| ⚡ Slash command | `.claude/commands/<name>.md` | Automatic (discovered by Claude Code) |
| 🪝 Lifecycle hook | `.claude/hooks/<name>.sh` | Register in `.claude/settings.json` |
| 🤖 AI subagent | `.claude/agents/<name>.md` | Automatic (discovered by Claude Code) |
| 🎓 Skill | `.claude/skills/<name>.md` | Automatic (discovered by Claude Code) |
| 🤝 Copilot instruction | `.github/instructions/<name>.instructions.md` | Automatic (matched by glob) |
| 💬 Copilot prompt | `.github/prompts/<name>.prompt.md` | Automatic (discovered by Copilot) |

Three worked examples in `claude/_examples/` — API domain, database domain, messaging domain.

> 📚 **Full reference:** [claude/docs/DETAILED_GUIDE.md](claude/docs/DETAILED_GUIDE.md) — complete file inventory, architecture diagrams, all 26 commands, all 14 hooks, placeholder reference, stack-specific examples, FAQ.

---

## ❓ FAQ

<details>
<summary><strong>🌍 Does this work with languages other than JavaScript?</strong></summary>

Yes! The discovery engine detects **25+ languages**: TypeScript, JavaScript, Python, Go, Rust, Java, Kotlin, Scala, Groovy, Ruby, PHP, C#, C, C++, Objective-C, Swift, Dart, Shell/Bash, Elixir, Lua, Zig, Julia, Perl, OCaml, F#, Clojure, R, and more. The knowledge docs and golden rules are language-agnostic. Stack-specific details (build commands, test runner, formatter) are auto-detected and populated for your language automatically.
</details>

<details>
<summary><strong>🖥️ Does this work on macOS / Windows?</strong></summary>

Yes — Linux, macOS, and Windows (WSL2 / Git Bash) are all supported. Three layers of cross-platform hardening ensure it:

1. **`_platform.sh`** — portable shell helper library used by all scripts. Wraps GNU-only commands (`sed -i`, `readlink -f`, `mktemp -d`, `date`) with platform-safe alternatives that work on both GNU and BSD (macOS) systems.
2. **`portability-lint.sh`** — CI check that scans every `.sh` file for 9 known GNU-only patterns and fails the build if any slip through (e.g., `sed -i ''` without platform guard, `readlink -f` without fallback).
3. **`integration-test.sh`** — 17 assertions covering FRESH install, UPGRADE, `--check` mode, and 3 guard scenarios, run on all 3 platforms in CI.

macOS note: `discover.sh` and `populate-templates.sh` require Bash 4+ (`brew install bash`) — all other scripts work with the system bash 3.2. `jq` is needed for safety hooks and JS/TS discovery (`brew install jq` on macOS, pre-installed on most Linux distros and Git Bash). `awk` is POSIX-standard — always available. Run `bash install.sh --check` to verify your environment before installing.
</details>

<details>
<summary><strong>🔄 Will this conflict with my existing Claude Code config?</strong></summary>

Nope. The bootstrap detects existing configurations and enters **upgrade mode** — it preserves your domain docs, lessons, task state, and customizations. Only missing structural pieces are added. Your knowledge is never overwritten.
</details>

<details>
<summary><strong>💰 How much does this cost in tokens?</strong></summary>

The always-on layer (`CLAUDE.md` + imported rules) costs ~3-4K tokens per conversation. Path-scoped rules add ~200-400 tokens each, only when triggered. Full domain docs are ~1-2K each, loaded on-demand. The three-tier architecture ensures you're not paying for context you don't need.
</details>

<details>
<summary><strong>🧠 Does this work with smaller models, local LLMs, or third-party providers?</strong></summary>

Yes — and it's designed for it. The model strategy has two layers:

1. **Best choice by default:** Quality-critical agents (`reviewer`, `plan-challenger`, `security-auditor`) declare `model: opus` for maximum quality. Lightweight agents (`research`, `session-reviewer`) use the session model for efficiency — a smaller model is *faster and cheaper* for mechanical tasks like grep and pattern matching.

2. **Universal compatibility:** When the declared model isn't available (local LLM via Ollama/LM Studio, alternative provider, Haiku-only plan), agents **fall back to the session model** automatically. Everything still works — the protocol auto-scales to model capability (full 10-point review on Opus, streamlined on smaller models).

The three-layer token strategy (always-on ~3-4K, auto-loaded ~200-400, on-demand ~1-2K) keeps context lean enough for smaller context windows.
</details>

<details>
<summary><strong>🤝 Can I use this without Claude Code? Just Copilot?</strong></summary>

Yes! The `.github/` directory contains Copilot-native configuration (root instructions, scoped instructions, reusable prompts) that works independently. The `claude/*.md` knowledge docs are plain Markdown — any AI can read them.
</details>

<details>
<summary><strong>⚖️ What's the difference between this and cursor rules / .cursorrules?</strong></summary>

Scope. Cursor rules are a flat instruction file. This is a **multi-layered knowledge architecture** with lifecycle hooks, subagents, skills, session persistence, self-maintenance, and multi-tool support. It's the difference between a sticky note and an operating system.
</details>

<details>
<summary><strong>👥 Is this just for solo developers?</strong></summary>

Not at all! The config lives in the repo — version-controlled and shared across the team (**TEAM mode**, the default). Every developer gets the same AI experience. Knowledge improvements from one person benefit everyone on the next `git pull`.

Not ready to share? Use **SOLO mode**: add `CLAUDE.md`, `claude/`, `.claude/`, `.claudeignore`, `.mcp.json` to `.gitignore`. Only the `.github/` Copilot config stays committed — it benefits the whole team regardless.
</details>

---

## 🤝 Contributing

PRs welcome! The most impactful contributions:

| Area | Difficulty | Example |
|:-----|:----------:|:--------|
| 🔍 **Stack detection** | 🟢 Easy | New language/framework in `discover.sh` |
| 📚 **Documentation** | 🟢 Easy | Typo fix, better examples, clearer explanations |
| ⚡ **Slash commands** | 🟡 Medium | New workflow command for any project |
| 🪝 **Hook improvements** | 🟠 Advanced | Safety patterns, quality gates |

All contributions must be **domain-agnostic** (no project-specific content).

👉 **[Full step-by-step guide → CONTRIBUTING.md](CONTRIBUTING.md)** — fork, branch, validate, submit. PR template auto-loads with checklist.

🐛 **Found a bug?** → [Open an issue](https://github.com/y-abs/claude-code-brain-bootstrap/issues/new/choose) — structured templates for bug reports and feature requests.

🔄 **CI runs 5 checks on every PR** — ShellCheck on all scripts, portability lint (GNU-only pattern detector), documentation links (all .md cross-references), cross-platform validation (Linux / macOS / Windows — validate.sh + install --check), and integration tests (FRESH install, UPGRADE, --check mode, and 3 guard scenarios, all 3 platforms). All must pass to merge.

> 🚀 **Maintainers:** See [CONTRIBUTING.md — Release Process](CONTRIBUTING.md#-release-process-maintainers-only) for the full step-by-step release workflow (PR → tag → GitHub Release).

---

## 📄 License

MIT — see [LICENSE](LICENSE).
