from pathlib import Path

from pgbench_driver import bucket_log, parse_log_line


def test_parse_success_line_returns_timestamp_and_ok() -> None:
    line = "0 12 345 0 1700000000 12345678"
    rec = parse_log_line(line)
    assert rec is not None
    assert rec.ok is True
    assert rec.epoch_us == 1700000000 * 1_000_000 + 12345678


def test_parse_error_line_returns_timestamp_and_not_ok() -> None:
    # pgbench with --failures-detailed writes error lines without durations
    line = "0 13 - 0 1700000001 999 serialization"
    rec = parse_log_line(line)
    assert rec is not None
    assert rec.ok is False


def test_parse_comment_returns_none() -> None:
    assert parse_log_line("# this is a comment") is None


def test_bucket_log_groups_into_100ms_buckets(tmp_path: Path) -> None:
    lines = [
        # t=0 success, t=50ms success, t=100ms error, t=150ms success, t=200ms error
        "0 1 10 0 1700000000 0",
        "0 2 10 0 1700000000 50000",
        "0 3 - 0 1700000000 100000 err",
        "0 4 10 0 1700000000 150000",
        "0 5 - 0 1700000000 200000 err",
    ]
    log = tmp_path / "pgbench.log"
    log.write_text("\n".join(lines) + "\n")

    buckets = bucket_log(log, start_epoch_us=1700000000 * 1_000_000, bucket_ms=100)

    # bucket 0 (0-99ms): 2 ok, 0 err
    # bucket 1 (100-199ms): 1 ok, 1 err
    # bucket 2 (200-299ms): 0 ok, 1 err
    assert buckets[0]["ok"] == 2 and buckets[0]["err"] == 0
    assert buckets[1]["ok"] == 1 and buckets[1]["err"] == 1
    assert buckets[2]["ok"] == 0 and buckets[2]["err"] == 1


def test_build_pgbench_cmd_includes_logging_and_script() -> None:
    from pgbench_driver import build_pgbench_cmd

    cmd = build_pgbench_cmd(
        host="127.0.0.1", port=6133, db="pgbench", user="app",
        duration=90, clients=8, jobs=4,
        script="workload.sql", log_prefix="/tmp/pfx",
    )

    assert cmd[0] == "pgbench"
    assert "-h" in cmd and "127.0.0.1" in cmd
    assert "-p" in cmd and "6133" in cmd
    assert "-U" in cmd and "app" in cmd
    assert "-T" in cmd and "90" in cmd
    assert "-c" in cmd and "8" in cmd
    assert "-j" in cmd and "4" in cmd
    assert "-l" in cmd
    assert "--log-prefix=/tmp/pfx" in cmd
    assert "-f" in cmd and "workload.sql" in cmd
    assert "--failures-detailed" in cmd
