# Bootstrap Prompt — ᗺB Brain Bootstrap

> **Paste this into Claude Code.** Works on both fresh repos and repos with an existing Claude Code configuration.
> Powered by [Brain Bootstrap](https://github.com/y-abs/claude-code-brain-bootstrap) · by y-abs
> The AI will detect your tech stack, then either install from scratch or **intelligently upgrade** your existing config — preserving all your domain knowledge, lessons, and customizations.

---

## ⛔ READ THIS FIRST — FILES YOU MUST NEVER CREATE

Bootstrap is **READ + CONFIGURE**. You document what exists. You do not initialize or scaffold the project.

**Never create these files:**
- Any `*.lock` file (`yarn.lock`, `package-lock.json`, `pnpm-lock.yaml`, `bun.lockb`)
- Package manager configs for tools **not already in the project** (`.yarnrc.yml` if no yarn, `bunfig.toml` if no bun)
- Any `.env*` file (blocked by permissions)

The ONLY paths you write to: `claude/`, `.claude/`, `.github/`, `CLAUDE.md`, `.claudeignore`.

---

## ⭐ START HERE — READ · PLAN · EXECUTE (mandatory before any tool call)

**Three rules that govern the entire bootstrap:**

**1. SCAN EVERYTHING FIRST** — before running any command, skim all `### Phase` headings below. You need the full mental model before the first tool call. Takes 30 seconds. Prevents skipping steps.

**2. WRITE YOUR PLAN FIRST** — your very first action is:

```bash
cat > claude/tasks/.bootstrap-plan.txt << 'PLAN'
MODE: TBD (Phase 1 will set this)
P1: discover.sh → read MODE= line → start plugin bg install
P2: FRESH→SKIP | UPGRADE→read claude/bootstrap/UPGRADE_GUIDE.md, run A through H then verify
P3S1: populate-templates.sh (1 command)
P3S2 checklist (mark ✓ as done):
  [ ] 1. architecture.md
  [ ] 2. CLAUDE.md (lookup table + critical patterns + hard constraints + key decisions + don't list)
  [ ] 3. Domain docs + .claude/rules/ per signal
  [ ] 4. .claude/commands/context.md (domain→file mapping)
  [ ] 5. copilot-instructions.md (patterns + lookup table)
  [ ] 5b. .github/instructions/ globs (actual service paths)
  [ ] 6. test.md + lint.md vs SECONDARY_LANGUAGES
  [ ] 7+8. rules/ + skills/ per domain (MANDATORY if ≥3 domains)
P4: setup-plugins.sh (1 command — all automated)
P5: post-bootstrap-validate.sh · report from claude/bootstrap/REFERENCE.md
Risk: [one specific risk for THIS repo — fill in after Phase 1]
PLAN
cat claude/tasks/.bootstrap-plan.txt
```

**You may NOT run any other command until `.bootstrap-plan.txt` exists.** Update `Risk:` after Phase 1.

**3. ALWAYS BATCH PARALLEL READS** — reading N files sequentially costs N×3s. Reading N in parallel costs 3s once. Whenever you need ≥2 files: read them all in one parallel batch. Applies every phase.

---

## ⚡ AUTONOMOUS EXECUTION MODE — MANDATORY

**Execute all operations immediately and autonomously. Do NOT ask for permission. Do NOT pause between phases. Do NOT say "shall I proceed?" — just proceed.**

If you hit ambiguity, make the best choice and document it in the report. Only stop for genuine blockers.

---

## 📋 Phase Map

| Phase | Applies to | Core action | Expected AI-work |
|:------|:-----------|:-----------|:---:|
| **1** Discovery | Both | `discover.sh` → sets MODE, starts plugin bg install | ~2s |
| **2** Smart Merge | **UPGRADE only** | Read guide → backup → preserve + enhance | 1-3 min |
| **3** Populate | Both | Script + creative docs | 3-5 min |
| **3.5** MCP | Both | Scan discovery → add suggestions to report (no user input) | ~5s |
| **4** Plugins | Both | 1 script: claude-mem (install, disable, verify) + graphify (pip, skill, hooks) | ~5s |
| **5** Validate | Both | Validate script + report | 30s |

---

## 🔴 Quality Standards — memorize, apply every phase

- **NEVER lose user data** — lessons, domain docs, tasks are irreplaceable. No exceptions.
- **Real patterns only** — read actual source files. Generic filler defeats the purpose.
- **First-session productive** — every file must work immediately after bootstrap.
- **UPGRADE = additive** — never remove or overwrite existing user-written content.
- **Stack-aware, not kitchen-sink** — only add config/ignores/permissions for tools ACTUALLY detected. Adding `yarn.lock` to `.claudeignore` in a pnpm project is noise.
- **No phantom files** — NEVER create empty placeholder files (`.env`, `yarn.lock`, `bunfig.toml`, etc.) to test detection heuristics. Run discovery as read-only.

---

### Phase 1: Discovery + Background Plugin Install (2 commands)

> TL;DR: Run discovery script, read MODE= line, start plugin install in background, done.

```bash
bash claude/scripts/discover.sh . > claude/tasks/.discovery.env 2>&1
cat claude/tasks/.discovery.env
```

Auto-detects in ~2 seconds: project name, languages (with file counts), package manager, runtime, formatter/linter, test framework, build/test/lint/serve/migrate/db/deps commands, security scanner, monorepo tools, CI, database/ORM, Docker, 1100+ frameworks, installed plugins.

**Read the output.** The `MODE=` line tells you FRESH or UPGRADE. Update `Risk:` in your plan file now.

> **⚠️ SELF-BOOTSTRAP CHECK (mandatory):** If `IS_TEMPLATE_REPO=true`, **STOP**. You are running on the template repo itself. Copy template files into your target project first, then re-run.

```bash
# Start plugin install in background NOW (runs during Phase 2/3 — saves 30-60s)
if grep -q 'HAS_CLAUDE_MEM=false' claude/tasks/.discovery.env 2>/dev/null; then
  setsid claude plugin install claude-mem@thedotmack > claude/tasks/.plugin-install.log 2>&1 &
  echo "⏳ claude-mem install started in background (PID $!)"
else
  echo "✅ claude-mem already installed"
fi
# Report all plugin statuses discovered (so the plan reflects true state)
echo "📦 Plugin status from discovery:"
grep -E '^HAS_(CLAUDE_MEM|GRAPHIFY|RTK|CBM|COCOINDEX|CRG|CODEBURN|CAVEMAN|SERENA)=' \
  claude/tasks/.discovery.env 2>/dev/null | sed 's/^/  /' || true
echo "P1 $(date +%H:%M:%S)" > claude/tasks/.bootstrap-progress.txt
```

---

### Phase 2: Smart Merge (UPGRADE only — FRESH: skip entirely, go to Phase 3)

> If MODE=UPGRADE: read `claude/bootstrap/UPGRADE_GUIDE.md` and follow ALL steps A through H. Then continue here.
> If MODE=FRESH: skip to Phase 3.
> **💾 Backup note**: `install.sh` already created `claude/tasks/.pre-upgrade-backup.tar.gz` — no need to re-run it.

```bash
cat claude/bootstrap/UPGRADE_GUIDE.md
```

**✅ Phase 2 done when `phase2-verify.sh` passes (instructions in the guide).**

---

### Phase 3: Template Population (2 steps — mechanical then creative)

> TL;DR: 1 command fills ~70 placeholders; then YOU fill what needs reasoning.

#### Step 1: Batch Mechanical Replacement (1 command)

```bash
bash claude/scripts/populate-templates.sh claude/tasks/.discovery.env . 2>&1
```

Handles in one pass: `PROJECT_NAME` (8 files), build/test/lint/serve commands, package manager, runtime, formatter, scanner, migration/DB/deps commands, TDD skill layers, settings.json permissions, **plus**:
- **Per-service CLAUDE.md stubs** — `generate-service-claudes.sh` creates stubs for each monorepo service
- **IDE Integration** — auto-detects `.idea/`/`.vscode/` → uncomments matching CLAUDE.md section
- **GitHub Copilot docs** — `generate-copilot-docs.sh` mirrors `claude/*.md` → `.github/copilot/`

**Read the output.** It lists remaining placeholders for creative work.

---

#### Step 2: Creative Population (YOU do this)

> 🧠 **ATTENTION CHECK** — Most important phase. Re-read your checklist and mark what's still unchecked:
> ```bash
> cat claude/tasks/.bootstrap-plan.txt
> ```
> Rules still in effect: (1) NEVER lose user data, (2) real patterns from code — not filler, (3) batch reads

> **⚠️ DEPTH RULE**: For repos with >10 services, read 2-3 actual source files per domain. A 20-line doc with 3 real patterns beats 100 lines of filler.

> **⚠️ ALREADY AUTOMATED** (do NOT redo): per-service stubs, IDE section. After YOU create domain docs, re-run: `bash claude/scripts/generate-copilot-docs.sh . 2>&1` — this mirrors docs AND extracts key patterns into `.github/instructions/`. Review the generated files and **refine `applyTo` globs** to match actual project paths (e.g., `"src/services/auth-service/**"` is better than `"**/auth*/**"`).

---

##### 🔴 MANDATORY — Complete ALL (items 1-6). Skipping any = broken config.

**Step 0 (BEFORE any creative work): Run the quality gate**

```bash
bash claude/scripts/pre-creative-check.sh . 2>&1
```

**You MUST follow the manifest output:**
- **SKIP** domains → do NOT create or modify their docs (they already have ≥5 real patterns)
- **ENRICH** domains → read source files, add real patterns to the existing doc
- **CREATE** domains → create `claude/<domain>.md` + `.claude/rules/<domain>.md`

This prevents duplicate docs while ensuring gaps are filled. The manifest overrides item 2's greps below — if the manifest says SKIP, do NOT create that domain doc even if the grep returns hits.

1. **`claude/architecture.md`** — Fill workspace layout, service/module catalog, shared packages, infrastructure. Use `TOP_DIRS` from discovery plus:
   ```bash
   ls -d */ 2>/dev/null
   ```
   For monorepos: check each dir for `package.json`, `Cargo.toml`, `go.mod`, `pom.xml`.

2. **`CLAUDE.md` — Fill ALL commented sections + scan for Critical Patterns**:
   - `<!-- {{DOMAIN_LOOKUP_TABLE}} -->` — one row per domain doc created
   - `<!-- {{CRITICAL_PATTERNS}} -->` — **DEPTH PROTOCOL**: run ALL 8 greps below. For each that returns results, you MUST create a domain doc (item 3) AND write the actual pattern from that file into `{{CRITICAL_PATTERNS}}`. Generic advice is worthless; project-specific patterns with real file paths are the goal.
     ```bash
     # Messaging (Kafka/RabbitMQ/SQS/NATS) → claude/messaging.md
     grep -rl 'KafkaConsumer\|KafkaProducer\|producer\.\|createTopic\|RabbitMQ\|SQSClient\|NATS\|publishMessage' . --include='*.js' --include='*.ts' 2>/dev/null | head -5 || true
     # DB / multi-connection → claude/database.md
     grep -rl 'knex\|\.db\.\|createConnection\|getRepository\|DataSource' . --include='*.js' --include='*.ts' 2>/dev/null | head -5 || true
     # State machine / lifecycle / status workflow → claude/lifecycle.md
     grep -rl 'StatusCode\|StatusEnum\|\.state\b\|transition\|workflow.*state\|state.*machine' . --include='*.js' --include='*.ts' 2>/dev/null | head -5 || true
     # Auth / identity (Keycloak/Auth0/Cognito/OIDC) → claude/auth.md
     grep -rl 'keycloak\|realm\|client_credentials\|grant_type\|jwt\|bearer\|guard\|protect\|token.*verify' . --include='*.js' --include='*.ts' 2>/dev/null | head -5 || true
     # Webhooks / callbacks / event delivery → claude/webhooks.md
     grep -rl 'onConflict\|delivery.*id\|idempotent\|deduplicat\|webhook.*url\|callback.*endpoint' . --include='*.js' --include='*.ts' 2>/dev/null | head -5 || true
     # Adapters / integrations / external APIs → claude/adapters.md
     grep -rl 'adapter\|Adapter\|adapterFactory\|BaseAdapter\|ApiClient\|integration\|ExternalAPI' . --include='*.js' --include='*.ts' 2>/dev/null | head -5 || true
     # Reporting / analytics / data export → claude/reporting.md
     grep -rl 'report\|Report\|aggregate\|Aggregate\|export.*data\|analytics\|XSLT\|xlsx\|csv.*export' . --include='*.js' --include='*.ts' 2>/dev/null | head -5 || true
     # User onboarding / registration / signup → claude/enrollment.md
     grep -rl 'signup\|SignUp\|onboard\|Onboard\|registration.*flow\|user.*wizard\|multi.*step.*form\|identity.*verif' . --include='*.js' --include='*.ts' 2>/dev/null | head -5 || true
     ```
     **Read 1-2 actual implementation files per detected signal.** Every grep that returns results = one domain doc + one `.claude/rules/<domain>.md` to create. Do not skip.
   - `<!-- {{HARD_CONSTRAINTS}} -->` — large file patterns to exclude (`.xsd`, `.xslt`, generated files). For every "NEVER add X to context" item, also add glob to `.claudeignore`. Verify both match.
   - `<!-- {{KEY_DECISIONS}} -->` — 2-4 settled architectural choices with dates. Full rationale → `claude/decisions.md` (write ACTUAL entries there — do NOT leave the file empty with "No decisions logged yet")
   - `<!-- {{DONT_LIST}} -->` — explicit prohibitions from codebase analysis

3. **Domain docs + rules** — For EACH domain signal that fired in item 2 greps, create ALL THREE:
   - `claude/<domain>.md` — deep patterns doc (use `claude/_examples/` as reference, ≥50 lines of real patterns)
   - `.claude/rules/<domain>.md` — path-scoped rule (use `_template-domain-rule.md`, set `paths:` to ACTUAL service directories, ≤40 lines)
   - Add domain to lookup table in CLAUDE.md
   - **Detection → doc name mapping** (signals → create if found):
     - Messaging (Kafka/RabbitMQ/SQS/NATS) → `claude/messaging.md` + `.claude/rules/kafka-safety.md`
     - DB / multi-connection → `claude/database.md` + `.claude/rules/database.md`
     - State machine / lifecycle → `claude/lifecycle.md` + `.claude/rules/lifecycle.md`
     - Auth / identity → `claude/auth.md` + `.claude/rules/auth.md`
     - Webhooks / callbacks → `claude/webhooks.md` + `.claude/rules/webhooks.md`
     - Adapters / external integrations → `claude/adapters.md` + `.claude/rules/adapters.md`
     - Reporting / analytics → `claude/reporting.md` + `.claude/rules/reporting.md`
     - User onboarding / registration → `claude/enrollment.md` + `.claude/rules/enrollment.md`
   - **MANDATORY**: Every path in CLAUDE.md lookup table MUST exist on disk. Create stubs if needed.
   - Re-run after creating: `bash claude/scripts/generate-copilot-docs.sh . 2>&1`

4. **`.claude/commands/context.md`** — Add domain→file mapping for each new domain doc

5. **`.github/copilot-instructions.md`** — Fill `<!-- {{CRITICAL_PATTERNS}} -->` with same patterns as CLAUDE.md. Also sync the lookup table: for every row in CLAUDE.md's `Mandatory Reads` table, add a matching row to copilot-instructions.md pointing to the same `claude/<domain>.md` file. The template ships with 5 generic rows — expand to match ALL your domains.

5b. **Refine `.github/instructions/` globs** — `generate-copilot-docs.sh` creates instruction files with heuristic globs (e.g., `**/webhook*/**`). Review each and replace with **actual project paths** (e.g., `"src/services/notification/**,src/lib/adapters/**"`). Precise globs = instructions load only when truly relevant.

6. **Multi-language command validation** — Check `.claude/commands/test.md` and `lint.md` against `SECONDARY_LANGUAGES` from discovery. Every **actively developed** language must be reachable. **Exception**: secondary languages that are only build utilities (e.g., `py` scripts or `sh` hooks in a `pnpm`/TypeScript project) do NOT need dedicated pytest/ruff entries — adding them creates phantom commands that never run. Use `PRIMARY_LANGUAGE` + `PACKAGE_MANAGER` to distinguish dev languages from tooling languages.

> The completion check runs at the end of Phase 3 (below). Continue to recommended items 7–13.

---

##### 🟡 RECOMMENDED — Skip only if codebase is very simple (<5 services, single domain).

7. **Domain `.claude/rules/`** — **MANDATORY if you created ≥3 domain docs in item 3** (any monorepo detected). For EACH domain doc created, create the matching path-scoped rule file. Use `_template-domain-rule.md`. Set `paths:` to ACTUAL service directories from architecture.md (not generic globs). ≤40 lines. Min: kafka-safety + database + auth + webhooks for standard web backends.

8. **Domain skills** — **MANDATORY if you created ≥3 domain docs** (any monorepo) — Top 2-3 complex domains: `.claude/skills/<domain>/SKILL.md`. `user-invocable: false` + `paths:` (ACTUAL project paths, not `**/*`) + `## 🚨 Golden Rule` + `## ⚠️ Gotchas (3-5)`. Use `tdd/SKILL.md` as reference. ≤70 lines. Skills with `paths:` auto-inject background knowledge — without them, Claude rediscovers patterns every session.

9. **Cross-layer-check skill** (monorepos) — Edit `scripts/cross-layer-check.sh`: replace `LAYERS` array with actual directories.

10. **Per-service enrichment** (monorepos) — For 5-10 most complex services: read entry point, append 2-3 specific patterns to their stub. **⚠️ EDIT existing stub (append) — do NOT re-create.** If Write fails, read the file first then edit.

11. **Project-specific commands** — Generate based on what discover.sh detected (NOT based on guesses):
    - `SCANNER=SonarQube` or `sonar-project.properties` found → create `.claude/commands/sonar.md`
    - `SCANNER=trivy` or `trivy.yaml` found → create `.claude/commands/security-scan.md`
    - `helm/` directory found or K8s manifests found → create `.claude/commands/k8s.md`
    - Complex status/workflow enum found → create `.claude/commands/new-status.md`
    - 10-20 lines each, referencing actual project commands.

---

##### 🔵 BONUS — If time permits.

12. **Domain `.github/prompts/`** — DB migrations → `create-migration.prompt.md`; Kafka → `debug-messaging.prompt.md`; state machines → `trace-lifecycle.prompt.md`. Use `_template.prompt.md`.

13. **How-To guides** (skip for simple repos) — If >15 services AND shared enums: `claude/how-to-<procedure>.md`. Structure: Prerequisites → Steps → Verification → Common Mistakes.

---

##### ⚠️ MANDATORY COMPLETION CHECK — Do NOT proceed to Phase 3.5 until this passes.

```bash
bash claude/scripts/check-creative-work.sh . 2>&1
```

Fix any ❌. IDE ⚠️: if `.idea/`/`.vscode/` wasn't detected (fresh clone), uncomment IntelliJ section by default. Then re-run copilot docs:
```bash
bash claude/scripts/generate-copilot-docs.sh . 2>&1
```

**Parallelize**: items within each tier are independent — edit multiple files simultaneously.

---

### Phase 3.5: MCP Server Configuration (auto-skip — note in report only)

> **⚠️ Do NOT ask the user. Do NOT configure MCP servers during bootstrap. Proceed to Phase 4 immediately.**

Scan discovery output for stack-matched suggestions to include in the final report:
- `DATABASE` detected → `postgres` or `mysql` MCP server
- `CI_SYSTEM=github-actions` or GitHub remote → `github` MCP server
- Web frontend detected → `web-search` MCP server
- `DOCKER=true` or Kubernetes → `filesystem` MCP server

Add a **"💡 MCP Suggestions"** bullet list to the final report. User configures post-bootstrap: `/mcp add <server>` · Registry: [registry.smithery.ai](https://registry.smithery.ai).

---

### Phase 4: Plugin Setup (1 command)

> TL;DR: one script handles everything. Plugins extend Claude Code with persistent capabilities it doesn't have natively.

```bash
bash claude/scripts/setup-plugins.sh . 2>&1
```

**Why plugins matter — each solves a specific Claude Code limitation:**

| Plugin | What it solves | Value |
|--------|---------------|-------|
| **claude-mem** | Claude Code forgets everything between sessions | Cross-session memory: observations from every tool use are persisted in SQLite + ChromaDB. Next session, Claude recalls past decisions, mistakes, and patterns without re-exploring. **Disabled by default** — saves ~48% API quota. Enable when doing multi-session work. |
| **graphify** | Claude Code re-reads files every time you ask an architecture question | Knowledge graph: builds a navigable map of your codebase (entities, relationships, communities). After first build (~5 min), architecture questions cost **71.5× fewer tokens**. Auto-rebuilds on git commit/checkout via hooks. |

The script handles installation in sequence:
1. **claude-mem** — waits for background install → disables (quota protection) → kills worker → verifies → updates CLAUDE.md plugin placeholder. If install failed, documents in report with manual command.
2. **graphify** — detects Python 3.10+ → `pip install graphifyy` → `graphify install` (global skill) → `graphify hook install` (git hooks for auto-rebuild on commit/branch switch). If Python not available, skips gracefully with manual instructions.

> **graphify builds the graph on demand, not during bootstrap.** After bootstrap completes, the user runs `/graphify .` to build the knowledge graph (~5 min first run, then incremental via SHA256 cache). The PreToolUse hook in settings.json is already wired — it activates automatically once `graphify-out/graph.json` exists.

> **obsidian-mind**: companion Obsidian vault template (not a plugin). Clone separately: `git clone https://github.com/breferrari/obsidian-mind.git`. See `claude/plugins.md`.

---

### Phase 5: Validate + Report

> TL;DR: validation script → read report template → write report.
> 🧠 **ATTENTION ANCHOR** — The report is the user's FIRST impression of the bootstrap. Re-read `🔴 Quality Standards` above. Enthusiastic, emoji-rich, storytelling — not clinical.

> **⚠️ DO NOT generate custom bash checks for file existence.** The validation scripts (`post-bootstrap-validate.sh`, `validate.sh`, `canary-check.sh`) cover ALL checks. In particular, `.github/ISSUE_TEMPLATE/`, `.github/workflows/`, `.github/PULL_REQUEST_TEMPLATE.md`, `CONTRIBUTING.md`, and `.shellcheckrc` are **template-repo-only** files — `install.sh` does NOT copy them to end-user repos. They are NOT expected to exist in end-user projects.

**Track timing**: note approximate phase start/end times for the report footer.

```bash
bash claude/scripts/post-bootstrap-validate.sh . 2>&1
```

Runs `claude/scripts/validate.sh` + `canary-check.sh` + placeholder check + auto-fixes in one pass.

**If failures remain**: fix immediately, re-run. Do not proceed until clean.

#### Collaboration Mode — TEAM (default)

> **⚠️ Do NOT ask the user.** Default to TEAM. The report includes a SOLO switch command for users who want personal-only config.

**TEAM mode** = commit everything. The `git add` command goes in the report's "What's Next" section.

**SOLO mode** = personal config, not committed. If the user said "solo" or "don't commit" earlier in the conversation, apply SOLO now:
```bash
cat >> .gitignore << 'GITIGNORE'

# Claude Code Brain — SOLO mode (personal AI config, not shared)
CLAUDE.md
CLAUDE.local.md
.claudeignore
claude/
.claude/
.mcp.json
# Keep .github/ committed — Copilot config benefits the team even in SOLO mode
GITIGNORE
```

In the report, always include both options:
```
🤝 Mode: TEAM (default)
   → Commit: git add CLAUDE.md .claudeignore claude/ .claude/ .github/
   → Switch to SOLO later: echo -e '\nCLAUDE.md\nclaude/\n.claude/\n.claudeignore\n.mcp.json' >> .gitignore
```

#### Generate the Report

Read the report template now:
```bash
cat claude/bootstrap/REFERENCE.md
```

Write the full report (use FRESH or UPGRADE template from `claude/bootstrap/REFERENCE.md`) to `claude/tasks/bootstrap-report.md` and present it to the user.

> **⚠️ Report style MANDATORY**: enthusiastic, emoji-rich, storytelling. Do NOT strip emojis. Do NOT use markdown tables (terminal strips `|`). Use **bullet lists with `→` separators**. Include phase timing.

#### Cleanup — Remove Bootstrap Scaffolding

After the report is written and validated, delete the bootstrap scaffolding (it's single-use — re-clone from template for future upgrades):

```bash
rm -rf claude/bootstrap/
echo "✅ Bootstrap scaffolding removed"
```

#### 🗺️ Offer: Build the Knowledge Graph (graphify)

> **This is the absolute last step. Do it AFTER the report is shown to the user.**

If `setup-plugins.sh` successfully installed graphify (check `GRAPHIFY_STATUS` in Phase 4 output), **ask the user ONE question**:

```
🗺️ graphify is installed and ready. Want me to build the knowledge graph now?

   What you get: architecture map, god nodes, community clusters, cross-module connections
   Cost: ~5 minutes (first run — then incremental via SHA256 cache)
   Token savings: 71.5× fewer tokens per architecture question going forward

   → Yes: I'll run /graphify . now
   → No: You can run /graphify . anytime later
```

**This is the ONE exception to "do not ask for permission"** — the graph build takes ~5 minutes and costs tokens (Claude extraction pass). The user should choose when to spend that time.

If the user says yes:
```bash
/graphify .
```

If the user says no or doesn't respond, move on. The PreToolUse hook is already wired — it activates automatically whenever `graphify-out/graph.json` appears.

> This is the last step. `/bootstrap` will guide the user to re-install from template if needed in the future.

```bash
cat claude/tasks/.bootstrap-progress.txt 2>/dev/null || echo "No progress file"
```

Include the timing trail output in the report.

---

### Performance Budget

> **⚠️ AI-work-only times.** Wall-clock includes Claude Code reasoning overhead, tool latency (~2-5s each), context processing. **Expect ~2-3× wall-clock multiplier.** Report both.

- **Phase 1 (Discovery + plugin bg):** ~2s (1 script + background install)
- **Phase 2 (Smart Merge):** ~1-3 min (UPGRADE only — separate guide)
- **Phase 3 Step 1 (Mechanical):** ~5s (1 script)
- **Phase 3 Step 2 (Creative):** ~5-10 min (🔴 MANDATORY first, then 🟡 RECOMMENDED)
- **Phase 3.5 (MCP):** ~10s (optional)
- **Phase 4 (Plugins):** ~5s (1 script — claude-mem + graphify automated)
- **Phase 5 (Validate + Report):** ~10s (1 script + report)
- **AI-work total: ~5-10 min** · **Wall-clock total: ~8-16 min**
