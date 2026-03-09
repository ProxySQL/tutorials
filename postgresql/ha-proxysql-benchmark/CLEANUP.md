# Cleanup Database Connections

Depending on what prior benchmarks you have executed, you may have idle database connections which you would see with:

```
$ scripts/summary.sh hosts-per-db
```

## Remove idle DB connections 

```
for HOST in primary replica1 replica2; do
  docker exec -it ${HOST} psql -U postgres -c " SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND datname = 'demo' AND pid <> pg_backend_pid();"
done
