---
description: Debug a failing test, build, or service issue — gathers evidence, diagnoses root cause, fixes
effort: high
argument-hint: "[description of the failure]"
---

Debug a failing test, build, or service issue: $ARGUMENTS

> ultrathink — use extended reasoning for root cause analysis.

## Instructions

Read `claude/tasks/lessons.md` for known pitfalls before starting.

### Triage workflow:

1. **Identify the failure type** from the arguments:
   - Test failure → read test file + source under test
   - Build failure → read error output, check compiler/bundler errors
   - Runtime error → read logs, check DB state, check message queues
   - Lint error → run linter on the file

2. **Gather evidence** (do ALL of these before proposing a fix):
   - Read the full error message/stack trace
   - Read the failing source file
   - Check if the error is pre-existing: `git stash && <run-test> && git stash pop`
   - Search `claude/tasks/lessons.md` for similar past issues
   - Check if the file was recently modified: `git log --oneline -5 -- <file>`

3. **Diagnose root cause** — classify:
   | Category | Symptoms | Typical fix |
   |----------|----------|-------------|
   | Missing import | `ReferenceError`, `is not defined` | Add import statement |
   | Type mismatch | `TypeError`, `Cannot read properties` | Fix type/null check |
   | DB schema drift | `column X does not exist` | Check migration |
   | Stale build | Works after clean build | Clean + rebuild |
   | Stub mismatch | Test assertion fails | Verify stub key matches export name |

4. **Fix autonomously** — apply the fix, re-run the failing command, verify pass

5. **Update lessons** if this is a new pattern not yet documented

