# Post 2 — observed run

Latest run: `out/20260421-050130/`.

- Date: 2026-04-21
- PG version: 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
- ProxySQL commit: 955c0f5ee (`v3.0_pgsql_blogs`, includes the
  transaction-state fix)
- Workload driver: `driver_py.py` (8 workers, reconnect-on-error)
- Admin SQL wire protocol: PostgreSQL (port 6134), driven by `psql`

## Aggregated (3 trials)

- writes_resume_ms: median=1700, min=1600, max=1700
- error_count_post_inject: median=8, min=8, max=8
- total_ok_pre_inject: median=574387, min=566154, max=576629

`writes_resume_ms` is the time **since the kill** until the first
100 ms bucket with `ok>0` **and** `err==0` after any bucket with
`ok==0` or `err>0`. Measured failover window: **median 1700 ms, range
1600–1700 ms**.

## Qualitative notes

- Error shape: exactly eight errors per trial, landing in a single
  100 ms bucket 400–600 ms after the kill. One per worker, matching
  the eight concurrent in-flight UPDATEs at the kill instant. Every
  worker's logical connection to ProxySQL survived — the
  reconnect-and-retry loop in `driver_py.py` picks up cleanly on the
  next iteration.
- Backend state sequence on the writer hg (10): ONLINE (5433) →
  *row deleted by promote.sh* → ONLINE (5434). The 100 ms admin probe
  almost never sees a non-ONLINE writer because `promote.sh` swaps the
  hostgroup in a single `LOAD PGSQL SERVERS TO RUNTIME`. The alternating
  `-1` samples in the CSV are individual probe-query failures (admin
  connection churn), not real status.
- The "ok=0" gap is 11 consecutive 100 ms buckets. Of that, ~1000 ms
  is the configured `sleep 1` between `inject.sh` and `promote.sh`;
  ~100 ms is `pg_ctl promote` + admin-SQL rewrite; the rest is the
  next retry loop tick on each worker.
- Writer `ConnUsed` collapses to 0 during the gap and snaps back to
  the 5–8 band on recovery. Visible as the bottom panel of run.png.
- Pre-inject throughput ~19–20k tps with 8 workers (Python driver;
  pgbench on the same host also hits ~20k tps but aborts on
  connection loss which makes it useless for this specific measurement).

## Anomalies / history

- **The silent-retry bug.** An earlier run of this lab (20260416-121629,
  pgbench-driven, pre-955c0f5e) reported zero errors and full recovery
  — because ProxySQL was silently replaying in-transaction statements
  on fresh backend connections, and pgbench's `COMMIT` succeeded on a
  connection with no open transaction (PostgreSQL emitted `WARNING:
  there is no transaction in progress` that pgbench never saw). Fixed
  in commit 955c0f5e; this run is against the fixed binary.
- **Workload driver replaced.** The previous harness invoked `pgbench`.
  On a real connection drop `pgbench` aborts the affected client for
  the rest of the run — `--max-tries` only covers serialization /
  deadlock errors, not connection loss. Replaced with `driver_py.py`
  which reconnects and retries, matching production pool behavior.
- **Summary metric tightened.** `writes_resume_ms` previously used
  "first bucket with ok>0" for recovery; with the new driver the
  kill-bucket carries both pre-kill tail commits (ok>0) *and* the error
  storm (err>0), and the old rule would have marked that mixed bucket
  as recovery. Recovery now additionally requires `err==0`.

## Chart to use in the post

Trial-1 has `writes_resume_ms == 1700`, equal to the cross-trial
median. Copy `out/20260421-050130/trial-1/trial-1/run.png` to
`blogs/pgsql-failover/posts/02-chart.png` (already done).
