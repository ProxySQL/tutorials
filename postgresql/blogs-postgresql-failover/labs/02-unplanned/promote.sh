#!/usr/bin/env bash
# promote.sh — promote replica-1 to primary and rewire ProxySQL.
# Runs as a side-effect after inject.sh. In production this is done by an HA tool.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON="$SCRIPT_DIR/../common"
BASE="$SCRIPT_DIR/data"

pg_ctl -D "$BASE/replica-1" promote

ADM="$COMMON/proxysql_sandbox.sh admin-sql 6132"

# Move the new primary (5434) into the writer hostgroup (10).
# pgsql_replication_hostgroups with check_type=read_only will also flip this based on
# pg_is_in_recovery() once monitor runs — we do it explicitly here to measure the
# upper bound of the failover latency without depending on monitor interval.
$ADM "DELETE FROM pgsql_servers WHERE hostname='127.0.0.1' AND port=5433;"
$ADM "UPDATE pgsql_servers SET hostgroup_id=10 WHERE hostname='127.0.0.1' AND port=5434;"
$ADM "LOAD PGSQL SERVERS TO RUNTIME;"
echo "promote complete: replica-1 (5434) is now the writer in hg 10."
