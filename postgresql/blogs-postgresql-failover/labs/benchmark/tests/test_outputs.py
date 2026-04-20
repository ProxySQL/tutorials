import csv
import json
from pathlib import Path

from outputs import write_probe_csv, write_summary_json


def test_write_probe_csv_writes_header_and_rows(tmp_path: Path) -> None:
    rows = [
        {"t_ms": 0, "errors": 0, "tps": 120, "backend_state": "ONLINE"},
        {"t_ms": 100, "errors": 2, "tps": 115, "backend_state": "ONLINE"},
    ]
    out = tmp_path / "run-1.csv"
    write_probe_csv(out, rows)

    with out.open() as f:
        reader = csv.DictReader(f)
        actual = list(reader)

    assert [r["t_ms"] for r in actual] == ["0", "100"]
    assert actual[1]["errors"] == "2"
    assert actual[0]["backend_state"] == "ONLINE"


def test_write_summary_json_is_compact_one_object(tmp_path: Path) -> None:
    summary = {
        "writes_resume_ms": 1850,
        "reads_resume_ms": 1750,
        "error_count_60s": 47,
        "trial_count": 3,
    }
    out = tmp_path / "run-1.json"
    write_summary_json(out, summary)

    text = out.read_text()
    assert "\n" not in text.rstrip("\n"), "summary JSON must be single-line"
    assert json.loads(text) == summary


def test_write_chart_png_produces_nonempty_file(tmp_path: Path) -> None:
    from outputs import write_chart_png

    rows = [
        {"t_ms": i * 100, "errors": i % 4, "tps": 100 - (i % 10),
         "backend_state_code": 0 if i < 15 else 1}
        for i in range(40)
    ]
    out = tmp_path / "run-1.png"
    write_chart_png(out, rows, inject_ms=1500)

    assert out.exists()
    assert out.stat().st_size > 1000


def test_write_chart_png_includes_conn_panel_when_data_present(tmp_path: Path) -> None:
    from outputs import write_chart_png

    rows = [
        {"t_ms": i * 100, "errors": 0, "tps": 5000,
         "backend_state_code": 0, "writer_conn_used": max(0, 8 - i // 5)}
        for i in range(40)
    ]
    out = tmp_path / "run.png"
    write_chart_png(out, rows, inject_ms=1500)

    assert out.exists()
    assert out.stat().st_size > 5000
