# ProxySQL HA Tutorial - Demonstrate a benchmark using ProxySQL in a HA Environment

## Tutorial Outcomes
1. Launch a HA Application and Database environment.
2.

## Pre-requisites
- [Docker](https://docs.docker.com/desktop/)
- [Docker Compose](https://docs.docker.com/compose/)

## Launch the Containers

This tutorial will launch a three PostgreSQL servers (one primary with two replicas),  three application servers 
running [sysbench](https://github.com/akopytov/sysbench), an open-source, multi-threaded, and modular benchmarking tool used to evaluate system performance, and a Proxy running [proxysql](https://proxysql.com), an open-source, transparent database proxy.

### Container Topology
For this setup we will use the `172.113.0/24` network with:
- Databases
  - Primary    `.100`
  - Replica 1  `.101`
  - Replica 2  `.102`
- Application
  - Server 1   `.6`
  - Server 2   `.16`
  - Server 3   `.26`
- Proxy
  - ProxySQL   `.200`


### For Mac OS and Linux

```
$ ./run.sh
```

### For Windows

Using Powershell:
```
run.ps1
```

NOTE: You may need to run `Set-ExecutionPolicy RemoteSigned` once to allow PowerShell scripts. Alternatively, you run it with `powershell -ExecutionPolicy Bypass -File run.ps1`.

The prior commands will launch the setup, prepare the database for the benchmark and run a simple benchmark to verify.

## Simulating Application Load (No Proxy)

To emulate some random load from the three application servers to the primary DB.
```
$ ./run-benchmark.sh
```

This command will launch three benchmarks running for 10 minutes, with a random number of threads (5-15) and a random rate (50 - 250 in 50 increments). This will give feedback such as:

```
App Server 1: PID=7203 RATE=200 THREADS=10
App Server 2: PID=7204 RATE=50 THREADS=8
App Server 3: PID=7205 RATE=200 THREADS=10
```

### Monitoring the source of Database Connections

By default, you will see that the `primary` receives all the traffic from the applications `.6`, `.16`, `.26`.
```
$ scripts/summary.sh hosts-per-db
##### For DB 'primary' #####

  client_addr  | count
---------------+-------
 172.113.0.26  |    10
 172.113.0.6   |    10
 172.113.0.16  |     8
 172.113.0.101 |     1
 172.113.0.102 |     1
 172.113.0.222 |     1
(6 rows)

##### For DB 'replica1' #####

  client_addr  | count
---------------+-------
 172.113.0.222 |     1

##### For DB 'replica2' #####

  client_addr  | count
---------------+-------
 172.113.0.222 |     1
```

- [Read Write Splitting](READ-WRITE-SPLIT.md)

## Teardown

The following will delete all containers resources.

```
docker compose down -v
```
