---
globs: "**/*"
description: "Memory management policy — read errors before modifying code, maintain knowledge layers"
alwaysApply: true
---

# Memory Policy

## Error Memory (CLAUDE_ERRORS.md)
- Before modifying code, check `claude/tasks/CLAUDE_ERRORS.md` for known issues in the affected area
- After fixing a bug, record it: date, area, type, root cause, fix applied, derived rule
- If same error type appears 3+ times, promote the derived rule to `.claude/rules/` or `CLAUDE.md`
- Type must be one of: `syntax`, `logic`, `integration`, `config`, `security`

## Prescriptive vs Descriptive Memory
- `CLAUDE.md` + `claude/*.md` = **prescriptive** (what SHOULD happen — conventions, architecture)
- `claude/tasks/lessons.md` = **descriptive** (what WAS discovered — session wisdom, gotchas)
- `CLAUDE_ERRORS.md` = **diagnostic** (what went WRONG — structured bug tracker with promotion lifecycle)
- Don't duplicate between layers — each serves a distinct purpose

## Knowledge Promotion Lifecycle
```
Bug discovered → CLAUDE_ERRORS.md entry
  → Recurs 3+ times → Extract pattern → .claude/rules/<area>.md
  → Pattern is universal → CLAUDE.md Critical Patterns section
```

## Auto-Memory (Claude Code built-in)
- Claude Code persists discoveries automatically in `~/.claude/projects/`
- Only the first ~200 lines of MEMORY.md are injected — keep it as a concise index
- If MEMORY.md approaches 150 lines, consolidate related entries

