# Golden Rules (Non-Negotiable Working Standards)

> These rules apply to every task, every file, every layer, regardless of language or framework. Do not negotiate, reinterpret, or skip any rule.

---

## Working Methodology

### Never Skip Planning
- Do not start any non-trivial task (3+ steps or architectural decisions) without entering plan mode first.
- Do not keep pushing if something goes sideways — stop and re-plan immediately.
- Do not limit plan mode to building — use it for verification steps too.

### Never Underuse Subagents
- Do not pollute the main context window with research, exploration, or parallel analysis — offload to subagents.
- Do not hesitate to throw more compute at complex problems via subagents.
- Do not mix concerns — one task per subagent for focused execution.

### Never Repeat the Same Mistake
- Do not ignore user corrections — after ANY correction, update `claude/tasks/lessons.md` with the pattern.
- Do not start a session without reviewing `claude/tasks/lessons.md` for relevant project context.
- Do not yield back to the user without running the **Exit Checklist** (see `CLAUDE.md`). The learning loop is an **active exit gate**.

### Never Mark a Task Complete Without Proof
- Do not claim a task is done without running tests, checking logs, and demonstrating correctness.
- Do not approve your own work without asking: "Would a staff engineer approve this?"

### Never Ship Hacky Solutions
- Do not present a non-trivial change without first asking "is there a more elegant way?"
- Do not over-engineer simple, obvious fixes either — balance is key.

### Never Ask for Hand-Holding on Bugs
- Do not ask the user how to fix a bug — just fix it.
- Do not wait to be told which logs or errors to look at — find them yourself, then resolve.

### Task Management — Never Skip These Steps
1. **Plan First**: Write a plan to `claude/tasks/todo.md` with checkable items.
2. **Track Progress**: Mark items complete as you go.
3. **Explain Changes**: Provide a high-level summary at each step.
4. **Document Results**: Add a review section to `claude/tasks/todo.md`.
5. **Capture Lessons**: Update `claude/tasks/lessons.md` after any correction.

---

## Rule 1 — Never block critical flows for non-critical features
If a secondary or optional operation fails, the primary flow must not be impeded.
- Do not re-throw from a non-critical block — use `try/catch` with null/void fallback.

## Rule 2 — Never allow cross-layer inconsistency
No data field may be inconsistent across any layer it touches: DB schema → repository → service → mapper → DTO → validator → API response → tests.
- Do not close any naming or structural change without running a final `grep` across all packages.

## Rule 3 — Never invent a pattern when one already exists
Do not write any code without first reading the existing files in the affected area. Match codebase conventions precisely.
- Do not deviate from existing file structure, naming style, barrel exports, error handling, or test structure.

## Rule 4 — Never overengineer
Do not introduce dead code, useless comments, unnecessary abstractions, or speculative features.
- Do not write a line that does not serve a clear, immediate purpose.

## Rule 5 — Never implement without a plan and explicit agreement
For any non-trivial task:
- Do not touch any file without first presenting a full plan: exact file list, exact change per file, rationale per decision.
- Do not proceed without explicit user approval.

## Rule 6 — Never deliver a shallow review
When asked for a review:
- Do not scan files at the surface level — read every affected file in full.
- Do not skip the file-by-file status table with notes.
- Do not skip running all affected test suites and reporting exact pass/fail counts.

## Rule 7 — Never write meaningless tests
- Do not write tests that skip real scenarios, edge cases, or failure paths.
- Do not set up a stub without asserting it — a stub with no assertion is dead test code.

## Rule 8 — Never make non-surgical changes
Do not modify anything that is not required for the current task.
- Do not touch unrelated files or refactor pre-existing patterns unless explicitly asked.
- Do not rename any symbol without first grepping every caller across all packages.

## Rule 9 — Never hedge or guess
Verify before stating. Distinguish pre-existing issues from issues introduced by current work.

## Rule 10 — Never act without understanding the full data flow
Trace the complete path end-to-end before proposing changes. Identify insertion points from evidence, not assumption.

## Rule 11 — Never produce external side effects inside a DB transaction
A DB transaction can roll back. External side effects (HTTP calls, message queue emit, email, file write) will NOT roll back with it.
- Do not emit messages, make HTTP calls, or trigger irreversible side effects from inside a transaction block.
- Always ask: "Is this code running inside a transaction? If yes, defer it."

## Rule 12 — Never write code without finding an existing example first
Do not implement anything without first searching the codebase for an existing file that solves the same problem.
- Reproduce the exact same approach. Do not reinterpret or "improve" a working pattern.

## Rule 13 — Never mutate state from a listener or side-effect layer
Listeners/event handlers must only **react** to states: emit notifications, trigger messages. If the state is wrong, fix it where it is computed.

## Rule 14 — Never resolve configuration at the side-effect layer
When a domain decision depends on data from multiple sources, resolve it once at data-loading time. One query, one resolution, one place.

## Rule 15 — Never re-query the DB for data already in memory
Check what the caller already has in scope before writing a DB query.

## Rule 16 — Never delete or rename without verifying the entire scope
- Run `grep` across the codebase for every removed symbol.
- Run the **production build** — dev tools are lenient; production builds are strict.

## Rule 17 — Never trust specification values blindly
Do not use URLs, field names, constants from specs without searching the codebase for actual definitions. The codebase is the source of truth.

## Rule 18 — Never add error handling without matching it to criticality
Ask: "If this fails, is it acceptable to continue silently?"
- If no → let it throw. If yes → catch, log, and continue with a safe fallback.
- Every catch block must have a written justification for why swallowing is acceptable.

## Rule 19 — Never assume documentation is correct
Cross-check every concrete value against the codebase. Fix wrong documents with evidence-backed corrections.

## Rule 20 — Never assume external provider contracts are stable
Handle both current and deprecated states/events. Read provider changelogs before touching integration code.

## Rule 21 — Never infer UI success from flow progression
Derive displayed state from actual domain/backend outcome, not from step completion.

## Rule 22 — Never resolve a merge conflict without scanning the full repo
Run `grep -rn '^<<<<<<<\|^=======\|^>>>>>>>' .` across the entire repository. Run production build and tests after resolution.

## Rule 23 — Never skip test verification after any code change
Run relevant test suites after every change. Compare against `main` for non-trivial changes.

## Rule 24 — Never finish a task without updating the reference files
After completing any task that involved learning something new:
1. Update `claude/tasks/lessons.md` with the specific lesson (pattern, not incident).
2. If the lesson is general enough, also update the relevant `claude/*.md` file.
3. Do not add noise — only add lessons that would save ≥5 minutes in a future task.

**This rule is enforced by the Exit Checklist in `CLAUDE.md`.**

---

## Quality Thresholds (Measurable Standards)

### Code Quality
| Metric | Threshold | Enforcement |
|--------|-----------|-------------|
| Max function length | 50 lines | Linter + review |
| Max file length | 400 lines | Review |
| Max cyclomatic complexity | 15 per function | Static analysis |
| Max function parameters | 4 (use options object beyond) | Review |
| Max nesting depth | 3 levels (early return instead) | Review |
| Test coverage (new code) | ≥80% line coverage | CI gate |
| Lint violations | 0 introduced | CI gate |

### Architecture Quality
| Metric | Threshold | Enforcement |
|--------|-----------|-------------|
| DTO↔DB field alignment | 100% — every DTO field traces to a source | Cross-layer check |
| Always-on token budget | <10K tokens | Context budget calculator |
| Always-on rule count | <150 rules | Canary check |
| `claude/tasks/lessons.md` size | <500 lines (archive to `lessons-archive-YYYY.md`) | Exit checklist |

### Response Quality (AI Self-Assessment)
| Metric | Threshold | Action |
|--------|-----------|--------|
| Confidence in answer | ≥0.8 | Below → retry with more research |
| Tool calls on tangent | ≤3 | Above → yak shaving detected, refocus |
| Files read without acting | ≤5 per task step | Above → gold plating detected, simplify |

<!-- {{PROJECT_SPECIFIC_RULES}} — Add project-specific rules below this line -->

