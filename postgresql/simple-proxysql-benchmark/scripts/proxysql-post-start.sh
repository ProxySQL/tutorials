#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${PROXYSQL_CONTAINER_NAME:-proxysql}"
ADMIN_USER="${PROXYSQL_ADMIN_USER:-radmin}"
ADMIN_PASSWD="${PROXYSQL_ADMIN_PASSWD:-radmin}"
ADMIN_PORT="${PROXYSQL_ADMIN_PORT:-6132}"

# Wait for ProxySQL admin interface to be ready
until docker exec -e PGPASSWORD=${ADMIN_PASSWD} ${CONTAINER} psql -U ${ADMIN_USER} -h localhost -p ${ADMIN_PORT} -c "SELECT 1" > /dev/null 2>&1; do
  echo "Waiting for ProxySQL to be ready..."
  sleep 1
done

echo "ProxySQL is ready, configuring tsdb..."
docker exec -e PGPASSWORD=${ADMIN_PASSWD} ${CONTAINER} psql -U ${ADMIN_USER} -h localhost -p ${ADMIN_PORT} -c "SET tsdb-enabled=1;"
docker exec -e PGPASSWORD=${ADMIN_PASSWD} ${CONTAINER} psql -U ${ADMIN_USER} -h localhost -p ${ADMIN_PORT} -c "LOAD TSDB VARIABLES TO RUNTIME;"
echo "TSDB enabled."
