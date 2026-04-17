#!/usr/bin/env bash
# pre-creative-check.sh — Programmatic doc quality gate for Phase 3 Step 2
# Runs domain detection greps and checks existing doc quality.
# Outputs a machine-readable manifest: SKIP/ENRICH/CREATE per domain.
# The AI MUST follow this manifest — cannot CREATE a domain marked SKIP.
#
# Usage: bash claude/scripts/pre-creative-check.sh [project-dir]
# Exit:  0 always (manifest is informational)

# ─── Source guard ─────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "❌ pre-creative-check.sh must be EXECUTED, not sourced." >&2
  return 1 2>/dev/null || exit 1
fi

set -eo pipefail
PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

echo "🔍 Pre-creative quality gate — domain manifest"
echo ""

# ─── Domain detection signals ─────────────────────────────────────
# Each entry: signal_name|grep_pattern|doc_name|rule_name
# The grep patterns match the 8 domain signals from PROMPT.md

DOMAINS=(
  "messaging@KafkaConsumer\|KafkaProducer\|producer\.\|createTopic\|RabbitMQ\|SQSClient\|NATS\|publishMessage@messaging@kafka-safety"
  "database@knex\|\.db\.\|createConnection\|getRepository\|DataSource\|prisma\|sequelize\|mongoose@database@database"
  "lifecycle@StatusCode\|StatusEnum\|\.state\b\|transition\|workflow.*state\|state.*machine@lifecycle@lifecycle"
  "auth@keycloak\|realm\|client_credentials\|grant_type\|jwt\|bearer\|guard\|protect\|token.*verify@auth@auth"
  "webhooks@onConflict\|delivery.*id\|idempotent\|deduplicat\|webhook.*url\|callback.*endpoint@webhooks@webhooks"
  "adapters@adapter\|Adapter\|adapterFactory\|BaseAdapter\|ApiClient\|integration\|ExternalAPI@adapters@adapters"
  "reporting@report\|Report\|aggregate\|Aggregate\|export.*data\|analytics\|XSLT\|xlsx\|csv.*export@reporting@reporting"
  "enrollment@signup\|SignUp\|onboard\|Onboard\|registration.*flow\|user.*wizard\|multi.*step.*form\|identity.*verif@enrollment@enrollment"
)

CREATE_COUNT=0
ENRICH_COUNT=0
SKIP_COUNT=0

echo "  SIGNAL        HITS  DOC STATUS      RULE STATUS     ACTION"
echo "  ─────────────────────────────────────────────────────────────"

for DOMAIN_ENTRY in "${DOMAINS[@]}"; do
  IFS='@' read -r SIGNAL PATTERN DOC_NAME RULE_NAME <<< "$DOMAIN_ENTRY"

  # Run detection grep (exclude node_modules, dist, .git)
  HITS=$(grep -rl "$PATTERN" . \
    --include='*.js' --include='*.ts' --include='*.tsx' --include='*.jsx' \
    --include='*.py' --include='*.go' --include='*.rs' --include='*.java' \
    --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.git \
    --exclude-dir=build --exclude-dir=coverage --exclude-dir=.next \
    2>/dev/null | wc -l | tr -d ' ')

  [ "$HITS" -eq 0 ] && continue  # Signal not detected — skip entirely

  # Check doc quality
  DOC_FILE="claude/${DOC_NAME}.md"
  DOC_STATUS="MISSING"
  QUALITY_LINES=0

  if [ -f "$DOC_FILE" ]; then
    # Count quality lines: any non-blank, non-comment content (headings, bullets, bold, text, tables)
    QUALITY_LINES=$(awk '
      /^[[:space:]]*$/ {next}
      /^[[:space:]]*>/ {next}
      /^<!--/ {next}
      /^---$/ {next}
      /^#/ {n++; next}
      /^[[:space:]]*-[[:space:]]/ {n++; next}
      /^[[:space:]]*\*\*/ {n++; next}
      /^[[:space:]]*[A-Za-z0-9]/ {n++; next}
      /^\|/ {n++; next}
      END {print n+0}
    ' "$DOC_FILE")

    if [ "$QUALITY_LINES" -ge 5 ]; then
      DOC_STATUS="RICH(${QUALITY_LINES}L)"
    else
      DOC_STATUS="SHALLOW(${QUALITY_LINES}L)"
    fi
  fi

  # Check rule existence
  RULE_FILE=".claude/rules/${RULE_NAME}.md"
  RULE_STATUS="MISSING"
  [ -f "$RULE_FILE" ] && RULE_STATUS="EXISTS"

  # Determine action
  ACTION=""
  if [ "$DOC_STATUS" = "MISSING" ]; then
    # Before CREATE, check if any existing claude/*.md already covers this domain
    COVERED_BY=$(grep -rl "$PATTERN" claude/*.md 2>/dev/null | grep -v 'claude/architecture.md' | grep -v 'claude/rules.md' | grep -v 'claude/README.md' | head -1 || true)
    if [ -n "$COVERED_BY" ]; then
      ACTION="SKIP"
      DOC_STATUS="ALIAS($(basename "$COVERED_BY"))"
      SKIP_COUNT=$((SKIP_COUNT + 1))
    else
      ACTION="CREATE"
      CREATE_COUNT=$((CREATE_COUNT + 1))
    fi
  elif [ "$QUALITY_LINES" -lt 5 ]; then
    ACTION="ENRICH"
    ENRICH_COUNT=$((ENRICH_COUNT + 1))
  else
    ACTION="SKIP"
    SKIP_COUNT=$((SKIP_COUNT + 1))
  fi

  # Add rule creation note
  RULE_NOTE=""
  if [ "$RULE_STATUS" = "MISSING" ] && [ "$ACTION" != "SKIP" ]; then
    RULE_NOTE="+rule"
  elif [ "$RULE_STATUS" = "MISSING" ] && [ "$ACTION" = "SKIP" ]; then
    RULE_NOTE="+rule?"
  fi

  printf "  %-14s %3d   %-16s %-14s %s %s\n" \
    "$SIGNAL" "$HITS" "$DOC_STATUS" "$RULE_STATUS" "$ACTION" "$RULE_NOTE"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 CREATE: $CREATE_COUNT · ENRICH: $ENRICH_COUNT · SKIP: $SKIP_COUNT"
echo ""
echo "  ⚠️  AI INSTRUCTIONS:"
echo "  • SKIP domains: do NOT create or modify their docs"
echo "  • ENRICH domains: read source files, add real patterns to existing doc"
echo "  • CREATE domains: create claude/<domain>.md + .claude/rules/<domain>.md"
echo "  • +rule: create .claude/rules/<name>.md with actual project paths"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

