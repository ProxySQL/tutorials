Write-Host "Launching docker container(s)"
docker compose up -d
Write-Host "Verifying docker processes"
docker compose ps
Start-Sleep -Seconds 5
Write-Host "Validating PostgreSQL access"
docker exec primary psql "postgresql://postgres:changeme@localhost:" -c "SELECT version();"

Write-Host ""
Write-Host "To test using the container run"
Write-Host "  docker exec -it primary bash"
Write-Host "To exit the containers run"
Write-Host "  docker compose down -v"
