<#
.SYNOPSIS
    AutoTFL one-click deployment package builder
.DESCRIPTION
    Builds Docker images, exports offline image bundle, and generates
    a complete deployment package for local network deployment.
.PARAMETER OutputDir
    Output directory, default G:\Project release\AutoTFL
.PARAMETER SkipBuild
    Skip Docker build (use existing image)
.PARAMETER SkipImageSave
    Skip image export (use existing tar)
.PARAMETER WithLanding
    Include Landing page (default: off, direct proxy to app)
#>

param(
    [string]$OutputDir = "G:\Project release\AutoTFL",
    [switch]$SkipBuild,
    [switch]$SkipImageSave,
    [switch]$WithLanding
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

# ============================================================
# Helper functions
# ============================================================

function Write-Step {
    param([string]$Number, [string]$Message)
    Write-Host ""
    Write-Host "[$Number/6] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  .. $Message" -ForegroundColor Gray
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor Yellow
}

function New-DirectoryIfNotExist {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Reset-GeneratedDirectory {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item $Path -Recurse -Force
    }
    New-DirectoryIfNotExist $Path
}

# ============================================================
# Banner
# ============================================================

Write-Host ""
Write-Host "  _____         _______ _______ ______ _____  ______ _____  _____ " -ForegroundColor Cyan
Write-Host " / ____|   /\   |  ____|__   __|  ____|  __ \|  ____|  __ \|  __ \"  -ForegroundColor Cyan
Write-Host "| (___    /  \  | |__     | |  | |__  | |__) | |__  | |__) | |  | |" -ForegroundColor Cyan
Write-Host " \___ \  / /\ \ |  __|    | |  |  __| |  _  /|  __| |  ___/| |  | |" -ForegroundColor Cyan
Write-Host " ____) |/ ____ \| |       | |  | |____| | \ \| |____| |    | |__| |" -ForegroundColor Cyan
Write-Host "|_____/_/    \_\_|       |_|  |______|_|  \_\______|_|    |_____/" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Offline Deployment Package Builder" -ForegroundColor DarkCyan
Write-Host "  Target: $OutputDir" -ForegroundColor DarkGray
$modeLabel = if ($WithLanding) { "Landing + /app/ proxy" } else { "Direct proxy (no Landing)" }
Write-Host "  Mode:   $modeLabel" -ForegroundColor DarkGray
Write-Host ""

# ============================================================
# Step 1: Environment check
# ============================================================

Write-Step "1" "Environment check"

# Check Docker
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    Write-Success "Docker $dockerVersion"
} catch {
    Write-Host "  [X] Docker not installed or not running" -ForegroundColor Red
    exit 1
}

# Check Docker Compose
try {
    $composeVersion = docker compose version --short 2>$null
    Write-Success "Docker Compose $composeVersion"
} catch {
    Write-Host "  [X] Docker Compose not available" -ForegroundColor Red
    exit 1
}

# Check project key files
$requiredFiles = @(
    "Dockerfile",
    "docker-compose.local.yml",
    "nginx\local-test.conf",
    "nginx\default.conf",
    "postgres\init.sql",
    "postgres\postgresql.conf",
    "config\required_packages.R",
    "app.R"
)
foreach ($f in $requiredFiles) {
    $fullPath = Join-Path $ProjectRoot $f
    if (-not (Test-Path $fullPath)) {
        Write-Host "  [X] Missing file: $f" -ForegroundColor Red
        exit 1
    }
}
Write-Success "Project files integrity check passed"

# ============================================================
# Step 2: Build Docker image
# ============================================================

Write-Step "2" "Build Docker image"

if ($SkipBuild) {
    Write-Warn "Skipping build (using existing image)"
    $imageExists = docker images autotfl-shiny-app:latest --format '{{.Repository}}' 2>$null
    if (-not $imageExists) {
        Write-Host "  [X] Image autotfl-shiny-app:latest not found" -ForegroundColor Red
        exit 1
    }
    Write-Success "Image autotfl-shiny-app:latest ready"
} else {
    Write-Info "Building autotfl-shiny-app:latest (first build ~10-20 min)..."

    $env:DOCKER_BUILDKIT = "1"
    $env:COMPOSE_DOCKER_CLI_BUILD = "1"

    Push-Location $ProjectRoot
    try {
        $oldNativeErrorPreference = $null
        $hasNativePreference = Test-Path Variable:\PSNativeCommandUseErrorActionPreference
        if ($hasNativePreference) {
            $oldNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
            $PSNativeCommandUseErrorActionPreference = $false
        }
        try {
            $buildOutput = docker build -t autotfl-shiny-app:latest . 2>&1
            $buildExitCode = $LASTEXITCODE
        } finally {
            if ($hasNativePreference) {
                $PSNativeCommandUseErrorActionPreference = $oldNativeErrorPreference
            }
        }
        $buildOutput | ForEach-Object {
            if ($_ -match '^\#') {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
        if ($buildExitCode -ne 0) { throw "Docker build failed" }
        Write-Success "Image build complete"
    } finally {
        Pop-Location
    }
}

# Ensure base images are pulled
$baseImages = @("postgres:14-alpine", "redis:7-alpine", "nginx:1.27-alpine")
foreach ($img in $baseImages) {
    $exists = docker images $img --format '{{.Repository}}' 2>$null
    if (-not $exists) {
        Write-Info "Pulling base image $img ..."
        docker pull $img
    }
    Write-Success "Image $img ready"
}

# ============================================================
# Step 3: Export offline image bundle
# ============================================================

Write-Step "3" "Export offline image bundle"

$imagesDir = Join-Path $OutputDir "images"
New-DirectoryIfNotExist $imagesDir

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tarFileName = "autotfl-images-$timestamp.tar"
$tarPath = Join-Path $imagesDir $tarFileName

if ($SkipImageSave) {
    Write-Warn "Skipping image export"
    $existingTar = Get-ChildItem $imagesDir -Filter "autotfl-images-*.tar" -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($existingTar) {
        $tarFileName = $existingTar.Name
        $tarPath = $existingTar.FullName
        Write-Success "Using existing image bundle: $tarFileName"
    } else {
        Write-Host "  [X] No existing image bundle found" -ForegroundColor Red
        exit 1
    }
} else {
    Get-ChildItem $imagesDir -Filter "autotfl-images-*.tar*" -ErrorAction SilentlyContinue |
        Remove-Item -Force
    Write-Info "Exporting 4 images to $tarFileName ..."
    Write-Info "(~1.7GB, may take a few minutes)"

    docker save -o $tarPath autotfl-shiny-app:latest postgres:14-alpine redis:7-alpine nginx:1.27-alpine

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [X] Image export failed" -ForegroundColor Red
        exit 1
    }

    $fileSize = [math]::Round((Get-Item $tarPath).Length / 1MB, 1)
    Write-Success ("Image bundle exported: {0} ({1} MB)" -f $tarFileName, $fileSize)
}

# Generate SHA256
$sha256 = (Get-FileHash -Path $tarPath -Algorithm SHA256).Hash.ToLower()
$sha256File = Join-Path $imagesDir ("$tarFileName.sha256")
"$sha256  $tarFileName" | Out-File -FilePath $sha256File -Encoding utf8 -NoNewline
Write-Success "SHA256: $sha256"

# ============================================================
# Step 4: Copy deployment files
# ============================================================

Write-Step "4" "Copy deployment files"

Write-Info "Generating Docker Compose config..."

# Shared services (postgres, redis, app)
$composeCommon = @'
# AutoTFL LAN deployment (no SSL)
# Usage: docker compose up -d

name: autotfl-local

services:
  postgres:
    image: postgres:14-alpine
    container_name: autotfl-postgres
    environment:
      POSTGRES_DB: autotfl
      POSTGRES_USER: autotfl_user
      POSTGRES_PASSWORD: ${DB_PASSWORD:?Set DB_PASSWORD in .env}
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=C"
    volumes:
      - ${DATA_ROOT:-./data}/postgres:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
      - ./postgres/postgresql.conf:/etc/postgresql/postgresql.conf
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U autotfl_user -d autotfl"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - autotfl-network

  redis:
    image: redis:7-alpine
    container_name: autotfl-redis
    command: redis-server --appendonly yes
    volumes:
      - ${DATA_ROOT:-./data}/redis:/data
    restart: unless-stopped
    networks:
      - autotfl-network

  app:
    image: autotfl-shiny-app:latest
    pull_policy: never
    container_name: autotfl-shiny
    environment:
      POSTGRES_DB: autotfl
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_USER: autotfl_user
      POSTGRES_PASSWORD: ${DB_PASSWORD:?Set DB_PASSWORD in .env}
      STORAGE_ROOT: /app/data_storage
      APP_ADMIN_USERNAME: ${APP_ADMIN_USERNAME:-admin}
      APP_ADMIN_EMAIL: ${APP_ADMIN_EMAIL:-admin@example.com}
      APP_ADMIN_PASSWORD: ${APP_ADMIN_PASSWORD:-admin123}
    volumes:
      - ${DATA_ROOT:-./data}/storage:/app/data_storage
    depends_on:
      postgres:
        condition: service_healthy
    expose:
      - "3838"
    restart: unless-stopped
    networks:
      - autotfl-network
'@

# Nginx service block depends on mode
if ($WithLanding) {
    $composeNginx = @'
  nginx:
    image: nginx:1.27-alpine
    container_name: autotfl-nginx
    depends_on:
      - app
    volumes:
      - ./nginx/local-test.conf:/etc/nginx/conf.d/default.conf:ro
      - ./nginx/landing:/usr/share/nginx/html/landing:ro
    ports:
      - "${WEB_PORT:-8080}:80"
    restart: unless-stopped
    networks:
      - autotfl-network

networks:
  autotfl-network:
    driver: bridge
'@
} else {
    $composeNginx = @'
  nginx:
    image: nginx:1.27-alpine
    container_name: autotfl-nginx
    depends_on:
      - app
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    ports:
      - "${WEB_PORT:-8080}:80"
    restart: unless-stopped
    networks:
      - autotfl-network

networks:
  autotfl-network:
    driver: bridge
'@
}

$composeContent = $composeCommon + "`n" + $composeNginx
$composeContent | Out-File -FilePath (Join-Path $OutputDir "docker-compose.yml") -Encoding utf8 -NoNewline
if ($WithLanding) {
    Write-Success "docker-compose.yml (LAN, Landing + /app/)"
} else {
    Write-Success "docker-compose.yml (LAN, direct proxy)"
}

# --- .env ---
$envPath = Join-Path $OutputDir ".env"
if (Test-Path $envPath) {
    Write-Warn ".env already exists, preserving (passwords unchanged)"
} else {
    Write-Info "Generating .env config..."

    # Generate random passwords
    $dbPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
    $adminPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object { [char]$_ })

    $envContent = @"
# ============================================
# AutoTFL LAN Deployment Config
# Edit before first deployment
# ============================================

# [Required] Database password (auto-generated)
DB_PASSWORD=$dbPassword

# [Optional] Data storage path (default ./data)
DATA_ROOT=./data

# [Optional] Web port (default 8080)
WEB_PORT=8080

# [Optional] Admin account (created on first start)
APP_ADMIN_USERNAME=admin
APP_ADMIN_EMAIL=admin@example.com
APP_ADMIN_PASSWORD=$adminPassword

# [Optional] Email config (keep disabled for LAN)
EMAIL_DELIVERY_MODE=disabled
AUTH_REQUIRE_EMAIL_VERIFICATION=0
AUTH_DEV_SHOW_EMAIL_CODE=0
"@
    $envContent | Out-File -FilePath $envPath -Encoding utf8 -NoNewline
    Write-Success ".env (random passwords generated)"
}

# --- .env.example ---
$envExampleContent = @'
# AutoTFL LAN Deployment Config Template
DB_PASSWORD=CHANGE_ME_TO_A_SECURE_PASSWORD
DATA_ROOT=./data
WEB_PORT=8080
APP_ADMIN_USERNAME=admin
APP_ADMIN_EMAIL=admin@example.com
APP_ADMIN_PASSWORD=CHANGE_ME_ADMIN_PASSWORD
EMAIL_DELIVERY_MODE=disabled
AUTH_REQUIRE_EMAIL_VERIFICATION=0
'@
$envExampleContent | Out-File -FilePath (Join-Path $OutputDir ".env.example") -Encoding utf8 -NoNewline
Write-Success ".env.example"

# --- postgres directory ---
Write-Info "Copying PostgreSQL config..."
$postgresDir = Join-Path $OutputDir "postgres"
Reset-GeneratedDirectory $postgresDir

Copy-Item (Join-Path $ProjectRoot "postgres\init.sql") (Join-Path $postgresDir "init.sql") -Force
Copy-Item (Join-Path $ProjectRoot "postgres\postgresql.conf") (Join-Path $postgresDir "postgresql.conf") -Force

$migrationsDir = Join-Path $ProjectRoot "postgres\migrations"
if (Test-Path $migrationsDir) {
    Copy-Item $migrationsDir (Join-Path $postgresDir "migrations") -Recurse -Force
}
Write-Success "postgres/"

# --- nginx directory ---
Write-Info "Copying Nginx config..."
$nginxDir = Join-Path $OutputDir "nginx"
Reset-GeneratedDirectory $nginxDir

if ($WithLanding) {
    # Landing mode: use local-test.conf + landing page assets
    Copy-Item (Join-Path $ProjectRoot "nginx\local-test.conf") (Join-Path $nginxDir "local-test.conf") -Force

    $landingSrc = Join-Path $ProjectRoot "nginx\landing"
    $landingDst = Join-Path $nginxDir "landing"
    if (Test-Path $landingSrc) {
        if (Test-Path $landingDst) { Remove-Item $landingDst -Recurse -Force }
        Copy-Item $landingSrc $landingDst -Recurse -Force
    }
} else {
    # Direct mode: use default.conf, no landing page
    Copy-Item (Join-Path $ProjectRoot "nginx\default.conf") (Join-Path $nginxDir "default.conf") -Force
}
Write-Success "nginx/"

# ============================================================
# Step 5: Generate deployment scripts
# ============================================================

Write-Step "5" "Generate deployment scripts"

# --- Interactive Linux offline operations menu ---
$offlineOpsSrc = Join-Path $ProjectRoot "scripts\offline-ops.sh"
if (Test-Path $offlineOpsSrc) {
    Copy-Item $offlineOpsSrc (Join-Path $OutputDir "offline-ops.sh") -Force
    Write-Success "offline-ops.sh (Linux interactive menu)"
} else {
    Write-Warn "scripts\offline-ops.sh not found; offline menu was not copied"
}

# --- Linux deploy script (deploy.sh) ---
$deploySh = @'
#!/bin/bash
# ============================================================
# AutoTFL LAN Deployment Script (Linux)
# Usage: bash deploy.sh [command]
# Tip: run `bash offline-ops.sh` for the interactive menu.
#   install   - First deployment (default)
#   start     - Start services
#   stop      - Stop services
#   restart   - Restart services
#   status    - Show status
#   logs      - Show logs
#   update    - Update images and restart
#   uninstall - Stop and remove all data
# ============================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}..${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[X]${NC} $1"; }

check_docker() {
    if ! command -v docker &> /dev/null; then
        err "Docker not installed"
        echo "  Install: curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
    if ! docker compose version &> /dev/null; then
        err "Docker Compose not available"
        echo "  Please install Docker Compose V2"
        exit 1
    fi
    ok "Docker $(docker version --format '{{.Server.Version}}') + Compose $(docker compose version --short)"
}

load_images() {
    local tar_file
    tar_file=$(find images/ -name "autotfl-images-*.tar" -type f 2>/dev/null | sort -r | head -1)
    if [ -z "$tar_file" ]; then
        err "Image bundle not found (images/autotfl-images-*.tar)"
        exit 1
    fi
    info "Loading images: $tar_file"
    docker load -i "$tar_file"
    ok "Images loaded"
}

do_install() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  AutoTFL LAN Deployment${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    check_docker

    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            warn ".env created from .env.example - edit passwords and re-run"
            echo "  Config: $SCRIPT_DIR/.env"
            exit 0
        else
            err ".env file not found"
            exit 1
        fi
    fi

    if grep -q "CHANGE_ME" .env 2>/dev/null; then
        err ".env contains default passwords - please edit first"
        exit 1
    fi

    load_images

    DATA_ROOT=$(grep DATA_ROOT .env | cut -d= -f2 | tr -d '"' | tr -d "'")
    DATA_ROOT=${DATA_ROOT:-./data}
    mkdir -p "$DATA_ROOT"/{postgres,redis,storage}
    ok "Data directory: $DATA_ROOT"

    info "Starting services..."
    docker compose up -d
    ok "Services started"

    info "Waiting for database..."
    for i in $(seq 1 30); do
        if docker compose exec -T postgres pg_isready -U autotfl_user -d autotfl &>/dev/null; then
            ok "Database ready"
            break
        fi
        sleep 2
        if [ $i -eq 30 ]; then
            warn "Database startup timeout, check: docker compose logs postgres"
        fi
    done

    WEB_PORT=$(grep WEB_PORT .env | cut -d= -f2 | tr -d '"' | tr -d "'")
    WEB_PORT=${WEB_PORT:-8080}
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "  Landing:  http://${LOCAL_IP}:${WEB_PORT}"
    echo "  App:      http://${LOCAL_IP}:${WEB_PORT}/app/"
    echo ""
    echo "  Admin:    see APP_ADMIN_* in .env"
    echo ""
    echo "  Commands:"
    echo "    bash deploy.sh status    # Show status"
    echo "    bash deploy.sh logs      # Show logs"
    echo "    bash deploy.sh restart   # Restart"
    echo "    bash deploy.sh stop      # Stop"
    echo ""
}

case "${1:-install}" in
    install)
        do_install
        ;;
    start)
        docker compose up -d
        ok "Services started"
        ;;
    stop)
        docker compose down
        ok "Services stopped"
        ;;
    restart)
        docker compose restart
        ok "Services restarted"
        ;;
    status)
        docker compose ps
        ;;
    logs)
        docker compose logs -f --tail=100
        ;;
    update)
        load_images
        docker compose up -d
        ok "Update complete"
        ;;
    uninstall)
        echo ""
        warn "This will stop services and DELETE ALL DATA!"
        read -p "Confirm? (type YES): " confirm
        if [ "$confirm" = "YES" ]; then
            docker compose down -v
            DATA_ROOT=$(grep DATA_ROOT .env 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'" || echo "./data")
            rm -rf "$DATA_ROOT"
            ok "Uninstalled"
        else
            info "Cancelled"
        fi
        ;;
    *)
        echo "Usage: bash deploy.sh [install|start|stop|restart|status|logs|update|uninstall]"
        exit 1
        ;;
esac
'@
$deployShPath = Join-Path $OutputDir "deploy.sh"
$deploySh | Out-File -FilePath $deployShPath -Encoding utf8 -NoNewline
Write-Success "deploy.sh (Linux)"

# --- Windows deploy script (deploy.ps1) ---
$deployPs1 = @'
<#
.SYNOPSIS
    AutoTFL LAN Deployment Script (Windows)
.DESCRIPTION
    Usage: .\deploy.ps1 [command]
    install   - First deployment (default)
    start     - Start services
    stop      - Stop services
    restart   - Restart services
    status    - Show status
    logs      - Show logs
    update    - Update images and restart
    uninstall - Stop and remove all data
#>

param(
    [ValidateSet("install","start","stop","restart","status","logs","update","uninstall")]
    [string]$Command = "install"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

function Write-Info  { param([string]$Msg) Write-Host "  .. $Msg" -ForegroundColor Gray }
function Write-Ok    { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "  [!] $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "  [X] $Msg" -ForegroundColor Red }

function Test-Docker {
    try { docker version --format '{{.Server.Version}}' | Out-Null }
    catch { Write-Err "Docker not installed or not running"; exit 1 }
    try { docker compose version --short | Out-Null }
    catch { Write-Err "Docker Compose not available"; exit 1 }
    Write-Ok "Docker ready"
}

function Load-Images {
    $tar = Get-ChildItem "images\autotfl-images-*.tar" -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $tar) { Write-Err "Image bundle not found (images\autotfl-images-*.tar)"; exit 1 }
    Write-Info "Loading images: $($tar.Name)"
    docker load -i $tar.FullName
    Write-Ok "Images loaded"
}

function Install-AutoTFL {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  AutoTFL LAN Deployment" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Test-Docker

    if (-not (Test-Path ".env")) {
        if (Test-Path ".env.example") {
            Copy-Item ".env.example" ".env"
            Write-Warn ".env created from .env.example - edit passwords and re-run"
            Write-Host "  Config: $ScriptDir\.env"
            exit 0
        } else {
            Write-Err ".env file not found"; exit 1
        }
    }

    $envContent = Get-Content ".env" -Raw
    if ($envContent -match "CHANGE_ME") {
        Write-Err ".env contains default passwords - please edit first"; exit 1
    }

    Load-Images

    $dataRoot = (Get-Content ".env" | Where-Object { $_ -match "^DATA_ROOT=" }) -replace "DATA_ROOT=","" -replace '"',"" -replace "'",""
    if (-not $dataRoot) { $dataRoot = ".\data" }
    @("postgres","redis","storage") | ForEach-Object {
        New-Item -ItemType Directory -Path (Join-Path $dataRoot $_) -Force | Out-Null
    }
    Write-Ok "Data directory: $dataRoot"

    Write-Info "Starting services..."
    docker compose up -d
    Write-Ok "Services started"

    Write-Info "Waiting for database..."
    $maxWait = 60
    $waited = 0
    while ($waited -lt $maxWait) {
        try {
            docker compose exec -T postgres pg_isready -U autotfl_user -d autotfl 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "Database ready"; break }
        } catch {}
        Start-Sleep 2
        $waited += 2
    }
    if ($waited -ge $maxWait) { Write-Warn "Database startup timeout, check logs" }

    $webPort = (Get-Content ".env" | Where-Object { $_ -match "^WEB_PORT=" }) -replace "WEB_PORT=","" -replace '"',"" -replace "'",""
    if (-not $webPort) { $webPort = "8080" }
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 |
                Where-Object { $_.IPAddress -notmatch "^(127\.|169\.254\.)" } |
                Select-Object -First 1).IPAddress
    if (-not $localIP) { $localIP = "localhost" }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Deployment Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Landing:  http://${localIP}:${webPort}"
    Write-Host "  App:      http://${localIP}:${webPort}/app/"
    Write-Host ""
    Write-Host "  Admin:    see APP_ADMIN_* in .env"
    Write-Host ""
    Write-Host "  Commands:"
    Write-Host "    .\deploy.ps1 status    # Show status"
    Write-Host "    .\deploy.ps1 logs      # Show logs"
    Write-Host "    .\deploy.ps1 restart   # Restart"
    Write-Host "    .\deploy.ps1 stop      # Stop"
    Write-Host ""
}

switch ($Command) {
    "install"   { Install-AutoTFL }
    "start"     { docker compose up -d; Write-Ok "Services started" }
    "stop"      { docker compose down; Write-Ok "Services stopped" }
    "restart"   { docker compose restart; Write-Ok "Services restarted" }
    "status"    { docker compose ps }
    "logs"      { docker compose logs -f --tail=100 }
    "update"    { Load-Images; docker compose up -d; Write-Ok "Update complete" }
    "uninstall" {
        Write-Warn "This will stop services and DELETE ALL DATA!"
        $confirm = Read-Host "Confirm (type YES)"
        if ($confirm -eq "YES") {
            docker compose down -v
            $dataRoot = (Get-Content ".env" | Where-Object { $_ -match "^DATA_ROOT=" }) -replace "DATA_ROOT=",""
            if ($dataRoot -and (Test-Path $dataRoot)) { Remove-Item $dataRoot -Recurse -Force }
            Write-Ok "Uninstalled"
        } else {
            Write-Info "Cancelled"
        }
    }
}
'@
$deployPs1Path = Join-Path $OutputDir "deploy.ps1"
$deployPs1 | Out-File -FilePath $deployPs1Path -Encoding utf8 -NoNewline
Write-Success "deploy.ps1 (Windows)"

# --- README ---
$readmeContent = @'
# AutoTFL LAN Deployment Guide

## Prerequisites

- **Docker** 20.10+ and **Docker Compose** V2
- At least **4GB RAM**, **10GB disk space**
- Port **8080** available (configurable in .env)

### Install Docker (if not installed)

```bash
# Linux (Ubuntu/Debian)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in
```

Windows: Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)

---

## Quick Deploy (3 steps)

### Step 1: Configure

Edit `.env` file:

```ini
# Required
DB_PASSWORD=your_database_password
APP_ADMIN_PASSWORD=your_admin_password

# Optional
WEB_PORT=8080
APP_ADMIN_EMAIL=admin@yourcompany.com
```

### Step 2: Start

**Linux:**
```bash
bash offline-ops.sh
```

**Windows (PowerShell):**
```powershell
.\deploy.ps1
```

### Step 3: Access

- Landing page: `http://YOUR_IP:8080`
- Application: `http://YOUR_IP:8080/app/`
- Admin account: see `APP_ADMIN_*` in `.env`

---

## Commands

| Action | Linux | Windows |
|--------|-------|---------|
| Interactive menu | `bash offline-ops.sh` | `.\deploy.ps1` |
| First deploy | `bash offline-ops.sh --action install` | `.\deploy.ps1` |
| Start/update | `bash offline-ops.sh --action up` | `.\deploy.ps1 start` |
| Stop | `bash offline-ops.sh --action stop` | `.\deploy.ps1 stop` |
| Restart | `bash offline-ops.sh --action restart` | `.\deploy.ps1 restart` |
| Status | `bash offline-ops.sh --action status` | `.\deploy.ps1 status` |
| Logs | `bash offline-ops.sh --action logs` | `.\deploy.ps1 logs` |
| Load image + recreate app/nginx | `bash offline-ops.sh --action image` | `.\deploy.ps1 update` |
| Backup database dump | `bash offline-ops.sh --action backup` | 手工执行 `docker compose exec` |
| Backup database volume | `bash offline-ops.sh --action backup-volume` | 手工停止后打包数据目录 |
| Run DB migrations | `bash offline-ops.sh --action migrate` | 手工执行迁移 SQL |
| Reset DB volume | `bash offline-ops.sh --action reset-db` | 停止服务后重建数据目录 |
| Uninstall | `bash offline-ops.sh --action uninstall` | `.\deploy.ps1 uninstall` |

---

## Directory Structure

```
AutoTFL/
├── .env                     # Config (passwords etc.)
├── .env.example             # Config template
├── docker-compose.yml       # Docker compose
├── offline-ops.sh           # Linux interactive deployment menu
├── deploy.sh                # Linux deploy script
├── deploy.ps1               # Windows deploy script
├── README.md                # This file
├── images/
│   └── autotfl-images-*.tar # Offline image bundle
├── postgres/
│   ├── init.sql             # DB init
│   ├── postgresql.conf      # PG config
│   └── migrations/          # Migrations
├── nginx/
│   ├── local-test.conf      # Nginx config
│   ├── default.conf         # Simple proxy config
│   └── landing/             # Landing page
└── data/                    # Runtime data (auto-created)
    ├── postgres/
    ├── redis/
    └── storage/
```

---

## FAQ

### Port occupied?
Edit `WEB_PORT=other_port` in `.env`, then restart.

### Forgot admin password?
Edit `APP_ADMIN_PASSWORD` in `.env`, delete `data/storage/`, restart.

### How to backup?
```bash
# Backup database
docker compose exec postgres pg_dump -U autotfl_user autotfl > backup.sql

# Backup all data
tar -czf autotfl-backup.tar.gz data/
```

### How to migrate?
1. Backup data (above)
2. Copy deployment folder to new machine
3. Run `bash offline-ops.sh` on new machine
4. Restore data
'@
$readmePath = Join-Path $OutputDir "README.md"
$readmeContent | Out-File -FilePath $readmePath -Encoding utf8 -NoNewline
Write-Success "README.md"

# ============================================================
# Step 6: Generate manifest
# ============================================================

Write-Step "6" "Generate manifest"

$manifest = @()
$manifest += "# AutoTFL Deployment Package Manifest"
$manifest += "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$manifest += "# Image bundle: $tarFileName"
$manifest += "# SHA256: $sha256"
$manifest += ""
$manifest += "Files:"

Get-ChildItem $OutputDir -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($OutputDir.Length).TrimStart('\').TrimStart('/')
    $size = if ($_.Length -gt 1MB) { "$([math]::Round($_.Length/1MB,1)) MB" }
            elseif ($_.Length -gt 1KB) { "$([math]::Round($_.Length/1KB,1)) KB" }
            else { "$($_.Length) B" }
    $manifest += "  $rel  ($size)"
}

$manifestContent = $manifest -join "`n"
$manifestPath = Join-Path $OutputDir "MANIFEST.txt"
$manifestContent | Out-File -FilePath $manifestPath -Encoding utf8 -NoNewline
Write-Success "MANIFEST.txt"

# ============================================================
# Done
# ============================================================

$totalSize = [math]::Round(
    (Get-ChildItem $OutputDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 1
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Package Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Output:  $OutputDir" -ForegroundColor White
Write-Host "  Size:    $totalSize MB" -ForegroundColor White
Write-Host ""
Write-Host "  Contents:" -ForegroundColor White
Write-Host "    docker-compose.yml  - Docker compose" -ForegroundColor Gray
Write-Host "    .env                - Config (with random passwords)" -ForegroundColor Gray
Write-Host "    offline-ops.sh      - Linux interactive deployment menu" -ForegroundColor Gray
Write-Host "    deploy.sh           - Linux deploy script" -ForegroundColor Gray
Write-Host "    deploy.ps1          - Windows deploy script" -ForegroundColor Gray
Write-Host "    README.md           - Deployment guide" -ForegroundColor Gray
Write-Host "    images/*.tar        - Offline image bundle" -ForegroundColor Gray
Write-Host "    postgres/           - Database config" -ForegroundColor Gray
Write-Host "    nginx/              - Web proxy config" -ForegroundColor Gray
Write-Host ""
Write-Host "  Deploy steps:" -ForegroundColor Yellow
Write-Host "    1. Copy entire folder to target machine" -ForegroundColor White
Write-Host "    2. Edit .env to set passwords" -ForegroundColor White
Write-Host "    3. Run offline-ops.sh (Linux menu) or deploy.ps1 (Windows)" -ForegroundColor White
Write-Host ""
