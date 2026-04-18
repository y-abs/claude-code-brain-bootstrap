---
description: Route codebase question to the right tool — graph, semantic search, or risk analysis
agent: "agent"
argument-hint: "<question about the codebase>"
---


# Codebase Question Router

Answer this question about the codebase: {{input}}

> Route to the right tool based on question type. Don't search files manually when a smarter tool exists.

## Routing rules

Classify the question and use the corresponding tool:

### Architecture / flow / how does X work / trace a call
Use `mcp__codebase-memory-mcp__trace_path` or `mcp__codebase-memory-mcp__get_architecture`.
Also read `graphify-out/GRAPH_REPORT.md` if it exists — it contains god nodes, community structure,
and surprising cross-module connections already analyzed.

### Find / search / locate / what file / which function
Use `mcp__cocoindex-code__search` with a semantic query.
This finds code by **meaning**, not exact text — useful when you don't know the exact name.

### Safe to change / impact / blast radius / what breaks / risk score / dependencies
Use `mcp__code-review-graph__detect_changes_tool` with `base_branch="main"`.
Reports: risk score 0–100, blast radius (files affected), breaking changes, dependent modules.

### General code question (no plugin available / question is narrow / specific file)
Read the file directly. Grep for the symbol. Don't over-route simple questions.

## Decision logic

1. If {{input}} contains architecture/flow/trace/how/explain → codebase-memory-mcp + graphify
2. If {{input}} contains find/search/locate/where/what file → cocoindex
3. If {{input}} contains safe/impact/blast/breaks/risk/change/affect → code-review-graph
4. If none match → read directly, use Grep/Glob

## Answer format

Give a direct, concise answer. Include:
- The tool used and why
- The finding (file path + line if applicable)
- Any surprising connections the graph revealed (if applicable)

If the question cannot be answered from graph/search alone, fall back to reading the relevant files.
