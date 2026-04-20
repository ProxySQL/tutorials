# Post 2 — Unplanned primary failure

Topology:

```
pgbench  →  ProxySQL  →  primary   (port 5433, hg 10)
                     →  replica-1 (port 5434, hg 20 → promoted to hg 10 at t=30s)
                     →  replica-2 (port 5435, hg 20)
```

## What the lab does

1. Bring up 1P + 2R + ProxySQL.
2. Start pgbench (write-heavy, 90 s).
3. At T=30 s: SIGKILL the primary.
4. +1 s after: promote replica-1, rewire ProxySQL (move it into hg 10, delete the dead row).
5. Measure writes-resume, error count, backend state transitions.
6. Repeat 3 times; aggregate median/min/max.

## Run

```bash
./run.sh
```

Outputs land under `out/<timestamp>/trial-{1,2,3}/` and an aggregated `summary.json`.

## Caveats

Single-host lab. No real network, no disk contention. The promote step is triggered by the harness, not an HA tool — measuring the ProxySQL-side + promotion shell latency, not a production HA tool's decision time.
