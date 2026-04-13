---
description: Start service(s) locally — single service or preset group
disable-model-invocation: true
effort: low
argument-hint: "[service-name|all|frontend|backend]"
---

Start service(s) locally: $ARGUMENTS

## Instructions

Read `claude/build.md` for local development setup.

### Determine scope from arguments:

| Argument | Action |
|----------|--------|
| `<service-name>` | `{{SERVE_CMD_SINGLE}} <service-name>` |
| `all` | `{{SERVE_CMD_ALL}}` |
| `frontend` | `{{SERVE_CMD_FRONTEND}}` |
| `backend` | `{{SERVE_CMD_BACKEND}}` |
<!-- Add more serve targets as discovered by /bootstrap -->

### ⚠️ Key rules:
<!-- Add locality rules, port assignments, etc. -->

