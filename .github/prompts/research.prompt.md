---
description: Generate targeted research questions + gather external knowledge for a task
agent: "agent"
argument-hint: "<topic or task to research>"
---


Research and gather knowledge about: {{input}}


## Context

Read `CLAUDE.md` for project architecture and conventions.
Read `claude/architecture.md` for the tech stack.

## Instructions

### Phase 1: Analyze Information Gaps

Based on {{input}} and the project context:

1. Identify what you already know from the codebase
2. Identify knowledge gaps where external information would be valuable
3. Categorize gaps: technical implementation, best practices, security, performance, alternatives

### Phase 2: Generate Targeted Research Questions

Generate 5-7 focused research questions that are:

- **Specific** — target a distinct piece of information, not general knowledge
- **Actionable** — the answer should directly inform a design or implementation decision
- **Prioritized** — most critical questions first
- **Diverse** — cover different aspects (implementation patterns, pitfalls, performance, security)

Example questions:
- "What are the current best practices for [specific pattern] in [framework version]?"
- "What are common pitfalls when integrating [library A] with [library B]?"
- "How does [approach A] compare to [approach B] for [specific use case] in terms of performance and maintainability?"

### Phase 3: Research

For each question:

1. **Check the codebase first** — grep for existing patterns, read relevant files
2. **Check project docs** — `claude/*.md` may already have the answer
3. **If MCP web search is available** (check `.mcp.json`): use `mcp__SERVER_KEY__search` to find current information
4. **If no web search**: use your training knowledge, clearly marking confidence levels

### Phase 4: Synthesize Findings

Present findings as a structured report:

```markdown
## Research Report: [Topic]

### Question 1: [Question]
**Confidence:** [High/Medium/Low]
**Finding:** [Concise answer]
**Source:** [Codebase pattern / MCP search / Training knowledge]
**Recommendation:** [Actionable next step]

### Question 2: ...
```

### Phase 5: Update Knowledge Base (if significant findings)

If the research revealed important patterns or decisions:
1. Add key findings to the relevant `claude/*.md` domain doc
2. If no domain doc exists, consider creating one
3. Update `claude/tasks/lessons.md` with any surprising discoveries

## Tips

- Prefer codebase evidence over external knowledge when both are available
- Flag any findings that contradict existing project conventions
- Note when information may be outdated (training knowledge cutoff)
- If using MCP tools, cite the source URL when available
