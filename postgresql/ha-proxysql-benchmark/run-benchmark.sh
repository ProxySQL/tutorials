#!/usr/bin/env bash
set -o pipefail
set -e
[[ -n "${TRACE}" ]] && set -x
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"


for COUNT in $(seq 1 3); do
  RATE=$(( (RANDOM % 7) * 25 + 50 ))
  THREADS=$((RANDOM % 10 + 5))
  docker exec -e RATE=${RATE} -e THREADS=${THREADS} -e TIME=600 sysbench${COUNT} /usr/local/bin/benchmark.sh run > "${LOG_DIR}/sysbench${COUNT}.log" &
  echo "App Server ${COUNT}: PID=$! RATE=${RATE} THREADS=${THREADS}"
done
