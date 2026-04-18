---
description: Clean workspace — builds, dependencies, caches, Docker, temp files
agent: "agent"
argument-hint: "[all|build|deps|cache|docker|tasks|reinstall]"
---


Clean up workspace: {{input}}

## Instructions

### Determine action from arguments:

| Argument | Action |
|----------|--------|
| `build` or `dist` | Remove all build artifacts |
| `deps` | Remove dependency directories (node_modules, venv, target, etc.) |
| `all` | Full clean: deps + build artifacts, then reinstall |
| `cache` | Clear build tool caches |
| `docker` | `docker system prune -f` (does NOT remove named volumes) |
| `tasks` | Clean obsolete task files (never delete `claude/tasks/lessons.md`) |
| `reinstall` | Full reinstall: clean deps → install |

### Tasks file cleanup rules:
- **Never delete** `claude/tasks/lessons.md` (accumulated wisdom)
- `claude/tasks/todo.md` can be archived if no active task
- `claude/tasks/mr-description-*.md` can be deleted after MR is merged
- `claude/tasks/ticket-*.md` can be deleted after ticket is created
