---
description: Query the database — schemas, tables, records
agent: "agent"
argument-hint: "[schemas|tables|describe table|query SQL]"
---


Query the database: {{input}}

## Instructions

### Determine action from arguments:

| Argument | Action |
|----------|--------|
| `schemas` | `{{DB_LIST_SCHEMAS_CMD}}` |
| `tables` | `{{DB_LIST_TABLES_CMD}}` |
| `describe <table>` | `{{DB_DESCRIBE_CMD}} <table>` |
| `<raw-sql>` | `{{DB_QUERY_CMD}} "<sql>" \| cat` |

> **SQLite note**: If commands show `$DB_PATH`, set the env var to the actual DB file path before running (it varies by deployment/runtime config). Check project docs or config files for the configured path.

### ⚠️ Always use non-interactive mode:
- PostgreSQL: `psql -c "SQL" | cat`
- MySQL: `mysql -e "SQL" | cat`
- SQLite: `sqlite3 db.sqlite "SQL"`
- MongoDB: `mongosh --eval "db.collection.find()" --quiet`
