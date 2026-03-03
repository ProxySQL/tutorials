# Monitoring


## Database Monitoring

You can monitor the active connections to a specific database instance with the following command, selecting one of the following `DB_HOST` values:

- `primary`
- `replica1`
- `replica2`

```
$ docker exec -e DB_HOST=primary -it sysbench1 /usr/local/bin/monitor-db-connections.sh
Monitoring PostgreSQL for 180 seconds (polling every 2s)
Time                 | Total Conn | Active | Idle | Idle in Txn | Active Queries
------------------------------------------------------------------------------------
2026-02-27 20:42:40 |         14 |      3 |    7 |           4 |              2
2026-02-27 20:42:42 |         15 |      2 |   12 |           1 |              1
2026-02-27 20:42:44 |         18 |      2 |   12 |           4 |              1
2026-02-27 20:42:46 |         21 |      2 |   15 |           4 |              1
```


## Monitoring the source of Database Connections

When running tests from multiple applications you can review the source IP of these connections to each DB instance.

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
