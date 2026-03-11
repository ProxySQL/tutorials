# Cleanup Database Connections

Depending on what prior benchmarks you have executed, you may have idle database connections which you would see with:

```
$ scripts/summary.sh hosts-per-db
```

## Remove idle DB connections
This script resets ProxySQL stats, prepares sysbench for next run, and removes idle connections from PostgreSQL.

```
$ scripts/cleanup.sh
```
