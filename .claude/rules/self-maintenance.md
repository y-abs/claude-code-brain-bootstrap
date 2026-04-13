---
paths:
  - "claude/**"
  - "CLAUDE.md"
  - ".claude/rules/**"
  - ".claude/commands/**"
  - ".claude/skills/**"
  - "claude/tasks/lessons.md"
  - "**/CLAUDE.md"
---

# Knowledge Base Self-Maintenance

> Auto-loaded when editing any knowledge or instruction file.

## Consistency invariants

- Every `claude/*.md` file in the lookup table (CLAUDE.md) must exist on disk — and vice versa.
- Every `.claude/rules/*.md` must have a matching entry in `claude/README.md` Path-Scoped Rules table.
- Every `.claude/commands/*.md` must appear in `claude/README.md` Custom Slash Commands table.
- Every `.claude/skills/*/SKILL.md` must appear in `claude/README.md` Skills table.

## DRY rule

`.claude/rules/*.md` are **summaries** (≤40 lines); `claude/*.md` are **references** (full detail). Never duplicate content — rules reference docs with `> Full reference: claude/<file>.md`.

## Quality rules

- CLAUDE.md ≤ 200 lines. Path-scoped rules ≤ 40 lines. `claude/tasks/lessons.md` ≤ 500 lines (archive older entries).
- Match existing style: imperative phrasing, "Do not…", ⚠️ for pitfalls, concrete file paths.
- After editing any knowledge file, verify cross-references still resolve.

## After any rename/delete/move

Run `grep -rn 'old_name' claude/ .claude/ CLAUDE.md` and fix every stale reference.

