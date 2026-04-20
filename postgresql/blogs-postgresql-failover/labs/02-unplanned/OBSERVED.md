# Post 2 — observed run

Latest run: `out/20260416-121629/`.

- Date: 2026-04-16
- PG version: 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
- ProxySQL commit: 1ed9969fdf51ecdb84fa60fffc12a54e03dbebfe (`v3.0_pgsql_blogs`)

## Aggregated (3 trials)

- writes_resume_ms: median=31900, min=31500, max=32100
- error_count_post_inject: median=0, min=0, max=0
- total_ok_pre_inject: median=134484, min=133713, max=138829

Per the harness (`harness.py` `compute_summary`), `writes_resume_ms` is the
absolute time of the first 100 ms bucket where `ok>0` *after* the first
post-inject bucket with `ok==0` or `err>0`. With `--inject-at 30` (30000 ms),
the median 31900 implies a measurable failover window of **1900 ms** from the
SIGKILL of the primary postmaster to the resumption of successful writes
through ProxySQL. Min/max across the three trials: 1500–2100 ms.

## Qualitative notes

- Backend state sequence on the writer hg (10): ONLINE (5433) →
  *row deleted by promote.sh* → ONLINE (5434). The 100 ms admin probe
  almost never sees a non-ONLINE writer because `promote.sh` swaps the
  hostgroup in a single `LOAD PGSQL SERVERS TO RUNTIME` after deleting the
  dead row and re-tagging replica-1. The transient `-1` blips in the CSV are
  individual probe-query failures (admin connection churn), not real status.
- pgbench error types (from `--failures-detailed` log): **none**. pgbench
  retried connection drops silently; 1,761,114 transactions logged across
  the trial, zero failure rows. The 1100 ms `ok==0` gap visible in
  `run.csv` (t≈30800 → t≈31800 in trial-1) reflects clients waiting on the
  reconnect rather than reporting errors. **This is the headline asymmetry
  for the post**: applications using a connection pool with retry will see
  no errors at all, just a brief stall.
- Observed inject-chain delay: ~700–800 ms from `inject_at` (30000 ms) to
  the first all-zero bucket. SIGKILL is instant, but the in-flight pgbench
  transactions to the dead primary continue to drain on already-open
  connections until the kernel resets them.
- Anomalies / surprises:
  - Two prior runs of this lab were broken by an inter-trial race
    (`proxysql_sandbox.sh stop` returned before the daemon released its
    admin port; the next bring-up started against a stale listener). Fixed
    in this commit's hardened `stop()` (waits for pid exit + port to drop
    out of LISTEN) plus a SELECT 1 health-check at the end of `bring-up.sh`.
  - The previous `compute_summary` definition ("first post-inject bucket
    with `ok>0 AND err==0`") returned `inject_ms + bucket_ms` (= 30100)
    regardless of real recovery, because pre-disruption buckets satisfied it
    immediately. Replaced with disruption-then-recovery detection; new
    metric matches the gap visible in the CSV.

## Chart to use in the post

Trial-1 has `writes_resume_ms == 31900`, equal to the cross-trial median.
Copy `out/20260416-121629/trial-1/trial-1/run.png` to
`blogs/pgsql-failover/posts/02-chart.png` in Task 22.
