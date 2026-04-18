---
description: Build project — all, single service, or specific target
agent: "agent"
argument-hint: "[all|service-name|packages|frontend]"
---


Build: {{input}}

## Instructions

Read `claude/build.md` for build reference.

### Determine scope from arguments:

| Argument | Action |
|----------|--------|
| `all` | `{{BUILD_CMD_ALL}}` |
| `<service-name>` | `{{BUILD_CMD_SINGLE}} <service-name>` |
| `packages` | `{{BUILD_CMD_PACKAGES}}` |
<!-- Add more build targets as discovered by /bootstrap -->

### Post-build:

1. Check exit code
2. If build fails, read the error output
3. Diagnose the root cause
4. Fix autonomously and re-build
