#Requires -Version 5.1
<#
.SYNOPSIS
  Start local Supabase and run CTFd against it (free local stack).

.DESCRIPTION
  1. Starts Supabase via npx (Postgres, Auth, Storage, Studio)
  2. Writes .env from .env.example if missing
  3. Optionally starts CTFd with Docker or prints native run instructions

.PARAMETER Docker
  Start CTFd via docker-compose.supabase.yml after Supabase is ready.

.PARAMETER Native
  Print commands to run CTFd locally with Python (no Docker for CTFd).
#>
param(
    [switch]$Docker,
    [switch]$Native
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

function Test-DockerRunning {
    try {
        docker info 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

if (-not (Test-DockerRunning)) {
    Write-Error "Docker is not running. Start Docker Desktop, then run this script again."
}

Write-Host "Starting local Supabase (free)..." -ForegroundColor Cyan
npx supabase start

Write-Host "`nSupabase status:" -ForegroundColor Cyan
npx supabase status

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example" -ForegroundColor Yellow
    Write-Host "Run 'npx supabase status' and paste anon/service keys into .env if needed."
}

$statusJson = npx supabase status -o json 2>$null | ConvertFrom-Json
$dbUrl = $statusJson.DB_URL
if ($dbUrl) {
    $ctfdUrl = $dbUrl -replace "/postgres`$", "/ctfd"
    Write-Host "`nSuggested DATABASE_URL for CTFd: $ctfdUrl" -ForegroundColor Green
    if ((Get-Content ".env" -Raw) -match "DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/ctfd") {
        (Get-Content ".env") -replace "DATABASE_URL=.*", "DATABASE_URL=$ctfdUrl" | Set-Content ".env"
    }
}

Write-Host "`nSupabase Studio: http://127.0.0.1:54323" -ForegroundColor Green
Write-Host "Supabase API:    http://127.0.0.1:54321" -ForegroundColor Green

if ($Docker) {
    Write-Host "`nStarting CTFd (Docker)..." -ForegroundColor Cyan
    docker compose -f docker-compose.supabase.yml up --build
} elseif ($Native -or (-not $Docker)) {
    Write-Host @"

Native CTFd (install deps once):
  pip install -r requirements.txt
  pip install psycopg2-binary

Run CTFd:
  `$env:DATABASE_URL = (Get-Content .env | Where-Object { `$_ -match '^DATABASE_URL=' }) -replace 'DATABASE_URL=',''
  python serve.py

Or set DATABASE_URL in .env and use flask run after exporting it.
"@ -ForegroundColor Yellow
}
