"""CSV / JSON / PNG emission for the benchmark harness."""

from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Mapping, Sequence


def write_probe_csv(path: Path, rows: Sequence[Mapping[str, object]]) -> None:
    """Write probe rows to CSV. Header taken from the first row's keys."""
    if not rows:
        path.write_text("")
        return
    fieldnames = list(rows[0].keys())
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_summary_json(path: Path, summary: Mapping[str, object]) -> None:
    """Write a compact single-line JSON summary."""
    path.write_text(json.dumps(summary, separators=(",", ":")) + "\n")


def write_chart_png(
    path: Path,
    rows: Sequence[Mapping[str, object]],
    inject_ms: int,
) -> None:
    """Render throughput, errors, state, and (optionally) writer conn_used.

    A fourth panel for `writer_conn_used` is drawn only when the row data
    contains that key — keeps Post 2 charts byte-comparable while letting
    Post 3 visualize connection draining during a planned switchover.
    """
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    t = [float(r["t_ms"]) / 1000.0 for r in rows]
    tps = [int(r["tps"]) for r in rows]
    errors = [int(r["errors"]) for r in rows]
    state = [int(r["backend_state_code"]) for r in rows]
    has_conn_panel = rows and "writer_conn_used" in rows[0]

    panel_count = 4 if has_conn_panel else 3
    height = 7 if has_conn_panel else 6
    height_ratios = [4, 1, 1, 2] if has_conn_panel else [4, 1, 1]
    fig, axes = plt.subplots(
        panel_count, 1, figsize=(10, height), sharex=True,
        gridspec_kw={"height_ratios": height_ratios},
    )
    ax_tps, ax_err, ax_state = axes[0], axes[1], axes[2]

    ax_tps.plot(t, tps, linewidth=1)
    ax_tps.set_ylabel("successful tx / s")
    ax_tps.axvline(inject_ms / 1000.0, linestyle="--", linewidth=1)
    ax_tps.set_title("pgbench throughput (1P + 2R via ProxySQL, inject at dashed line)")

    ax_err.plot(t, errors, linewidth=1)
    ax_err.set_ylabel("errors / 100 ms")
    ax_err.axvline(inject_ms / 1000.0, linestyle="--", linewidth=1)

    ax_state.step(t, state, where="post", linewidth=1)
    ax_state.set_ylabel("writer hg state")
    ax_state.set_yticks([0, 1, 2, 3])
    ax_state.set_yticklabels(["ONLINE", "SHUNNED", "OFFLINE_SOFT", "OFFLINE_HARD"])

    if has_conn_panel:
        conn = [int(r["writer_conn_used"]) for r in rows]
        ax_conn = axes[3]
        ax_conn.plot(t, conn, linewidth=1)
        ax_conn.set_ylabel("writer hg ConnUsed")
        ax_conn.axvline(inject_ms / 1000.0, linestyle="--", linewidth=1)
        ax_conn.set_xlabel("seconds")
    else:
        ax_state.set_xlabel("seconds")

    fig.tight_layout()
    fig.savefig(path, dpi=100)
    plt.close(fig)
