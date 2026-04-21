"""Benchmark harness entry point and summary math."""

from __future__ import annotations

import argparse
import statistics
from pathlib import Path
from typing import Dict, List, Mapping, Sequence


def compute_summary(
    buckets: Sequence[Mapping[str, int]],
    *,
    bucket_ms: int,
    inject_ms: int,
    metric_label: str = "writes",
) -> Dict[str, int]:
    inject_idx = inject_ms // bucket_ms
    post = buckets[inject_idx:]
    pre = buckets[:inject_idx]

    total_ok_pre = sum(b["ok"] for b in pre)
    errors_post = sum(b["err"] for b in post)

    # Writes-resume: ms *after the kill* until writes come back — the real
    # failover window.  Recovery is the first post-inject bucket with ok>0
    # **and** err==0 following any bucket with ok==0 or err>0.  The err==0
    # guard skips transitional buckets that carry both the pre-kill tail of
    # commits and the error storm, which would otherwise be miscounted as
    # recovery before the real failover window had even begun.
    #
    # Returned value is the offset from inject_ms, not the absolute trial
    # time — "writes resumed 1300 ms after the kill" is what readers want.
    # Sentinel -1 means no disruption was ever observed.
    writes_resume_ms = -1
    disruption_offset = None
    for offset, b in enumerate(post[1:], start=1):
        if b["ok"] == 0 or b["err"] > 0:
            disruption_offset = offset
            break

    if disruption_offset is not None:
        for offset in range(disruption_offset, len(post)):
            if post[offset]["ok"] > 0 and post[offset]["err"] == 0:
                writes_resume_ms = offset * bucket_ms
                break

    return {
        f"{metric_label}_resume_ms": writes_resume_ms,
        "error_count_post_inject": errors_post,
        "total_ok_pre_inject": total_ok_pre,
    }


def median_summary(trials: Sequence[Mapping[str, int]]) -> Dict[str, Dict[str, float]]:
    if not trials:
        return {}
    keys = list(trials[0].keys())
    out: Dict[str, Dict[str, float]] = {}
    for k in keys:
        values = [t[k] for t in trials]
        out[k] = {
            "median": statistics.median(values),
            "min": min(values),
            "max": max(values),
        }
    return out


def build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser()
    p.add_argument("--pgbench-host", required=True)
    p.add_argument("--pgbench-port", required=True,
                   help="Single port (e.g. '5433') or comma-separated for libpq multi-host (e.g. '5433,5434,5435').")
    p.add_argument("--pgbench-db", required=True)
    p.add_argument("--pgbench-user", required=True)
    p.add_argument("--admin-host", required=True)
    p.add_argument("--admin-port", type=int, required=True)
    p.add_argument("--admin-user", required=True)
    p.add_argument("--admin-password", required=True)
    p.add_argument("--script", required=True, help="Path to pgbench SQL script")
    p.add_argument("--duration", type=int, default=90)
    p.add_argument("--warmup", type=int, default=30)
    p.add_argument("--inject-at", type=int, default=30)
    p.add_argument("--inject-cmd", default="", help="Shell command to run at inject time")
    p.add_argument("--writer-hg", default="10")
    p.add_argument("--clients", type=int, default=8)
    p.add_argument("--jobs", type=int, default=4)
    p.add_argument("--trials", type=int, default=3)
    p.add_argument("--metric-label", default="writes",
                   help="Resume-time JSON key prefix; e.g. 'writes' or 'reads'.")
    p.add_argument("--driver", choices=["pgbench", "python"], default="pgbench",
                   help="Workload driver. 'python' uses driver_py.py which "
                        "reconnects+retries on backend errors (needed when "
                        "measuring failover through ProxySQL).")
    p.add_argument("--proxysql-log", type=Path, default=None,
                   help="Path to ProxySQL error log; copied into each trial dir after pgbench exits.")
    p.add_argument("--pre-trial-cmd", default="",
                   help="Shell command run after bring-up, before pgbench starts (e.g. snapshot pg_stat_database).")
    p.add_argument("--post-trial-cmd", default="",
                   help="Shell command run after pgbench exits (e.g. snapshot pg_stat_database again).")
    p.add_argument("--out", type=Path, required=True)
    return p


def main(argv: list[str] | None = None) -> int:
    import subprocess
    import threading
    import time

    from pgbench_driver import build_pgbench_cmd, bucket_logs
    from probes import (
        parse_connection_pool_tsv,
        parse_show_pgsql_servers_tsv,
        query_admin,
        status_to_code,
        summarize_backend_state,
        summarize_writer_conn_used,
    )
    from outputs import write_chart_png, write_probe_csv, write_summary_json

    args = build_argparser().parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)

    trial_summaries: List[Dict[str, int]] = []

    for trial in range(1, args.trials + 1):
        trial_dir = args.out / f"trial-{trial}"
        trial_dir.mkdir(exist_ok=True)
        log_prefix = str(trial_dir / "pgbench")

        if args.driver == "python":
            driver_py = str(Path(__file__).parent / "driver_py.py")
            cmd = [
                "python3", driver_py,
                "--host", args.pgbench_host,
                "--port", str(args.pgbench_port),
                "--user", args.pgbench_user,
                "--db", args.pgbench_db,
                "--clients", str(args.clients),
                "--duration", str(args.duration),
                "--log-prefix", log_prefix,
            ]
        else:
            cmd = build_pgbench_cmd(
                host=args.pgbench_host, port=args.pgbench_port,
                db=args.pgbench_db, user=args.pgbench_user,
                duration=args.duration, clients=args.clients, jobs=args.jobs,
                script=args.script, log_prefix=log_prefix,
            )

        if args.pre_trial_cmd:
            subprocess.run(
                args.pre_trial_cmd, shell=True, check=False,
                env={**__import__("os").environ, "TRIAL_DIR": str(trial_dir), "PHASE": "pre"},
            )

        start_epoch_s = int(time.time())
        start_epoch_us = start_epoch_s * 1_000_000
        pgbench_stdout = open(trial_dir / "pgbench_stdout.txt", "w")
        pgbench_stderr = open(trial_dir / "pgbench_stderr.txt", "w")
        proc = subprocess.Popen(cmd, stdout=pgbench_stdout, stderr=pgbench_stderr)

        probe_rows: List[Dict[str, int]] = []
        stop = {"flag": False}

        def poll_admin() -> None:
            t0 = time.time()
            while not stop["flag"]:
                t_ms = int((time.time() - t0) * 1000)
                try:
                    servers_tsv = query_admin(
                        host=args.admin_host, port=args.admin_port,
                        user=args.admin_user, password=args.admin_password,
                        sql="SELECT hostgroup_id, hostname, port, status, weight, "
                            "compression, max_connections, max_replication_lag, "
                            "use_ssl, max_latency_ms, comment FROM pgsql_servers",
                    )
                    servers = parse_show_pgsql_servers_tsv(servers_tsv)
                    state = summarize_backend_state(servers, writer_hg=args.writer_hg)
                except Exception:
                    state = {"writer_state_code": -1, "reader_state_code": -1}
                try:
                    pool_tsv = query_admin(
                        host=args.admin_host, port=args.admin_port,
                        user=args.admin_user, password=args.admin_password,
                        sql="SELECT hostgroup, srv_host, srv_port, status, "
                            "ConnUsed, ConnFree, ConnOK, ConnERR "
                            "FROM stats_pgsql_connection_pool",
                    )
                    pool = parse_connection_pool_tsv(pool_tsv)
                    writer_conn_used = summarize_writer_conn_used(
                        pool, writer_hg=args.writer_hg,
                    )
                except Exception:
                    writer_conn_used = -1
                probe_rows.append({
                    "t_ms": t_ms,
                    **state,
                    "writer_conn_used": writer_conn_used,
                })
                time.sleep(0.1)

        poller = threading.Thread(target=poll_admin, daemon=True)
        poller.start()

        if args.inject_cmd:
            time.sleep(args.inject_at)
            subprocess.run(args.inject_cmd, shell=True, check=False)

        proc.wait()
        stop["flag"] = True
        poller.join(timeout=2)
        pgbench_stdout.close()
        pgbench_stderr.close()

        if args.proxysql_log and args.proxysql_log.exists():
            import shutil
            shutil.copy(args.proxysql_log, trial_dir / "proxysql.log")

        if args.post_trial_cmd:
            subprocess.run(
                args.post_trial_cmd, shell=True, check=False,
                env={**__import__("os").environ, "TRIAL_DIR": str(trial_dir), "PHASE": "post"},
            )

        # pgbench with -j N writes one log file per worker thread:
        # pgbench.<PID>, pgbench.<PID>.1, ..., pgbench.<PID>.N-1. Aggregate all.
        import re
        log_files = sorted(
            f for f in trial_dir.glob("pgbench.*")
            if re.fullmatch(r"pgbench\.\d+(\.\d+)?", f.name)
        )
        if not log_files:
            raise RuntimeError("pgbench produced no log; check pgbench_stderr.txt")
        buckets = bucket_logs(log_files, start_epoch_us=start_epoch_us, bucket_ms=100)

        # Merge pgbench error buckets into probe rows by aligning on t_ms.
        merged: List[Dict[str, int]] = []
        for i, b in enumerate(buckets):
            t_ms = i * 100
            probe = next(
                (p for p in probe_rows if abs(p["t_ms"] - t_ms) < 50),
                {"writer_state_code": -1, "reader_state_code": -1, "writer_conn_used": -1},
            )
            merged.append({
                "t_ms": t_ms,
                "ok": b["ok"],
                "errors": b["err"],
                "tps": b["ok"] * 10,
                "backend_state_code": probe["writer_state_code"],
                "reader_state_code": probe["reader_state_code"],
                "writer_conn_used": probe.get("writer_conn_used", -1),
            })

        write_probe_csv(trial_dir / "run.csv", merged)
        summary = compute_summary(
            buckets, bucket_ms=100, inject_ms=args.inject_at * 1000,
            metric_label=args.metric_label,
        )
        write_summary_json(trial_dir / "run.json", summary)
        write_chart_png(trial_dir / "run.png", merged, inject_ms=args.inject_at * 1000)
        trial_summaries.append(summary)

    median = median_summary(trial_summaries)
    write_summary_json(args.out / "summary.json", median)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
