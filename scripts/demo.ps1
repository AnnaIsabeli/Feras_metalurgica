$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if (-not (Test-Path -LiteralPath '.env')) { throw 'Copie .env.example para .env e configure a senha local.' }
docker compose up -d --build --wait
if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar os serviços.' }
Get-Content -Raw database/seeds/development.sql | docker compose exec -T db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao carregar usuários de demonstração.' }
Write-Host 'API: http://localhost:8080/ready'
Write-Host 'No Flutter: flutter run -d chrome --web-port 5000 --dart-define=ENABLE_DEMO=true'
