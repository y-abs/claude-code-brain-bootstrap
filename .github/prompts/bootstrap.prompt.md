---
description: Auto-configure or upgrade Claude Code — FRESH install or smart UPGRADE with full preservation of existing config
agent: "agent"
argument-hint: "[optional: fresh|upgrade|hooks|commands|docs]"
---


Auto-configure Claude Code for this repository: {{input}}


**⚠️ AUTONOMOUS EXECUTION: Run all phases A to Z without stopping. NO "shall I proceed?", NO confirmation prompts, NO pauses between phases. If user asks a question mid-bootstrap, answer briefly then continue. ONLY stop for genuine blockers (missing file, script failure).**

## Instructions

**Step 0 — Verify scaffolding exists (MUST do first):**
Run this bash command to check if the bootstrap scaffolding is present:
```bash
test -f claude/bootstrap/PROMPT.md && echo "FOUND" || echo "MISSING"
```

- If **FOUND**: read `claude/bootstrap/PROMPT.md` using the read_file tool (use the exact path `claude/bootstrap/PROMPT.md`), then execute the bootstrap process autonomously.
- If **MISSING**: the scaffolding was cleaned up after a previous bootstrap. Tell the user to re-install: `git clone https://github.com/y-abs/claude-code-brain-bootstrap.git /tmp/brain && bash /tmp/brain/install.sh . && rm -rf /tmp/brain` — then run `/bootstrap` again.

> ⚠️ Do NOT use file search to find PROMPT.md — newly installed files may not be in the git index yet. Use `test -f` or `read_file` with the exact path.

### Quick summary of phases:
1. **Discovery** — Run `bash claude/scripts/discover.sh` (single script, ~2s) → detects stack + plugins + FRESH/UPGRADE mode
2. **Smart Merge** _(UPGRADE only)_ — Normalize directory structure, enhance CLAUDE.md, deep-merge settings.json, add missing commands/hooks/agents without touching existing ones
3. **Population Step 1** — Run `bash claude/scripts/populate-templates.sh` (batch replacement, ~3s) → fills ~70 mechanical placeholders
4. **Population Step 2** — YOU fill architecture.md, CLAUDE.md sections, domain docs (creative work)
5. **Plugins** — Install claude-mem (skip if already installed), disable by default (quota protection), verify present
6. **Validate + Report** — Run `bash claude/scripts/post-bootstrap-validate.sh` (unified check, ~10s) → generate bootstrap-report.md

### If `{{input}}` specifies a focus area:
- `fresh` — Force fresh install mode (use with caution on repos with existing config)
- `upgrade` — Force upgrade mode and run only Phase 2 + 3 + 5 + 6
- `hooks` — Only configure hook scripts (formatter, protected files, extensions)
- `commands` — Only fill command placeholders (build, test, lint commands)
- `docs` — Only generate domain knowledge docs
- `architecture` — Re-run Phase 2 AI writing only: re-fill `claude/architecture.md` sections with fresh analysis of the current codebase (stack, modules, service catalog, key infrastructure). Does not touch any other files.
- `plugins` — Re-run Phase 4 only: run `bash claude/scripts/setup-plugins.sh --interactive .` to install or upgrade plugins. Safe to re-run (idempotent). The user chooses a strategy: none/full/recommended/personalize.
- `validate` — Re-run Phase 5 only: run `bash claude/scripts/post-bootstrap-validate.sh` and generate a fresh `claude/tasks/bootstrap-report.md`. No files are modified.
- `architecture` — Re-run Phase 2 AI writing only: re-fill `claude/architecture.md` sections with fresh analysis of the current codebase (stack, modules, service catalog, key infrastructure). Does not touch any other files.
- `plugins` — Re-run Phase 4 only: run `bash claude/scripts/setup-plugins.sh` to install or upgrade plugins. Safe to re-run (idempotent).
> ✅ **After bootstrap completes:** Run `/health` to verify your setup is working — it checks that all hooks are executable, settings.json is valid, no placeholders remain unfilled, and at least one plugin is installed.

- `validate` — Re-run Phase 5 only: run `bash claude/scripts/post-bootstrap-validate.sh` and generate a fresh `claude/tasks/bootstrap-report.md`. No files are modified.
- `full` or empty — Run all phases (auto-detect mode)

> ✅ **After bootstrap completes:** Run `/health` to verify your setup is working — it checks that all hooks are executable, settings.json is valid, no placeholders remain unfilled, and at least one plugin is installed.
