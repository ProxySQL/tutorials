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
