#!/usr/bin/env bash
# We remove set -e to handle failures manually in the loop
set -o pipefail

# Configuration
TABLES=${TABLES:-10}
TABLE_SIZE=${TABLE_SIZE:-100000}
TIME=${TIME:-30}
THREADS_LIST=${THREADS_LIST:-"8 16 32 64 128 256 512 1024"}

usage() {
  echo "Usage: $0 <test_type> [target_host] [target_port]"
  echo ""
  echo "Mandatory Arguments:"
  echo "  test_type    The sysbench test to run. Possible values:"
  echo "               - oltp_read_write"
  echo "               - oltp_read_only"
  echo "               - oltp_point_select"
  echo "               - oltp_write_only"
  echo ""
  echo "Optional Arguments:"
  echo "  target_host  Default: \$PROXY_HOST (current: ${PROXY_HOST})"
  echo "  target_port  Default: \$PROXY_PORT (current: ${PROXY_PORT})"
  echo ""
  echo "Example:"
  echo "  $0 oltp_read_only proxysql 6133"
  exit 1
}

# Check for mandatory argument and validate test type
TEST_TYPE=$1
case "${TEST_TYPE}" in
  oltp_read_write|oltp_read_only|oltp_point_select|oltp_write_only)
    # Valid test type
    ;;
  *)
    usage
    ;;
esac

# Target: proxysql or postgresql
TARGET_HOST=${2:-$PROXY_HOST}
TARGET_PORT=${3:-$PROXY_PORT}

# Force SSL for the pgsql driver
export PGSSLMODE=require

echo "Starting Detailed Benchmark [${TEST_TYPE}] against ${TARGET_HOST}:${TARGET_PORT}"
echo "Preparing data..."

sysbench \
  --db-driver=pgsql \
  --pgsql-host=${TARGET_HOST} \
  --pgsql-port=${TARGET_PORT} \
  --pgsql-user=${DB_USER} \
  --pgsql-password=${DB_PASSWD} \
  --pgsql-db=${DB_NAME} \
  --tables=${TABLES} \
  --table-size=${TABLE_SIZE} \
  "${TEST_TYPE}" prepare > /dev/null 2>&1

echo "Concurrency |    TPS     |    QPS     | Latency 95th (ms)"
echo "------------|------------|------------|-------------------"

for THREADS in ${THREADS_LIST}; do
  # Run sysbench and capture stdout and stderr
  CMD="sysbench \
    --db-driver=pgsql \
    --pgsql-host=${TARGET_HOST} \
    --pgsql-port=${TARGET_PORT} \
    --pgsql-user=${DB_USER} \
    --pgsql-password=${DB_PASSWD} \
    --pgsql-db=${DB_NAME} \
    --tables=${TABLES} \
    --table-size=${TABLE_SIZE} \
    --threads=${THREADS} \
    --time=${TIME} \
    --percentile=95 \
    --report-interval=10 \
    ${TEST_TYPE} run"

  RESULT=$($CMD 2>&1)
  EXIT_CODE=$?

  if [ $EXIT_CODE -ne 0 ]; then
    echo "FAILED at Concurrency $THREADS (Exit Code: $EXIT_CODE)"
    echo "--- RAW OUTPUT START ---"
    echo "$RESULT"
    echo "--- RAW OUTPUT END ---"
    exit $EXIT_CODE
  fi

  TPS=$(echo "$RESULT" | grep "transactions:" | awk '{print $3}' | tr -d '(')
  QPS=$(echo "$RESULT" | grep "queries:" | awk '{print $3}' | tr -d '(')
  L95=$(echo "$RESULT" | grep "95th percentile:" | awk '{print $3}')

  printf "%11s | %10s | %10s | %17s\n" "$THREADS" "$TPS" "$QPS" "$L95"
done

# Cleanup
echo "Cleaning up..."
sysbench \
  --db-driver=pgsql \
  --pgsql-host=${TARGET_HOST} \
  --pgsql-port=${TARGET_PORT} \
  --pgsql-user=${DB_USER} \
  --pgsql-password=${DB_PASSWD} \
  --pgsql-db=${DB_NAME} \
  --tables=${TABLES} \
  --table-size=${TABLE_SIZE} \
  "${TEST_TYPE}" cleanup > /dev/null 2>&1
