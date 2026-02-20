#!/usr/bin/env bash

echo "Building docker container"
docker compose build # --no-cache
echo "Launching docker container(s)"
docker compose up -d 
echo "Verifying docker processes"
docker compose ps
sleep 5

echo "Validating PostgreSQL access"
docker exec primary psql "postgresql://postgres:changeme@localhost:" -c "SELECT version();"

echo "Prepare Benchmark"
docker exec sysbench /usr/local/bin/benchmark.sh prepare

echo "Run Benchmark Test"
docker exec sysbench /usr/local/bin/benchmark.sh run

echo "To test using the container run"
echo "$ docker exec -it primary bash"
echo "To exit the containers run"
echo "$ docker compose down -v"
