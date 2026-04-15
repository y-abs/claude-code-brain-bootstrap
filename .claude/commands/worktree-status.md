---
model: haiku
description: Show all git worktrees with branch, status, and last commit — /worktree-status
argument-hint: "[verbose]"
---

# Worktree Status

Show all active git worktrees with their branch, dirty/clean status, and last commit.

## Usage

```bash
/worktree-status           # Show all worktrees
/worktree-status verbose   # Include last 3 commits per worktree
```

## Implementation

Execute this script:

```bash
#!/bin/bash
set -euo pipefail

VERBOSE=false
if [[ "${ARGUMENTS:-}" == *"verbose"* ]]; then
  VERBOSE=true
fi

GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
if [ -z "$GIT_COMMON_DIR" ]; then
  echo "Not in a git repository"
  exit 1
fi

echo "Git Worktrees"
echo "============="
echo ""

COUNT=0
while IFS= read -r line; do
  if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([0-9a-f]+)[[:space:]]+\[(.+)\]$ ]]; then
    WT_PATH="${BASH_REMATCH[1]}"
    WT_COMMIT="${BASH_REMATCH[2]}"
    WT_BRANCH="${BASH_REMATCH[3]}"

    # Check dirty status
    if git -C "$WT_PATH" diff --quiet 2>/dev/null && git -C "$WT_PATH" diff --cached --quiet 2>/dev/null; then
      STATUS="clean"
    else
      CHANGED=$(git -C "$WT_PATH" status --short 2>/dev/null | wc -l | xargs)
      STATUS="dirty ($CHANGED files)"
    fi

    # Short commit hash
    SHORT_HASH="${WT_COMMIT:0:7}"

    echo "  Branch: $WT_BRANCH"
    echo "  Path:   $WT_PATH"
    echo "  Status: $STATUS"
    echo "  Commit: $SHORT_HASH"

    if [ "$VERBOSE" = true ]; then
      echo "  Recent commits:"
      git --no-pager -C "$WT_PATH" log --oneline -3 2>/dev/null | sed 's/^/    /' || true
    fi

    echo ""
    COUNT=$((COUNT + 1))
  fi
done < <(git worktree list 2>/dev/null)

echo "Total: $COUNT worktree(s)"
echo ""
echo "Create:  /worktree <branch>"
echo "Cleanup: /clean-worktrees"
```

## Output Example

```
Git Worktrees
=============

  Branch: main
  Path:   /home/user/myproject
  Status: clean
  Commit: 9982075

  Branch: feature/new-ui
  Path:   /home/user/myproject/.worktrees/feature-new-ui
  Status: dirty (3 files)
  Commit: a1b2c3d

Total: 2 worktree(s)

Create:  /worktree <branch>
Cleanup: /clean-worktrees
```

## Integration

`/worktree` tells you to check status with:
```
Check all worktrees: /worktree-status
```
