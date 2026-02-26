#!/usr/bin/env bash
set -euo pipefail

TIME=${TIME:-600}

[[ -n "${TRACE:-}" ]] && set -x
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

echo "Connecting via '${PROXYSQL_CONTAINER_NAME}'"
for COUNT in $(seq 1 3); do
  RATE=$(( (RANDOM % 7) * 25 + 50 ))
  THREADS=$((RANDOM % 10 + 5))
  docker exec -e RATE=${RATE} -e THREADS=${THREADS} -e TIME=${TIME} -e DB_CONTAINER_NAME=${PROXYSQL_CONTAINER_NAME} -e DB_PORT=${PROXYSQL_DB_PORT} -e TEST_TYPE=oltp_read_only sysbench${COUNT} /usr/local/bin/read-benchmark.sh run > "${LOG_DIR}/sysbench${COUNT}.log" &
  echo "App Server ${COUNT}: PID=$! RATE=${RATE} THREADS=${THREADS}"
done
