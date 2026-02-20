Write-Host "Launching docker container(s)"
docker compose up -d

Write-Host "Verifying docker processes"
Start-Sleep -Seconds 5
docker compose ps

Write-Host "Validating Database access"
docker exec primary mysql -u demo -pchangeme -e "SELECT VERSION()"

Write-Host ""
Write-Host "To test using the container run"
Write-Host "  docker exec -it primary bash"
Write-Host "To exit the containers run"
Write-Host "  docker compose down -v"
