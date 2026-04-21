#!/usr/bin/env bash
set -euo pipefail
export PGPASSWORD=app
export PATH=/usr/lib/postgresql/16/bin:$PATH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS="$SCRIPT_DIR/../benchmark"
BASE_OUT="$SCRIPT_DIR/out/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BASE_OUT"

INJECT_CHAIN="$SCRIPT_DIR/inject.sh && sleep 1 && $SCRIPT_DIR/promote.sh"
PGSTAT_CMD="$SCRIPT_DIR/pg_stat_snapshot.sh"

trap "$SCRIPT_DIR/tear-down.sh" EXIT

# Pre-flight: kill any stale proxysql/postgres processes from previous lab runs
# to avoid port conflicts on 6132/6133/6134/5433/5434/5435.
pkill -f "proxysql.*-c.*labs.*proxysql.cnf" 2>/dev/null || true
pkill -f "postgres.*labs.*data/(primary|replica)" 2>/dev/null || true

for trial in 1 2 3; do
    echo "=== trial $trial ==="
    "$SCRIPT_DIR/tear-down.sh" >/dev/null 2>&1 || true
    "$SCRIPT_DIR/bring-up.sh"

    TRIAL_OUT="$BASE_OUT/trial-$trial"
    python3 "$HARNESS/harness.py" \
        --pgbench-host 127.0.0.1 --pgbench-port 6133 \
        --pgbench-db pgbench --pgbench-user app \
        --admin-host 127.0.0.1 --admin-port 6134 \
        --admin-user admin --admin-password admin \
        --script "$SCRIPT_DIR/workload.sql" \
        --duration 90 --warmup 30 --inject-at 30 \
        --inject-cmd "$INJECT_CHAIN" \
        --writer-hg 10 \
        --trials 1 \
        --driver python \
        --proxysql-log "$SCRIPT_DIR/data/proxysql/proxysql.log" \
        --pre-trial-cmd  "$PGSTAT_CMD" \
        --post-trial-cmd "$PGSTAT_CMD" \
        --out "$TRIAL_OUT"
done

# Aggregate the three trials into a single summary.
python3 - <<PY
import json, statistics
from pathlib import Path
base = Path("$BASE_OUT")
trials = [json.loads((base / f"trial-{i}" / "trial-1" / "run.json").read_text())
          for i in (1, 2, 3)]
keys = trials[0].keys()
summary = {}
for k in keys:
    vals = [t[k] for t in trials]
    summary[k] = {"median": statistics.median(vals), "min": min(vals), "max": max(vals)}
(base / "summary.json").write_text(json.dumps(summary, separators=(",", ":")) + "\n")
print("aggregated summary:", summary)
PY

echo "run complete → $BASE_OUT"
