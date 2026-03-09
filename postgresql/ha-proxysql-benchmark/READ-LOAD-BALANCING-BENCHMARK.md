# Simulating Application Load Balancing (With Proxy)

### Cleanup
If you have been running other tests, you may need to cleanup database connections. See [CLEANUP.md](CLEANUP.md) before commencing benchmark.

## Prepare ProxySQL Configuration

To emulate load from the three application servers to the Proxy Layer that splits Writes and Reads between the Primary DB and a replica DB we first configure ProxySQL.

1. Remove any existing hostgroup `20` servers.
2. Add the second replica as a known server to ProxySQL using hostgroup `20`. NOTE: hostgroup `10` defines the primary.
3. Set the `weight` of each server equally. To emulate a percentage, we make the two servers 50, so this mirrors 50%, however any equal value will produce equal load.


```
$ docker exec -it proxysql psql -U radmin -p 6132 -hlocalhost
```

```
DELETE FROM pgsql_servers WHERE hostgroup_id=20;
INSERT INTO pgsql_servers (hostgroup_id, hostname, port, status, max_connections, weight)
VALUES (20, 'replica1', 5432, 'ONLINE', 50, 50);
INSERT INTO pgsql_servers (hostgroup_id, hostname, port, status, max_connections, weight)
VALUES (20, 'replica2', 5432, 'ONLINE', 50, 50);
LOAD PGSQL SERVERS TO RUNTIME;

SELECT * FROM pgsql_servers;
```

## Run Benchmark

To emulate some random load from the three application servers to the databases run the benchmark. 

```
$ ./run-proxysql-benchmark.sh
```

If we look at database connections, we will find the Proxy layer connected to the `primary` and `replica1` AND `replica2` which matches the configuration setup in **ProxySQL**.

```
$ scripts/summary.sh hosts-per-db

##### For DB 'primary' #####

  client_addr  | count
---------------+-------
 172.113.0.222 |     7
 172.113.0.101 |     1
 172.113.0.102 |     1
(3 rows)


##### For DB 'replica1' #####

  client_addr  | count
---------------+-------
 172.113.0.222 |    34
(1 row)


##### For DB 'replica2' #####

  client_addr  | count
---------------+-------
 172.113.0.222 |    26
(1 row)
```
