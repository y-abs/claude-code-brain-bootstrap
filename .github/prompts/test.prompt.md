---
description: Run unit/integration/E2E tests for services
agent: "agent"
argument-hint: "[all|service-name|ci|coverage]"
---


Run tests for: {{input}}

## Instructions

Read `claude/build.md` for test commands reference.

### Determine scope from arguments:

| Argument | Action |
|----------|--------|
| `all` | `{{TEST_CMD_ALL}}` |
| `<service-name>` | `{{TEST_CMD_SINGLE}} <service-name>` |
| `ci` | `{{TEST_CMD_CI}}` |
| `coverage` | `{{TEST_CMD_COVERAGE}}` |
<!-- Add more test targets as discovered by /bootstrap -->

### After running:

1. Report pass/fail counts
2. If failures exist, read the failing test file and the source code it tests
3. Diagnose the root cause
4. Fix autonomously if the fix is clear
5. Re-run to verify the fix

### ⚠️ Pitfalls (from lessons):
<!-- Add known test pitfalls as they are discovered -->
- Always redirect large CI output: `command > claude/tasks/ci-test.txt 2>&1; echo "EXIT=$?"`
