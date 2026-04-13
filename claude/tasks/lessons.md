# Lessons Learned

> Accumulated wisdom from past sessions. Read this at the start of every session.
> Format: dated entries, pattern-focused (not incident reports), "Do not…" phrasing.
> Archive to `lessons-archive-YYYY.md` when this file exceeds 500 lines.

---

## Format Guide

```markdown
### YYYY-MM-DD — [Category] Short title
**Pattern**: [What to always do / never do]
**Why**: [Root cause explanation]
**Example**: [Concrete code or command example if applicable]
```

### Categories
- `[Terminal]` — Shell/command issues
- `[Build]` — Build/compile/bundle issues
- `[Test]` — Test framework/runner issues
- `[Git]` — Version control issues
- `[Architecture]` — Design/pattern issues
- `[Knowledge]` — Doc accuracy issues
- `[Hook]` — Claude Code hook issues

---

### 2026-01-01 — [Terminal] Always use git --no-pager
**Pattern**: Do not run bare `git log`, `git diff`, or `git show` — always prefix with `--no-pager` or pipe through `| cat`.
**Why**: Bare git commands trigger interactive pagers that hang AI coding sessions indefinitely.
**Example**: `git --no-pager log --oneline -20`

### 2026-01-02 — [Terminal] NEVER use grep -E with double-quoted alternation — use `case` for file extensions
**Pattern**: Do not write `grep -E "\.(js|ts)$"` anywhere — use shell `case "$VAR" in *.js|*.ts)` instead.
**Why**: The `|` inside double quotes is misinterpreted by zsh as a pipe operator. This causes SILENT corruption: the value is split and only the first part is used, OR the shell hangs. The `case` statement uses `|` as a shell KEYWORD (pattern separator), which is always safe regardless of quoting context.
**Example**:
```bash
# ❌ WRONG — silently corrupts when | is in double-quoted context
if echo "$FILE" | grep -E "\.(js|ts|tsx)$"; then ...

# ✅ CORRECT — pipe-immune by design
case "$FILE" in
  *.js|*.ts|*.tsx) do_something ;;
esac
```
**Extended rule**: This applies to WRITING shell code too, not just running terminal commands. When a template placeholder `{{EXTENSIONS}}` holds a value like `js|ts|tsx`, and you write it into a grep pattern, the `|` chars can be garbled depending on quoting context. The `case` approach eliminates this entire class of bugs.

### 2026-01-03 — [Hook] Template placeholder values with `|` must go in shell `case`, never grep -E
**Pattern**: Template placeholders that expand to pipe-separated values (e.g., `{{CASE_EXTENSIONS}} = *.js|*.ts|*.tsx`) MUST be placed in `case` patterns, never in `grep -E` patterns.
**Why**: When `populate-templates.sh` substitutes `{{FORMATTABLE_EXTENSIONS}}` via `sed`, the resulting grep pattern `'\.(js|ts|tsx)$'` works IF (and only if) the surrounding quotes are correct. This is fragile. One wrong quote type in a template = silent runtime failure. The `case` approach requires no quoting of the substituted value at all.
**Example**: The `edit-accumulator.sh` hook was rewritten from grep to case precisely because of this fragility.


