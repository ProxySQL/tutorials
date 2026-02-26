## Simulating Application Load (With Proxy)

To emulate some random load from the three application servers to the Proxy Layer.
```
$ ./run-proxysql-benchmark.sh
```

Using the same script to review the host connects per database you will find all connections to the primary originating from the Proxy `.222` and there are no connections to the replicas from the Proxy.

```
$ scripts/summary.sh hosts-per-db

##### For DB 'primary' #####

  client_addr  | count
---------------+-------
 172.113.0.222 |    17
 172.113.0.101 |     1
 172.113.0.102 |     1
(3 rows)
```

### Configuring ProxySQL for simulations

```
$ source scripts/alias
$ admin
```

```
select * from pgsql_servers;
select username, default_hostgroup from pgsql_users;
select * from pgsql_query_rules;
```


```
radmin=# select username, default_hostgroup from pgsql_users;
 username | default_hostgroup
----------+-------------------
 appuser  | 10
 postgres | 10
 ```
 
```
INSERT INTO mysql_query_rules (rule_id,active,match_digest,destination_hostgroup,apply)
VALUES (1,1,'^SELECT.*FOR UPDATE',10,1),
      (2,1,'^SELECT',20,1);
LOAD MYSQL QUERY RULES TO RUNTIME;
```
