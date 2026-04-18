---
description: Debug a failing test, build, or service issue — gathers evidence, diagnoses root cause, fixes
agent: "agent"
argument-hint: "[description of the failure]"
---


Debug a failing test, build, or service issue: {{input}}


## Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Symptom fixes are failure. A fix that makes a test pass without understanding why it was failing is not a fix — it is a masked bug. This law is especially critical under time pressure, after 2+ failed fix attempts, or when there is a "just try this quick thing" temptation.

**4 Phases (do not skip or reorder):**
1. **Root Cause** — gather all evidence, classify the failure
2. **Hypothesis** — form a specific, testable hypothesis about the cause
3. **Fix Design** — design a minimal fix that addresses the root cause only
4. **Verification** — run the test/build, confirm fix, check for regressions

## Instructions

Read `claude/tasks/lessons.md` for known pitfalls before starting.

### Phase 1 — Root Cause (gather ALL evidence before hypothesizing):

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
   - Check if the file was recently modified: `git --no-pager log --oneline -5 -- <file>`

### Phase 2 — Hypothesis (form one specific, testable hypothesis before acting):

Write it explicitly: "I believe the root cause is X because Y."

### Phase 3 — Fix Design (fix only the root cause, no opportunistic changes):

3. **Diagnose root cause** — classify:
   | Category | Symptoms | Typical fix |
   |----------|----------|-------------|
   | Missing import | `ReferenceError`, `is not defined` | Add import statement |
   | Type mismatch | `TypeError`, `Cannot read properties` | Fix type/null check |
   | DB schema drift | `column X does not exist` | Check migration |
   | Stale build | Works after clean build | Clean + rebuild |
   | Stub mismatch | Test assertion fails | Verify stub key matches export name |

4. **Fix autonomously** — apply the fix targeting ONLY the root cause

### Phase 4 — Verification:

5. **Re-run the failing command** — confirm it passes
6. **Check for regressions** — run the full test suite for the affected area
7. **Update lessons** if this is a new pattern not yet documented
