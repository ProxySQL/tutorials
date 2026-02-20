@echo off
echo Launching docker container(s)
docker compose up -d

echo Verifying docker processes
timeout /t 5 /nobreak >nul
docker compose ps

echo Validating PostgreSQL access
docker exec primary mysql -u demo -pchangeme -e "SELECT VERSION()"

echo.
echo To test using the container run
echo   docker exec -it primary bash
echo To exit the containers run
echo   docker compose down -v
