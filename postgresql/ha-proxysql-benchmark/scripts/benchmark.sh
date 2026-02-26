#!/usr/bin/env bash
set -o pipefail
set -e
[[ -n "${TRACE}" ]] && set -x

## Database Setup
DB_USER="postgres"
DB_PASSWD="changeme"
DB_NAME="demo"
DB_PORT="${DB_PORT:-5432}"

## Container Setup
DB_CONTAINER_NAME="${DB_CONTAINER_NAME:-primary}"
SYSBENCH_CONTAINER_NAME="sysbench"

# Default values
TABLES=${TABLES:-10}
TABLE_SIZE=${TABLE_SIZE:-10000}
THREADS=${THREADS:-4}
TIME=${TIME:-10}
REPORT_INTERVAL=${REPORT_INTERVAL:-1}
TEST_TYPE=${TEST_TYPE:-oltp_read_write}
RATE=${RATE:-0}
SKIP_TRX=${SKIP_TRX:=off}

# Base sysbench command
if [ -f /.dockerenv ]; then
  SYSBENCH_EXEC="sysbench"
else
  SYSBENCH_EXEC="docker compose exec ${SYSBENCH_CONTAINER_NAME} sysbench"
fi
SYSBENCH_CMD="${SYSBENCH_EXEC} \
  --db-driver=pgsql \
  --pgsql-host=${DB_CONTAINER_NAME} \
  --pgsql-port=${DB_PORT} \
  --pgsql-user=${DB_USER} \
  --pgsql-password=${DB_PASSWD} \
  --pgsql-db=${DB_NAME} \
  --skip-trx=${SKIP_TRX} \
  --tables=${TABLES} \
  --table-size=${TABLE_SIZE}"

usage() {
  echo "Usage: $0 {prepare|run|cleanup} [test_type]"
  echo ""
  echo "Commands:"
  echo "  prepare  - Create tables and insert test data"
  echo "  run      - Execute benchmark"
  echo "  cleanup  - Remove test data"
  echo ""
  echo "Test types:"
  echo "  oltp_read_write (default)"
  echo "  oltp_read_only"
  echo "  oltp_write_only"
  echo "  oltp_insert"
  echo "  oltp_update_index"
  echo "  oltp_delete"
  echo ""
  echo "Environment variables:"
  echo "  TABLES=${TABLES}"
  echo "  TABLE_SIZE=${TABLE_SIZE}"
  echo "  THREADS=${THREADS}"
  echo "  TIME=${TIME}"
  echo "  REPORT_INTERVAL=${REPORT_INTERVAL}"
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

COMMAND=$1
TEST_TYPE=${2:-$TEST_TYPE}

case $COMMAND in
  prepare)
    echo "Preparing test data..."
    ${SYSBENCH_CMD} "${TEST_TYPE}" prepare
    ;;
  run)
    echo "Running benchmark: $TEST_TYPE"
    echo "Threads: $THREADS, Time: ${TIME}s, Tables: $TABLES, Rows/table: $TABLE_SIZE"
    echo "DEBUG: ${SYSBENCH_CMD}"
    ${SYSBENCH_CMD} \
      --threads="${THREADS}" \
      --time="${TIME}" \
      --rate="${RATE}" \
      --report-interval="${REPORT_INTERVAL}" \
      "${TEST_TYPE}" run
    ;;
  cleanup)
    echo "Cleaning up test data..."
    ${SYSBENCH_CMD} "${TEST_TYPE}" cleanup
    ;;
  *)
    usage
    ;;
esac
