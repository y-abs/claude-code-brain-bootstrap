---
mode: "agent"
description: "Review selected code against project golden rules (claude/rules.md)"
---
Review the selected code against the project's golden rules:

1. Read `claude/rules.md` for the full list of 24 golden rules
2. Check each rule against the selected code
3. For each violation found:
   - Quote the specific rule
   - Show the offending code
   - Propose a concrete fix
4. Classify severity: 🔴 Must Fix | 🟡 Should Fix | 🟢 Can Skip

Present results as a structured table.

