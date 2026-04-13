---
description: Run database or schema migrations
disable-model-invocation: true
effort: low
argument-hint: "[up|down|rollback|status|create name]"
---

Database migration: $ARGUMENTS

## Instructions

### Determine action from arguments:

| Argument | Action |
|----------|--------|
| `up` or `migrate` | `{{MIGRATE_UP_CMD}}` |
| `down` or `rollback` | `{{MIGRATE_DOWN_CMD}}` |
| `status` | `{{MIGRATE_STATUS_CMD}}` |
| `create <name>` | `{{MIGRATE_CREATE_CMD}} <name>` |
<!-- Add more migration commands as discovered by /bootstrap -->

### ⚠️ Migration rules:
- Never mix DDL and DML in the same migration
- Test rollback after every new migration: `migrate` → `rollback` → `migrate`
- Column names: `snake_case`, scoped by table, no redundant prefixes

