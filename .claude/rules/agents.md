---
globs: "**/*"
description: "Agent orchestration — delegation, teams, model routing"
alwaysApply: true
---

# Agent Orchestration

## Delegation Decision Tree

Before starting any task, evaluate:
1. **Single-file fix / quick question** → handle directly, no subagent
2. **Research-heavy or verbose output** → delegate to `research`
3. **Code review / MR review** → delegate to `reviewer`
4. **Plan validation / adversarial critique** → delegate to `plan-challenger`
5. **Security/vulnerability concern** → delegate to `security-auditor`
6. **Session analysis / pattern detection** → delegate to `session-reviewer`

## Subagent Rules

- Pass minimal, focused context — don't dump the full conversation
- Each subagent must return a structured summary, not raw output
- If a subagent result is unclear or incomplete, send follow-up — don't restart
- Always verify subagent output (run tests/lint) before declaring done
- Subagent raw output must not exceed 30% of main context

## Agent Teams (multi-agent for large refactors)

Spawn an Agent Team ONLY when ALL hold:
- Task touches ≥3 independent components/files
- Components don't share mutable state during the task
- Estimated single-agent time >15 minutes
- Each teammate can own a distinct file set (no overlap)

Team pattern: Lead (coordinates, does NOT implement) + max 3-4 teammates.
Each teammate MUST use `isolation: "worktree"`. Require plan approval before code.

## Model Routing

- **haiku** — file search, grep, list, test execution, repetitive transforms
- **sonnet** — standard implementation, bug fixes, code review, documentation
- **opus** — architecture decisions across 3+ components, security audits, ambiguous high-stakes tasks

Escalate to opus when: 2+ valid approaches with real consequences, security/data integrity risk, or 2 failed sonnet attempts. Downgrade to haiku for pure retrieval.

