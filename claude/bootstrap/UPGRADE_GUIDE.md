# Bootstrap Upgrade Guide — ᗺB Brain Bootstrap

> **Read this ONLY when `MODE=UPGRADE`.** Follow steps 0 through 4, then return to `claude/bootstrap/PROMPT.md` → Phase 3.
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

---

## Step 0: Dry Run Preview (MANDATORY)

> **See what will change BEFORE changing anything.**

```bash
bash claude/scripts/dry-run.sh . 2>&1
```

Review the output. If anything looks wrong, stop and investigate. The dry run changes nothing on disk.

---

## Step 1: Tasks Directory Migration (deterministic script)

> Moves ONLY known Claude files (lessons.md, todo.md, CLAUDE_ERRORS.md, session-logs/) from old layout to `claude/tasks/`. NEVER moves non-Claude files. NEVER deletes the source directory.

```bash
bash claude/scripts/migrate-tasks.sh --discovery-env claude/tasks/.discovery.env --target . 2>&1; EC=$?; [ $EC -eq 0 ] || [ $EC -eq 2 ] || exit $EC
```

Exit 0 = migrated · Exit 2 = nothing to migrate (already correct layout) — both are success. Move on.

---

## Step 2: CLAUDE.md Section Enhancement (deterministic script)

> Appends ONLY genuinely missing sections from the template. Never modifies existing content. Uses heading similarity matching (emoji-tolerant, keyword-aware) to detect equivalent sections.

```bash
bash claude/scripts/merge-claude-md.sh --template claude/bootstrap/_CLAUDE.md.template --target CLAUDE.md 2>&1; EC=$?; [ $EC -eq 0 ] || [ $EC -eq 2 ] || exit $EC
```

Exit 0 = sections added · Exit 2 = all sections already covered — both are success. Move on.

---

## Step 3: settings.json Deep Merge (deterministic script)

> Pure jq merge. Hooks merged by ID (same ID → keep yours). Permissions union with stack-aware filtering (no Python tools in a TypeScript project). User values always win.

```bash
bash claude/scripts/merge-settings.sh --template claude/bootstrap/_settings.json.template --target .claude/settings.json --discovery-env claude/tasks/.discovery.env 2>&1
```

Validate:
```bash
jq . .claude/settings.json > /dev/null && echo "✅ settings.json valid" || echo "❌ FIX REQUIRED"
```

---

## Step 3b: .claudeignore Union (deterministic script)

> Preserves ALL your patterns. Adds only missing template patterns with stack-aware filtering.

```bash
bash claude/scripts/merge-claudeignore.sh --template claude/bootstrap/_claudeignore.template --target .claudeignore --discovery-env claude/tasks/.discovery.env 2>&1
```

---

## Step 3c: Add Missing Commands, Hooks, Agents, Skills, Rules

> **Already handled by install.sh Phase C.** install.sh adds missing files without overwriting. No action needed here. Verify:

```bash
echo "Commands: $(ls .claude/commands/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "Hooks: $(ls .claude/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')"
echo "Agents: $(ls .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')"
```

---

## Step 3d: Add Missing Knowledge Docs

> **Already handled by install.sh Phase D.** Missing `claude/*.md` files were added. Existing docs are NEVER overwritten. No action needed here.

---

## Step 3e: Add Missing GitHub Copilot Files

> **Already handled by install.sh Phase D.** Missing `.github/` files were added. Existing `copilot-instructions.md` is NEVER overwritten.

---

## Step 4: Post-Merge Verification (MANDATORY)

```bash
bash claude/scripts/phase2-verify.sh .
```

Fix any ❌ by restoring from backup before proceeding.

---

## Phase 3 Step 2 Scope for UPGRADE — Creative Work

> **Creative work is EQUALLY mandatory for UPGRADE.** Do NOT skip it because config exists.

Before starting creative work, run the quality gate:

```bash
bash claude/scripts/pre-creative-check.sh . 2>&1
```

**You MUST follow the manifest output:**
- **SKIP** domains: do NOT create or modify their docs (they already have ≥5 real patterns)
- **ENRICH** domains: read source files, add real patterns to the existing doc
- **CREATE** domains: create `claude/<domain>.md` + `.claude/rules/<domain>.md`

This prevents duplicate docs while ensuring gaps are filled.

---

> ✅ **Phase 2 complete.** Return to `claude/bootstrap/PROMPT.md` → Phase 3.
