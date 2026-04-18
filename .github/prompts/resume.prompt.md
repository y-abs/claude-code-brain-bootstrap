---
description: Resume a previous session from checkpoint — reads claude/tasks/todo.md, lessons, reloads context
agent: "agent"
tools:
  - Read Bash(git *) Bash(cat *) Bash(head *)
---


Resume previous session: {{input}}

## Pre-loaded context

**Branch:** **Context:** Use terminal to run: `git branch --show-current`
**Uncommitted:** **Context:** Use terminal to run: `git status --short 2>/dev/null | head -20`
**Current todo:** **Context:** Use terminal to run: `head -40 claude/tasks/todo.md 2>/dev/null || echo "No active todo"`

## Instructions

1. **Read checkpoint** — Read `claude/tasks/todo.md` in full. Identify the most recent task.
2. **Read lessons** — Read `claude/tasks/lessons.md` (mandatory).
3. **Verify branch** — Compare against checkpoint. Warn if different.
4. **Check uncommitted state** — Compare against checkpoint.
5. **Reload domain docs** — Read each `claude/*.md` listed in checkpoint's "Loaded docs".
6. **Present resumption summary:**
   ```
   ## Session Resumed

   **Task:** [title]
   **Branch:** [current] (matches checkpoint: ✅/❌)
   **Last completed step:** [step N]
   **Next action:** [description from NEXT → marker]
   **Domain docs loaded:** [list]

   Ready to continue. Shall I proceed with [next action]?
   ```
7. **Wait for user confirmation** before proceeding.

### If no checkpoint exists
1. Read `claude/tasks/lessons.md`
2. Read `claude/architecture.md`
3. Ask the user what task to work on
