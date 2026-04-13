# MR / PR & Ticket Templates

## MR / PR Description Template

```markdown
## <type>: <imperative summary>

<!-- type: feat | fix | docs | refactor | test | chore | build | ci | perf | revert -->

### Actual Behavior
<!-- What is true today (the problem) -->

### Wanted Behavior
<!-- What should be true after this MR -->

### Description
<!-- 10 lines max. Concise, factual, review-friendly -->

### Proofs
<!-- File-based facts, exact references, test results -->
- Build: ✅ passing
- Tests: ✅ X passing, 0 failing
- Lint: ✅ 0 violations introduced

### Proposed Solution
<!-- Implementation steps taken -->
1. ...
2. ...
```

### Quality Rules for MR Descriptions
- Base MR text on the ACTUAL diff, not assumptions
- Distinguish committed changes from uncommitted local cleanup
- Keep descriptions concise, factual, review-friendly
- Do not over-claim runtime guarantees
- Never reference internal AI tooling in the MR body

## Ticket / Issue Template

```markdown
## Title
<!-- Imperative, concise -->

## Type
<!-- Bug | Story | Task -->

## Story
<!-- As a [role], I want [feature], so that [benefit] -->

## Description
<!-- Technical description, max 10 lines -->

## Proof
<!-- File-based evidence — keep stakeholder-readable -->

## How to Reproduce (bugs only)
<!-- Exact steps -->

## Proposed Solution
<!-- Concrete implementation steps with exact files -->

## Acceptance Criteria
<!-- Checkable bullet points -->
- [ ] ...

## Technical Notes (if applicable)
<!-- Implementation details, migration needs, config changes -->
```

## Context Window Management

When context is running low:
1. Run `/checkpoint` to save state
2. Start a new session
3. Run `/resume` to restore context

