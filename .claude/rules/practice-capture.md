---
globs: "**/*"
description: "Suggest capturing lessons when generalizable patterns are detected"
alwaysApply: true
---

# Practice Capture

After completing a task, check if any of these signals are present:
- A workaround was needed because the obvious approach failed
- A bug required more than one fix attempt to resolve
- An architectural or config decision involved real trade-offs
- A tool, flag, or API behavior was non-obvious or surprising
- A rule in CLAUDE.md or a domain rule was missing and would have prevented the problem

If ANY signal is present, capture the learning:
1. Add to `claude/tasks/lessons.md` with date and brief description
2. If it's a recurring pattern (3+ times), promote to `.claude/rules/` or `CLAUDE.md`
3. If it's a domain fact, persist to `.claude/rules/domain/`

Do NOT suggest for: trivial tasks, routine edits, tasks where the first approach worked cleanly.
Threshold: if you had to reason about it or backtrack, capture it. If not, stay silent.

