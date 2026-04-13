# Changelog

All notable changes to ᗺB Brain Bootstrap are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.1] — 2026-04-13

### 🎉 Initial Public Release

The first public release of ᗺB Brain Bootstrap — a complete AI knowledge architecture for Claude Code, GitHub Copilot, and any LLM.

### Added

#### Core Architecture
- **`CLAUDE.md`** — Operating protocol template: exit checklist, token strategy, terminal rules, critical patterns, review protocol, session continuity
- **`CLAUDE.local.md.example`** — Personal override template (auto-gitignored)
- **`.claudeignore`** — Context exclusion template (lock files, binaries, build artifacts)
- **`.mcp.json`** — MCP server configuration template

#### Knowledge Base (`claude/`)
- **`architecture.md`** — Workspace layout and service catalog template
- **`rules.md`** — 24 golden rules for AI-assisted development
- **`build.md`** — Build, test, lint, serve, migrate command templates
- **`terminal-safety.md`** — Shell anti-patterns reference (pagers, interactive programs, pipe safety)
- **`templates.md`** — MR/ticket description templates
- **`cve-policy.md`** — CVE decision tree and dependency security workflow
- **`plugins.md`** — Plugin configuration guide (claude-mem + obsidian-mind)
- **`decisions.md`** — Architectural decision log template
- **`docs/DETAILED_GUIDE.md`** — Complete 1000-line reference guide
- **`_examples/`** — 3 worked domain examples (API, database, messaging)
- **`bootstrap/PROMPT.md`** — 5-phase bootstrap prompt (works with any LLM)
- **`bootstrap/REFERENCE.md`** — Bootstrap report templates (FRESH + UPGRADE)
- **`bootstrap/UPGRADE_GUIDE.md`** — Smart Merge guide for existing configs

#### Automation (`claude/scripts/`)
- **`discover.sh`** — 2700+ line repo scanner: 25+ languages, 480+ frameworks, 21 package managers, 13 CI systems, zero tokens
- **`populate-templates.sh`** — Batch fills 70+ `{{PLACEHOLDER}}` values in one pass
- **`post-bootstrap-validate.sh`** — Unified post-bootstrap validation (validate + canary + auto-fix)
- **`validate.sh`** — 120-check template validator (file existence, JSON validity, hook executability, placeholder integrity)
- **`canary-check.sh`** — Live config health check (token budget, stale refs, @imports)
- **`phase2-verify.sh`** — Phase 2 data-integrity verification for Smart Merge
- **`generate-service-claudes.sh`** — Auto-generates per-service `CLAUDE.md` stubs for monorepo services
- **`generate-copilot-docs.sh`** — Mirrors `claude/*.md` → `.github/copilot/` for GitHub Copilot
- **`toggle-claude-mem.sh`** — Toggle claude-mem plugin on/off with quota awareness
- **`setup-plugins.sh`** — All-in-one bootstrap plugin management
- **`check-creative-work.sh`** — Phase 3 creative work quality gate
- **`tdd-loop-check.sh`** — TDD enforcement Stop hook

#### Slash Commands (`.claude/commands/`) — 26 commands
`/plan` · `/review` · `/mr` · `/ticket` · `/build` · `/test` · `/lint` · `/debug` · `/serve` · `/migrate` · `/db` · `/context` · `/docker` · `/deps` · `/diff` · `/git` · `/cleanup` · `/maintain` · `/checkpoint` · `/resume` · `/bootstrap` · `/mcp` · `/squad-plan` · `/research` · `/update-code-index` · `/health`

#### Lifecycle Hooks (`.claude/hooks/`) — 14 hooks
- **`session-start.sh`** — Injects branch, task state, and reminders on startup/resume/clear
- **`on-compact.sh`** — Re-injects context after compaction
- **`pre-compact.sh`** — Backs up session transcript before compaction
- **`config-protection.sh`** — Blocks editing linter/compiler configs (forces source fixes)
- **`terminal-safety-gate.sh`** — Blocks pagers, interactive programs, unbounded output (3 profiles)
- **`pre-commit-quality.sh`** — Catches `debugger`, `console.log`, secrets, TODOs in staged files
- **`suggest-compact.sh`** — Nudges `/compact` when context budget grows
- **`identity-reinjection.sh`** — Periodic identity refresh (prevents context drift)
- **`subagent-stop.sh`** — Logs subagent completion + quality nudge
- **`stop-batch-format.sh`** — Auto-formats all edited files at session end
- **`edit-accumulator.sh`** — Tracks edited files for batch formatting
- **`exit-nudge.sh`** — 6-item exit checklist reminder at session end
- **`permission-denied.sh`** — Audit trail for denied operations
- **`warn-missing-test.sh`** — Warns when source files lack tests (strict profile)

#### AI Subagents (`.claude/agents/`) — 5 agents
- **`research`** — Deep codebase exploration in isolated context (Sonnet, read-only)
- **`reviewer`** — Expert 10-point MR review with severity classification (Opus)
- **`plan-challenger`** — Adversarial plan review — finds real risks before you write code (Opus)
- **`session-reviewer`** — Conversation pattern analysis (Sonnet)
- **`security-auditor`** — Security scanning with DEPLOY/HOLD/BLOCK verdict (Opus)

#### Skills (`.claude/skills/`) — 5 skills
- **`tdd`** — Test-first discipline (background, auto-loads on test files)
- **`root-cause-trace`** — 5-step systematic error investigation (invocable)
- **`changelog`** — Release notes from git commits (invocable, isolated context)
- **`careful`** — Session safety guards — blocks dangerous commands (invocable)
- **`cross-layer-check`** — Symbol consistency across all monorepo layers (invocable + script)

#### Path-Scoped Rules (`.claude/rules/`) — 13 rules
Terminal safety · Quality gates · Self-maintenance · Memory policy · Domain learning · Practice capture · Agent orchestration · TypeScript · Python · Node.js backend · React · Domain template · Rule template

#### GitHub Copilot (`.github/`) — 8 files
Root instructions · General scoped instructions · Terminal safety instructions · Testing instructions · 2 reusable prompts · 2 templates

#### Settings & Infrastructure
- **`.claude/settings.json`** — Tool permissions, hook registration, env vars
- **`install.sh`** — 570-line smart installer: FRESH and UPGRADE mode with automatic pre-upgrade backup (`claude/tasks/.pre-upgrade-backup.tar.gz`)
- **`.shellcheckrc`** — ShellCheck configuration for CI linting
- **CI workflow** — 3 automated checks: template validation (120 checks), ShellCheck (28 scripts), documentation link verification
- **`.github/ISSUE_TEMPLATE/`** — 3 structured issue templates: bug report, feature request, configuration
- **`.github/PULL_REQUEST_TEMPLATE.md`** — 9-point PR checklist auto-loaded on every pull request

#### Bootstrap Intelligence
- **8 domain-detection greps** — Messaging, DB, lifecycle, auth, webhooks, adapters, reporting, enrollment. Each fired signal → one domain doc + one path-scoped rule
- **Adaptive tier escalation** — Items 7+8 (domain rules/skills) automatically become MANDATORY when ≥3 domain docs detected
- **SOLO/TEAM collaboration modes** — Report includes both options; TEAM (default) commits everything, SOLO adds sensitive files to `.gitignore`
- **Phase 3.5 MCP suggestions** — Auto-suggests MCP servers (postgres, github, web-search, filesystem) based on detected stack
- **Bootstrap cleanup** — `claude/bootstrap/` deleted after successful bootstrap (single-use scaffolding)
- **Per-service CLAUDE.md stubs** — `generate-service-claudes.sh` auto-generates service-scoped AI context for every monorepo service directory

#### Plugin
- **claude-mem** — Persistent cross-session memory (SQLite + ChromaDB), installed and disabled by default for quota protection

---

> 💡 **For upgrade instructions from a previous alpha/beta installation**, see [`claude/bootstrap/UPGRADE_GUIDE.md`](claude/bootstrap/UPGRADE_GUIDE.md).

