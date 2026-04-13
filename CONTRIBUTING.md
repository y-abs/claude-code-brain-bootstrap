<p align="center">
  <a href="https://github.com/y-abs/claude-code-brain-bootstrap">
    <img src="https://img.shields.io/badge/ᗺB-Brain%20Bootstrap-6B21A8?style=for-the-badge&labelColor=1e1b4b" alt="ᗺB Brain Bootstrap" />
  </a>
</p>

<h1 align="center">Contributing to ᗺB Brain Bootstrap</h1>
<p align="center"><em>Every contribution makes AI coding better for everyone.<br>Here's how to do it right — step by step.</em></p>

---

## 🙏 Thank You

You're about to improve something that thousands of developers use every day to teach their AI assistants. Whether it's a typo fix, a new language in the discovery engine, or a brand-new hook — **your contribution matters.**

---

## 🧭 What Can I Contribute?

| Area | Examples | Difficulty |
|:-----|:--------|:----------:|
| 🔍 **Stack detection** | New language, framework, or package manager in `discover.sh` | 🟢 Easy |
| 📚 **Documentation** | Fix a typo, improve clarity, add a worked example | 🟢 Easy |
| ⚡ **Slash commands** | New workflow command in `.claude/commands/` | 🟡 Medium |
| 📏 **Path-scoped rules** | New domain rule in `.claude/rules/` | 🟡 Medium |
| 🪝 **Lifecycle hooks** | Safety patterns, quality gates in `.claude/hooks/` | 🟠 Advanced |
| 🤖 **Subagents / Skills** | New AI agent or skill in `.claude/agents/` or `.claude/skills/` | 🟠 Advanced |
| 🐛 **Bug fixes** | Something broken? Fix it! | Varies |

> 🎯 **Golden rule:** All contributions must be **domain-agnostic**. No project-specific content — this is a universal template that works for any repo, any language, any team.

---

## 🚀 Step-by-Step: Your First Contribution

### Step 1 — Fork and clone

```bash
# Fork the repo on GitHub first, then:
git clone https://github.com/YOUR_USERNAME/claude-code-brain-bootstrap.git
cd claude-code-brain-bootstrap
```

### Step 2 — Create a branch

```bash
git checkout -b feat/my-awesome-contribution
```

Use a descriptive branch name:
- `feat/discover-elixir` — adding Elixir detection
- `fix/hook-timeout` — fixing a hook timeout issue
- `docs/improve-faq` — improving documentation

### Step 3 — Make your changes

Follow the patterns already in the codebase:

| If you're adding… | Look at these for reference |
|:-------------------|:--------------------------|
| A new language in `discover.sh` | Search for an existing language (e.g., `Python`) and follow the same pattern |
| A slash command | Any file in `.claude/commands/` — copy the structure |
| A lifecycle hook | Any `.sh` file in `.claude/hooks/` — same structure + register in `.claude/settings.json` |
| A path-scoped rule | `.claude/rules/_template-domain-rule.md` — the template is ready for you |
| A worked example | `claude/_examples/` — three examples to follow |
| A GitHub Copilot instruction | `.github/instructions/_template.instructions.md` |
| A reusable prompt | `.github/prompts/_template.prompt.md` |

### Step 4 — Run the validator

```bash
bash claude/scripts/validate.sh
```

This runs **120+ checks** — file existence, hook executability, placeholder integrity, settings consistency, and more. **All checks must pass.**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ᗺB  Brain Bootstrap  ·  Validator  ·  by y-abs
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ...
  Results: ✅ 120 passed | ❌ 0 failed | ⚠️  0 warnings
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

> 💡 If you added a new file that should be validated (hook, command, script), add it to `claude/scripts/validate.sh` too!

### Step 5 — Commit with a clear message

```bash
git add -A
git commit -m "feat: add Elixir detection to discover.sh"
```

Follow [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` — new feature
- `fix:` — bug fix
- `docs:` — documentation only
- `refactor:` — code change that neither fixes a bug nor adds a feature
- `test:` — adding or fixing tests
- `chore:` — maintenance (CI, scripts, configs)

### Step 6 — Push and open a PR

```bash
git push origin feat/my-awesome-contribution
```

Then open a Pull Request on GitHub. The **PR template will auto-load** — fill in every section.

**CI will automatically run 3 checks on your PR:**

1. ✅ **Template Validation** — `claude/scripts/validate.sh` (120+ checks)
2. 🐚 **ShellCheck** — lints every `.sh` file for bugs
3. 🔗 **Link Check** — verifies all internal links in docs

All three must pass before your PR can be reviewed.

---

## 📝 Contribution Guidelines

### ✅ Do

- **Follow existing patterns** — consistency is more important than cleverness
- **Keep it domain-agnostic** — no company names, no project-specific logic, no proprietary patterns
- **Use placeholders** where users will customize: `{{PROJECT_NAME}}`, `{{BUILD_CMD}}`, etc.
- **Make hooks executable** — `chmod +x .claude/hooks/your-hook.sh`
- **Update `claude/scripts/validate.sh`** if you add files that should be checked
- **Update documentation** if your change affects the user experience (README, DETAILED_GUIDE, or relevant `claude/*.md`)
- **Test in a real repo** — clone the template into a fresh project, run `/bootstrap`, verify your contribution works end-to-end

### ❌ Don't

- **Don't add project-specific content** — no company names, no `my-company`, no hardcoded API keys
- **Don't break existing placeholders** — `{{PLACEHOLDER}}` syntax is sacred, the bootstrap engine depends on it
- **Don't add large binary files** — keep the template lightweight
- **Don't modify `.claude/settings.json` permissions** without explaining why in the PR
- **Don't skip the validator** — if it fails, your PR will too

### 📐 Code Style

- **Shell scripts**: `set -euo pipefail` at the top, `#!/bin/bash` shebang
- **Markdown**: ATX headings (`##`), reference links for repeated URLs, tables for structured data
- **Line width**: 120 characters max
- **Naming**: `kebab-case` for files, `UPPER_SNAKE` for env vars and placeholders

---

## 🔍 Adding a Language to `discover.sh`

This is the most common contribution — and the easiest. Here's a real example:

**Goal:** Add Dart detection.

1. Open `claude/scripts/discover.sh`
2. Find the language detection section (search for `# === Language Detection ===`)
3. Add the detection pattern following existing examples:

```bash
# Dart
if find_ext "dart" || [ -f "pubspec.yaml" ]; then
  add_lang "Dart"
  [ -f "pubspec.yaml" ] && add_pm "pub"
fi
```

4. Run `bash claude/scripts/validate.sh` — all checks pass
5. Test: create a dummy repo with a `.dart` file, run `bash claude/scripts/discover.sh`, verify Dart appears
6. Submit PR!

---

## ⚡ Adding a Slash Command

1. Create `.claude/commands/my-command.md`:

```markdown
---
description: "One-line description of what this command does"
---

## What this does
Explain the command purpose.

## Steps
1. First action
2. Second action
3. Final action

## Output format
Describe expected output.
```

2. Add to `claude/scripts/validate.sh` in the `COMMANDS` array
3. Mention in DETAILED_GUIDE if it's a major addition
4. Run `bash claude/scripts/validate.sh`

---

## 🪝 Adding a Lifecycle Hook

This is more involved — hooks are bash scripts registered in `settings.json`:

1. Create `.claude/hooks/my-hook.sh`:

```bash
#!/bin/bash
set -euo pipefail

# Your hook logic here
# Exit 0 = allow, exit 2 = block (for PreToolUse hooks)
```

2. Make it executable: `chmod +x .claude/hooks/my-hook.sh`
3. Register in `.claude/settings.json` under the appropriate event (`PreToolUse`, `PostToolUse`, `Stop`, etc.)
4. Add to the `HOOKS` array in `claude/scripts/validate.sh`
5. Document in DETAILED_GUIDE under the hooks section
6. Run `bash claude/scripts/validate.sh`

> ⚠️ **Hooks execute on every matching event.** Keep them fast (<500ms) and deterministic. No network calls, no AI reasoning — pure bash logic.

---

## 🐛 Reporting Issues

Found a bug? Something confusing in the docs? Got a feature idea?

👉 **[Open an issue](https://github.com/y-abs/claude-code-brain-bootstrap/issues/new/choose)** — pick the right template:

| Template | When to use |
|:---------|:-----------|
| 🐛 **Bug Report** | Something isn't working — crashes, wrong output, broken hooks |
| ✨ **Feature Request** | You have an idea for a new command, hook, detection, or improvement |

> 💬 **Got a question?** Use [GitHub Discussions](https://github.com/y-abs/claude-code-brain-bootstrap/discussions) instead — issues are for actionable bugs and features.

---

## 💬 Questions?

- **Open a discussion** on [GitHub Discussions](https://github.com/y-abs/claude-code-brain-bootstrap/discussions)
- **Check the FAQ** in [README.md](README.md#-faq) or [DETAILED_GUIDE.md](claude/docs/DETAILED_GUIDE.md#-faq)

---

## 📋 PR Checklist (preview)

When you open a PR, this checklist auto-loads. Make sure you can check every box:

- [ ] `bash claude/scripts/validate.sh` passes (120+ checks, 0 failures)
- [ ] Changes are domain-agnostic (no project-specific content)
- [ ] New files are registered in `claude/scripts/validate.sh` (if applicable)
- [ ] Documentation updated (README / DETAILED_GUIDE / relevant docs)
- [ ] Shell scripts have `#!/bin/bash` shebang + `set -euo pipefail`
- [ ] Hooks are executable (`chmod +x`)
- [ ] Commit messages follow Conventional Commits
- [ ] New placeholders use `{{UPPER_SNAKE_CASE}}` syntax (not hardcoded values)
- [ ] Tested in a real (or fresh test) repo

---

## 🚀 Release Process (Maintainers Only)

> **Do NOT push tags or create releases yourself.** Present the summary and let the maintainer do it.

Here's the step-by-step process for creating a new release:

### Step 1 — Prepare the release PR

```bash
git checkout -b release/v<VERSION>
```

Update `CHANGELOG.md`:
- Add a new `## [VERSION] — YYYY-MM-DD` entry at the top
- List all changes since the previous version
- Keep the format consistent with existing entries

### Step 2 — Run all checks locally

```bash
bash claude/scripts/validate.sh
# Must show: Results: ✅ 120 passed | ❌ 0 failed | ⚠️  0 warnings

shellcheck .claude/hooks/*.sh claude/scripts/*.sh .claude/skills/cross-layer-check/scripts/*.sh install.sh
# Must show: 0 errors, 0 warnings
```

> 💡 Install ShellCheck: `sudo apt install shellcheck` (Linux) or `brew install shellcheck` (macOS)

### Step 3 — Commit and open PR

```bash
git add CHANGELOG.md <other changed files>
git commit -m "chore: release v<VERSION>"
git push origin release/v<VERSION>
```

Open a PR targeting `main`. The **CI will run 3 checks automatically**:
1. ✅ Template Validation (120 checks)
2. 🐚 ShellCheck (28 scripts)
3. 🔗 Link Check (documentation links)

**All three must pass before merging.**

### Step 4 — Merge and tag

After the PR is approved and CI passes:

```bash
# Merge the PR on GitHub (Squash or Merge commit — your preference)
# Then tag the release:
git checkout main
git pull origin main
git tag v<VERSION>
git push origin v<VERSION>
```

### Step 5 — Create a GitHub Release

1. Go to **Releases** → **Draft a new release**
2. Select the tag `v<VERSION>` you just pushed
3. Set the release title: `v<VERSION> — <short description>`
4. Paste the relevant CHANGELOG section as the release notes
5. **Publish release** 🎉

> **That's it.** The GitHub Release page becomes the public announcement. The CI badge on the README will show the current status of `main`.

---

<p align="center">
  <strong>Ready? Pick something from the table above and start. We can't wait to see what you build. 🚀</strong>
</p>





