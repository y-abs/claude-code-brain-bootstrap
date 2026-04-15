---
name: pr-triage
description: >
  PR triage: audit open PRs, deep review selected ones, draft and post review comments.
  Args: "all" to review all, PR numbers to focus (e.g. "42 57"), "fr" for French output, no arg = audit only in English.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
effort: medium
---

# PR Triage

Workflow in 3 phases: automatic audit → opt-in deep review → comments with mandatory user validation.

## When to Use

| Skill | Usage | Output |
|-------|-------|--------|
| `/pr-triage` | Triage, review, and comment on PRs | Action table + reviews + posted comments |
| `/repo-recap` | General recap to share with the team | Markdown summary (PRs + issues + releases) |

**Triggers**:
- Manually: `/pr-triage` or `/pr-triage all` or `/pr-triage 42 57`
- Proactively: when >5 open PRs without review, or PR stale >14d detected

---

## Language

- Check the argument passed to this skill
- If `fr` or `french` → output tables and summary in French
- If `en`, `english`, or no argument → English (default)
- Note: GitHub comments (Phase 3) are ALWAYS in English (international audience)

---

## Preconditions

```bash
git rev-parse --is-inside-work-tree
gh auth status
```

If either fails, stop and explain what's missing.

---

## Phase 1 — Audit (always executed)

### Data Gathering (parallel commands)

```bash
# Repo identity
gh repo view --json nameWithOwner -q .nameWithOwner

# Open PRs with full metadata
gh pr list --state open --limit 50 \
  --json number,title,author,createdAt,updatedAt,additions,deletions,changedFiles,isDraft,mergeable,reviewDecision,statusCheckRollup,body

# Collaborators (to distinguish "our PRs" from external ones)
gh api "repos/{owner}/{repo}/collaborators" --jq '.[].login'
```

**Collaborators fallback** — if `gh api .../collaborators` fails (403/404):
```bash
gh pr list --state merged --limit 10 --json author --jq '.[].author.login' | sort -u
```
If still ambiguous, ask the user via `AskUserQuestion`.

For each PR, fetch existing reviews AND modified files:

```bash
gh api "repos/{owner}/{repo}/pulls/{num}/reviews" \
  --jq '[.[] | .user.login + ":" + .state] | join(", ")'

gh pr view {num} --json files --jq '[.files[].path] | join(",")'
```

**Note on rate limiting**: fetching files is N API calls (1 per PR). For repos with 20+ PRs, prioritize PRs that are candidates for overlap (same functional area, same author).

**Note**: `author` is an object `{login: "..."}` — always extract `.author.login`.

### Analysis

**Size classification**:
| Label | Additions |
|-------|-----------|
| XS | < 50 |
| S | 50–200 |
| M | 200–500 |
| L | 500–1000 |
| XL | > 1000 |

Size format: `+{additions}/-{deletions}, {files} files ({label})`

**Detections**:
- **Overlaps**: compare file lists across PRs — if >50% files in common → cross-reference
- **Clusters**: author with 3+ open PRs → suggest review order (smallest first)
- **Staleness**: no activity since >14d → flag "stale"
- **CI status**: via `statusCheckRollup` → `clean` / `unstable` / `dirty`
- **Reviews**: approved / changes_requested / none

**PR ↔ Issue links**:
- Scan each PR's `body` for `fixes #N`, `closes #N`, `resolves #N` (case-insensitive)
- If found, display in the table: `Fixes #42` in the Action/Status column

**Categorization**:

_Our PRs_: author in collaborators list

_External — Ready_: additions ≤ 1000 AND files ≤ 10 AND `mergeable` ≠ `CONFLICTING` AND CI clean/unstable

_External — Problematic_: any of:
- additions > 1000 OR files > 10
- OR `mergeable` == `CONFLICTING` (merge conflict)
- OR CI dirty (statusCheckRollup contains failures)
- OR overlap with another open PR (>50% shared files)

### Output — Triage Table

```
## Open PRs ({count})

### Our PRs
| PR | Title | Size | CI | Status |
| -- | ----- | ---- | -- | ------ |

### External — Ready for Review
| PR | Author | Title | Size | CI | Reviews | Action |
| -- | ------ | ----- | ---- | -- | ------- | ------ |

### External — Problematic
| PR | Author | Title | Size | Problem | Recommended Action |
| -- | ------ | ----- | ---- | ------- | ------------------ |

### Summary
- Quick wins: {XS/S PRs ready to merge}
- Risks: {overlaps, XL sizes, dirty CI}
- Clusters: {authors with 3+ PRs}
- Stale: {PRs with no activity >14d}
- Overlaps: {PRs touching the same files}
```

0 PRs → display `No open PRs.` and finish.

### Auto-copy

After displaying the triage table, copy to clipboard:
```bash
clip() {
  if command -v pbcopy &>/dev/null; then pbcopy
  elif command -v xclip &>/dev/null; then xclip -selection clipboard
  elif command -v wl-copy &>/dev/null; then wl-copy
  else cat
  fi
}
```
Confirm: `Triage table copied to clipboard.`

---

## Phase 2 — Deep Review (opt-in)

### PR Selection

**If argument passed**:
- `"all"` → all external PRs
- Numbers (`"42 57"`) → only those PRs
- No argument → propose via `AskUserQuestion`

**If no argument**, ask:

```
question: "Which PRs do you want to deep review?"
header: "Deep Review"
multiSelect: true
options:
  - label: "All external"
    description: "Review {N} external PRs with code-reviewer agents in parallel"
  - label: "Problematic only"
    description: "Focus on the {M} at-risk PRs (dirty CI, too large, overlaps)"
  - label: "Ready only"
    description: "Review {K} PRs ready to merge"
  - label: "Skip"
    description: "Stop here — audit only"
```

**Draft PRs**:
- Excluded from "All external" and "Ready only"
- Included in "Problematic only" (they need attention)
- To review a draft: type its number explicitly (e.g., `42`)

If "Skip" → end workflow.

### Running Reviews

For each selected PR, spawn a `reviewer` subagent via the **Agent tool in parallel**:

```
subagent_type: reviewer
prompt: |
  Review PR #{num}: "{title}" by @{author}

  **Metadata**: +{additions}/-{deletions}, {changedFiles} files ({size_label})
  **CI**: {ci_status} | **Reviews**: {existing_reviews} | **Draft**: {isDraft}

  **PR Body**:
  {body}

  **Diff**:
  {gh pr diff {num} output}

  Apply your full 10-point review protocol. Focus on:
  - Correctness and logic
  - Test coverage for new code paths
  - Security implications (injection, data exposure, permissions)
  - Cross-layer consistency (if applicable)
  - Code quality and maintainability

  Return a structured review:
  ### Critical Issues 🔴
  ### Important Issues 🟡
  ### Suggestions 🟢
  ### What's Good ✅

  Be specific: quote file:line, explain why it's an issue, suggest the fix.
```

Fetch diff via:
```bash
gh pr diff {num}
gh pr view {num} --json body,title,author -q '{body: .body, title: .title, author: .author.login}'
```

Aggregate all reports. Display a summary after all reviews complete.

---

## Phase 3 — Comments (mandatory validation)

### Generating Drafts

For each reviewed PR, generate a GitHub comment in English.

**Rules**:
- Language: **English** (international audience)
- Tone: professional, constructive, factual
- Always include at least 1 positive point
- Cite code lines when relevant (format `file.ext:42`)
- Never post without explicit user validation

### Display and Validation

**Display ALL drafted comments** in format:

```
---
### Draft — PR #{num}: {title}

{full comment}

---
```

Then ask via `AskUserQuestion`:

```
question: "These comments are ready. Which ones do you want to post?"
header: "Post"
multiSelect: true
options:
  - label: "All ({N} comments)"
    description: "Post on all reviewed PRs"
  - label: "PR #{x} — {title_truncated}"
    description: "Post only on this PR"
  - label: "None"
    description: "Cancel — don't post anything"
```

### Posting

For each validated comment:

```bash
gh pr comment {num} --body-file - <<'REVIEW_EOF'
{comment}
REVIEW_EOF
```

Confirm each post: `✅ Comment posted on PR #{num}: {title}`

If "None" → `No comments posted. Workflow complete.`

---

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| 0 open PRs | `No open PRs.` + finish |
| Draft PR | Flag in table, skip for review unless explicitly selected |
| Unknown CI | Display `?` in CI column |
| Reviewer agent timeout | Show partial error, continue with others |
| `gh pr diff` empty | Skip that PR, notify user |
| Very large PR (>5000 additions) | Warn: "Partial review, diff truncated" |
| Collaborators API 403/404 | Fallback to authors of last 10 merged PRs |

---

## Notes

- Always derive owner/repo via `gh repo view`, never hardcode
- Use `gh` CLI (not `curl` GitHub API) except for the collaborators list
- `statusCheckRollup` can be null → treat as `?`
- `mergeable` can be `MERGEABLE`, `CONFLICTING`, or `UNKNOWN` → treat `UNKNOWN` as `?`
- Never post without explicit user confirmation in chat
- Drafted comments must be visible BEFORE any `gh pr comment`
