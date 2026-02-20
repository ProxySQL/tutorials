#!/usr/bin/env bash
set -euo pipefail

echo "Launching docker container(s)"
docker compose up -d 

echo "Verifying docker processes"
docker compose ps
sleep 5

echo "Validating PostgreSQL access"
docker exec primary psql "postgresql://postgres:changeme@localhost:" -c "SELECT version();"

echo "To test using the container run"
echo "$ docker exec -it primary bash"
echo ""
echo "To exit the containers run"
echo "$ docker compose down -v"
