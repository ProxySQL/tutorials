# Common sandbox scripts

Shared scripts used by every lab in this series.

## `pg_sandbox.sh`

Creates / destroys a local PostgreSQL instance using `initdb` + `pg_ctl`. No Docker, no root.

- Data lives under a user-supplied data directory (typically `./data/primary`, `./data/replica-1`, etc.).
- Binds to `127.0.0.1` on a user-supplied port.
- Creates roles: `postgres` (trust local), `replicator` (replication), `app` (superuser, for pgbench init).
- Creates database: `pgbench`, owned by `app`.

## `proxysql_sandbox.sh`

Creates / destroys a local ProxySQL instance pointed at this tree's `./src/proxysql` binary.

- Writes a standalone config under a user-supplied data directory.
- Admin on `127.0.0.1:6132`, pgsql listener on `127.0.0.1:6133`.
