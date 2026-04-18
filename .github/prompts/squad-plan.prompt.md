---
description: Generate a parallel workstream plan for Claude Squad — multi-instance coordination
agent: "agent"
argument-hint: "<feature-description or task>"
---


Generate a detailed **Claude Squad** parallel execution plan for: {{input}}


## Context

Read `CLAUDE.md` for project architecture, conventions, and critical patterns.
Read `claude/architecture.md` for the workspace layout and service catalog.

## Instructions

### Phase 1: Analyze the Task

1. Break down {{input}} into independent subtasks
2. Identify natural parallelism boundaries (frontend/backend, services, features, layers)
3. Map dependencies between subtasks — what must complete before something else can start
4. Identify shared resources that need coordination (DB schemas, API contracts, shared types)

### Phase 2: Design Workstreams

Create 2-5 distinct workstreams, each assignable to a separate Claude Code instance:

For each workstream:
- **Workstream ID & Title** — e.g., "WS1: API Layer"
- **Assigned Role** — e.g., "Backend API Developer"
- **Objective** — what this instance accomplishes
- **Files/Components** — the specific parts of the codebase this workstream owns
- **Tasks** — numbered checklist items with:
  - Description + specific instructions
  - Follow the Explore → Plan → Act TDD workflow for each coding task
  - Expected outcome
  - Verification steps
- **Dependencies** — which tasks from other workstreams must complete first
- **Deliverables** — what this workstream produces for other workstreams to consume

### Phase 3: Integration Strategy

1. Define integration points between workstreams
2. Create integration test checklist
3. Specify merge order (which branch merges first)
4. Define smoke test for the combined result

### Phase 4: Write ACTION_PLAN.md

Save the plan to `claude/tasks/ACTION_PLAN.md` with this structure:

```markdown
# ACTION_PLAN — [Feature Name]

## Overall Objective
[Clear statement of the goal]

## Project Context
[Brief summary — refer to CLAUDE.md for details]

## Workstream Definitions

### WS1: [Title]
**Role:** [Role Name]
**Objective:** [Goal]
**Files:** [List]

#### Tasks
- [ ] Task 1: [Description] — *Explore → Plan → Act*
- [ ] Task 2: ...

**Dependencies:** None (can start immediately)
**Delivers to:** WS2 needs [output] from Task 3

### WS2: [Title]
...

## Integration Points
- [ ] [Integration task 1]
- [ ] [Integration task 2]

## Testing Strategy
- [ ] Unit tests per workstream
- [ ] Integration tests after merge
- [ ] End-to-end smoke test

## Coordination Notes
- Each instance should check off tasks as they complete
- Signal completion by updating this file
- All instances must follow `CLAUDE.md` standards
```

## Usage with Claude Squad

After generating the plan, the user can assign instances:

```
"You are the Backend API Developer. Execute Workstream WS1 from claude/tasks/ACTION_PLAN.md."
"You are the Frontend Developer. Execute Workstream WS2, noting you depend on WS1 Task 3."
```

Each instance reads `CLAUDE.md` for project standards and follows the Explore-Plan-Act TDD workflow.
