---
description: Git workflow helpers — status, rebase, commit, pre-push checklist
agent: "agent"
tools:
  - run_in_terminal
argument-hint: "[status|rebase main|commit message|amend|log|branches]"
---


Manage Git workflow: {{input}}

## Pre-loaded context

**Branch:** **Context:** Use terminal to run: `git branch --show-current`
**Status:** **Context:** Use terminal to run: `git status --short 2>/dev/null | head -15`
**Recent commits:** **Context:** Use terminal to run: `git --no-pager log --oneline -5 2>/dev/null || echo "N/A"`

## Instructions

### ⚠️ NEVER `git push` autonomously — present summary + proposed command, wait for user confirmation.

### Determine action from arguments:

| Argument | Action |
|----------|--------|
| `status` | `git status` + `git --no-pager log --oneline -5` |
| `branch` | `git branch --show-current` |
| `branches` | `git --no-pager branch -a \| head -30` |
| `stash` | `git stash` |
| `stash pop` | `git stash pop` |
| `rebase main` | `git fetch origin main && git rebase origin/main` |
| `commit <message>` | `git add -A && git commit -m "<message>"` |
| `amend` | `git add -A && git commit --amend --no-edit` |
| `log` | `git --no-pager log --oneline -20` |
| `conflicts` | `grep -rn '^<<<<<<<\|^=======\|^>>>>>>>' .` |

### Branch naming convention:
- Feature: `feat/<ticket-id>-<short-description>`
- Fix: `fix/<ticket-id>-<short-description>`
- Chore: `chore/<description>`

### Pre-push checklist (present to user):
1. ✅ Build passes
2. ✅ Tests pass
3. ✅ Lint clean on changed files
4. ✅ No conflict markers in repo
5. ✅ Diff review complete (merge-base aware)
6. 📋 Proposed command: `git push origin <branch>`
7. ⏳ Waiting for user confirmation...
