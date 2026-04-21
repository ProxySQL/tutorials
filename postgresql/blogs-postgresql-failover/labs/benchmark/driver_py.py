"""Retry-capable workload driver — pgbench-log-compatible.

A minimal stand-in for `pgbench` when the lab needs a client that reconnects
on connection loss instead of aborting. Each worker owns one connection to
ProxySQL, runs the pgbench_accounts UPDATE loop in an explicit transaction,
and on any psycopg2 error closes the connection, reconnects (with backoff),
and resumes — exactly the behavior a production app-pool gives you.

Log format per worker matches pgbench's `-l` output so harness.bucket_logs
keeps working:

    <client_id> <txn_num> <time_us_or_dash> <file_no> <epoch_s> <us_in_second>

On error, field 3 is "-" and the line is counted as err; on success it's the
transaction's elapsed microseconds and counted as ok.
"""

from __future__ import annotations

import argparse
import os
import random
import sys
import threading
import time
from pathlib import Path

import psycopg2


def _connect(host: str, port: int, user: str, db: str, password: str | None):
    return psycopg2.connect(
        host=host, port=port, user=user, dbname=db, password=password,
        connect_timeout=3,
    )


def _worker(
    *,
    client_id: int,
    log_path: Path,
    host: str,
    port: int,
    user: str,
    db: str,
    password: str | None,
    deadline: float,
    counters: dict,
) -> None:
    rng = random.Random(client_id * 1_000_003 + os.getpid())
    txn_num = 0
    conn = None
    with log_path.open("w", buffering=1 << 14) as log:
        while time.time() < deadline:
            if conn is None:
                try:
                    conn = _connect(host, port, user, db, password)
                    conn.autocommit = False
                except Exception:
                    counters["connect_errors"] += 1
                    # log a connect failure as an err line at the current time
                    now = time.time()
                    epoch_s = int(now)
                    us = int((now - epoch_s) * 1_000_000)
                    txn_num += 1
                    log.write(f"{client_id} {txn_num} - 0 {epoch_s} {us}\n")
                    time.sleep(0.05)
                    continue
            aid = rng.randint(1, 100_000)
            balance = rng.randint(-5000, 5000)
            t0 = time.time()
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "UPDATE pgbench_accounts SET abalance = abalance + %s "
                        "WHERE aid = %s",
                        (balance, aid),
                    )
                conn.commit()
                t1 = time.time()
                txn_num += 1
                counters["ok"] += 1
                epoch_s = int(t1)
                us = int((t1 - epoch_s) * 1_000_000)
                elapsed_us = int((t1 - t0) * 1_000_000)
                log.write(f"{client_id} {txn_num} {elapsed_us} 0 {epoch_s} {us}\n")
            except Exception:
                t1 = time.time()
                txn_num += 1
                counters["err"] += 1
                epoch_s = int(t1)
                us = int((t1 - epoch_s) * 1_000_000)
                log.write(f"{client_id} {txn_num} - 0 {epoch_s} {us}\n")
                try:
                    conn.close()
                except Exception:
                    pass
                conn = None
    if conn is not None:
        try:
            conn.close()
        except Exception:
            pass


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--host", required=True)
    p.add_argument("--port", type=int, required=True)
    p.add_argument("--user", required=True)
    p.add_argument("--db", required=True)
    p.add_argument("--clients", type=int, default=8)
    p.add_argument("--duration", type=int, default=90)
    p.add_argument("--log-prefix", required=True,
                   help="Prefix for per-worker logs (matches pgbench -l --log-prefix).")
    args = p.parse_args()

    password = os.environ.get("PGPASSWORD")
    deadline = time.time() + args.duration
    counters = {"ok": 0, "err": 0, "connect_errors": 0}
    pid = os.getpid()
    threads = []
    for i in range(args.clients):
        suffix = "" if i == 0 else f".{i}"
        log_path = Path(f"{args.log_prefix}.{pid}{suffix}")
        t = threading.Thread(
            target=_worker,
            kwargs=dict(
                client_id=i,
                log_path=log_path,
                host=args.host,
                port=args.port,
                user=args.user,
                db=args.db,
                password=password,
                deadline=deadline,
                counters=counters,
            ),
            daemon=True,
        )
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    print(f"driver_py: clients={args.clients} duration={args.duration}s "
          f"ok={counters['ok']} err={counters['err']} "
          f"connect_errors={counters['connect_errors']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
