from harness import compute_summary, median_summary


def test_compute_summary_computes_writes_resume_and_error_count() -> None:
    # 10 buckets of 100 ms = 1 s total.
    # Injection at bucket 3 (300 ms). Errors in 4,5. First success after bucket 3 is bucket 6.
    buckets = [
        {"ok": 5, "err": 0},
        {"ok": 5, "err": 0},
        {"ok": 5, "err": 0},
        {"ok": 3, "err": 0},   # inject happens during this bucket
        {"ok": 0, "err": 5},
        {"ok": 0, "err": 4},
        {"ok": 2, "err": 0},   # recovery
        {"ok": 5, "err": 0},
        {"ok": 5, "err": 0},
        {"ok": 5, "err": 0},
    ]
    summary = compute_summary(buckets, bucket_ms=100, inject_ms=300)

    assert summary["writes_resume_ms"] == 600  # bucket 6 * 100 ms
    assert summary["error_count_post_inject"] == 9
    assert summary["total_ok_pre_inject"] == 15


def test_compute_summary_silent_gap_no_errors() -> None:
    # Real-world unplanned-failover shape: inject takes time to actually kill
    # writes (buckets 4,5 still succeed) and pgbench retries silently (no err
    # surfaces, just an ok=0 gap in buckets 6,7,8). Recovery is bucket 9.
    buckets = [
        {"ok": 5, "err": 0},
        {"ok": 5, "err": 0},
        {"ok": 5, "err": 0},
        {"ok": 5, "err": 0},   # inject_ms=300
        {"ok": 5, "err": 0},   # inject hasn't propagated yet
        {"ok": 5, "err": 0},
        {"ok": 0, "err": 0},   # disruption — silent gap, no errors logged
        {"ok": 0, "err": 0},
        {"ok": 0, "err": 0},
        {"ok": 4, "err": 0},   # recovery
        {"ok": 5, "err": 0},
    ]
    summary = compute_summary(buckets, bucket_ms=100, inject_ms=300)

    assert summary["writes_resume_ms"] == 900  # bucket 9 * 100 ms
    assert summary["error_count_post_inject"] == 0
    assert summary["total_ok_pre_inject"] == 15


def test_compute_summary_no_disruption_returns_minus_one() -> None:
    # If writes never falter post-inject, we cannot observe a recovery. Return -1
    # so the caller knows the harness didn't measure anything (rather than
    # falsely returning inject_ms+bucket_ms as before).
    buckets = [{"ok": 5, "err": 0}] * 10
    summary = compute_summary(buckets, bucket_ms=100, inject_ms=300)
    assert summary["writes_resume_ms"] == -1


def test_median_summary_takes_median_of_numeric_fields() -> None:
    trials = [
        {"writes_resume_ms": 1000, "error_count_post_inject": 10},
        {"writes_resume_ms": 1200, "error_count_post_inject": 12},
        {"writes_resume_ms": 1100, "error_count_post_inject": 11},
    ]
    m = median_summary(trials)
    assert m["writes_resume_ms"]["median"] == 1100
    assert m["writes_resume_ms"]["min"] == 1000
    assert m["writes_resume_ms"]["max"] == 1200
    assert m["error_count_post_inject"]["median"] == 11


def test_compute_summary_renames_resume_key_via_metric_label() -> None:
    from harness import compute_summary

    buckets = [
        {"ok": 5, "err": 0},
        {"ok": 5, "err": 0},
        {"ok": 5, "err": 0},
        {"ok": 5, "err": 0},   # inject_ms=300
        {"ok": 0, "err": 0},
        {"ok": 4, "err": 0},
    ]
    summary = compute_summary(
        buckets, bucket_ms=100, inject_ms=300, metric_label="reads",
    )

    assert "reads_resume_ms" in summary
    assert "writes_resume_ms" not in summary
    assert summary["reads_resume_ms"] == 500
    assert summary["error_count_post_inject"] == 0
    assert summary["total_ok_pre_inject"] == 15


def test_pgbench_port_accepts_comma_separated_string() -> None:
    from harness import build_argparser

    args = build_argparser().parse_args([
        "--pgbench-host", "127.0.0.1,127.0.0.1,127.0.0.1",
        "--pgbench-port", "5433,5434,5435",
        "--pgbench-db", "pgbench",
        "--pgbench-user", "app",
        "--admin-host", "127.0.0.1",
        "--admin-port", "9999",
        "--admin-user", "admin",
        "--admin-password", "admin",
        "--script", "/tmp/x.sql",
        "--out", "/tmp/x",
    ])
    assert args.pgbench_port == "5433,5434,5435"
    assert args.pgbench_host == "127.0.0.1,127.0.0.1,127.0.0.1"
