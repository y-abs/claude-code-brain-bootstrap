---
applyTo: "**/*"
---
# {{PROJECT_NAME}} — General Coding Instructions

## Style & Formatting
- **{{FORMATTER}}** is the single formatter and linter
- {{STYLE_RULES}}
- Line ending: LF only
<!-- Example: Single quotes, semicolons always, 2-space indent, 120 char line width -->

## Architecture
<!-- {{ARCHITECTURE_SUMMARY}} — Brief architecture overview -->
<!-- Example: Monorepo: src/ (services), packages/ (shared libs) -->

## Critical Safety Rules
<!-- {{CRITICAL_RULES}} — Project-specific safety rules -->
<!-- Example: NEVER emit side effects inside a DB transaction -->

## Package Manager
- **{{PACKAGE_MANAGER}}** only
- **{{RUNTIME}}**

## Terminal Safety
> **⚠️ The `|` pipe character is the #1 recurring bug. 5 ABSOLUTE RULES — apply immediately:**
- **🚨 PIPE RULE 1 — Terminal regex**: `grep -E 'a|b'` ✅ — `grep -E "a|b"` ❌ — ALWAYS single quotes
- **🚨 PIPE RULE 2 — Writing files**: use file tool — NEVER heredoc in terminal (strips `|`)
- **🚨 PIPE RULE 3 — Verifying files**: `grep -c '|' file` ✅ — `cat file` ❌ — display STRIPS `|`
- **🚨 PIPE RULE 4 — Markdown tables**: `\|` inside cells — bare `|` outside
- **🚨 PIPE RULE 5 — Shell scripts**: `case "$F" in *.js|*.ts)` ✅ — `grep -E` ❌ — `case` is pipe-immune
- **NEVER** trigger a pager: always `git --no-pager` or `| cat`
- **NEVER** open interactive programs (vi, nano, psql without `-c`)
- **NEVER** dump unbounded output — always `| head -N`
- **ALWAYS** `--color=never` for ANSI-free output
- **ALWAYS** `2>&1` to capture stderr

