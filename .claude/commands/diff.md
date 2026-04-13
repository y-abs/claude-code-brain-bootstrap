---
description: Analyze branch diff against merge-base — stat, files, commits, overlap check
effort: high
allowed-tools: Bash(git *)
argument-hint: "[stat|full|files|commits|overlap branch-name]"
---

Analyze branch diff: $ARGUMENTS

## Pre-loaded context

**Branch:** !`git branch --show-current`
**Merge base:** !`git merge-base main HEAD 2>/dev/null || echo "N/A"`

## Instructions

### ⚠️ CRITICAL: Always use merge-base, never bare `git diff main`

```bash
# CORRECT — only shows YOUR changes
git diff $(git merge-base main HEAD)..HEAD

# WRONG — includes main's forward progress as noise
git diff main
```

### Determine action from arguments:

| Argument | Action |
|----------|--------|
| `stat` or (empty) | `git --no-pager diff $(git merge-base main HEAD)..HEAD --stat` |
| `full` | `git --no-pager diff $(git merge-base main HEAD)..HEAD` |
| `files` | `git --no-pager diff $(git merge-base main HEAD)..HEAD --name-only` |
| `commits` | `git --no-pager log $(git merge-base main HEAD)..HEAD --oneline` |
| `overlap <branch>` | Cross-branch file overlap check |

