---
description: Create a git worktree for isolated parallel development — /worktree feature/my-branch
agent: "agent"
argument-hint: "<branch-name>"
---


# Git Worktree Setup

Create isolated git worktrees for parallel development without switching branches.

**Performance**: ~1s setup — instant, non-blocking

## Usage

```bash
/worktree feature/new-ui         # Create worktree on new branch
/worktree fix/bug-name           # Create worktree for a fix
```

**Branch naming**: Use `category/description` with a slash.

- `feature/new-ui` → branch: `feature/new-ui`, dir: `.worktrees/feature-new-ui`
- `fix/bug-name` → branch: `fix/bug-name`, dir: `.worktrees/fix-bug-name`

## Implementation

Execute this **single bash script** with branch name from `{{input}}`:

```bash
#!/bin/bash
set -euo pipefail

# Resolve main repo root (works from worktree too)
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
if [ -z "$GIT_COMMON_DIR" ]; then
  echo "Not in a git repository"
  exit 1
fi
REPO_ROOT="$(cd "$GIT_COMMON_DIR/.." && pwd)"

# Parse arguments
RAW_ARGS="${ARGUMENTS:-}"
BRANCH_NAME="$RAW_ARGS"

# Validate branch name
if [[ -z "$BRANCH_NAME" ]]; then
  echo "Usage: /worktree <branch-name>"
  echo "Example: /worktree feature/my-feature"
  exit 1
fi

if [[ "$BRANCH_NAME" =~ [[:space:]\$\`] ]]; then
  echo "Invalid branch name (spaces or special characters not allowed)"
  exit 1
fi
if [[ "$BRANCH_NAME" =~ [~^:?*\\\[\]] ]]; then
  echo "Invalid branch name (git forbidden characters)"
  exit 1
fi

# Paths
WORKTREE_NAME="${BRANCH_NAME//\//-}"
WORKTREE_DIR="$REPO_ROOT/.worktrees/$WORKTREE_NAME"

# 1. Check .gitignore (fail-fast)
if ! grep -qE '^\.worktrees/?$' "$REPO_ROOT/.gitignore" 2>/dev/null; then
  echo ".worktrees/ not in .gitignore"
  echo "Run: echo '.worktrees/' >> .gitignore && git add .gitignore && git commit -m 'chore: ignore worktrees'"
  exit 1
fi

# 2. Create worktree
echo "Creating worktree for $BRANCH_NAME..."
mkdir -p "$REPO_ROOT/.worktrees"
if ! git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" 2>/tmp/worktree-error.log; then
  echo "Failed to create worktree:"
  cat /tmp/worktree-error.log
  exit 1
fi

# 3. Copy files listed in .worktreeinclude (non-blocking)
(
  INCLUDE_FILE="$REPO_ROOT/.worktreeinclude"
  if [ -f "$INCLUDE_FILE" ]; then
    while IFS= read -r entry || [ -n "$entry" ]; do
      [[ "$entry" =~ ^#.*$ || -z "$entry" ]] && continue
      entry="$(echo "$entry" | xargs)"
      SRC="$REPO_ROOT/$entry"
      if [ -e "$SRC" ]; then
        DEST_DIR="$(dirname "$WORKTREE_DIR/$entry")"
        mkdir -p "$DEST_DIR"
        cp -R "$SRC" "$WORKTREE_DIR/$entry"
      fi
    done < "$INCLUDE_FILE"
  else
    cp "$REPO_ROOT"/.env* "$WORKTREE_DIR/" 2>/dev/null || true
  fi
) &
wait $! 2>/dev/null || true

# 4. Report
echo ""
echo "Worktree ready: $WORKTREE_DIR"
echo "Branch: $BRANCH_NAME"
echo ""
echo "Next steps:"
echo ""
echo "If Claude Code is running:"
echo "   1. /exit"
echo "   2. cd $WORKTREE_DIR"
echo "   3. claude"
echo ""
echo "If Claude Code is NOT running:"
echo "   cd $WORKTREE_DIR && claude"
echo ""
echo "Check all worktrees: /worktree-status"
echo "Clean merged worktrees: /clean-worktrees"
```

## Environment Files

Files listed in `.worktreeinclude` are copied automatically. If the file doesn't exist, `.env*` files are copied by default.

Example `.worktreeinclude`:
```
.env
.env.local
.claude/settings.local.json
```

## Cleanup

```bash
git worktree remove .worktrees/${BRANCH_NAME//\//-}
git worktree prune
```

Or use `/clean-worktrees` to remove all merged worktrees at once.

## Troubleshooting

**"worktree already exists"**
```bash
git worktree remove .worktrees/feature-name
```

**"branch already exists"**
```bash
git branch -D feature/name
```
