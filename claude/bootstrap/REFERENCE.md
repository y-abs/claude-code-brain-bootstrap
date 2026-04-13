# Bootstrap Reference — Report Templates

> **This file is read by Claude in Phase 5 only.** It contains the report templates for FRESH INSTALL and UPGRADE.
> Keeping it separate from `claude/bootstrap/PROMPT.md` prevents these ~130 lines from occupying working context during execution phases 1-4.

---

## Template: FRESH INSTALL

```markdown
# 🎉 Bootstrap Complete — [PROJECT_NAME]

> ᗺB · [Brain Bootstrap](https://github.com/y-abs/claude-code-brain-bootstrap) · by y-abs
> Your AI coding assistant just learned everything about your codebase.
> Generated [date] · **Mode: Fresh Install** · ⏱️ Completed in ~[N] minutes

---

## ✅ Configuration Health — All Systems Go

- **validate.sh** → ✅ **[N] passed**, 0 failed
- **canary-check.sh** → ✅ **[N] passed**, 0 errors
- **Remaining placeholders** → ✅ 0
- **Hooks executable** → ✅ [N]/14
- **settings.json** → ✅ Valid JSON
- **CLAUDE.md size** → ✅ [N] lines (budget: ≤200)
- **Token budget** → ✅ ~[N] tokens (healthy)
- **Hard Constraints ↔ .claudeignore** → ✅ Fully synced
- **Plugins** → ✅ claude-mem (disabled — saves quota)

## 🔍 What Brain Learned About Your Stack

- 🗣️ **Language(s)** → [list with file counts]
- 📦 **Package Manager** → [name + version]
- 🏗️ **Frameworks** → [list]
- 🎨 **Formatter/Linter** → [name]
- 🧪 **Test Framework** → [name]
- 📐 **Architecture** → [monorepo/single-app/dual-tier]
- ⚙️ **CI** → [name]
- 🗄️ **Database** → [name or N/A]
- 🔌 **Plugins** → claude-mem (disabled by default)

## 📁 What Was Installed

> [N] files configured, each one making your AI smarter.

- **[N] validated config files** — zero placeholders remaining
- **[N] slash commands** — `/build`, `/test`, `/lint`, `/review`, `/mr`, `/squad-plan`, `/research`, `/health`, `/mcp`, and more
- **14 lifecycle hooks** — config protection, terminal safety, destructive blocking, batch formatting, session recovery, permission audit, test reminders...
- **5 AI subagents** — `research` (isolated exploration), `reviewer` (10-point MR review), `plan-challenger` (adversarial critique), `session-reviewer` (pattern detection), `security-auditor` (vulnerability scanning)
- **5 skills** — TDD discipline, root-cause tracing, changelog generation, session safety, cross-layer consistency
- **[N] domain docs** — `claude/architecture.md`, `claude/build.md`[, list others]
- **[N] per-service CLAUDE.md stubs** — auto-generated for each monorepo service directory
- **[N] copilot domain docs** — mirrored to `.github/copilot/` for GitHub Copilot users
- **Project-specific rules** — captured in `claude/rules.md`

## 🧠 Project-Specific Patterns Captured

[List 3-5 critical safety rules discovered from the codebase, e.g.:]
- [Pattern 1 — e.g., "Never block detector real-time loops with I/O"]
- [Pattern 2 — e.g., "Config is load-once — changes require restart"]
- [Pattern 3]

## 🔌 Plugin Status

```
🔌 claude-mem v[X] — DISABLED (saves ~48% API quota)
   → Enable when you want cross-session memory:
     bash claude/scripts/toggle-claude-mem.sh on
   → Check status: bash claude/scripts/toggle-claude-mem.sh status
```

## 🤝 Collaboration Mode

🤝 **TEAM** (default) — config is committed, shared with the team.
→ Switch to SOLO (personal, not committed): `echo -e '\nCLAUDE.md\nclaude/\n.claude/\n.claudeignore\n.mcp.json' >> .gitignore`

## 🎯 What's Next — Get Productive in 60 Seconds

1. 💾 **Commit the brain**: `git add CLAUDE.md .claudeignore claude/ .claude/ .github/`
2. 👀 **Review** `claude/architecture.md` — adjust as you explore deeper
3. 🧪 **Try it** — run `/build`, `/test`, `/lint check` — they Just Work™
4. 📚 **Grow the brain** — create domain docs as you work: `claude/<domain>.md`
5. 🧠 **Enable memory** when ready: `bash claude/scripts/toggle-claude-mem.sh on`
6. 🔄 **Future upgrades**: `git clone .../claude-code-brain-bootstrap.git /tmp/brain && bash /tmp/brain/install.sh . && rm -rf /tmp/brain` → run `/bootstrap`

---

> 💡 **Pro tip:** After a few sessions, your AI will know things about your codebase that even some team members don't. Every correction you make gets captured in `claude/tasks/lessons.md` — it literally cannot make the same mistake twice.

⏱️ **Phase timing (AI-work):** P1 [time] · P2 [time] · P3S1 [time] · P3S2 [time] · P4 [time] · P5 [time]
⏱️ **Wall-clock total:** ~[N] minutes (includes Claude Code reasoning + tool overhead)
⏱️ **Progress trail:** [paste output of `cat claude/tasks/.bootstrap-progress.txt`]
```

---

## Template: UPGRADE

```markdown
# 🔄 Configuration Upgraded — [PROJECT_NAME]

> ᗺB · [Brain Bootstrap](https://github.com/y-abs/claude-code-brain-bootstrap) · by y-abs
> Your Brain just got smarter — new capabilities installed, all your knowledge preserved.
> Generated [date] · **Mode: Smart Upgrade** · ⏱️ Completed in ~[N] minutes

---

## ✅ Configuration Health — All Systems Go

- **validate.sh** → ✅ **[N] passed**, 0 failed
- **canary-check.sh** → ✅ **[N] passed**, 0 errors
- **Remaining placeholders** → ✅ 0
- **Hooks executable** → ✅ [N]/14
- **settings.json** → ✅ Valid JSON
- **CLAUDE.md size** → ✅ [N] lines (budget: ≤200)
- **Token budget** → ✅ ~[N] tokens (healthy)
- **Hard Constraints ↔ .claudeignore** → ✅ Fully synced
- **Plugins** → ✅ claude-mem (disabled — saves quota)

## 🛡️ What Was Preserved — Your Knowledge is Sacred

- 📚 **Your domain docs** → ✅ Untouched — [list of preserved claude/*.md]
- 🧠 **Your lessons & todo** → ✅ Untouched — Sacred, never modified
- ⚡ **Your custom commands** → ✅ Untouched — [list]
- 🪝 **Your custom hooks** → ✅ Untouched — [list]
- 🚫 **Your .claudeignore** → ✅ Merged — Your exclusions kept, [N] patterns added
- 📋 **Your CLAUDE.md** → ✅ Enhanced — [N] sections added, all your content preserved

## ➕ What Was Added / Upgraded

- ⚡ **New commands** → [list of added commands, or "none — you had them all!"]
- 🪝 **New hooks** → [list of added hooks, or "none — fully hooked up!"]
- ⚙️ **Settings.json** → [N] new permissions, [N] new hooks merged
- 📁 **Directory structure** → [normalized to claude/tasks/, or "already standard ✅"]
- 🔌 **Plugins** → claude-mem [installed/already present] (disabled)

## 🤝 Collaboration Mode

🤝 **TEAM** (default) — config is committed, shared with the team.
→ Switch to SOLO (personal, not committed): `echo -e '\nCLAUDE.md\nclaude/\n.claude/\n.claudeignore\n.mcp.json' >> .gitignore`

## 🎯 Review Recommendations

1. 💾 **Commit**: `git add CLAUDE.md .claudeignore claude/ .claude/ .github/`
2. 👀 Scan `CLAUDE.md` for `<!-- Added by template upgrade -->` markers — verify they fit your project
3. ⚙️ Check `.claude/settings.json` — review new permissions and hooks added
4. 🧪 Run `/plan` to verify Claude has the full project context

---

> 💡 Your accumulated knowledge (`claude/tasks/lessons.md`) was never touched. Every lesson learned carries forward.

⏱️ **Phase timing (AI-work):** P1 [time] · P2 [time] · P3S1 [time] · P3S2 [time] · P4 [time] · P5 [time]
⏱️ **Wall-clock total:** ~[N] minutes (includes Claude Code reasoning + tool overhead)
⏱️ **Progress trail:** [paste output of `cat claude/tasks/.bootstrap-progress.txt`]
```

