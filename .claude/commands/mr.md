---
description: Generate an MR description for the current branch after verifying build/test pass
disable-model-invocation: true
effort: high
argument-hint: "[optional: ticket reference]"
---

Generate MR description for the current branch: $ARGUMENTS

> ultrathink — use extended reasoning for accurate diff analysis.

## Pre-loaded context

**Branch:** !`git branch --show-current`
**Commits:** !`git --no-pager log $(git merge-base main HEAD)..HEAD --oneline 2>/dev/null || echo "N/A"`
**Diff stat:** !`git --no-pager diff $(git merge-base main HEAD)..HEAD --stat 2>/dev/null || echo "N/A"`

## Instructions

Read `claude/templates.md` for the MR template format.

### Prerequisites — ALL must pass before generating MR text:
1. Build passes: `{{BUILD_CMD_ALL}}`
2. Tests pass: `{{TEST_CMD_CI}}`
3. Lint clean: `{{LINT_CHECK_CMD}}`

### Steps:

1. **Identify the branch** and get the diff (merge-base aware)
2. **Read the ticket** (if referenced in branch name)
3. **Write MR description** using template from `claude/templates.md`
4. **Save** to `claude/tasks/mr-description-<branch-slug>.md`
5. **Present summary** and the exact file path

### Quality rules:
- Base MR text on the ACTUAL diff, not assumptions
- Keep descriptions concise, factual, review-friendly
- Never reference internal AI tooling in the MR body

