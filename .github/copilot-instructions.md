# GitHub Copilot — {{PROJECT_NAME}} Instructions

> Auto-injected with every Copilot interaction. Keep concise (<4KB).
> Detailed knowledge in `claude/*.md` — read them for deep context.

## ⚠️ Mandatory Reads

| If task involves… | YOU MUST read FIRST |
|---|---|
| _anything_ (first action) | `claude/tasks/lessons.md` + `claude/architecture.md` + `claude/rules.md` |
| build, test, CI, lint, format | `claude/build.md` |
| MR/PR, ticket | `claude/templates.md` |
| terminal, command, shell | `claude/terminal-safety.md` |
| CVE, dependency, security | `claude/cve-policy.md` |
<!-- ⚠️ EXPAND THIS TABLE: Add one row per domain doc in claude/*.md.
     Match the lookup table in CLAUDE.md. Example rows:
     | auth, token, JWT, guard | `claude/auth.md` |
     | DB, migration, schema, query | `claude/database.md` |
     | webhook, callback, adapter | `claude/webhooks.md` |
     | Kafka, messaging, consumer, producer | `claude/messaging.md` |
-->

## Operating Protocol

1. **Plan first** — write plan to `claude/tasks/todo.md` before non-trivial tasks
2. **Prove completion** — run tests, check logs
3. **No hacky solutions** — find the elegant way
4. **Fix bugs autonomously** — don't ask, just fix
5. **Mark progress** — check items in `claude/tasks/todo.md`
6. **Maintain knowledge** — update `claude/*.md` when you discover stale info

## 🚨 Exit Checklist (MANDATORY before ending turn)

1. User corrected me? → Update `claude/tasks/lessons.md` + relevant `claude/*.md`
2. Learned something new? → Same
3. Open task? → Mark progress in `claude/tasks/todo.md`
4. Touched a domain? → Verify `claude/*.md` still accurate
5. New pattern discovered? → Add to relevant doc + `claude/tasks/lessons.md`

## Terminal Safety

- **🚨 PIPE `|` — 5 ABSOLUTE RULES** (apply immediately):
  1. **Terminal regex**: `grep -E 'a|b'` ✅ — `grep -E "a|b"` ❌ — ALWAYS single quotes
  2. **Writing files**: use file tool — NEVER heredoc (strips `|`)
  3. **Verifying files**: `grep -c '|' file` ✅ — `cat file` ❌ — display STRIPS `|`
  4. **Markdown tables**: `\|` inside cells — bare `|` outside
  5. **Shell scripts**: `case "$F" in *.js|*.ts)` ✅ — `grep -E` ❌ — `case` is pipe-immune
- **NEVER** trigger a pager: always `git --no-pager` or `| cat`
- **NEVER** open interactive programs (vi, nano, psql without `-c`)
- **NEVER** dump unbounded output — always `| head -N`
- **ALWAYS** `--color=never` for ANSI-free output
- **ALWAYS** `2>&1` to capture stderr

## Critical Patterns

- **NEVER `git push` autonomously** — present summary, wait for confirmation
- **Temp files in `./claude/tasks/`**, never `/tmp/`
- **All proofs must pass** before generating MR description
<!-- {{CRITICAL_PATTERNS}} — Add project-specific patterns -->

## Review Protocol

1. Ticket re-read 2. Cross-layer consistency 3. Enum completeness
4. Transaction safety 5. Race conditions 6. Test completeness
7. Pre-existing vs introduced 8. Cross-branch safety
9. Security & side effects 10. Confidence gate

## Core Principles

Simplicity · No laziness · Surgical changes · Evidence-based

