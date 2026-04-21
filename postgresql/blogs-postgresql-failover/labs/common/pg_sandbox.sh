#!/usr/bin/env bash
# pg_sandbox.sh — create / destroy local PostgreSQL instances for failover labs.
#
# Usage:
#   pg_sandbox.sh init-primary <data_dir> <port>
#   pg_sandbox.sh init-replica <data_dir> <port> <primary_port>
#   pg_sandbox.sh start        <data_dir>
#   pg_sandbox.sh stop         <data_dir>
#   pg_sandbox.sh destroy      <data_dir>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="$SCRIPT_DIR/config"

require() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: $1 not on PATH" >&2
        exit 1
    }
}

require initdb
require pg_ctl
require psql
require pg_basebackup

init_primary() {
    local data_dir="$1" port="$2"
    initdb -D "$data_dir" -U postgres --auth-local=trust --auth-host=md5 --pwfile=<(echo "postgres") >/dev/null

    sed -e "s|__PORT__|$port|g" -e "s|__DATA_DIR__|$data_dir|g" \
        "$CONF_DIR/postgresql.conf.template" > "$data_dir/postgresql.conf"
    cp "$CONF_DIR/pg_hba.conf.template" "$data_dir/pg_hba.conf"

    pg_ctl -D "$data_dir" -l "$data_dir/server.log" start
    PGPASSWORD=postgres psql -h 127.0.0.1 -p "$port" -U postgres -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator';"
    PGPASSWORD=postgres psql -h 127.0.0.1 -p "$port" -U postgres -c "CREATE ROLE app LOGIN PASSWORD 'app' SUPERUSER;"
    PGPASSWORD=postgres psql -h 127.0.0.1 -p "$port" -U postgres -c "CREATE ROLE monitor LOGIN PASSWORD 'monitor';"
    PGPASSWORD=postgres psql -h 127.0.0.1 -p "$port" -U postgres -c "CREATE DATABASE pgbench OWNER app;"
}

init_replica() {
    local data_dir="$1" port="$2" primary_port="$3"
    PGPASSWORD=replicator pg_basebackup -h 127.0.0.1 -p "$primary_port" \
        -U replicator -D "$data_dir" -R -X stream >/dev/null

    sed -e "s|__PORT__|$port|g" -e "s|__DATA_DIR__|$data_dir|g" \
        "$CONF_DIR/postgresql.conf.template" > "$data_dir/postgresql.conf"
    cp "$CONF_DIR/pg_hba.conf.template" "$data_dir/pg_hba.conf"

    pg_ctl -D "$data_dir" -l "$data_dir/server.log" start
}

start()   { pg_ctl -D "$1" -l "$1/server.log" start; }

stop() {
    local data_dir="$1"
    pg_ctl -D "$data_dir" stop -m fast 2>/dev/null || true

    # Belt and suspenders: pg_ctl can return success without the postmaster
    # actually exiting (e.g. after a previous SIGKILL leaves a stale pid file).
    # Kill any postgres process still bound to this datadir, then wait.
    local pid=""
    [[ -f "$data_dir/postmaster.pid" ]] && pid="$(head -n 1 "$data_dir/postmaster.pid" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        for _ in $(seq 1 50); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$pid" 2>/dev/null || true
    fi
    pkill -9 -f "postgres.*-D $data_dir(\$| )" 2>/dev/null || true
    rm -f "$data_dir/postmaster.pid"
}

destroy() {
    stop "$1"
    rm -rf "$1"
}

cmd="$1"; shift
case "$cmd" in
    init-primary) init_primary "$@" ;;
    init-replica) init_replica "$@" ;;
    start)        start "$@" ;;
    stop)         stop "$@" ;;
    destroy)      destroy "$@" ;;
    *) echo "unknown cmd: $cmd" >&2; exit 2 ;;
esac
