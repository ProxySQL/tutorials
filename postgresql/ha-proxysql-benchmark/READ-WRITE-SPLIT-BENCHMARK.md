# Simulating Application Load (With Proxy)

### Cleanup
If you have been running other tests, you may need to cleanup database connections. See [CLEANUP.md](CLEANUP.md) before commencing benchmark.

## Prepare ProxySQL Configuration

To emulate load from the three application servers to the Proxy Layer that splits Writes and Reads between the Primary DB and a replica DB we first configure ProxySQL.

1. Add the replica as a known server to ProxySQL using hostgroup `20`. NOTE: hostgroup `10` defines the primary.
2. Add a query rule that directs `SELECT` statements to hostgroup `20`. Queries that do not match will goto the primary. 


```
$ docker exec -it proxysql psql -U radmin -p 6132 -hlocalhost
```

```
INSERT INTO pgsql_servers (hostgroup_id, hostname, port, status, max_connections, weight)
VALUES (20, 'replica1', 5432, 'ONLINE', 50, 100);
LOAD PGSQL SERVERS TO RUNTIME;

SELECT * FROM pgsql_servers;

INSERT INTO pgsql_query_rules (rule_id, active, match_digest, destination_hostgroup, apply)
VALUES (10, 1, '^SELECT.*FOR UPDATE', 10, 1),
(20, 1, '^SELECT', 20, 1);
LOAD PGSQL QUERY RULES TO RUNTIME;

SELECT * FROM pgsql_query_rules;

```

## Run Benchmark

To emulate some random load from the three application servers to the databases run the benchmark. 

```
$ ./run-proxysql-benchmark.sh
```

If we look at database connections, we will find the Proxy layer connected to the `primary` and `replica1`, but not `replica2` which matches the configuration setup in **ProxySQL**.

```
$ scripts/summary.sh hosts-per-db

##### For DB 'primary' #####

  client_addr  | count
---------------+-------
 172.113.0.222 |     9
 172.113.0.101 |     1
 172.113.0.102 |     1
(3 rows)


##### For DB 'replica1' #####

  client_addr  | count
---------------+-------
 172.113.0.222 |    12
(1 row)


##### For DB 'replica2' #####

 client_addr | count
-------------+-------
(0 rows)
```
