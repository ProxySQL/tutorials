@echo off
echo Launching docker container(s)
docker compose up -d
echo Verifying docker processes
docker compose ps
timeout /t 5 /nobreak >nul
echo Validating PostgreSQL access
docker exec primary psql "postgresql://postgres:changeme@localhost:" -c "SELECT version();"

echo "Prepare Benchmark"
docker exec sysbench /usr/local/bin/benchmark.sh prepare

echo "Run Benchmark Test"
docker exec sysbench /usr/local/bin/benchmark.sh run

echo.
echo To test using the container run
echo   docker exec -it primary bash
echo To exit the containers run
echo   docker compose down -v
