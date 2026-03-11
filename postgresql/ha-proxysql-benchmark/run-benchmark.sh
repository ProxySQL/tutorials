#!/usr/bin/env bash
set -euo pipefail
[[ -n "${TRACE:-}" ]] && set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

for COUNT in $(seq 1 3); do
  RATE=$(( (RANDOM % 7) * 25 + 50 ))
  THREADS=$((RANDOM % 10 + 5))
  docker exec -e RATE=${RATE} -e THREADS=${THREADS} -e TIME=60 sysbench${COUNT} /usr/local/bin/benchmark.sh run > "${LOG_DIR}/sysbench${COUNT}.log" &
  echo "App Server ${COUNT}: PID=$! RATE=${RATE} THREADS=${THREADS}"
done

echo "Waiting for all sysbench processes to complete..."
wait
echo "All benchmarks finished."
