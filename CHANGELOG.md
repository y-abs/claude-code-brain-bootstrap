# Changelog

All notable changes to ᗺB Brain Bootstrap are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-04-20

### 🚀 First Stable Release

ẂB Brain Bootstrap graduates from pre-release to **v1.0.0** — a production-ready AI knowledge architecture for Claude Code and any LLM-powered IDE.

Seven months of alpha → beta development condensed into a single installable template:

- **One command install** — `bash install.sh /path/to/your-repo` handles FRESH and UPGRADE
- **31 slash commands** — `/plan`, `/review`, `/mr`, `/debug`, `/bootstrap`, `/health` and 25 more
- **15 lifecycle hooks** — terminal safety, TDD enforcement, quality gates, session continuity
- **11 skills** — invocable AI workflows (root-cause-trace, cross-layer-check, graphify, caveman…)
- **5 subagents** — `reviewer` (Opus), `plan-challenger` (Opus), `security-auditor` (Opus), `research`, `session-reviewer`
- **10-tool plugin stack** — graphify · codebase-memory-mcp · cocoindex-code · code-review-graph · claude-mem · rtk · playwright · codeburn · caveman · serena
- **1100+ framework detections** — 25+ languages, 21 package managers, 13 CI systems via `discover.sh`
- **Cross-platform** — CI matrix on Linux, macOS, Windows; bash 3.2 compatible; Git Bash ready
- **127+ validation checks** — template integrity, hook executability, placeholder detection, link verification
- **Community-ready** — `CONTRIBUTING.md`, issue templates, PR template, Discussions

### What changed since v0.6.6

No new features — this is a stability milestone. All pre-release bug fixes are included (see v0.6.3–v0.6.6 entries below).

---

## [0.6.6] — 2026-04-20 (PR #37)

### 🐛 SKIP_RTK Optional Tier

### Fixed

- **`setup-plugins.sh`** — move `SKIP_RTK` to `OPTIONAL` tier so the recommended install strategy skips RTK by default (#37)

---

## [0.6.5] — 2026-04-20 (PR #36)

### 🐛 Bootstrap Sleep Block & RTK Recommended Strategy

### Fixed

- **`setup-plugins.sh`** — narrow sleep block scope to prevent unintended delays during non-RTK install paths (#36)
- **`setup-plugins.sh`** — drop RTK from recommended tier; remove background install pattern that caused race conditions (#36)

---

## [0.6.4] — 2026-04-20 (PR #35)

### 🐛 Merge Script Exit Codes

### Fixed

- **`merge-claude-md.sh`** / **`merge-claudeignore.sh`** / **`merge-settings.sh`** — exit `2` (no-op) changed to exit `0` so callers treat a clean no-op as success, not an error (#35)

---

## [0.6.3] — 2026-04-19 (PR #34)

### 🐛 Plugin Ecosystem URL Fixes

### Fixed

- **`README.md`** / **`DETAILED_GUIDE.md`** — correct broken plugin ecosystem URLs that returned 404 (#34)

---

## [0.6.2] — 2026-04-18 (PRs #30, #32)

### 🧹 Bootstrap Phantom File Cleanup

### Fixed

- **`install.sh`** — prevent phantom files being generated during bootstrap runs (#30)
- **`install.sh`** — add cleanup for old bootstrap package manager phantom entries that persisted across sessions (#32)

---

## [0.6.1] — 2026-04-18 (PRs #27, #28, #29)

### 🐛 Hook, Schema & Prompt Fixes

### Fixed

- **`tdd-loop-check.sh`** — fix trigger condition and nx monorepo detection (#27)
- **`settings.json`** — enforce current `claude-code-settings.json` schema `$schema` URL (#28)
- **`bootstrap/PROMPT.md`** — clarify obsidian-mind companion vault intent (not a plugin, clone separately) (#29)

---

## [0.6.0] — 2026-04-18 (PRs #18–#26)

### 🖥️ Cross-Platform Parity

Extended cross-platform support beyond the hardening pass in v0.2.0 — ensuring behavioral parity across Linux, macOS, and Windows for the full plugin and hook stack.

### Added

- **Cross platform parity** — additional portability fixes and parity guarantees for plugin installation and hook execution across all three platforms (#18)

### Changed

- **README** — feature hierarchy clarification and accurate count sync (#19, #20–#25)
- **`DETAILED_GUIDE.md`** — corrections and accuracy improvements (#26)

---

## [0.5.2] — 2026-04-17 (PRs #16, #17)

### 🐛 Bootstrap Quality Gates & Plugin Detection

### Fixed

- **`setup-plugins.sh`** / **`validate.sh`** — bootstrap quality gate checks and plugin detection logic (#17)
- **`CHANGELOG.md`** — completed all version entries, added comparison links (#16)

---

## [0.5.1] — 2026-04-17 (PR #15)

### 🐛 Canary Check False Positives & UPGRADE Mode

Live end-to-end testing on a mature monorepose with an existing Claude Code configuration revealed 15 distinct issues (documented in `tasks/bootstrap-bugs-found.md`) spanning false positives in canary checks, missing guards in scripts, and UPGRADE mode edge cases. All have been fixed with a combination of script hardening, guard clauses, and improved logic.

### Added

- **UPGRADE mode infrastructure** — `merge-claude-md.sh`, `merge-claudeignore.sh`, `merge-settings.sh`, `migrate-tasks.sh`, `pre-creative-check.sh`, `dry-run.sh` for bootstrapping repos with existing Claude Code configuration.
- **`_CLAUDE.md.template`**, **`_claudeignore.template`**, **`_settings.json.template`** — standalone templates for UPGRADE merge operations.
- **Domain alias detection** in `pre-creative-check.sh` — greps existing `claude/*.md` for domain keywords before recommending CREATE (prevents duplicate docs with different names).
- **`--yes` flag** for `setup-plugins.sh` — non-interactive mode for CI/automation.

### Fixed

- **`canary-check.sh`** — 4 false positive fixes:
  - Skill-not-in-README downgraded from per-skill FAIL to aggregated WARN (UPGRADE adds skills the user hasn't documented)
  - grep -E double-quote detector now skips comment lines (`^#`)
  - Placeholder scan excludes guard comparisons (`= '{{...}}'`) and `.instructions.md` documentation
  - Bare-git detector excludes `case` patterns that _detect_ bare git (not run it)
- **`populate-templates.sh`** — `tdd-loop-check.sh` path in `PLACEHOLDER_FILES` pointed to wrong location (`claude/scripts/` → `.claude/hooks/`)
- **`generate-service-claudes.sh`** — strip trailing slash to avoid double-slash paths in output
- **`setup-plugins.sh`** — `--yes` flag recognized in case statement; `timeout` guards on `claude plugin` CLI calls
- **`merge-claude-md.sh`** — removed unused `user_words` variable (ShellCheck SC2034)

---

## [0.5.0] — 2026-04-16 (PRs #12, #13, #14)

### 🧠 Six-Tool Codebase Intelligence Stack

### Added

- **code-review-graph plugin** — 29 MCP tools for change risk analysis (risk score 0–100, blast radius, breaking changes). Pre-PR safety gate via `mcp__code-review-graph__detect_changes_tool`. Requires Python 3.10+.
- **cocoindex-code plugin** — semantic vector search via `mcp__cocoindex-code__search`. Find code by meaning, not exact names. Requires Python 3.11+. (~1 GB first install for local embeddings.)
- **codebase-memory-mcp plugin** — live structural graph with 14 MCP tools. `trace_path`, `detect_changes`, `get_architecture` — 120× fewer tokens than file exploration.
- **SKILL.md files** for all three new plugins — decision matrices, gotchas, pre-PR workflows.
- **Plugin opt-out env vars** — `SKIP_CLAUDE_MEM`, `SKIP_GRAPHIFY`, `SKIP_RTK`, `SKIP_COCOINDEX`, `SKIP_CRG`, `SKIP_CBM` in `setup-plugins.sh`.
- **MCP primer** in `DETAILED_GUIDE.md` — explains MCP for first-time users (mental model, tool naming, `.mcp.json` anatomy, graceful degradation).
- **jq absence warning** in `session-start.sh` — surfaces visibly when safety hooks are silently inactive.
- **Post-bootstrap `/health` prompt** — `/bootstrap` now directs users to run `/health` after setup.
- **Worktree commands documented** — `/worktree`, `/worktree-status`, `/clean-worktrees` now appear in all documentation tables.
- **Triage skills documented** — `repo-recap`, `pr-triage`, `issue-triage` now appear in all documentation tables.
- **`CHANGELOG.md`** — this file, tracking changes from v0.0.1 onward.
- **`/status` command** — one-glance project status dashboard: CLAUDE.md budget, unfilled placeholders, lessons size, hook executability, plugin states (rtk/cbm/ccc/crg/graphify/claude-mem), jq, knowledge graph, MCP servers. At-a-glance ✅/⚠️/❌ per category.
- **`/ask` command** — codebase question router: automatically routes architecture/flow questions to codebase-memory-mcp + graphify, find/search to cocoindex, impact/blast-radius to code-review-graph.
- **`--lite` mode** for `setup-plugins.sh` — skips heavy plugins (graphify, cocoindex, code-review-graph ~1–3 GB total). Installs only rtk + codebase-memory-mcp + claude-mem (~2 min total).
- **Interactive plugin install** — when running from a TTY, `setup-plugins.sh` prompts yes/no for each plugin with recommendation tier (RECOMMENDED/OPTIONAL/HEAVY), estimated time, and manual install instructions. Non-interactive in CI.
- **`SKIP_CBM` env var** — opt-out for codebase-memory-mcp (Section 4, previously had no skip guard).
- **Bootstrap focus modes** — `/bootstrap architecture`, `/bootstrap plugins`, `/bootstrap validate` for targeted re-runs.
- **Lessons-driven review** — `/review` now reads `lessons.md` before the 10-point checklist and surfaces project-specific patterns relevant to the diff.
- **MCP server binary validation** — `/health` now verifies each server in `.mcp.json` has its binary in PATH (with known mapping: cocoindex→`ccc`, code-review-graph→`uvx`).

### Changed

- **`tdd-loop-check.sh` moved** from `claude/scripts/` → `.claude/hooks/` for consistency with all other hooks.
- **`setup-plugins.sh`** — removed `-q` flag from cocoindex install (users see download progress for ~1 GB install); added `--lite`/`--interactive`/`--non-interactive` flags; added `ask_plugin()` interactive prompt function.
- **README** — "Get Started in 5 Minutes" → "Get Started in 5 Minutes (+ ~15 min for full plugin setup)".
- **Command/skill/hook counts** synced to reality: 31 commands (was 26), 11 skills (was 5/8), 15 hooks (was 12/14).
- **DETAILED_GUIDE.md** — hooks table updated to 15 entries; skills table updated to 11 entries; all 31 commands listed.

### Fixed

- **`/review` and `/mr`** — removed `disable-model-invocation: true` from both. The flag prevented the model from processing the command body, silently breaking the two most value-critical commands.
- **`/review` and `/mr` pre-fetch** — `$(git merge-base main HEAD)..HEAD` → `main...HEAD` to avoid `command_substitution` rejection.
- **`health.md`** — added YAML frontmatter (`description`, `effort: low`, `allowed-tools`). Was the only command without metadata.
- **`tdd-loop-check.sh` hook path** in `settings.json` — added `${CLAUDE_PROJECT_DIR:-.}` guard (was a bare relative path).
- **`validate.sh`** — added `rtk-rewrite.sh` and `tdd-loop-check.sh` to hook check list; fixed placeholder fail message threshold.

---

## [0.4.0] — 2026-04-14 (PR #11)

### 🔧 RTK — Command Token Optimizer

### Added

- **rtk plugin** — Rust binary that transparently rewrites Claude's bash commands for 60-90% output token savings. No-op when absent.
- **`rtk-rewrite.sh`** PreToolUse hook — intercepts all Bash tool calls before execution.
- `rtk gain` / `rtk discover` commands for ROI tracking and gap discovery.

---

## [0.3.0] — 2026-04-13 (PR #9, #10)

### 🧠 Graphify + Three-Tool Memory Stack

### Added

- **graphify** knowledge graph — Python package + git post-commit hook for automatic AST re-indexing. Generates `GRAPH_REPORT.md` with god nodes, community structure, and surprising cross-module connections.
- **claude-mem** plugin — persistent cross-session memory (SQLite + ChromaDB). Installed and disabled by default (quota protection: PostToolUse(\*) fires after every tool call).
- **`toggle-claude-mem.sh`** — enable/disable claude-mem with worker lifecycle management.
- Three-tool memory stack: graphify (architecture snapshot) + codebase-memory-mcp (live structural) + claude-mem (temporal).

### Fixed

- Phantom files and attention issues impacting session context quality (#10).

---

## [0.2.0] — 2026-04-13 (PRs #5, #6, #7, #8)

### 🖥️ Cross-Platform Hardening + Model-Aware Routing

Full portability pass ensuring the installer and all scripts work identically on Linux, macOS (bash 3.2 system shell), and Windows (Git Bash / MSYS2). Plus model-aware agent routing for local LLM compatibility.

### Added

- **Model-aware agent routing** — agents declare optimal model (`opus` for review/security, session model for research) with graceful fallback. Local LLMs (Ollama, LM Studio) work out of the box. Protocol auto-scales to model capability. (PR #5)
- **Source guards** on all 13 scripts — prevents environment corruption when accidentally sourced instead of executed. (PR #5)
- **`_platform.sh`** — Portable shell helper library sourced by all scripts: `sed_inplace()` (macOS `-i ''` vs Linux `-i`), `safe_pgrep()` (fallback for Git Bash), `require_tool()` (actionable install instructions per OS), `supports_unicode()`, emoji symbol fallback (`PASS_SYM`, `FAIL_SYM`, `WARN_SYM`), Windows path normalization
- **`install.sh --check`** — Pre-flight mode: verifies platform, git, jq, bash version before any install operation
- **`portability-lint.sh`** — Extensible GNU-only pattern detector (catches `head -n -N`, `grep -P`, process substitutions, etc.)
- **`integration-test.sh`** — 17 end-to-end integration tests: FRESH install, UPGRADE idempotency, self-bootstrap guard, non-git-root guard, non-existent target guard, `_platform.sh` sourceable check, file count check
- **3-platform CI matrix** — `validate` and `integration` jobs now run on `ubuntu-latest`, `macos-latest`, and `windows-latest`
- **Platform Support section** in README — compatibility table for all supported environments

### Fixed

- **`install.sh` Check 3** — Replaced `--show-toplevel` path string comparison (fails on macOS symlinks `/var` vs `/private/var` and Windows MSYS vs native paths) with `--show-cdup` (empty at repo root — no path format dependency)
- **`integration-test.sh` cleanup** — `CLEANUP_DIRS+=()` was inside a `$()` subshell (modifications silently lost); moved to caller scope. Empty-array guard `${arr[@]+"${arr[@]}"}` prevents `unbound variable` crash on bash 3.2 (macOS system shell) with `set -u`
- **`pre-compact.sh`** — Replaced GNU-only `head -n -20` with portable count-then-head pattern
- **`cross-layer-check.sh`** — Replaced `grep -P` (PCRE, not available on macOS) with `grep -wE` (POSIX)
- **`setup-plugins.sh`, `toggle-claude-mem.sh`** — Replaced `pgrep`/`pkill` with `safe_pgrep()` fallback for Git Bash/Windows
- **`install.sh` (UPGRADE)** — Replaced 7 process substitutions `< <(find)` with tmpfile pattern for macOS bash 3.2 compatibility
- **Inaccurate feature/behavior claims** — full audit of README and DETAILED_GUIDE corrected overstated or incorrect descriptions (PR #7)
- **Model selection documentation** — added enforcement instructions for Claude Code agent frontmatter (PR #8)

### Changed

- `install.sh` now sources `_platform.sh` at startup — banner shows `Platform: linux/macos/windows`
- CI expanded from 3 jobs to 5: added `portability` lint and `integration` test matrix (all 3 platforms)
- `_platform.sh` DRY-consolidates 3 duplicate `sed_inplace()` definitions that previously lived in separate scripts

---

## [0.1.0] — 2026-04-13

### 🔍 Massive Discovery Engine Expansion — 1100+ Frameworks

The biggest single update to `discover.sh` — framework detection expanded from 480 to **1115 unique frameworks** across 25+ languages. Every addition is industry-driven: Language → Industry → Package.

### Added

#### JS/TS (110+ new)

- **Serverless/Edge**: Cloudflare Workers, Netlify Functions, Vercel Functions, OpenFaaS
- **CSS/Styling**: Vanilla Extract, Stitches, UnoCSS, WindiCSS, PandaCSS, PicoCSS, DaisyUI, NextUI, Fluent UI, BlueprintJS, Tremor, Ark UI
- **Animation**: GSAP, React Spring, Lottie, Anime.js, Motion One, AutoAnimate
- **Data Grids**: TanStack Table, AG Grid, Handsontable
- **Rich Text Editors**: Tiptap, Lexical, CKEditor, Quill, ProseMirror, Slate, Milkdown, BlockNote
- **Date/Time**: date-fns, Day.js, Luxon, Moment.js, Temporal Polyfill
- **DI Containers**: Inversify, TSyringe, Awilix
- **Workflow/Jobs**: Inngest, Defer, Quirrel, Graphile Worker
- **Scraping**: Cheerio, Crawlee
- **Build Tools**: Changesets, Lerna, SWC, unbuild, Parcel
- **Config**: dotenv, T3-Env, Convex
- **Drag & Drop**: dnd-kit, react-beautiful-dnd
- **CLI**: Commander, Oclif, Ink, Citty
- **Email Templating**: React Email, MJML
- **Video/Streaming**: HLS.js, Video.js, Remotion
- **Security**: bcrypt, Helmet, Argon2, CORS, CSRF
- **Payments**: Coinbase, MercadoPago, Iyzico, Wise, Flutterwave
- **Plus**: Sonner, React Hot Toast, Bottleneck, Rate Limiter, Bugsnag, Highlight, Honeybadger, PropelAuth, Stytch, FormatJS, Lingui, React Aria, Keyv

#### Python (48+ new)

- **Security/Crypto**: Cryptography, Passlib, bcrypt, python-multipart
- **DB Drivers**: Psycopg, PyMySQL, PyMongo, Motor, Cassandra Driver, Neo4j
- **Data Engineering**: PySpark, Dask, Vaex, Great Expectations, Delta Lake, PyArrow, SQLModel
- **Config**: python-dotenv, Dynaconf, Hydra
- **Serialization**: Marshmallow, attrs
- **API/gRPC**: gRPC-Python, Requests, Tenacity, Pika-RabbitMQ, NATS
- **ML Deployment**: FastAPI-Users, ONNX, Triton, vLLM, HF-PEFT
- **CV/Audio**: YOLO, Detectron2, Whisper, Librosa, Pydub
- **Monitoring**: Prometheus, structlog, Loguru
- **IaC**: Pulumi-Python, Troposphere
- **Time Series**: Prophet, Statsmodels, TimeSeries-ML

#### Rust (27+ new)

- **Networking/Crypto**: Rustls, ring, libp2p, Quinn-QUIC
- **Database**: rusqlite, MongoDB-Rust, Redis-rs, Sled, RocksDB
- **Testing**: Proptest, Mockall, Insta, Criterion
- **Serialization**: Bincode, Prost-Protobuf
- **CLI/TUI**: Ratatui, Dialoguer, Indicatif
- **Error Handling**: Anyhow, Thiserror, Eyre
- **Config**: Config-rs, Figment
- **Observability**: Metrics-rs, Prometheus

#### Go (29+ new)

- **Auth/Security**: JWT-Go, OIDC-Go, Casbin
- **HTTP**: Go-Kit, Resty, Gorilla Schema, WebSocket-Go
- **Database**: MongoDB-Go, BadgerDB, BoltDB, sqlx-Go, Bun-Go
- **CLI/TUI**: urfave-cli, BubbleTea, Lipgloss, Glamour
- **Networking**: DNS-Go, QUIC-Go
- **Config**: godotenv, Koanf
- **Testing**: Godog, Mockery, go-sqlmock
- **API**: OpenAPI-Go
- **Service Mesh**: Envoy Control Plane

#### Java/Kotlin (40+ new)

- **Messaging**: ActiveMQ, Apache Pulsar, RabbitMQ, NATS
- **Security**: Apache Shiro, BouncyCastle
- **Serialization**: Protobuf, Apache Avro
- **Search**: Lucene, Elasticsearch
- **Spring Cloud**: Stream, Gateway, Config
- **Scheduling**: Quartz
- **Caching**: Hazelcast, EhCache
- **Validation**: Bean Validation
- **Reactive**: RxJava
- **Service Discovery**: Eureka, Consul, Zuul
- **Kotlin/Android**: Exposed, SQLDelight, KSP, Detekt, MockK, Kotest, Navigation, WorkManager, Paging, DataStore, Coil, Glide, OkHttp, Moshi, Timber

#### Ruby (17+ new)

- **Testing**: Shoulda, SimpleCov
- **API**: Grape Entity, Oj, Pagy
- **Auth**: Rodauth, Warden
- **State Machines**: AASM, Statesman
- **Deployment**: Capistrano, Kamal
- **Monitoring**: Skylight, Sentry
- **Caching**: Memcached, Rack-Attack

#### PHP (19+ new)

- **Laravel Ecosystem**: Breeze, Jetstream, Cashier, Scout, Octane, Pennant, Pulse, Reverb
- **Admin**: Nova, Backpack, EasyAdmin
- **Testing**: Mockery, Dusk
- **Auth**: JWT-PHP
- **Observability**: Sentry, Bugsnag
- **Deployment**: Deployer

#### .NET (11+ new)

- **Identity**: IdentityServer (Duende)
- **CQRS**: EventFlow, Marten
- **Database**: Npgsql, MongoDB, MySQL
- **Jobs**: Quartz
- **HTTP**: RestSharp, Refit

#### Elixir (12+ new)

- **Auth**: Guardian, Pow, Ueberauth
- **HTTP**: Tesla, Finch
- **Testing**: ExMachina, Wallaby
- **JSON**: Jason
- **PDF**: ChromicPDF

#### Dart/Flutter (14+ new)

- **Testing**: Mockito, Flutter Test, Patrol
- **State**: MobX, Redux, Signals
- **Networking**: Retrofit, GraphQL
- **Storage**: SQFlite, ObjectBox, Appwrite

#### Scala (5+ new)

- Chimney, Quill, Cats-Effect, sttp, Refined

#### C/C++ (20+ new)

- **Networking**: Asio, CPR, libcurl, WebSocket++
- **JSON**: nlohmann-json, RapidJSON
- **Scientific**: Eigen, Armadillo
- **Logging**: spdlog, fmt
- **GUI**: wxWidgets, FLTK
- **Audio**: PortAudio, FFmpeg
- **Database**: SQLite, libpq
- **Testing**: Google Benchmark, Doctest

#### Cross-Language Infrastructure (25+ new)

- **Observability**: Grafana, Prometheus configs, Distributed Tracing (Jaeger/Zipkin)
- **Secret Management**: SOPS, Vault configs
- **Containers**: Docker Compose, DevContainers, Vagrant
- **API Specs**: OpenAPI Spec files, Protobuf files, GraphQL schema files, Avro Schema files
- **Documentation**: mdBook, Jekyll configs, Sphinx, Antora
- **Monorepo Tools**: Moon, Rush, Pants, Buck2
- **IaC**: Crossplane, Bicep, CDKTF
- **GitOps**: FluxCD

### Changed

- `discover.sh` expanded from ~2775 to ~3877 lines (+1102 lines)
- Framework count: 480 → 1115 unique detections (+633 unique, +935 cross-language detection lines)
- All documentation updated to reflect new counts

---

## [0.0.1] — 2026-04-13

### 🎉 Initial Public Release

The first public release of ẂB Brain Bootstrap — a complete AI knowledge architecture for Claude Code and any LLM.

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

- **`discover.sh`** — 3800+ line repo scanner: 25+ languages, 1100+ frameworks, 21 package managers, 13 CI systems, zero tokens
- **`populate-templates.sh`** — Batch fills 70+ `{{PLACEHOLDER}}` values in one pass
- **`post-bootstrap-validate.sh`** — Unified post-bootstrap validation (validate + canary + auto-fix)
- **`validate.sh`** — 120-check template validator (file existence, JSON validity, hook executability, placeholder integrity)
- **`canary-check.sh`** — Live config health check (token budget, stale refs, @imports)
- **`phase2-verify.sh`** — Phase 2 data-integrity verification for Smart Merge
- **`generate-service-claudes.sh`** — Auto-generates per-service `CLAUDE.md` stubs for monorepo services
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

---

<!-- Version comparison links -->

[1.0.0]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.6.6...v1.0.0
[0.6.6]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.6.5...v0.6.6
[0.6.5]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.6.4...v0.6.5
[0.6.4]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.6.3...v0.6.4
[0.6.3]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.5.2...v0.6.0
[0.5.2]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/y-abs/claude-code-brain-bootstrap/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/y-abs/claude-code-brain-bootstrap/releases/tag/v0.0.1
