# Terminal Safety Rules (always loaded)

> Full reference: `claude/terminal-safety.md`. Auto-loaded every session because terminal misuse is the #1 cause of session hangs.

## Environment

- Detect shell with `echo $SHELL` — rules below cover bash, zsh, and fish
- IDE terminals (IntelliJ PTY, VS Code) have additional quirks: pagers trigger more aggressively, ANSI codes garble output
- **Python** must use `-u` flag (unbuffered) in IDE terminals: `python3 -u -c "..."`

## Pipe character `|` — known session killer

- **Single quotes for regex alternation**: `grep -E 'a|b'` not `grep -E "a|b"` — shells may misinterpret `|` in double quotes
- **Simple pipe chains are OK**: `command 2>&1 | head -20`
- **Never use `|` inside double-quoted patterns** — always single quotes for grep/sed/awk patterns

## NEVER do

- **NEVER** trigger a pager: always `git --no-pager` or `| cat`
- **NEVER** open an interactive program: no `vi`, `nano`, `psql` (without `-c`), `node`/`python` REPL, `docker exec -it`
- **NEVER** run `cd /path && command` — use absolute paths
- **NEVER** run `sleep` as a standalone command
- **NEVER** dump unbounded output: always `| head -N`, `--tail 50`, or redirect to file
- **NEVER** run commands that prompt for input: no `rm -i`, `apt install` without `-y`

## ALWAYS do

- `git --no-pager log/diff/show/branch` — or pipe through `| cat`
- `--color=never` / `NO_COLOR=1` — disable ANSI escape codes
- `| head -N` or `> claude/tasks/out.txt 2>&1` — limit or redirect large output
- `2>&1` — capture stderr alongside stdout
- `grep 'pattern' file || true` — suppress exit code 1 (use **single quotes**)
- Single quotes for all patterns containing `|`, `!`, `*`, `?`, `#`, `~`

## After ANY terminal issue

Update `claude/terminal-safety.md` AND `claude/tasks/lessons.md` with the new pattern.

