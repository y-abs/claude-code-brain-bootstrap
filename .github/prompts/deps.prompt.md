---
description: Upgrade dependencies and fix CVEs following the decision tree
agent: "agent"
argument-hint: "[check|update package|audit|why package|dedupe]"
---


Manage dependencies: {{input}}

## Instructions

Read `claude/cve-policy.md` for the CVE decision tree.

### Determine action from arguments:

| Argument | Action |
|----------|--------|
| `check` | `{{DEPS_OUTDATED_CMD}}` |
| `check <package>` | `{{DEPS_OUTDATED_CMD}} <package>` |
| `update <package>` | `{{DEPS_UPDATE_CMD}} <package>` |
| `audit` | `{{SCAN_COMMAND}}` |
| `why <package>` | `{{DEPS_WHY_CMD}} <package>` |
| `dedupe` | `{{DEPS_DEDUPE_CMD}}` |

### Safety checklist (MANDATORY before any upgrade):
1. [ ] Is the bump MINOR or PATCH? (MAJOR → ignore list)
2. [ ] Run install / lock file update
3. [ ] Run full build
4. [ ] Run full test suite
5. [ ] Run security scan
