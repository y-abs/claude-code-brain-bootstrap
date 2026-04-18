---
description: Lint and format code with project linter
agent: "agent"
argument-hint: "[check|fix|format|file-path|changed]"
---


Lint and format code: {{input}}

## Instructions

Uses **{{LINTER}}** for linting/formatting. Config: `{{LINTER_CONFIG_FILE}}` at repo root.
Style: {{STYLE_RULES}}

### Determine scope from arguments:

| Argument | Action |
|----------|--------|
| `check` or `all` | `{{LINT_CHECK_CMD}}` (report only) |
| `fix` or `write` | `{{LINT_FIX_CMD}}` (auto-fix) |
| `format` | `{{FORMAT_CMD}}` (format only) |
| `<file-path>` | `{{LINT_FIX_CMD}} <file-path>` (single file) |
| `changed` | Lint only files changed vs main |

### Common workflows:

1. **Before commit**: `{{LINT_FIX_CMD}} <changed-files>`
2. **CI equivalent**: `{{LINT_CHECK_CMD}}`

### ⚠️ Pitfalls:
<!-- Add linter-specific pitfalls as discovered -->
