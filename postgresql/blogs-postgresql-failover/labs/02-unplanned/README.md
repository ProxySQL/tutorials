# Post 2 — Unplanned primary failure

Sandbox and harness for the measurement behind
[`posts/02-unplanned-primary-failure.md`](../../posts/02-unplanned-primary-failure.md).

## Topology

```
driver_py  →  ProxySQL  →  primary   (port 5433, hg 10)
                        →  replica-1 (port 5434, hg 20 — promoted into hg 10 at t=31s)
                        →  replica-2 (port 5435, hg 20)
```

ProxySQL listens on 6133 (app-facing), 6134 (admin — PostgreSQL wire
protocol, driven with `psql`), and 6132 (admin — MySQL wire protocol,
same SQL surface). The lab uses 6134.

## What the lab does

1. `bring-up.sh` — initdb the primary on 5433, `pg_basebackup` two
   replicas on 5434 / 5435, start ProxySQL, register backends, create
   the `pgbench` schema on the primary, and wait for `SELECT 1` through
   the proxy port.
2. `run.sh` — for each of three trials:
   - Snapshot `pg_stat_database` (pre).
   - Start `driver_py.py` — 8 worker threads, 90 s, each running the
     `pgbench_accounts` UPDATE workload in an explicit `BEGIN / COMMIT`
     block, logging per-transaction outcome in a pgbench-compatible
     format.
   - At T = 30 s: `inject.sh` SIGKILLs the primary postmaster.
   - At T = 31 s: `promote.sh` runs `pg_ctl promote` on replica-1 and
     rewires ProxySQL (`DELETE` the dead row, `UPDATE` replica-1 into
     hg 10, `LOAD PGSQL SERVERS TO RUNTIME`).
   - Snapshot `pg_stat_database` (post).
   - Harness computes `writes_resume_ms`, `error_count_post_inject`,
     and `total_ok_pre_inject` from the per-transaction log bucketed at
     100 ms.
3. `tear-down.sh` — always runs on exit; stops ProxySQL and every
   Postgres instance, wipes `data/`.

## Run

```bash
./run.sh
```

Outputs land under `out/<timestamp>/`:

```
out/20260420-184436/
├── summary.json                    # median/min/max across the three trials
├── trial-1/
│   └── trial-1/
│       ├── run.json                # summary for this trial
│       ├── run.csv                 # 100 ms buckets (ok, err, state, ConnUsed)
│       ├── run.png                 # 4-panel chart (throughput, errors, state, ConnUsed)
│       ├── pgbench.<pid>[.N]       # per-worker transaction logs
│       ├── pgbench_stdout.txt      # driver summary line
│       ├── pgbench_stderr.txt      # driver tracebacks if any
│       ├── pg_stat.txt             # pg_stat_database pre/post snapshots
│       └── proxysql.log            # ProxySQL error log, captured post-trial
├── trial-2/ …
└── trial-3/ …
```

## Workload driver

The driver is **not** `pgbench`. pgbench aborts its affected client on
connection loss (its `--max-tries` flag only covers serialization /
deadlock errors, not backend drops), which makes it useless for
measuring failover behavior from the application's point of view.

Instead, `labs/benchmark/driver_py.py` mimics what a production
connection pool does: each worker keeps one libpq connection to
ProxySQL; on any psycopg2 error it closes that connection, opens a new
one, and resumes. The per-transaction log format matches pgbench's
`-l --log-prefix=…` output, so the harness's bucketing and chart
rendering are unchanged.

Switch between drivers via `harness.py --driver {pgbench,python}`
(default `pgbench`). `run.sh` in this lab uses `--driver python`.

## Key files

| File | Purpose |
|------|---------|
| `bring-up.sh` | Primary + 2 replicas + ProxySQL + pgbench-accounts schema |
| `inject.sh` | SIGKILL the primary's postmaster |
| `promote.sh` | `pg_ctl promote` replica-1 + rewire ProxySQL via admin SQL |
| `tear-down.sh` | Stop everything, wipe `data/` |
| `run.sh` | Orchestrate three trials and aggregate `summary.json` |
| `workload.sql` | pgbench-syntax workload (kept for reference; the python driver hard-codes the same UPDATE) |
| `pg_stat_snapshot.sh` | Pre/post `pg_stat_database` capture |
| `OBSERVED.md` | Latest observed numbers + anomaly log |

## Caveats

- **Single-host lab.** No real network, no disk contention, no cloud
  control-plane latency. Numbers here are a lower bound — use them for
  relative comparisons against the other posts' labs, not as production
  forecasts.
- **The promote step is triggered by the harness, not a real HA tool.**
  The `inject.sh && sleep 1 && promote.sh` chain hard-codes a 1-second
  detect-and-decide latency. Post 5 (Patroni) and Post 6
  (pg_auto_failover) replace this with actual HA-tool behavior.
- **Explicit rewire.** `promote.sh` issues `DELETE` / `UPDATE` /
  `LOAD PGSQL SERVERS TO RUNTIME` against ProxySQL's admin port
  directly, bypassing `monitor_read_only_interval`. If you want to
  measure the implicit-rewire path (`pgsql_replication_hostgroups` +
  `check_type='read_only'` only), drop the three admin-SQL lines from
  `promote.sh` and expect the window to drift up by up to one monitor
  interval (default 1500 ms).
- **ProxySQL build requirement.** Commit
  [`955c0f5ee`](https://github.com/sysown/proxysql/commit/955c0f5ee) —
  the fix for the silent in-transaction retry on broken backend — must
  be in the binary under `src/proxysql`. A pre-fix build will report
  zero post-inject errors for the wrong reason (see §"A bug we found"
  in the post).
- **Workload is write-only.** UPDATE on `pgbench_accounts`; there is no
  read traffic. The point of this lab is the *writer* recovery window.

## Interpreting the numbers

- `writes_resume_ms`: the measured failover window — **ms from the
  kill to the first 100 ms bucket where `ok>0` and `err==0`** after any
  bucket with `ok==0` or `err>0`. Sentinel `-1` means no disruption
  was observed.
- `error_count_post_inject`: total errors across all post-inject
  buckets. With the python driver, this is one per in-flight worker at
  kill time (typically equal to `--clients`).
- `total_ok_pre_inject`: committed transactions in the 30-second warmup.
  Sanity check — confirms the workload actually ran before the inject.

See `OBSERVED.md` for the most recent numbers and the fairness note.
