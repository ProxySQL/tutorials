#!/usr/bin/env bash
set -euo pipefail

[[ -n "${TRACE:-}" ]] && set -x

THREADS=${THREADS:-20}
docker exec -e DB_CONTAINER_NAME=localhost -e THREADS=${THREADS} -e DB_PORT=${PROXYSQL_DB_PORT} ${PROXYSQL_CONTAINER_NAME} /usr/local/bin/benchmark.sh run
