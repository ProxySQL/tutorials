# HA Tutorial SQL Statements


## Insert Query Rules for SELECT traffic
```sql
DELETE FROM pgsql_query_rules;
INSERT INTO pgsql_query_rules (rule_id, active, match_digest, destination_hostgroup, apply)
VALUES (10, 1, '^SELECT.*FOR UPDATE', 10, 1),
       (20, 1, '^SELECT', 20, 1);
LOAD PGSQL QUERY RULES TO RUNTIME;
```

## Reset Statistics tables

Between each benchmark we can reset the statistics to see the actual impact of each test.

```sql
SELECT 1 FROM stats_pgsql_connection_pool_reset LIMIT 1;
SELECT 1 FROM stats_pgsql_query_digest_reset LIMIT 1;
```

## Select Query Digests

This shows the queries by frequency of execution.

```sql
SELECT hostgroup, digest_text, count_star, sum_time
FROM stats_pgsql_query_digest
ORDER BY count_star DESC
LIMIT 20;
```

For Example
```
hostgroup |                             digest_text                              | count_star | sum_time
-----------+----------------------------------------------------------------------+------------+----------
20        | SELECT c FROM sbtest2 WHERE id=$1                                    | 1519       | 380617
20        | SELECT c FROM sbtest3 WHERE id=$1                                    | 1493       | 497395
20        | SELECT c FROM sbtest10 WHERE id=$1                                   | 1403       | 805586
20        | SELECT c FROM sbtest6 WHERE id=$1                                    | 1354       | 460381
20        | SELECT c FROM sbtest9 WHERE id=$1                                    | 1333       | 459937
20        | SELECT c FROM sbtest5 WHERE id=$1                                    | 1283       | 402680
20        | SELECT c FROM sbtest7 WHERE id=$1                                    | 1231       | 373084
20        | SELECT c FROM sbtest4 WHERE id=$1                                    | 1203       | 495676
20        | SELECT c FROM sbtest1 WHERE id=$1                                    | 1073       | 476558
20        | SELECT c FROM sbtest8 WHERE id=$1                                    | 1033       | 364307
20        | SELECT c FROM sbtest4 WHERE id BETWEEN $1 AND $2 ORDER BY c          | 180        | 80777
20        | SELECT c FROM sbtest6 WHERE id BETWEEN $1 AND $2 ORDER BY c          | 178        | 65076
20        | SELECT c FROM sbtest9 WHERE id BETWEEN $1 AND $2 ORDER BY c          | 177        | 58879
20        | SELECT c FROM sbtest10 WHERE id BETWEEN $1 AND $2                    | 174        | 48598
20        | SELECT c FROM sbtest8 WHERE id BETWEEN $1 AND $2 ORDER BY c          | 172        | 64982
20        | SELECT SUM(k) FROM sbtest6 WHERE id BETWEEN $1 AND $2                | 170        | 48491
20        | SELECT c FROM sbtest2 WHERE id BETWEEN $1 AND $2                     | 169        | 31988
20        | SELECT DISTINCT c FROM sbtest1 WHERE id BETWEEN $1 AND $2 ORDER BY c | 167        | 84833
20        | SELECT c FROM sbtest3 WHERE id BETWEEN $1 AND $2                     | 166        | 62944
20        | SELECT DISTINCT c FROM sbtest3 WHERE id BETWEEN $1 AND $2 ORDER BY c | 166        | 42421
```

## Select Traffic Balancing

Using reset between tests, we can validate the % of traffic sent to individual servers

```sql
SELECT hostgroup, srv_host, Queries,
       ROUND(100.0 * Queries / SUM(Queries) OVER (PARTITION BY hostgroup), 2) AS pct
FROM stats_pgsql_connection_pool
ORDER BY Queries DESC;
```

In the example where we are sending different 25% of traffic to one replica, and 75% to another.

```
hostgroup | srv_host | Queries |  pct
-----------+----------+---------+-------
20        | replica2 | 17194   | 74.79
20        | replica1 | 5797    | 25.21
10        | primary  | 0       |

radmin=# select hostgroup_id, hostname, status, weight from pgsql_servers;
 hostgroup_id | hostname | status | weight
--------------+----------+--------+--------
 10           | primary  | ONLINE | 1
 20           | replica1 | ONLINE | 1
 20           | replica2 | ONLINE | 3
 
```
