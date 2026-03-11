#!/usr/bin/env bash
set -euo pipefail
[[ -n "${TRACE:-}" ]] && set -x

TEST_TYPE="${TEST_TYPE:-oltp_read_only}"

echo "Cleaning up sysbench test data..."
docker exec -e DB_CONTAINER_NAME=${PROXYSQL_CONTAINER_NAME} -e DB_PORT=${PROXYSQL_DB_PORT} -e TEST_TYPE=${TEST_TYPE} sysbench1 /usr/local/bin/benchmark.sh cleanup || true

echo "Preparing sysbench test data..."
docker exec -e DB_CONTAINER_NAME=${PROXYSQL_CONTAINER_NAME} -e DB_PORT=${PROXYSQL_DB_PORT} -e TEST_TYPE=${TEST_TYPE} sysbench1 /usr/local/bin/benchmark.sh prepare

echo "Resetting ProxySQL stats..."
docker exec -e PGPASSWORD=${PROXYSQL_ADMIN_PASSWD} ${PROXYSQL_CONTAINER_NAME} psql -U ${PROXYSQL_ADMIN_USER} -h localhost -p ${PROXYSQL_ADMIN_PORT} -c "SELECT * FROM stats.stats_pgsql_query_digest_reset;" > /dev/null
docker exec -e PGPASSWORD=${PROXYSQL_ADMIN_PASSWD} ${PROXYSQL_CONTAINER_NAME} psql -U ${PROXYSQL_ADMIN_USER} -h localhost -p ${PROXYSQL_ADMIN_PORT} -c "SELECT * FROM stats.stats_pgsql_connection_pool_reset;" > /dev/null

echo "Terminating idle connections..."
for HOST in primary replica1 replica2; do
  docker exec -it ${HOST} psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND datname = 'demo' AND pid <> pg_backend_pid();"
done
