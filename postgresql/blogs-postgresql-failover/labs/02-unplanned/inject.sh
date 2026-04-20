#!/usr/bin/env bash
# inject.sh — SIGKILL the primary's postmaster to simulate an unplanned crash.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$SCRIPT_DIR/data"
PIDFILE="$BASE/primary/postmaster.pid"

if [[ ! -f "$PIDFILE" ]]; then
    echo "ERROR: no postmaster.pid under $BASE/primary — is the lab running?" >&2
    exit 1
fi

PID=$(head -n 1 "$PIDFILE")
echo "injecting: SIGKILL pid $PID (primary postmaster)"
kill -9 "$PID"
