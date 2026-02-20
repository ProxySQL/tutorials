#!/usr/bin/env bash
set -o pipefail
set -e
[[ -n "${TRACE}" ]] && set -x

INTERVAL=${INTERVAL:-2}
DURATION=${DURATION:-180}
DB_USER=${DB_USER:-postgres}
DB_PASSWD=${DB_PASSWD:-changeme}
DB_HOST=${DB_HOST:-primary}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-demo}

usage() {
  echo "Usage: $0 [duration]"
  echo ""
  echo "Monitor PostgreSQL connections and queries"
  echo ""
  echo "Arguments:"
  echo "  duration  - How long to monitor in seconds (default: 60)"
  echo ""
  echo "Environment variables:"
  echo "  INTERVAL=${INTERVAL}  - Polling interval in seconds"
  exit 1
}

DURATION=${1:-$DURATION}

# Connection string
PSQL_CMD="psql postgresql://${DB_USER}:${DB_PASSWD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

echo "Monitoring PostgreSQL for ${DURATION} seconds (polling every ${INTERVAL}s)"
echo "Time                 | Total Conn | Active | Idle | Idle in Txn | Active Queries"
echo "------------------------------------------------------------------------------------"

END_TIME=$((SECONDS + DURATION))

while [ $SECONDS -lt $END_TIME ]; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

  # Get connection stats
  STATS=$($PSQL_CMD -t -A -F'|' <<EOF
SELECT
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE state = 'active') as active,
  COUNT(*) FILTER (WHERE state = 'idle') as idle,
  COUNT(*) FILTER (WHERE state = 'idle in transaction') as idle_in_txn,
  COUNT(*) FILTER (WHERE state = 'active' AND query NOT LIKE '%pg_stat_activity%') as active_queries
FROM pg_stat_activity
WHERE datname = '${DB_NAME}';
EOF
)

  # Parse results
  IFS='|' read -r TOTAL ACTIVE IDLE IDLE_TXN ACTIVE_Q <<< "$STATS"

  printf "%s | %10s | %6s | %4s | %11s | %14s\n" \
    "$TIMESTAMP" "$TOTAL" "$ACTIVE" "$IDLE" "$IDLE_TXN" "$ACTIVE_Q"

  sleep $INTERVAL
done

echo ""
echo "Monitoring complete. Final statistics:"
echo "------------------------------------------------------------------------------------"

# Show final detailed stats
$PSQL_CMD <<EOF
SELECT
  state,
  COUNT(*) as count,
  MAX(EXTRACT(EPOCH FROM (now() - state_change))) as max_duration_sec
FROM pg_stat_activity
WHERE datname = '${DB_NAME}'
GROUP BY state
ORDER BY count DESC;
EOF
