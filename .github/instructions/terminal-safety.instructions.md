---
applyTo: "**/*"
---
# Terminal Safety — MANDATORY for every `run_in_terminal` call AND every shell file written

> **This is the #1 cause of session hangs.** Shell is **zsh** in IntelliJ. Read EVERY rule before running ANY command OR writing any `.sh` file.

## 🚨 PIPE `|` — THE RECURRING SESSION KILLER (applies to COMMANDS and FILE CONTENT)

The pipe character kills sessions in **two different contexts**:

### Context 1: Running a command in terminal
```
✅ grep -E 'pattern1|pattern2' file       (single quotes)
❌ grep -E "pattern1|pattern2" file       (double quotes — zsh misinterprets |)
```

### Context 2: WRITING shell code (hooks, scripts, templates)
```
✅ case "$FILE" in *.js|*.ts|*.tsx) ;;    (| is a shell case separator — always safe)
❌ echo "$FILE" | grep -E "\.(js|ts)$"    (| in double quotes = silent corruption risk)
❌ EXTS="js|ts|tsx"  then  grep -E "$EXTS"  (| preserved in var but fragile in expansion)
```

**The `case` statement is the ONLY pipe-immune approach for file extension matching.**
When a template `{{PLACEHOLDER}}` expands to pipe-separated values, `case` is mandatory.

### ABSOLUTE RULES for `|`:
```
✅ grep -E 'a|b' file                         (single quotes for terminal regex)
✅ case "$VAR" in *.js|*.ts) ;;               (case for extension matching in scripts)
✅ CASE_EXTENSIONS='*.js|*.ts'  then  case "$F" in $CASE_EXTENSIONS) ;;
❌ grep -E "a|b" file                         (double quotes — session killer)
❌ grep -E "\.(js|ts)$" hooks/*.sh            (grep for extension — use case instead)
❌ EXTS="js|ts" then grep -E "\.$EXTS\$"     (expansion context unpredictable)
```

## 🚨 PAGER — THE OTHER SESSION KILLER

```
❌ git log           → ✅ git --no-pager log --oneline -20
❌ git show          → ✅ git --no-pager show HEAD | head -50
❌ git stash list    → ✅ git --no-pager stash list
❌ helm template     → ✅ helm template . | cat
❌ kubectl describe  → ✅ kubectl describe pod xyz | cat
```

## 🚨 INTERACTIVE PROGRAMS — INSTANT HANG

```
❌ vi, vim, nano, emacs    → use file editing tools
❌ psql (no -c)            → psql -c "SELECT ..." dbname
❌ node (no script)        → node -e "console.log(...)"
❌ docker exec -it         → docker exec container command
❌ ssh (no command)        → ssh host "command"
❌ sleep N                 → use isBackground: true
```

## MANDATORY CHECKLIST before ANY `run_in_terminal` call

1. ✅ `--no-pager` for git log/show/stash?
2. ✅ `| cat` for helm/kubectl/man?
3. ✅ SINGLE QUOTES for any regex with `|`?
4. ✅ `| head -N` or redirect to limit output?
5. ✅ `2>&1` to capture stderr?
6. ✅ `--color=never` or `NO_COLOR=1`?
7. ✅ No `cd /path &&` (use absolute paths)?
8. ✅ `|| true` for grep in `&&` chains?
9. ✅ `python3 -u` (unbuffered) for Python?
10. ✅ Non-interactive (no vi/psql/node REPL/docker -it)?

## MANDATORY CHECKLIST before WRITING any `.sh` file

1. ✅ File extension matching uses `case "$VAR" in *.ext1|*.ext2)`, NOT `grep -E`?
2. ✅ Any template placeholder that may contain `|` is in a `case` pattern, NOT grep?
3. ✅ All grep patterns are in SINGLE QUOTES?
4. ✅ `${VAR:-.}` used instead of bare `$VAR` for path variables that may be empty?
5. ✅ `set -eo pipefail` at top of script (or deliberate reason it's absent)?
6. ✅ `|| true` after any `grep` whose exit code 1 (no match) should not abort the script?

