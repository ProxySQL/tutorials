#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON="$SCRIPT_DIR/../common"
BASE="$SCRIPT_DIR/data"
PROXYSQL_BIN="$SCRIPT_DIR/../../../../src/proxysql"

rm -rf "$BASE"
mkdir -p "$BASE"

"$COMMON/pg_sandbox.sh" init-primary "$BASE/primary"   5433
"$COMMON/pg_sandbox.sh" init-replica "$BASE/replica-1" 5434 5433
"$COMMON/pg_sandbox.sh" init-replica "$BASE/replica-2" 5435 5433

"$COMMON/proxysql_sandbox.sh" start "$BASE/proxysql" "$PROXYSQL_BIN"
"$COMMON/proxysql_sandbox.sh" wait-ready 6132 15

ADM="$COMMON/proxysql_sandbox.sh admin-sql 6132"

# Clear any stale state (handles repeated bring-ups without a full destroy).
$ADM "DELETE FROM pgsql_servers;"
$ADM "DELETE FROM pgsql_users;"
$ADM "DELETE FROM pgsql_replication_hostgroups;"

$ADM "INSERT INTO pgsql_servers (hostgroup_id, hostname, port) VALUES (10,'127.0.0.1',5433);"
$ADM "INSERT INTO pgsql_servers (hostgroup_id, hostname, port) VALUES (20,'127.0.0.1',5434);"
$ADM "INSERT INTO pgsql_servers (hostgroup_id, hostname, port) VALUES (20,'127.0.0.1',5435);"
$ADM "INSERT INTO pgsql_users (username, password, default_hostgroup) VALUES ('app','app',10);"
$ADM "INSERT INTO pgsql_replication_hostgroups (writer_hostgroup, reader_hostgroup, check_type) VALUES (10, 20, 'read_only');"
$ADM "LOAD PGSQL SERVERS TO RUNTIME;"
$ADM "LOAD PGSQL USERS TO RUNTIME;"
$ADM "LOAD PGSQL VARIABLES TO RUNTIME;"

PGPASSWORD=app pgbench -h 127.0.0.1 -p 5433 -U app -i -s 5 pgbench >/dev/null

# Verify ProxySQL→backend wiring before the harness runs. The earlier failure
# mode (trial-2 producing an empty pgbench log) happened when the new ProxySQL
# was admin-reachable but its backend pool wasn't yet warm — pgbench connected,
# got nothing back, and exited fast. Probe via the proxy port until SELECT 1
# succeeds.
for _ in $(seq 1 50); do
    if PGPASSWORD=app psql -h 127.0.0.1 -p 6133 -U app -d pgbench \
            -c "SELECT 1" >/dev/null 2>&1; then
        echo "bring-up complete (1P + 2R + ProxySQL)."
        exit 0
    fi
    sleep 0.2
done
echo "ERROR: ProxySQL did not start serving SELECT 1 on port 6133 within 10s" >&2
exit 1
