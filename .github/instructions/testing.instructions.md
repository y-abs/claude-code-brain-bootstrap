---
applyTo: "**/*.{test,spec}.{js,ts,jsx,tsx,py,rb,go,rs}"
---
# Testing Instructions

- Test runner: **{{TEST_FRAMEWORK}}**
- Coverage: **{{COVERAGE_TOOL}}**
- Always test ALL enum values, not just the happy path
- Each new branch/case in a switch must have a dedicated test
- Use `describe`/`it` style; test names should describe behavior, not implementation
- Fixtures go in `test-fixtures/` (permanent) or temp directories (ephemeral) — NEVER mix

