#!/usr/bin/env bash
# proxysql_sandbox.sh — create / destroy local ProxySQL instances for failover labs.
#
# Usage:
#   proxysql_sandbox.sh start   <data_dir> <proxysql_binary>
#   proxysql_sandbox.sh stop    <data_dir>
#   proxysql_sandbox.sh destroy <data_dir>
#   proxysql_sandbox.sh admin-sql <admin_port> <sql>
#   proxysql_sandbox.sh wait-ready <admin_port> <timeout_s>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="$SCRIPT_DIR/config"

start() {
    local data_dir="$1" binary="$2"
    mkdir -p "$data_dir"
    sed -e "s|__DATA_DIR__|$data_dir|g" \
        "$CONF_DIR/proxysql.cnf.template" > "$data_dir/proxysql.cnf"
    # ProxySQL daemonizes itself and writes its own proxysql.pid in datadir.
    # Do NOT write a pid file here — that would collide with ProxySQL's own
    # daemon_pid_file_is_running() check and falsely report "already running".
    "$binary" --initial -c "$data_dir/proxysql.cnf" -D "$data_dir"
}

stop() {
    local data_dir="$1"
    # ProxySQL writes proxysql.pid inside its datadir after daemonizing.
    local pidfile="$data_dir/proxysql.pid"
    local pid=""
    [[ -f "$pidfile" ]] && pid="$(cat "$pidfile" 2>/dev/null || true)"

    # SIGTERM the daemon, then wait until it actually exits before returning.
    # The previous implementation removed the pidfile immediately, which let
    # bring-up race against a still-listening worker on ports 6132/6133/6134
    # and produce empty pgbench trials.
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        for _ in $(seq 1 50); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$pid" 2>/dev/null || true
    fi

    # Belt and suspenders: kill any orphan proxysql still bound to this datadir
    # (angel/worker fork can outlive the main pid) and wait for the admin port
    # (6132) to drop out of LISTEN, otherwise the next bring-up's `start` races.
    pkill -9 -f "proxysql.*-D $data_dir(\$| )" 2>/dev/null || true
    for _ in $(seq 1 50); do
        ss -ltn 'sport = :6132' 2>/dev/null | grep -q LISTEN || break
        sleep 0.1
    done
    rm -f "$pidfile"
}

destroy() {
    stop "$1"
    rm -rf "$1"
}

admin_sql() {
    local admin_port="$1" sql="$2"
    mysql -h 127.0.0.1 -P "$admin_port" -u admin -padmin -N -B -e "$sql"
}

wait_ready() {
    local admin_port="$1" timeout="$2"
    local deadline=$((SECONDS + timeout))
    while (( SECONDS < deadline )); do
        if mysql -h 127.0.0.1 -P "$admin_port" -u admin -padmin \
                 -e "SELECT 1" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.2
    done
    echo "ERROR: ProxySQL admin on port $admin_port did not become ready in ${timeout}s" >&2
    return 1
}

cmd="$1"; shift
case "$cmd" in
    start)      start "$@" ;;
    stop)       stop "$@" ;;
    destroy)    destroy "$@" ;;
    admin-sql)  admin_sql "$@" ;;
    wait-ready) wait_ready "$@" ;;
    *) echo "unknown cmd: $cmd" >&2; exit 2 ;;
esac
