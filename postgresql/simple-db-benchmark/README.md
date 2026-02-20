# Demonstrate a Benchmark of a Single PostgreSQL environment

## Tutorial Outcomes
1. Launch a single PostgreSQL instance
2. Launch a benchmark instance
3. Demonstrate a Read/Write SQL workload

## Pre-requisites
- [Docker](https://docs.docker.com/desktop/)
- [Docker Compose](https://docs.docker.com/compose/)

## Launch the Container

This tutorial will launch a single PostgreSQL server (as shown in [Tutorial 1](../tutorial1), and a second container  running [sysbench](https://github.com/akopytov/sysbench), an open-source, multi-threaded, and modular benchmarking tool used to evaluate system performance.

For simplicity we remove all configuration and customization features. See benchmark-db tutorial for a fully customized version of this tutorial.

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

## Expected Output

```
./run.sh
Building docker container
[+] Building 0.4s (11/11) FINISHED
...
[+] Building 1/1
 ✔ tutorial2-sysbench  Built                                                                                              0.0s
Launching docker container(s)
[+] Running 4/4
 ✔ Network tutorial2_default      Created                                                                                 0.0s
 ✔ Volume tutorial2_primary-data  Created                                                                                 0.0s
 ✔ Container primary              Healthy                                                                                10.7s
 ✔ Container sysbench             Started                                                                                10.8s
Verifying docker processes
NAME       IMAGE                COMMAND                  SERVICE        CREATED          STATUS                    PORTS
primary    postgres:18          "docker-entrypoint.s…"   postgresql18   11 seconds ago   Up 10 seconds (healthy)   0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
sysbench   tutorial2-sysbench   "tail -f /dev/null"      sysbench       11 seconds ago   Up Less than a second
Validating PostgreSQL access
                                                         version
--------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 18.1 (Debian 18.1-1.pgdg13+2) on aarch64-unknown-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
(1 row)

Prepare Benchmark
Preparing test data...
sysbench 1.0.20 (using system LuaJIT 2.1.0-beta3)

Creating table 'sbtest1'...
Inserting 10000 records into 'sbtest1'
Creating a secondary index on 'sbtest1'...
Creating table 'sbtest2'...
Inserting 10000 records into 'sbtest2'
Creating a secondary index on 'sbtest2'...
Creating table 'sbtest3'...
Inserting 10000 records into 'sbtest3'
Creating a secondary index on 'sbtest3'...
Creating table 'sbtest4'...
Inserting 10000 records into 'sbtest4'
Creating a secondary index on 'sbtest4'...
Creating table 'sbtest5'...
Inserting 10000 records into 'sbtest5'
Creating a secondary index on 'sbtest5'...
Creating table 'sbtest6'...
Inserting 10000 records into 'sbtest6'
Creating a secondary index on 'sbtest6'...
Creating table 'sbtest7'...
Inserting 10000 records into 'sbtest7'
Creating a secondary index on 'sbtest7'...
Creating table 'sbtest8'...
Inserting 10000 records into 'sbtest8'
Creating a secondary index on 'sbtest8'...
Creating table 'sbtest9'...
Inserting 10000 records into 'sbtest9'
Creating a secondary index on 'sbtest9'...
Creating table 'sbtest10'...
Inserting 10000 records into 'sbtest10'
Creating a secondary index on 'sbtest10'...
Run Benchmark Test
Running benchmark: oltp_read_write
Threads: 4, Time: 10s, Tables: 10, Rows/table: 10000
sysbench 1.0.20 (using system LuaJIT 2.1.0-beta3)

Running the test with following options:
Number of threads: 4
Report intermediate results every 1 second(s)
Initializing random number generator from current time


Initializing worker threads...

Threads started!

[ 1s ] thds: 4 tps: 3875.24 qps: 77554.76 (r/w/o: 54296.33/15502.96/7755.48) lat (ms,95%): 1.42 err/s: 0.00 reconn/s: 0.00
[ 2s ] thds: 4 tps: 3636.49 qps: 72747.78 (r/w/o: 50927.85/14539.95/7279.98) lat (ms,95%): 1.52 err/s: 1.00 reconn/s: 0.00
[ 3s ] thds: 4 tps: 3843.53 qps: 76872.57 (r/w/o: 53804.40/15376.11/7692.05) lat (ms,95%): 1.47 err/s: 1.00 reconn/s: 0.00
[ 4s ] thds: 4 tps: 3661.36 qps: 73273.30 (r/w/o: 51302.12/14643.45/7327.73) lat (ms,95%): 1.50 err/s: 1.00 reconn/s: 0.00
[ 5s ] thds: 4 tps: 3953.81 qps: 79036.11 (r/w/o: 55315.28/15808.22/7912.61) lat (ms,95%): 1.44 err/s: 0.00 reconn/s: 0.00
[ 6s ] thds: 4 tps: 3700.07 qps: 74012.48 (r/w/o: 51812.04/14797.30/7403.15) lat (ms,95%): 1.67 err/s: 0.00 reconn/s: 0.00
[ 7s ] thds: 4 tps: 4148.27 qps: 83024.43 (r/w/o: 58124.81/16596.08/8303.54) lat (ms,95%): 1.42 err/s: 2.00 reconn/s: 0.00
[ 8s ] thds: 4 tps: 4271.98 qps: 85434.68 (r/w/o: 59800.78/17085.94/8547.97) lat (ms,95%): 1.37 err/s: 1.00 reconn/s: 0.00
[ 9s ] thds: 4 tps: 4177.86 qps: 83604.22 (r/w/o: 58525.05/16715.44/8363.72) lat (ms,95%): 1.32 err/s: 3.00 reconn/s: 0.00
[ 10s ] thds: 4 tps: 4321.39 qps: 86442.81 (r/w/o: 60512.46/17285.57/8644.78) lat (ms,95%): 1.30 err/s: 1.00 reconn/s: 0.00
SQL statistics:
    queries performed:
        read:                            554554
        write:                           158395
        other:                           79251
        total:                           792200
    transactions:                        39601  (3958.90 per sec.)
    queries:                             792200 (79196.06 per sec.)
    ignored errors:                      10     (1.00 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          10.0027s
    total number of events:              39601

Latency (ms):
         min:                                    0.40
         avg:                                    1.01
         max:                                   19.72
         95th percentile:                        1.44
         sum:                                39988.52

Threads fairness:
    events (avg/stddev):           9900.2500/511.49
    execution time (avg/stddev):   9.9971/0.00
```

## Simulate a 'too many connections' benchmark

The PostgreSQL instance is configured with a maximum of 10 connections. We can simulate an application that runs with a larger number of connections with.

```
$ docker exec -e THREADS=15 sysbench /usr/local/bin/benchmark.sh run
```

This will fail with the following command:
```
Running benchmark: oltp_read_write
Threads: 15, Time: 10s, Tables: 10, Rows/table: 10000
sysbench 1.0.20 (using system LuaJIT 2.1.0-beta3)

Running the test with following options:
Number of threads: 15
Report intermediate results every 1 second(s)
Initializing random number generator from current time


Initializing worker threads...

FATAL: Connection to database failed: connection to server at "primary" (172.20.0.2), port 5432 failed: FATAL:  sorry, too many clients already
```

## Teardown

The following will delete all containers resources.

```
docker compose down -v
```
