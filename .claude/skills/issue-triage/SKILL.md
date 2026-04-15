---
name: issue-triage
description: >
  Issue triage: audit open issues, categorize, detect duplicates, cross-ref PRs, risk assessment, post comments.
  Args: "all" for deep analysis of all, issue numbers to focus (e.g. "42 57"), "fr" for French, no arg = audit only in English.
allowed-tools:
  - Bash
  - Read
  - Grep
effort: medium
---

# Issue Triage

Workflow in 3 phases: automatic audit → opt-in deep analysis → actions with mandatory user validation.

## When to Use

| Skill | Usage | Output |
|-------|-------|--------|
| `/issue-triage` | Triage, analyze, and comment on issues | Action tables + deep analysis + posted comments |
| `/repo-recap` | General recap to share with the team | Markdown summary (PRs + issues + releases) |

**Triggers**:
- Manually: `/issue-triage` or `/issue-triage all` or `/issue-triage 42 57`
- Proactively: when >10 open issues without triage, or issue stale >30d detected

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

# Open issues with full metadata
gh issue list --state open --limit 100 \
  --json number,title,author,createdAt,updatedAt,labels,assignees,body,comments

# Open PRs (for cross-reference)
gh pr list --state open --limit 50 --json number,title,body

# Recently closed issues (for duplicate detection)
gh issue list --state closed --limit 20 \
  --json number,title,labels,closedAt

# Collaborators (to protect maintainer issues)
gh api "repos/{owner}/{repo}/collaborators" --jq '.[].login'
```

**Collaborators fallback** — if `gh api .../collaborators` fails (403/404):
```bash
gh pr list --state merged --limit 10 --json author --jq '.[].author.login' | sort -u
```
If still ambiguous, ask the user via `AskUserQuestion`.

**Note**: `author` is an object `{login: "..."}` — always extract `.author.login`.

### Analysis — 6 Dimensions

**1. Categorization** (existing labels > inferred from title/body):
- **Bug**: keywords `crash`, `error`, `fail`, `broken`, `regression`, `wrong`, `unexpected`
- **Feature**: `add`, `implement`, `support`, `new`, `feat:`
- **Enhancement**: `improve`, `optimize`, `better`, `enhance`, `refactor`
- **Question/Support**: `how`, `why`, `help`, `unclear`, `docs`, `documentation`
- **Duplicate Candidate**: see dimension 3 below

**2. Cross-ref PRs**:
- Scan each open PR's `body` for `fixes #N`, `closes #N`, `resolves #N` (case-insensitive regex)
- Build a map: `issue_number -> [PR numbers]`
- Issue linked to a merged PR → recommend closing

**3. Duplicate Detection**:
- Normalize titles: lowercase, strip prefixes (`bug:`, `feat:`, `[bug]`, `[feature]`, etc.)
- **Jaccard on title words**: if score > 60% between two issues → duplicate candidate
- **Keywords body overlap** > 50% → reinforces the signal
- Also compare with recently closed issues (last 20)
- False positives confirmed/rejected in Phase 2

**4. Risk Classification**:
- **Red**: keywords `CVE`, `vulnerability`, `injection`, `auth bypass`, `security`, `exploit`, `unsafe`, `credentials`, `leak`, `RCE`, `XSS`
- **Yellow**: `breaking change`, `migration`, `deprecation`, `remove API`, `breaking`, `incompatible`
- **Green**: everything else

**5. Staleness**:
- >30d without activity (updatedAt) → **Stale**
- >90d without activity → **Very Stale**
- Compute from current date

**6. Action Recommendations**:
- `Accept & Prioritize`: clear, reproducible, in scope
- `Label needed`: issue has no labels
- `Comment needed`: missing info, insufficient body
- `Linked to PR`: an open PR references this issue
- `Duplicate candidate`: duplicate identified (cite `#N`)
- `Close candidate`: stale + no recent activity, or out of scope (never for collaborator issues)
- `PR merged → close`: linked PR is merged, issue still open

### Output — 5 Tables

```
## Open Issues ({count})

### Critical (red risk)
| # | Title | Author | Age | Labels | Action |
| - | ----- | ------ | --- | ------ | ------ |

### Linked to a PR
| # | Title | Author | Linked PR(s) | PR Status | Action |
| - | ----- | ------ | ------------ | --------- | ------ |

### Active
| # | Title | Author | Category | Age | Labels | Action |
| - | ----- | ------ | -------- | --- | ------ | ------ |

### Duplicate Candidates
| # | Title | Duplicate of | Similarity | Action |
| - | ----- | ------------ | ---------- | ------ |

### Stale
| # | Title | Author | Last Activity | Action |
| - | ----- | ------ | ------------- | ------ |

### Summary
- Total: {N} open issues
- Critical: {N} (security or breaking risk)
- Linked to PR: {N}
- Duplicate candidates: {N}
- Stale (>30d): {N} | Very Stale (>90d): {N}
- Without labels: {N}
- Quick wins (close or label fast): {list}
```

0 issues → display `No open issues.` and finish.

**Note**: `Age` = days since `createdAt`, format `{N}d`. If >30d, display in **bold**.

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

## Phase 2 — Deep Analysis (opt-in)

### Issue Selection

**If argument passed**:
- `"all"` → all open issues
- Numbers (`"42 57"`) → only those issues
- No argument → propose via `AskUserQuestion`

**If no argument**, ask:

```
question: "Which issues do you want to analyze in depth?"
header: "Deep Analysis"
multiSelect: true
options:
  - label: "All ({N} issues)"
    description: "Deep analysis of all issues with parallel agents"
  - label: "Critical only"
    description: "Focus on {M} red/yellow risk issues"
  - label: "Duplicate candidates"
    description: "Confirm or dismiss the {K} detected duplicates"
  - label: "Stale only"
    description: "Close/keep decision on {J} stale issues"
  - label: "Skip"
    description: "Stop here — audit only"
```

If "Skip" → end workflow.

### Running Analysis

For each selected issue, spawn an agent via the **Agent tool in parallel**:

```
subagent_type: research
prompt: |
  Analyze GitHub issue #{num}: "{title}" by @{author}

  **Metadata**: Created {createdAt}, last updated {updatedAt}, labels: {labels}

  **Body**:
  {body}

  **Existing comments** ({comments_count} total, showing last 5):
  {last_5_comments}

  **Context**:
  - Linked PRs: {linked_prs or "none"}
  - Duplicate candidate of: {duplicate_of or "none"}
  - Risk classification: {risk_color}

  Analyze this issue and return a structured report:
  ### Scope Assessment
  What is this issue actually asking for? Is it clearly defined?

  ### Missing Information
  What's needed to act on this? (reproduction steps, version, environment, etc.)

  ### Risk & Impact
  Security risk? Breaking change? Who's affected?

  ### Effort Estimate
  XS (<1h) / S (1-4h) / M (1-2d) / L (3-5d) / XL (>1 week)

  ### Priority
  P0 (critical, act now) / P1 (high, this sprint) / P2 (medium, backlog) / P3 (low, someday)

  ### Recommended Action
  One of: Accept & Prioritize, Request More Info, Mark Duplicate (#N), Close (Stale), Close (Out of Scope), Link to Existing PR

  ### Draft Comment
  Draft a GitHub comment in English that is specific, helpful, and constructive.
  If requesting more info: specify exactly what's needed (reproduction steps, version, OS, error message, etc.)
  If marking duplicate: reference the original issue with a link.
  If closing stale: be respectful and invite re-opening if the issue recurs.
```

If issue has >50 comments, summarize only the last 5.

Aggregate all reports. Display a summary after all analyses complete.

---

## Phase 3 — Actions (mandatory validation)

### Types of Possible Actions

- **Comment**: `gh issue comment {num} --body-file -`
- **Label**: `gh issue edit {num} --add-label "{label}"` (skip if label already present)
- **Close**: `gh issue close {num} --reason "not planned"` (never without validation)

### Generating Drafts

For each analyzed issue, generate actions (comment + labels + close if applicable).

**Rules**:
- Comment language: **English** (international audience)
- Tone: professional, constructive, factual
- Never re-label an issue that already has the label
- Never propose "close" for a collaborator's issue
- Always show the draft BEFORE any `gh issue comment`

### Display and Validation

**Display ALL drafts** in format:

```
---
### Draft — Issue #{num}: {title}

**Proposed actions**: {Comment | Label: "bug" | Close}

**Comment**:
{full comment}

---
```

Then ask via `AskUserQuestion`:

```
question: "These actions are ready. Which ones do you want to execute?"
header: "Execute"
multiSelect: true
options:
  - label: "All ({N} actions)"
    description: "Comment + label + close according to drafts"
  - label: "Issue #{x} — {title_truncated}"
    description: "Execute only the actions for this issue"
  - label: "None"
    description: "Cancel — do nothing"
```

### Execution

For each validated action, execute in order: comment → label → close.

```bash
# Comment
gh issue comment {num} --body-file - <<'COMMENT_EOF'
{comment}
COMMENT_EOF

# Label (if applicable)
gh issue edit {num} --add-label "{label}"

# Close (if applicable)
gh issue close {num} --reason "not planned"
```

Confirm each action: `✅ Comment posted on issue #{num}: {title}`

If "None" → `No actions executed. Workflow complete.`

---

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| 0 open issues | `No open issues.` + finish |
| Issue without body | Categorize by title, recommend `Comment needed` |
| >50 comments | Summarize last 5 only |
| False positive duplicate | Phase 2 confirms/dismisses — don't act on suspicion alone |
| Labels already present | Don't re-label, note "label already applied" |
| Collaborator's issue | Never auto-close candidate |
| GitHub API rate limit | Reduce `--limit`, notify user |
| PR merged → issue still open | Recommend closing the issue |
| Issue with no activity >90d | Very Stale — propose close with respectful message |
| Duplicate confirmed in Phase 2 | Post comment + close in favor of the original issue |

---

## Notes

- Always derive owner/repo via `gh repo view`, never hardcode
- Use `gh` CLI (not `curl` GitHub API) except for the collaborators list
- `updatedAt` can be null on some issues → treat as `createdAt`
- Never post or close without explicit user confirmation in chat
- Drafted comments must be visible BEFORE any `gh issue comment`
- Jaccard similarity = |word intersection| / |word union| (exclude stop words: a, the, is, in, of, for, to, with, on, at, by)
