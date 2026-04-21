#!/usr/bin/env bash
# Snapshot xact_commit/rollback on every backend port. Harness invokes this
# pre-pgbench and post-pgbench with $PHASE and $TRIAL_DIR set. After the
# unplanned-primary-failure inject, port 5433 is dead; the psql call to it
# fails, and we record that failure rather than aborting.
set -u
: "${TRIAL_DIR:?TRIAL_DIR not set}"
: "${PHASE:?PHASE not set}"
export PGPASSWORD=app
OUT="$TRIAL_DIR/pg_stat.txt"
{
    for p in 5433 5434 5435; do
        echo "--- port=$p phase=$PHASE ts=$(date +%s.%N) ---"
        psql -h 127.0.0.1 -p "$p" -U app -d pgbench -Atc \
            "SELECT datname, xact_commit, xact_rollback FROM pg_stat_database WHERE datname='pgbench'" 2>&1 \
            || echo "(psql failed; backend likely down)"
    done
} >> "$OUT"
