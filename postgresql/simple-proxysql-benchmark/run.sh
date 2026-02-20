#!/usr/bin/env bash

. .envrc

echo "Building docker container"
docker compose build # --no-cache

echo "Launching docker container(s)"
docker compose up -d # --force-recreate

echo "Verifying docker processes"
sleep 5
docker compose ps

echo "Validating PostgreSQL access"
docker exec primary psql "postgresql://${DB_USER}:${DB_PASSWD}@localhost:" -c "SELECT version();"

echo "Prepare Benchmark"
docker exec -e DB_PORT=${DB_PORT} ${SYSBENCH_CONTAINER_NAME} /usr/local/bin/benchmark.sh cleanup 
docker exec -e DB_PORT=${DB_PORT} ${SYSBENCH_CONTAINER_NAME} /usr/local/bin/benchmark.sh prepare

echo "Run Benchmark Test"
docker exec -e DB_PORT=${DB_PORT} ${SYSBENCH_CONTAINER_NAME} /usr/local/bin/benchmark.sh run

echo "Run Benchmark Test that fails with too many connections"
docker exec -e THREADS=20 -e DB_PORT=${DB_PORT} ${SYSBENCH_CONTAINER_NAME} /usr/local/bin/benchmark.sh run

echo "To test using the container run"
echo "$ docker exec -it primary bash"

echo "To exit the containers run"
echo "$ docker compose down -v"
