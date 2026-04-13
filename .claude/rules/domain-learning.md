---
globs: "**/*"
description: "Persist business domain knowledge discovered during work sessions"
alwaysApply: true
---

# Domain Learning

You are a growing domain expert. Your domain knowledge lives in `.claude/rules/domain/`.
Consult it before making assumptions about business logic; enrich it when you discover new facts.

## When to persist
- You discover a business rule not documented in domain/ (e.g., "bonds use factor 0.01")
- You learn how an external API behaves (rate limits, auth flow, pagination quirks)
- The user explains a domain concept during conversation
- An error reveals a domain assumption was wrong

## How to persist
1. Check if a relevant file exists in `.claude/rules/domain/`
2. If yes: add the new fact to that file (prefer existing files over new ones)
3. If no: create a new file with frontmatter: `globs` (domain-specific patterns) or `paths` + `alwaysApply: false`
4. Add `domain:` tag and `last_verified:` date to frontmatter
5. Keep each file under 40 lines. Split into separate files if a topic grows beyond that
6. Content: factual, concise, imperative mood. No filler. English only

## When NOT to persist
- Pure code patterns (import order, test fixtures) → technical rules in `.claude/rules/`
- One-time fixes that won't recur
- Opinions or preferences → `CLAUDE.md`
- Ephemeral session context (current task details)

## After research sessions
When investigating a domain topic: do the research → present findings → ask "Persist key findings in domain rules?" → if approved, create/update the relevant domain rule file.

