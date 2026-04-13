---
description: Save session state to claude/tasks/todo.md for cross-session continuity
effort: low
allowed-tools: Bash(git *) Read Write
argument-hint: "[optional label for this checkpoint]"
---

Save session checkpoint: $ARGUMENTS

## Pre-loaded context

**Branch:** !`git branch --show-current`
**Uncommitted:** !`git status --short 2>/dev/null | head -20`
**Current todo:** !`head -30 claude/tasks/todo.md 2>/dev/null || echo "No active todo"`

## Instructions

Write a structured checkpoint to `claude/tasks/todo.md`:

```markdown
## [Task Title] — Checkpoint [date]

**Branch:** `<branch-name>`
**Status:** 🔄 IN PROGRESS

### Session Context
- **Loaded docs:** [list claude/*.md files read this session]
- **Key decisions:** [any architectural/design decisions made]
- **User corrections:** [any corrections to capture in lessons.md]

### Progress
- [x] Completed step 1
- [x] Completed step 2
- [ ] **NEXT →** Step 3: [exact description of what to do next]
- [ ] Step 4: ...

### Uncommitted Changes
[output of git status --short]

### Notes for Next Session
[free text: gotchas discovered, files to re-read, test commands to run]
```

Tell the user: "Checkpoint saved. Next session: run `/resume` to continue."

