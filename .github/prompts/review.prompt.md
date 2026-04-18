---
description: Full MR review protocol — 10-point checklist, diff analysis, cross-layer verification
agent: "agent"
---


Perform a full MR review on the current branch.


## Pre-loaded context

**Branch:** **Context:** Use terminal to run: `git branch --show-current`
**Diff stat:** **Context:** Use terminal to run: `git --no-pager diff main...HEAD --stat 2>/dev/null || echo "Not on a feature branch"`
**Commits:** **Context:** Use terminal to run: `git --no-pager log main...HEAD --oneline 2>/dev/null || echo "N/A"`

## Instructions

Read these files first:
- `claude/rules.md` (review protocol)
- `claude/architecture.md` (system context)
- `claude/tasks/lessons.md` (past mistakes to avoid)

**Step 0 — Lessons pre-scan:** Before running the checklist, scan `claude/tasks/lessons.md` for entries whose file paths, module names, or topic keywords overlap with the files in the diff. Extract matching lessons and prepend them as project-specific check items at the top of your review (e.g. "⚠️ Lesson: hooks must be executable — check .claude/hooks/*.sh"). These lessons represent real mistakes from this project that the standard 10-point protocol won't catch.

Then execute the review protocol:

1. **Ticket re-read** — If a ticket reference exists in the branch name, find and read it. Verify every scenario is addressed.
2. **Diff analysis** — Run `git --no-pager diff main...HEAD --stat` to identify all changed files. Then read the full diff.
3. **Cross-layer consistency** — For every new field/constant, grep across all layers. Report any gaps.
4. **Enum completeness** — For any modified switch/case, verify all enum values are handled.
5. **Transaction safety** — Trace every write caller. Confirm read callers don't write.
6. **Race condition analysis** — Trace concurrent flows.
7. **Test scenario completeness** — Verify every new branch/case has a dedicated test.
8. **Pre-existing vs introduced** — Run linter on changed files. Distinguish pre-existing from introduced warnings.
9. **Cross-branch merge safety** — Check if other branches are in flight that touch the same files.
10. **100/100 confidence gate** — Present a confidence score for each item. Do NOT generate MR description until all pass.
11. **Generate MR description** — Write to `claude/tasks/mr-description-<branch>.md` using the template from `claude/templates.md`.
