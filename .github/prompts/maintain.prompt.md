---
description: Full knowledge base maintenance — verify paths, prune stale entries, update inventories
agent: "agent"
tools:
  - run_in_terminal
argument-hint: "[full|paths|lessons|inventory|stale]"
---


Run a knowledge base maintenance cycle: {{input}}

## Instructions

### Mode selection

| Argument | Action |
|----------|--------|
| `full` or _(empty)_ | Run ALL checks below sequentially |
| `paths` | Verify all file paths in `claude/*.md` still exist |
| `lessons` | Check `claude/tasks/lessons.md` line count; archive if >500 |
| `inventory` | Verify `claude/README.md` tables match actual files |
| `stale` | Grep all knowledge files for stale references |

### Steps for `full` mode

1. **Verify file paths** — Grep file paths from `claude/*.md` and verify they exist on disk
2. **Verify lookup table** — Compare `CLAUDE.md` lookup entries against `ls claude/*.md`
3. **Verify rules inventory** — Compare `.claude/rules/*.md` against README
4. **Verify commands inventory** — Compare `.claude/commands/*.md` against README
5. **Lessons health** — `wc -l claude/tasks/lessons.md` — if >500 lines, archive older entries
6. **Stale references** — Grep for deleted symbols, old paths, stale field names
7. **CLAUDE.md size** — Verify `wc -l CLAUDE.md` ≤ 200 lines
8. **Rule sizes** — Verify each `.claude/rules/*.md` ≤ 40 lines
9. **Report** — Present summary with issues found and fixes applied
