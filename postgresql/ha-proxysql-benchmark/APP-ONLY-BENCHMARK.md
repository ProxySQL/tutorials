## Simulating Application Load (No Proxy)

To emulate some random load from the three application servers to the primary DB run the benchmark.  ProxySQL is already pre-configured via [proxysql.cnf](cnf/proxysql.cnf) to have defined the primary server in hostgroup `10`.

```
$ ./run-benchmark.sh
```

This command will launch three benchmarks running for 10 minutes, with a random number of threads (5-15) and a random rate (50 - 250 in 50 increments). This will give feedback such as:

```
App Server 1: PID=7203 RATE=200 THREADS=10
App Server 2: PID=7204 RATE=50 THREADS=8
App Server 3: PID=7205 RATE=200 THREADS=10
```


Using the `summary.sh` script to review the host connections per database you will find connections to the primary database `100` originating from application servers `.6`, `.16`, `.26`.

```
$ scripts/summary.sh hosts-per-db

##### For DB 'primary' #####

  client_addr  | count
---------------+-------
 172.113.0.16  |    11
 172.113.0.26  |     5
 172.113.0.6   |     5
 172.113.0.101 |     1
 172.113.0.102 |     1
```

You will find no connections to the replicas.

```
##### For DB 'replica1' #####

 client_addr | count
-------------+-------
(0 rows)

##### For DB 'replica2' #####

 client_addr | count
-------------+-------
(0 rows)
```
