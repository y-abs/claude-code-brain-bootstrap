---
description: Load all relevant domain context files for a topic area
effort: high
argument-hint: "[domain-keyword e.g. api|database|auth|build|security]"
---

Load all relevant context for the domain area: $ARGUMENTS

## Instructions

Based on the domain keyword(s) provided, read the appropriate knowledge files.

### Domain → Files mapping:
<!-- This mapping is populated by /bootstrap based on your project's domain docs -->
- **build/test/CI/lint** → `claude/build.md`
- **MR/PR/ticket/template** → `claude/templates.md`
- **CVE/security/dependency** → `claude/cve-policy.md`
- **terminal/command/shell** → `claude/terminal-safety.md`
<!-- Add domain mappings as you create domain docs:
- **your-domain-keyword** → `claude/your-domain.md`
-->

### Always read:
1. `claude/tasks/lessons.md` (accumulated wisdom)
2. `claude/architecture.md` (system overview)
3. `claude/rules.md` (golden rules)

After reading, provide a brief summary of the loaded context and ask what task to perform.

