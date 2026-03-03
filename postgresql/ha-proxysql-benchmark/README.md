# ProxySQL Tutorial - Demonstrate a benchmark using ProxySQL in a HA Environment

## Tutorial Outcomes
1. Launch a HA Application and Database environment.
2. Run different scenerios using ProxySQL.

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

To setup the container environment and verify the step:
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

## Scenerios

- [Simple Application Benchmark](SIMPLE-BENCHMARK.md)
- [Simple ProxySQL Benchmark](SIMPLE-BENCHMARK.md)

## Teardown

The following will delete all containers resources.

```
docker compose down -v
```
