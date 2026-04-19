#!/usr/bin/env bash
# merge-settings.sh — Deterministic settings.json deep merge via jq
# Implements all 8 merge rules. User values always win on conflict.
# Hooks merged by ID (same ID → keep user's). Stack-aware permission filtering.
#
# Usage: bash claude/scripts/merge-settings.sh --template <file> --target <file> --discovery-env <file> [--dry-run]
# Exit:  0 = merged, 1 = error, 2 = nothing to change

# ─── Source guard ─────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ merge-settings.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -eo pipefail

# ─── Parse arguments ──────────────────────────────────────────────
TEMPLATE=""
TARGET_FILE=""
DISCOVERY_ENV=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template) TEMPLATE="$2"; shift 2 ;;
    --target) TARGET_FILE="$2"; shift 2 ;;
    --discovery-env) DISCOVERY_ENV="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# ─── Validate inputs ─────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "❌ jq is REQUIRED for settings.json merge. Install: sudo apt install jq" >&2
  exit 1
fi

if [ -z "$TEMPLATE" ] || [ ! -f "$TEMPLATE" ]; then
  echo "❌ Template settings not found: ${TEMPLATE:-<not specified>}" >&2
  exit 1
fi
if [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ]; then
  echo "❌ Target settings not found: ${TARGET_FILE:-<not specified>}" >&2
  exit 1
fi

# Validate both are valid JSON
jq . "$TEMPLATE" > /dev/null 2>&1 || { echo "❌ Template is not valid JSON: $TEMPLATE" >&2; exit 1; }
jq . "$TARGET_FILE" > /dev/null 2>&1 || { echo "❌ Target is not valid JSON: $TARGET_FILE" >&2; exit 1; }

echo "🔄 settings.json deep merge"
$DRY_RUN && echo "  ⚠️  DRY RUN — no files will be modified"

# ─── Read discovery env for stack-aware filtering ─────────────────
PRIMARY_LANG=""
PACKAGE_MANAGER=""
DOCKER_DETECTED="false"

if [ -n "$DISCOVERY_ENV" ] && [ -f "$DISCOVERY_ENV" ]; then
  PRIMARY_LANG=$(grep '^PRIMARY_LANGUAGE=' "$DISCOVERY_ENV" 2>/dev/null | head -1 | cut -d= -f2 || true)
  PACKAGE_MANAGER=$(grep '^PACKAGE_MANAGER=' "$DISCOVERY_ENV" 2>/dev/null | head -1 | cut -d= -f2 || true)
  DOCKER_DETECTED=$(grep '^DOCKER=' "$DISCOVERY_ENV" 2>/dev/null | head -1 | cut -d= -f2 || echo "false")
fi

# ─── Build permission filter ──────────────────────────────────────
# Permissions to EXCLUDE from template if stack doesn't match
EXCLUDE_PERMS=""

# Python tools: only if primary language is Python
case "$PRIMARY_LANG" in
  py|python) ;;
  *)
    case "$PACKAGE_MANAGER" in
      pip|poetry|uv|pdm) ;;
      *) EXCLUDE_PERMS="pytest|ruff|black|mypy" ;;
    esac
    ;;
esac

# Docker tools: only if Docker detected
if [ "$DOCKER_DETECTED" != "true" ]; then
  EXCLUDE_PERMS="${EXCLUDE_PERMS:+$EXCLUDE_PERMS|}docker compose|docker build|docker run|docker logs|docker ps|docker exec"
fi

# Java tools: only if primary language is Java
case "$PRIMARY_LANG" in
  java|kotlin|scala|groovy) ;;
  *) EXCLUDE_PERMS="${EXCLUDE_PERMS:+$EXCLUDE_PERMS|}mvn |gradle " ;;
esac

echo "  📦 Stack: lang=$PRIMARY_LANG pkg=$PACKAGE_MANAGER docker=$DOCKER_DETECTED"
[ -n "$EXCLUDE_PERMS" ] && echo "  🚫 Excluding non-stack permissions: $(echo "$EXCLUDE_PERMS" | tr '|' ',')"

# ─── Perform the merge with jq ────────────────────────────────────
# The jq filter implements all 8 rules:
# 1. plansDirectory → forced
# 2. env → user wins, template fills gaps
# 3. hooks → merge by id (same id → user wins)
# 4. permissions.allow → union + dedup (with stack filter)
# 5. permissions.deny → union + dedup
# 6. spinnerTipsOverride → normalize + merge
# 7. companyAnnouncements → union
# 8. other fields → user wins

EXCLUDE_PATTERN="${EXCLUDE_PERMS:-NOTHING_TO_EXCLUDE}"

MERGED=$(jq --slurpfile tmpl "$TEMPLATE" --arg exclude "$EXCLUDE_PATTERN" '
  # Helper: merge hooks by id (user wins on same id)
  def merge_hooks_by_id(tmpl_hooks):
    . as $user_hooks |
    ($user_hooks | map(.id) | map(select(. != null))) as $user_ids |
    $user_hooks + [tmpl_hooks[] | select(.id as $tid | $user_ids | index($tid) | not)];

  # Start with user as base
  . as $user |
  $tmpl[0] as $tmpl |

  # 1. plansDirectory: forced
  .plansDirectory = "./claude/tasks/" |

  # 2. env: user wins, template fills gaps
  .env = ($tmpl.env // {} | to_entries | reduce .[] as $e (
    ($user.env // {}); if has($e.key) then . else . + {($e.key): $e.value} end
  )) |

  # 3. hooks: merge by id per event type
  .hooks = (
    ($user.hooks // {}) as $uh |
    ($tmpl.hooks // {}) as $th |
    ($th | keys) as $all_events |
    ($uh | keys) as $user_events |
    ([$all_events[], $user_events[]] | unique) | reduce .[] as $event (
      {};
      . + {
        ($event): (
          ($uh[$event] // []) | merge_hooks_by_id($th[$event] // [])
        )
      }
    )
  ) |

  # 4. permissions.allow: union + dedup + stack filter
  .permissions.allow = (
    [
      (.permissions.allow // []),
      [($tmpl.permissions.allow // [])[] | . as $p |
        if ($exclude | length) == 0 then $p
        elif ($exclude | split("|") | map(select(length > 0)) | map(select($p | ascii_downcase | contains(. | ascii_downcase))) | length) > 0 then empty
        else $p
        end
      ]
    ] | add | unique
  ) |

  # 5. permissions.deny: union + dedup
  .permissions.deny = (
    [(.permissions.deny // []), ($tmpl.permissions.deny // [])] | add | unique
  ) |

  # 6. spinnerTipsOverride: normalize + merge tips
  .spinnerTipsOverride = {
    "tips": ([
      ((.spinnerTipsOverride.tips // [])[] // empty),
      (($tmpl.spinnerTipsOverride.tips // [])[] // empty)
    ] | unique),
    "excludeDefault": ((.spinnerTipsOverride.excludeDefault // $tmpl.spinnerTipsOverride.excludeDefault) // true)
  } |

  # 7. companyAnnouncements: union
  .companyAnnouncements = (
    [(.companyAnnouncements // []), ($tmpl.companyAnnouncements // [])] | add | unique
  ) |

  # 8. Other fields: user wins, template fills gaps
  # Exception: $schema is always updated to template value — a Claude Code requirement,
  # not a user preference. Stale schema URLs cause "Settings Error" on every session start.
  . as $current |
  ($tmpl | to_entries | map(select(
    .key as $k | ["hooks","permissions","spinnerTipsOverride","companyAnnouncements","env"] | index($k) | not
  )) | reduce .[] as $e (
    $current;
    if $e.key == "$schema" then . + {($e.key): $e.value}
    elif has($e.key) then .
    else . + {($e.key): $e.value} end
  ))
' "$TARGET_FILE") || {
  echo "❌ jq merge failed" >&2
  exit 1
}

# ─── Validate output ──────────────────────────────────────────────
echo "$MERGED" | jq . > /dev/null 2>&1 || {
  echo "❌ Merged output is not valid JSON" >&2
  exit 1
}

# ─── Check for changes ────────────────────────────────────────────
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "$MERGED" | jq --sort-keys . > "$TMPDIR/merged.json"
jq --sort-keys . "$TARGET_FILE" > "$TMPDIR/original.json"

if diff -q "$TMPDIR/original.json" "$TMPDIR/merged.json" > /dev/null 2>&1; then
  echo "✅ settings.json: no changes needed"
  exit 0
fi

# ─── Report changes ───────────────────────────────────────────────
USER_HOOKS=$(jq '[.hooks | to_entries[] | .value | length] | add // 0' "$TARGET_FILE")
MERGED_HOOKS=$(echo "$MERGED" | jq '[.hooks | to_entries[] | .value | length] | add // 0')
USER_ALLOW=$(jq '.permissions.allow | length' "$TARGET_FILE")
MERGED_ALLOW=$(echo "$MERGED" | jq '.permissions.allow | length')
USER_DENY=$(jq '.permissions.deny | length' "$TARGET_FILE")
MERGED_DENY=$(echo "$MERGED" | jq '.permissions.deny | length')

echo "  📊 Hooks: $USER_HOOKS → $MERGED_HOOKS"
echo "  📊 Permissions allow: $USER_ALLOW → $MERGED_ALLOW"
echo "  📊 Permissions deny: $USER_DENY → $MERGED_DENY"

if $DRY_RUN; then
  echo ""
  echo "📋 Diff preview:"
  diff --unified=3 "$TMPDIR/original.json" "$TMPDIR/merged.json" | head -60 || true
else
  echo "$MERGED" | jq . > "$TARGET_FILE"
  echo ""
  echo "✅ settings.json merged successfully"
fi

