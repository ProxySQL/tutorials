# Detailed ProxySQL Benchmark for PostgreSQL

This setup compares ProxySQL, a single-core ProxySQL, PgBouncer, and direct PostgreSQL access.

## Architecture
- **postgresql-bench**: Primary database, tuned for high concurrency (8 CPUs).
- **proxysql-bench**: ProxySQL with 4 worker threads (2 CPUs).
- **proxysql-single-core**: ProxySQL with 1 worker thread (1 CPU).
- **pgbouncer-bench**: PgBouncer in transaction mode (1 CPU).
- **sysbench-loadgen**: Dedicated load generator (4 CPUs).

## Usage

### 1. Generate Certificates (SSL Enforcement)
```bash
./scripts/generate-certs.sh
```

### 2. Launch the Environment
```bash
docker compose up -d
```

### 2. Run Benchmarks

The `run_benchmarks.sh` script requires a `test_type` and takes `HOST` and `PORT` as optional arguments.

Possible `test_type` values:
- `oltp_read_write`
- `oltp_read_only`
- `oltp_point_select`

#### A. ProxySQL (Standard - 4 Threads, 2 CPUs)
```bash
docker exec sysbench-loadgen run_benchmarks.sh oltp_read_write proxysql 6133
```

#### B. ProxySQL (Single Core - 1 Thread, 1 CPU)
```bash
docker exec sysbench-loadgen run_benchmarks.sh oltp_read_only proxysql-single 6133
```

#### C. PgBouncer (1 CPU)
```bash
docker exec sysbench-loadgen run_benchmarks.sh oltp_point_select pgbouncer 6432
```

#### D. PostgreSQL Direct (Baseline)
```bash
docker exec sysbench-loadgen run_benchmarks.sh oltp_read_write postgresql 5432
```


## Monitoring
To monitor real-time connections on the database during tests:
```bash
docker exec sysbench-loadgen monitor-db-connections.sh
```

## Configuration
- ProxySQL (Standard): `cnf/proxysql.cnf`
- ProxySQL (Single): `cnf/proxysql-single.cnf`
- PgBouncer: `cnf/pgbouncer.ini`
