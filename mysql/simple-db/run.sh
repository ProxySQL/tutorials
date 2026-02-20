#!/usr/bin/env bash
set -euo pipefail

echo "Launching docker container(s)"
docker compose up -d 

echo "Verifying docker processes"
sleep 5
docker compose ps

echo "Validating PostgreSQL access"
docker exec primary mysql -u demo -pchangeme -e "SELECT VERSION()"

echo "To test using the container run"
echo "$ docker exec -it primary bash"
echo ""
echo "To exit the containers run"
echo "$ docker compose down -v"
