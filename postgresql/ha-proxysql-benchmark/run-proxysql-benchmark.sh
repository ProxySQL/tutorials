#!/usr/bin/env bash
set -euo pipefail
[[ -n "${TRACE:-}" ]] && set -x

TIME=${TIME:-60}
TEST_TYPE=${TEST_TYPE:-oltp_read_only}
SKIP_TRX=${SKIP_TRX:-on}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

echo "Connecting to '${PROXYSQL_CONTAINER_NAME}' for each server"
for COUNT in $(seq 1 3); do
  RATE=$(( (RANDOM % 7) * 25 + 50 ))
  THREADS=$((RANDOM % 10 + 5))
  docker exec -e RATE=${RATE} -e THREADS=${THREADS} -e TIME=${TIME} -e DB_CONTAINER_NAME=${PROXYSQL_CONTAINER_NAME} -e DB_PORT=${PROXYSQL_DB_PORT} -e TEST_TYPE=${TEST_TYPE} -e SKIP_TRX=${SKIP_TRX} sysbench${COUNT} /usr/local/bin/benchmark.sh run > "${LOG_DIR}/sysbench${COUNT}.log" &
  echo "App Server ${COUNT}: PID=$! RATE=${RATE} THREADS=${THREADS}"
done

echo "Waiting for all sysbench processes to complete..."
wait
echo "All benchmarks finished."
