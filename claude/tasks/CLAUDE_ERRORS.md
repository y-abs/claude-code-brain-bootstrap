# Known Errors — {{PROJECT_NAME}}

> Structured error log for cross-session learning. After 3+ recurrences of the same error type, promote the derived rule to `.claude/rules/` or `CLAUDE.md`.

| Date | Area | Type | Error | Cause | Fix | Rule |
|------|------|------|-------|-------|-----|------|
| <!-- Add entries as bugs are discovered --> | | | | | | |

## Error Types

- `syntax` — parse errors, typos, wrong API signatures
- `logic` — wrong behavior, off-by-one, race conditions
- `integration` — service communication, API contract mismatches
- `config` — environment, build, deployment configuration
- `security` — secrets exposure, injection, auth gaps

## Promotion Rule

When an error type recurs 3+ times across sessions:
1. Extract the prevention pattern
2. Create or update a rule in `.claude/rules/` with the pattern
3. Mark the entries here as "promoted to `<rule-file>`"

