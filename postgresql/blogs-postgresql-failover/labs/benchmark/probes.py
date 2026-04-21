"""Polls the ProxySQL admin interface for pgsql stats at 100 ms cadence."""

from __future__ import annotations

import subprocess
from typing import Dict, List, Tuple

# Subset of `stats_pgsql_connection_pool` columns the harness records.
# Order matches the SELECT in `query_connection_pool`.
CONN_POOL_COLUMNS = (
    "hostgroup", "host", "port", "status",
    "conn_used", "conn_free", "conn_ok", "conn_err",
)

# pgsql_servers columns (SHOW PGSQL SERVERS) — positional, headerless.
PGSQL_SERVERS_COLUMNS = [
    "hostgroup_id", "hostname", "port", "status",
    "weight", "compression", "max_connections", "max_replication_lag",
    "use_ssl", "max_latency_ms", "comment",
]


def parse_connection_pool_tsv(tsv: str) -> list[dict]:
    """Parse `stats_pgsql_connection_pool` TSV into per-backend dicts.

    Expected TSV columns (in order): hostgroup, srv_host, srv_port, status,
    ConnUsed, ConnFree, ConnOK, ConnERR, MaxConnUsed, Queries, Bytes_*, Latency.
    Only the first 8 are used; the rest are ignored.
    """
    rows: list[dict] = []
    for line in tsv.strip().splitlines():
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 8:
            continue
        rows.append({
            "hostgroup": int(parts[0]),
            "host": parts[1],
            "port": int(parts[2]),
            "status": parts[3],
            "conn_used": int(parts[4]),
            "conn_free": int(parts[5]),
            "conn_ok": int(parts[6]),
            "conn_err": int(parts[7]),
        })
    return rows


def parse_show_pgsql_servers_tsv(tsv: str) -> Dict[Tuple[str, str, str], str]:
    """Return {(host, port, hostgroup_id): status}."""
    out: Dict[Tuple[str, str, str], str] = {}
    for line in tsv.splitlines():
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        hg, host, port, status = parts[0], parts[1], parts[2], parts[3]
        out[(host, port, hg)] = status
    return out


def query_admin(
    *, host: str, port: int, user: str, password: str, sql: str,
) -> str:
    """Shell out to the ProxySQL admin interface.

    ProxySQL's admin listens on two ports with the same SQL surface: 6132 for
    the MySQL wire protocol, 6134 for the PostgreSQL wire protocol. We pick
    the client that matches the port so PostgreSQL-only hosts (where `mysql`
    may not even be installed) can still drive admin via `psql`.
    """
    import os
    if port == 6134:
        cmd = [
            "psql", "-h", host, "-p", str(port), "-U", user,
            "-A", "-t", "-F", "\t",  # unaligned, tuples-only, tab separator
            "-c", sql,
        ]
        env = {**os.environ, "PGPASSWORD": password}
    else:
        cmd = [
            "mysql", "-h", host, "-P", str(port),
            "-u", user, f"-p{password}",
            "-N", "-B",  # no headers, tab-separated
            "-e", sql,
        ]
        env = None
    result = subprocess.run(cmd, capture_output=True, text=True, env=env, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"admin query failed: {result.stderr.strip()}")
    return result.stdout


_STATUS_CODES = {
    "ONLINE": 0,
    "SHUNNED": 1,
    "OFFLINE_SOFT": 2,
    "OFFLINE_HARD": 3,
}


def status_to_code(status: str) -> int:
    return _STATUS_CODES.get(status, -1)


def summarize_writer_conn_used(
    rows: list[dict], *, writer_hg: int,
) -> int:
    """Sum conn_used across every backend currently in the writer hostgroup.

    During a planned switchover this number drops monotonically to zero on the
    old primary as in-flight transactions complete; the new primary then takes
    over and the value resumes at the steady-state pool size.
    """
    return sum(r["conn_used"] for r in rows if r["hostgroup"] == int(writer_hg))


def summarize_backend_state(
    servers: Dict[Tuple[str, str, str], str],
    *,
    writer_hg: str,
) -> Dict[str, int]:
    writer_state = 0
    reader_state = 0
    for (_host, _port, hg), status in servers.items():
        code = status_to_code(status)
        if hg == writer_hg:
            writer_state = max(writer_state, code)
        else:
            reader_state = max(reader_state, code)
    return {"writer_state_code": writer_state, "reader_state_code": reader_state}
