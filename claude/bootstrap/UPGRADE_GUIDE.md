# Bootstrap Upgrade Guide — ᗺB Brain Bootstrap

> **Read this ONLY when `MODE=UPGRADE`.** Follow steps A through H, then return to `claude/bootstrap/PROMPT.md` → Phase 3.
> Powered by [Brain Bootstrap](https://github.com/y-abs/claude-code-brain-bootstrap) · by y-abs

---

> **SACRED RULE: NEVER LOSE USER DATA.** Domain knowledge, lessons, task state are irreplaceable.

## Pre-upgrade Safety Backup

`install.sh` creates this backup automatically before touching anything. If you ran install.sh, the snapshot already exists:

```bash
ls -lh claude/tasks/.pre-upgrade-backup.tar.gz 2>/dev/null && echo "✅ Backup exists — skip this block" || echo "⚠️  No backup found — create one now"
```

If no backup exists (you copied template files manually without running install.sh), create it now:

```bash
# Only if install.sh was NOT used
tar czf claude/tasks/.pre-upgrade-backup.tar.gz CLAUDE.md .claudeignore .claude/ claude/ .github/ 2>/dev/null || true
echo "✅ Pre-upgrade backup saved to claude/tasks/.pre-upgrade-backup.tar.gz"
```

> **Restore at any time**: `tar xzf claude/tasks/.pre-upgrade-backup.tar.gz`

Check discovery output for `LAYOUT_MIGRATION_NEEDED=true` or `=merge`. Apply strategies below in order:

## A. Normalize Directory Structure

**If `LAYOUT_MIGRATION_NEEDED=true`** (tasks at `tasks/` or `.tasks/` root, not `claude/tasks/`):
- Create `claude/tasks/` if missing
- Move `tasks/lessons.md` or `.tasks/lessons.md` → `claude/tasks/lessons.md` (ONLY if destination doesn't exist)
- Move `tasks/todo.md` or `.tasks/todo.md` → `claude/tasks/todo.md` (ONLY if destination doesn't exist)
- Move `tasks/bootstrap-report.md`, `tasks/session-logs/`, `tasks/.claude-*` temp files → `claude/tasks/`
- Delete now-empty `tasks/` or `.tasks/` (only if truly empty — do NOT touch non-Claude files)
- Update `plansDirectory` in `.claude/settings.json` to `"./claude/tasks/"`
- Scan `.claude/hooks/*.sh` for bare `tasks/` refs → replace with `claude/tasks/`

**If `LAYOUT_MIGRATION_NEEDED=merge`** (`claude/tasks/` exists AND old location has real user data):
- Append user lessons to `claude/tasks/lessons.md` (after the template header)
- Copy `todo.md` only if user's has real task data
- Delete old directory, update `plansDirectory`

## B. Enhance — `CLAUDE.md`

Read the user's CLAUDE.md. For each **missing** section below: append it with `<!-- Added by template upgrade [date] -->`. For existing sections missing items: add only the missing items marked `<!-- template upgrade -->`. **NEVER remove or overwrite user content.**

Required sections: `@import directives` · `Mandatory Reads table` · `Operating Protocol (8 items)` · `Token Cost Strategy` · `Meta-Cognition` · `Exit Checklist (6 items)` · `Terminal Rules` · `Critical Patterns` · `Review Protocol (10-point)` · `Hard Constraints` · `Compact Instructions` · `Session Continuity Protocol` · `Plugin Ecosystem` · `Core Principles` · `IDE Integration`

Conditional sections (add ONLY if not already covered by `Critical Patterns`):
- `Key Decisions` — skip if architectural decisions are already bullet points in Critical Patterns
- `Don't list` — skip if prohibitions are already in Critical Patterns or Hard Constraints
- **Rationale**: Mature hand-crafted configs often flatten decisions + prohibitions into Critical Patterns for faster scanning. Adding separate sections would create duplication. Only add these sections for FRESH installs or if Critical Patterns is sparse (<5 items).

Also: update any `tasks/lessons.md` references → `claude/tasks/lessons.md` if migration occurred.

## C. Deep Merge — `.claude/settings.json`

Parse both files. Produce merged settings.json:
1. **`plansDirectory`**: `"./claude/tasks/"` (required)
2. **`env`**: Template defaults; user values WIN
3. **`hooks`**: Keep ALL user hooks. Add template hooks with different `id`. Same `id` → keep user's
4. **`permissions.allow`**: Union, deduplicate. **Stack-aware**: only add permissions for tools detected by `discover.sh`.
   - **Python tools** (`Bash(pytest *)`, `Bash(ruff *)`, `Bash(black *)`, `Bash(mypy *)`, `Bash(pip *)`) → ONLY if `PRIMARY_LANGUAGE=python` OR `PACKAGE_MANAGER=pip/poetry/uv/pdm`. **Do NOT add** when Python appears only in `SECONDARY_LANGUAGES` (e.g., 65 `.py` scripts in a TypeScript/Java monorepo — those are build tools, not the dev language).
   - **Docker tools** (`Bash(docker compose *)`, `Bash(docker build *)`, etc.) → only if Docker Compose file detected
   - **Java tools** (`Bash(mvn *)`, `Bash(gradle *)`) → only if `PRIMARY_LANGUAGE=java` or build file detected
5. **`permissions.deny`**: Union, deduplicate
6. **`spinnerTipsOverride`**: Normalize to `{"tips": [...], "excludeDefault": true}`, merge tips
7. **`companyAnnouncements`**: Union
8. **Other fields**: Template default; user's value wins if present

```bash
jq . .claude/settings.json > /dev/null && echo "✅ settings.json valid" || echo "❌ FIX REQUIRED"
```

## D. Add Missing — Commands, Hooks, Agents, Skills, Rules

For each dir (`.claude/commands/`, `.claude/hooks/`, `.claude/agents/`, `.claude/rules/`, `.claude/skills/*/`):
- File exists → **keep exactly as-is**
- File missing → **add from template**
- After adding hooks: `chmod +x .claude/hooks/*.sh`

If `claude/scripts/tdd-loop-check.sh` missing from repo root, add from template. (Its `{{TEST_CMD_ALL}}` and `{{LINT_CHECK_CMD}}` placeholders are replaced by the populate script in Phase 3 Step 1.)

## E. Preserve + Add — `claude/*.md` Knowledge Docs

- **NEVER overwrite existing `claude/*.md` files**
- Add only missing files from template
- `claude/tasks/lessons.md`, `claude/tasks/todo.md`, `claude/tasks/CLAUDE_ERRORS.md`: **ABSOLUTELY NEVER modify existing content** (CLAUDE_ERRORS.md: append only)
- If missing: add `claude/docs/DETAILED_GUIDE.md`, `claude/_examples/`, `claude/scripts/`, `.claude/rules/domain/_template.md`

**Phase 3 Step 2 scope for UPGRADE — creative work is EQUALLY mandatory.** Do NOT skip creative population because config already exists. Your goal: discover patterns in the codebase that are NOT yet documented in existing `claude/*.md` files, and create new docs for them. Decision rule per domain:
- Domain doc exists with ≥5 real patterns → skip (already covered)
- Domain doc exists but is shallow (< 5 quality lines, TODO markers) → treat as MANDATORY to enrich
- Domain entirely missing → treat as MANDATORY to create
Using "existing config" as an excuse to skip reading the actual source code is the #1 cause of UPGRADE output being worse than hand-crafted config. Phase 3 Step 2 always runs at full depth.

**🔎 UPGRADE gap scan (MANDATORY):** Before Phase 3, run the 8 domain detection greps from PROMPT.md item 2. For each grep that returns results, check: does a corresponding `claude/<domain>.md` exist with ≥5 real patterns? If NOT, you MUST create that domain doc during Phase 3 Step 2. Common gap domains in UPGRADE mode: `lifecycle.md`, `adapters.md`, `enrollment.md`, `reporting.md` (these are often missing from first-pass bootstraps but EXIST in hand-crafted configs). Do NOT skip them.

**🔎 Rules gap scan (MANDATORY):** For each `claude/<domain>.md` that exists (excluding architecture/rules/terminal-safety/build/cve-policy/templates/decisions), check: does `.claude/rules/<domain>.md` exist with `paths:` set to actual project directories? If NOT, create it during Phase 3 Step 2 item 7.

**Stub enrichment**: `generate-copilot-docs.sh` automatically enriches `.github/instructions/` stub files (< 4 content lines or containing TODO). Re-run after creating domain docs to propagate your new content.

## F. Union — `.claudeignore`

Keep ALL user patterns. Add missing template patterns preceded by `# Added by template upgrade [date]`.

**Stack-awareness (important):** Only add patterns for tools/languages **actually used as the primary dev language** in the project. Use `PRIMARY_LANGUAGE` and `PACKAGE_MANAGER` from `discover.sh` — not just file counts. For example:
- `yarn.lock` / `bun.lockb` / `.yarnrc` → only if `PACKAGE_MANAGER=yarn` or `PACKAGE_MANAGER=bun`
- `__pycache__/` / `.venv/` / `.pytest_cache/` / `*.pyc` → only if `PRIMARY_LANGUAGE=python` OR `PACKAGE_MANAGER=pip/poetry/uv/pdm`. **CRITICAL**: if Python appears only in `SECONDARY_LANGUAGES` (e.g., shell scripts, build utilities alongside a TypeScript primary), do **not** add Python ignores — those files are in-use and shouldn't be excluded
- `.gradle/` / `.bsp/` / `.metals/` → only if Gradle/Scala detected
- `vendor/` → only if Go or PHP detected
- `.turbo/` → only if Turborepo detected

Universal patterns (always safe to add): `**/*.zip`, `**/*.exe`, `**/*.dll`, `**/*.so`, `**/*.wasm`, `**/*.min.js`, `**/*.min.css`, `**/*.map`, `**/out/`, `**/generated/`, `**/.cache/`, `tasks/.claude-*`, `tasks/session-logs/`, `tasks/.permission-denials.log`

## G. Add Missing — `.github/` Copilot Files

- **NEVER overwrite** existing `.github/copilot-instructions.md`
- Add any missing instruction/prompt files from template

## H. Post-Merge Verification (MANDATORY — every line must show ✅)

```bash
bash claude/scripts/phase2-verify.sh .
```

Fix any ❌ by restoring from backup before proceeding.

---

> ✅ **Phase 2 complete.** Return to `claude/bootstrap/PROMPT.md` → Phase 3.

