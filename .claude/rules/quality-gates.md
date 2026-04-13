# Code Quality Gates (always loaded)

Hard numerical limits — aligned with `claude/rules.md` Quality Thresholds.
Self-check before completing **any** file.

| Constraint | Limit | Action if exceeded |
|------------|:-----:|-------------------|
| Lines per function | 50 | Split or extract a helper |
| Parameters per function | 4 | Bundle extras into an options object |
| Nesting depth | 3 levels | Extract early-return guard or helper function |
| Lines per file | 400 | Split by single responsibility |
| Cyclomatic complexity | 15 | Simplify control flow or extract functions |

## Self-check protocol

Before marking any file as done:
1. Count functions — each one ≤ 50 lines?
2. Count parameters — any function with 5+? → bundle into object
3. Check nesting — more than 3 levels deep? = refactor now
4. Count file lines — over 400? → split at responsibility boundary

## Test coverage expectation

Every new code path (branch, loop, edge case, error handler) must have a corresponding test.
Coverage percentages are a lagging signal — write tests for **behavior**, not to hit a number.

> These are project-level defaults. Document justified exceptions in `claude/rules.md`.

