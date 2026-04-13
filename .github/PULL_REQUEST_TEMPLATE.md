## 📋 What does this PR do?

<!-- A clear, one-paragraph description of your change. What problem does it solve? -->



## 🏷️ Type of change

<!-- Check the one that applies: -->

- [ ] 🔍 **Stack detection** — new language/framework/package manager in `discover.sh`
- [ ] ⚡ **New command** — slash command in `.claude/commands/`
- [ ] 🪝 **Hook** — new or improved lifecycle hook
- [ ] 📏 **Rule** — new path-scoped rule in `.claude/rules/`
- [ ] 🤖 **Agent / Skill** — new subagent or skill
- [ ] 📚 **Documentation** — README, DETAILED_GUIDE, knowledge docs, examples
- [ ] 🐛 **Bug fix** — something was broken, now it isn't
- [ ] ♻️ **Refactor** — code improvement with no behavior change
- [ ] 🔧 **Chore** — CI, scripts, configs, maintenance

## 🧪 How was this tested?

<!-- Describe how you verified your change works. Examples: -->
<!-- - Ran `bash claude/scripts/validate.sh` — 120+ checks pass -->
<!-- - Tested in a fresh repo with `/bootstrap` -->
<!-- - Added a dummy `.dart` file and ran `discover.sh` -->



## ✅ PR Checklist

<!-- You MUST check every applicable box before requesting review. -->

- [ ] `bash claude/scripts/validate.sh` passes — **0 failures**
- [ ] Changes are **domain-agnostic** (no company names, no project-specific logic)
- [ ] New files registered in `claude/scripts/validate.sh` (if applicable)
- [ ] Documentation updated (README / DETAILED_GUIDE / relevant `claude/*.md`)
- [ ] Shell scripts have `#!/bin/bash` shebang + `set -euo pipefail`
- [ ] Hooks are executable (`chmod +x .claude/hooks/your-hook.sh`)
- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, etc.)
- [ ] Placeholders use `{{UPPER_SNAKE}}` syntax (not hardcoded values)
- [ ] Tested in a real or fresh test repo (not just the template itself)

## 📸 Screenshots / Output (optional)

<!-- If your change affects terminal output, validator results, or discovery output — paste it here. -->



## 🔗 Related Issues

<!-- Link to any related issues: Fixes #123, Relates to #456 -->



