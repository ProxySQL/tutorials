# ProxySQL Tutorial 1 - Demonstrate a benchmark using ProxySQL

## Tutorial Outcomes
1. Launch a benchmark with a PostgreSQL instance [Tutorial 2](../tutorial2)).
2. Demonstrate a failing test with connection exhaustion using PostgreSQL.
3. Launch a benchmark with ProxySQL instance.
4. Demonstrate connection pooling with ProxySQL supporting the failing test. 
4. Demonstrate dynamic connection pooling management with ProxySQL.

## Pre-requisites
- [Docker](https://docs.docker.com/desktop/)
- [Docker Compose](https://docs.docker.com/compose/)

## Launch the Container

This tutorial will launch a single PostgreSQL server, and a second container 
running [sysbench](https://github.com/akopytov/sysbench), an open-source, multi-threaded, and modular benchmarking tool used to evaluate system performance, and running [proxysql](https://proxysql.com), an open-source, transparent database proxy.

It will then run a number of tests including:

- Run a successful PostgreSQL database benchmark using 4 threads
- Run a failing PostgreSQL database benchmark using 20 threads (too many connections)
- Run a successful benchmark via ProxySQL using 20 threads

### For Mac OS and Linux

```
$ ./run.sh
$ ./run-with-proxy.sh
```

### For Windows

Using Powershell:
```
run.ps1
```

NOTE: You may need to run `Set-ExecutionPolicy RemoteSigned` once to allow PowerShell scripts. Alternatively, you run it with `powershell -ExecutionPolicy Bypass -File run.ps1`.

## Simulate a 'too many connections' benchmark

The PostgreSQL instance is configured with a maximum of 12 connections. We can simulate an application that runs with a larger number of connections with.

```
$ docker exec -e THREADS=20 sysbench /usr/local/bin/benchmark.sh run
```

This will fail with the following command:
```
Running benchmark: oltp_read_write
Threads: 15, Time: 10s, Tables: 10, Rows/table: 10000
...
Initializing worker threads...

FATAL: Connection to database failed: connection to server at "primary" (172.20.0.2), port 5432 failed: FATAL:  sorry, too many clients already
```

## Using ProxySQL for Connection Pooling

```
$ ./run-with-proxy.sh
```

## Monitoring Database Connections

The following script will monitor the current connections in the database. You can run this in a separate window and run benchmarks to see the impact.

```
$ docker exec sysbench /usr/local/bin/monitor-db-connections.sh
```

By default you should just see 1 connection (the monitoring)
```
Time                 | Total Conn | Active | Idle | Idle in Txn | Active Queries
------------------------------------------------------------------------------------
2026-02-19 14:58:11 |          1 |      1 |    0 |           0 |              0
2026-02-19 14:58:13 |          1 |      1 |    0 |           0 |              0
```

If you run in a separate terminal the following 3 tests you will see the impact on connections and the benefits of ProxySQL.
```
$ docker exec -e THREADS=4 sysbench /usr/local/bin/benchmark.sh run
$ docker exec -e THREADS=10 sysbench /usr/local/bin/benchmark.sh run
$ THREADS=20 ./run-with-proxy.sql
```

When running with 4 threads the connections will look like:
```
Time                 | Total Conn | Active | Idle | Idle in Txn | Active Queries
------------------------------------------------------------------------------------
2026-02-19 14:58:25 |          5 |      4 |    0 |           1 |              3
2026-02-19 14:58:27 |          5 |      1 |    0 |           4 |              0
2026-02-19 14:58:29 |          5 |      2 |    0 |           3 |              1
```

When running with 10 threads the connections will look like:
```
Time                 | Total Conn | Active | Idle | Idle in Txn | Active Queries
------------------------------------------------------------------------------------
2026-02-19 14:58:46 |         11 |      5 |    0 |           6 |              4
2026-02-19 14:58:48 |         11 |      3 |    1 |           7 |              2
2026-02-19 14:58:50 |         11 |      5 |    0 |           6 |              4
2026-02-19 14:58:52 |         11 |      2 |    0 |           9 |              1
2026-02-19 14:58:54 |         11 |      2 |    1 |           8 |              1
```

When running with 20 threads using ProxySQL the connections will look like:
```
Time                 | Total Conn | Active | Idle | Idle in Txn | Active Queries
------------------------------------------------------------------------------------
2026-02-19 14:59:00 |          6 |      1 |    0 |           5 |              0
2026-02-19 14:59:02 |          6 |      2 |    0 |           4 |              1
2026-02-19 14:59:04 |          6 |      3 |    0 |           3 |              2
2026-02-19 14:59:06 |          6 |      2 |    1 |           3 |              1
2026-02-19 14:59:08 |          6 |      1 |    0 |           5 |              0
2026-02-19 14:59:10 |          6 |      1 |    5 |           0 |              0
```

### ProxySQL Analysis

When defining a `pgsql_servers` we define the primary hostgroup in ProxySQL configuration to point to the primary PostgreSQL database and to create a connection pool with a `max_connections=5`.

```

$ docker exec -it sysbench psql postgres://radmin:radmin@localhost:6132

radmin=# SELECT * FROM pgsql_servers;
 hostgroup_id | hostname | port | status | weight | compression | max_connections | max_replication_lag | use_ssl | max_latency_
ms | comment
--------------+----------+------+--------+--------+-------------+-----------------+---------------------+---------+-------------
---+---------
 10           | primary  | 5432 | ONLINE | 1      | 0           | 5               | 0                   | 0       | 0
   | primary
```

We can dynamically alter this with:

```
UPDATE pgsql_servers SET max_connections=8 WHERE hostgroup_id=10;
LOAD PGSQL SERVERS TO RUNTIME;
```

We can execute the above dynamic change mid-benchmark and this will be immediately reflected in an increase of connections between ProxySQL and PostgreSQL.

```
Time                 | Total Conn | Active | Idle | Idle in Txn | Active Queries
------------------------------------------------------------------------------------
2026-02-19 15:33:15 |          6 |      1 |    5 |           0 |              0
2026-02-19 15:33:17 |          6 |      1 |    0 |           5 |              0
2026-02-19 15:33:19 |          6 |      2 |    1 |           3 |              1
2026-02-19 15:33:22 |          9 |      2 |    0 |           7 |              1
2026-02-19 15:33:24 |          9 |      3 |    0 |           6 |              2
2026-02-19 15:33:26 |          9 |      2 |    0 |           7 |              1
```


## Teardown

The following will delete all containers resources.

```
docker compose down -v
```
