# Terminal Safety Reference

> The #1 cause of AI coding session hangs. These rules are universal across ALL projects and shells.

## Environment Detection

Determine your shell and IDE:
- **Shell**: check `echo $SHELL` — typically `bash`, `zsh`, or `fish`
- **IDE**: IntelliJ (PTY quirks), VS Code (integrated terminal), or standalone terminal
- **zsh-specific**: glob no-match is FATAL, history `!` expands in double quotes, arrays are 1-based
- **bash-specific**: more lenient glob, `!` less aggressive, arrays are 0-based

## NEVER do

| Pattern | Why it's dangerous | Safe alternative |
|---------|-------------------|-----------------|
| `git diff` / `git log` / `git show` (bare) | Triggers pager, hangs session | `git --no-pager diff` or `\| cat` |
| `vi`, `nano`, `emacs` | Interactive editor, hangs forever | Use `read_file` + `edit` tools |
| `psql` (bare) | Interactive REPL | `psql -c "SQL"` |
| `node` / `python` (bare) | Interactive REPL | `node -e "..."` / `python3 -u -c "..."` |
| `docker exec -it` | Interactive shell | `docker exec container command` |
| `ssh host` (bare) | Interactive shell | `ssh host "command"` |
| `cd /path && command` | Output swallowed in some IDEs | Use absolute paths |
| `sleep N` (standalone) | Blocks session | Use background processes |
| `cat large-file` | Unbounded output | `head -N file` or redirect to file |
| `find / -name ...` | Unbounded output | Add `-maxdepth` or pipe to `head` |
| `docker logs container` | Unbounded output | `docker logs --tail 50 container` |
| `kubectl logs pod` | Unbounded output | `kubectl logs --tail 50 pod` |
| `rm -i`, `apt install` (no `-y`) | Prompts for input | Add `-f` or `-y` flags |
| `ls *.xyz` (zsh, no matches) | Fatal error in zsh | `ls *.xyz 2>/dev/null \|\| true` |
| `grep -E "a\|b"` (double quotes) | zsh misinterprets `\|` in double quotes | `grep -E 'a\|b'` (single quotes) |

## ALWAYS do

| Pattern | Why |
|---------|-----|
| `git --no-pager log/diff/show` | Prevents pager |
| `--color=never` / `NO_COLOR=1` | Prevents ANSI escape codes in output |
| `\| head -N` or `> claude/tasks/out.txt 2>&1` | Limits or redirects large output |
| `2>&1` | Captures stderr alongside stdout |
| `grep 'pattern' file \|\| true` | Prevents exit code 1 from breaking `&&` chains |
| Single quotes for regex patterns | Prevents shell interpretation of `\|`, `!`, `*`, `?` |
| `timeout <seconds> command` | Wraps potentially hanging commands |
| `--tail 50` for docker/kubectl logs | Bounds output |
| `python3 -u -c "..."` | Unbuffered output (IntelliJ swallows buffered) |

## Safe Command Templates

```bash
# Git — always no-pager
git --no-pager log --oneline -20
git --no-pager diff --stat
git --no-pager show HEAD --stat

# Search — always bounded
grep -rn 'pattern' src/ --include='*.ts' | head -30
find . -name '*.py' -not -path '*/node_modules/*' | head -20

# Logs — always tailed
docker logs --tail 100 container-name
kubectl logs --tail 50 deployment/service-name

# Database — always non-interactive
psql -c "SELECT * FROM table LIMIT 10" | cat
sqlite3 db.sqlite "SELECT * FROM table LIMIT 10"

# Large output — redirect to file
command > claude/tasks/out.txt 2>&1; echo "EXIT=$?"
```

## After ANY Terminal Issue

1. Document the pattern in `claude/tasks/lessons.md`
2. Update this file (`claude/terminal-safety.md`) with the new anti-pattern
3. If it's a shell-specific issue, add it to the shell-specific notes section below

## Shell-Specific Notes

### zsh
- Glob no-match is FATAL: `ls *.xyz` → `zsh: no matches found`. Use `ls *.xyz 2>/dev/null || true`
- History expansion `!` is active in double quotes. Use single quotes or `setopt NO_BANG_HIST`
- Pipe `|` in double-quoted grep patterns is misinterpreted. Always: `grep -E 'a|b'`
- Arrays are 1-based (unlike bash's 0-based)

### bash
- Glob no-match returns the literal pattern (no error, but confusing)
- `set -e` causes scripts to exit on any non-zero return
- Process substitution `<()` works but may not in all POSIX shells

### fish
- No `&&` — use `; and` instead
- No `||` — use `; or` instead
- Variables: `set var value` not `var=value`
- Command substitution: `(command)` not `$(command)`

## Destructive Command Profiles

The `terminal-safety-gate.sh` hook supports 3 profiles via `CLAUDE_HOOK_PROFILE` env var:

- **minimal** — only catastrophic patterns: `rm -rf /`, `rm -rf ~`, force push to main/master
- **standard** (default) — minimal + `DROP TABLE/DATABASE`, `TRUNCATE`, `git reset --hard`, `chmod -R 777`, `docker system prune -a`
- **strict** — standard + `curl|sh`, `wget|sh`, `eval`, `dd if=... of=/dev/`, writing to `/etc/`

Set in `CLAUDE.local.md` or shell env: `export CLAUDE_HOOK_PROFILE=strict`

## Auto-Mode (YOLO) Permission Stripping

⚠️ When auto mode activates, these allow patterns are **silently removed**:
- Interpreters: `python`, `python3`, `node`, `deno`, `ruby`, `perl`
- Package runners: `npx`, `bunx`, `npm run`, `yarn run`, `pnpm run`
- Shells: `bash`, `sh`, `zsh`, `fish`, `eval`, `exec`
- Network: `curl`, `wget`, `ssh`
- System: `sudo`, `kubectl`, `aws`, `gcloud`

**Impact**: `Bash(python3 *)` in your allow list stops working without warning.
**Fix**: Use specific tool commands instead: `Bash(pytest *)`, `Bash(uvicorn *)`, `Bash(vitest *)`, `Bash(pnpm test *)`.

## Self-Evolution Protocol

This file is a **living document**. After every terminal issue:
1. Add the anti-pattern to the "NEVER do" table
2. Add the safe alternative to the "ALWAYS do" table
3. If it's new, add a shell-specific note
4. Update `claude/tasks/lessons.md` with the incident

