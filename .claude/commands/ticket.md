---
description: Create a ticket/issue description with evidence-backed proof sections
effort: high
argument-hint: "[bug or feature description]"
---

Create a ticket/issue description: $ARGUMENTS

## Instructions

Read `claude/templates.md` for the ticket template.

### Steps:

1. **Understand the request** — Parse arguments to identify: Bug or Story? Which services affected? Current vs expected behavior?
2. **Research** — Read relevant source files, collect evidence (file paths, line numbers)
3. **Write ticket** using template from `claude/templates.md`
4. **Save** to `claude/tasks/ticket-<slug>.md`
5. **Tell the user** the exact file path

### Quality rules:
- Every claim must be backed by evidence (file path + line number)
- Acceptance criteria must be testable (not vague)
- Proposed solution must reference exact files to change

