# Benchmark harness

Single harness used by every post in the series. Drives `pgbench` against the ProxySQL listener, polls ProxySQL admin stats at 100 ms, emits CSV + JSON + PNG.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## CLI

```bash
python3 harness.py \
  --pgbench-host 127.0.0.1 --pgbench-port 6133 \
  --pgbench-db pgbench --pgbench-user app \
  --admin-host 127.0.0.1 --admin-port 6132 \
  --admin-user admin --admin-password admin \
  --script workload.sql \
  --duration 90 --warmup 30 --inject-at 30 \
  --trials 3 \
  --out out/
```

Emits under `out/`:
- `run-N.csv` — per-100ms probe rows
- `run-N.json` — summary (writes-resume ms, reads-resume ms, error count, etc.)
- `run-N.png` — errors/s + backend state timeline
- `summary.json` — median across trials + min/max

## Testing

```bash
pytest -v
```
