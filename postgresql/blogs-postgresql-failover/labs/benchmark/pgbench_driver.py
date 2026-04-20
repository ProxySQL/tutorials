"""Wrapper around pgbench: launch, parse per-transaction log, bucket results."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional


@dataclass
class LogRecord:
    epoch_us: int
    ok: bool


def parse_log_line(line: str) -> Optional[LogRecord]:
    line = line.strip()
    if not line or line.startswith("#"):
        return None
    parts = line.split()
    if len(parts) < 6:
        return None
    # Field 2 is transaction time in microseconds on success; "-" on error.
    time_field = parts[2]
    try:
        epoch_s = int(parts[4])
        time_us_in_second = int(parts[5])
    except ValueError:
        return None
    epoch_us = epoch_s * 1_000_000 + time_us_in_second
    ok = time_field != "-"
    return LogRecord(epoch_us=epoch_us, ok=ok)


def bucket_log(
    log_path: Path,
    start_epoch_us: int,
    bucket_ms: int = 100,
) -> List[Dict[str, int]]:
    """Return a list of buckets indexed by 100ms offsets from start_epoch_us.

    Each bucket is {'ok': n_ok, 'err': n_err}.
    """
    bucket_us = bucket_ms * 1_000
    buckets: Dict[int, Dict[str, int]] = {}
    with log_path.open() as f:
        for line in f:
            rec = parse_log_line(line)
            if rec is None:
                continue
            idx = (rec.epoch_us - start_epoch_us) // bucket_us
            if idx < 0:
                continue
            b = buckets.setdefault(int(idx), {"ok": 0, "err": 0})
            if rec.ok:
                b["ok"] += 1
            else:
                b["err"] += 1
    if not buckets:
        return []
    max_idx = max(buckets.keys())
    return [buckets.get(i, {"ok": 0, "err": 0}) for i in range(max_idx + 1)]


import subprocess


def build_pgbench_cmd(
    *,
    host: str,
    port: int,
    db: str,
    user: str,
    duration: int,
    clients: int,
    jobs: int,
    script: str,
    log_prefix: str,
) -> List[str]:
    return [
        "pgbench",
        "-h", host,
        "-p", str(port),
        "-U", user,
        "-c", str(clients),
        "-j", str(jobs),
        "-T", str(duration),
        "-f", script,
        "-l",
        f"--log-prefix={log_prefix}",
        "--failures-detailed",
        db,
    ]


def run_pgbench(cmd: List[str], env: dict | None = None) -> subprocess.CompletedProcess:
    """Run pgbench to completion. Does not raise on non-zero exit;
    caller inspects returncode and stderr."""
    return subprocess.run(cmd, capture_output=True, text=True, env=env, check=False)
