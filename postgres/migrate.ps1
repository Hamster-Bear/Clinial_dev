<#
.SYNOPSIS
  AutoTFL database migration script (file-driven, idempotent)
.DESCRIPTION
  Auto-detects running PostgreSQL container and credentials,
  then applies all .sql files from postgres/migrations/ in order.
  Each migration file is expected to be idempotent (IF NOT EXISTS etc).
.EXAMPLE
  .\postgres\migrate.ps1
.EXAMPLE
  .\postgres\migrate.ps1 -Container "my-postgres" -PgUser "admin"
#>

param(
  [string]$Container  = "",
  [string]$PgUser     = "",
  [string]$PgPassword = "",
  [string]$PgDatabase = ""
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MigrationsDir = Join-Path $ScriptDir "migrations"

# ── helpers ──────────────────────────────────────────────────
$Green  = "Green"
$Yellow = "Yellow"
$Cyan   = "Cyan"
$Gray   = "Gray"
$Red    = "Red"

# ── 1. detect container ──────────────────────────────────────
if (-not $Container) {
  $candidates = @("hamster-analysis-postgres", "autotfl-postgres", "medflow-postgres-1")
  $psfmt = '{{' + '.Names}}'
  $running = docker ps --format $psfmt 2>$null | Where-Object { $_ -in $candidates }
  if (-not $running) {
    Write-Host "[ERR] No running PostgreSQL container found" -ForegroundColor $Red
    exit 1
  }
  $Container = $null
  foreach ($c in $candidates) {
    if ($c -in $running) { $Container = $c; break }
  }
  if (-not $Container) { $Container = @($running)[0] }
}
Write-Host "[OK] Container: $Container" -ForegroundColor $Green

# ── 2. read credentials ──────────────────────────────────────
$inspectFmt = '{{' + 'range .Config.Env}}{{' + 'println .}}{{' + 'end}}'
$envLines = docker inspect $Container --format $inspectFmt 2>$null

if (-not $PgUser)     { $PgUser     = ($envLines | Select-String "^POSTGRES_USER="     | ForEach-Object { $_ -replace "^POSTGRES_USER=", "" }) }
if (-not $PgPassword) { $PgPassword = ($envLines | Select-String "^POSTGRES_PASSWORD=" | ForEach-Object { $_ -replace "^POSTGRES_PASSWORD=", "" }) }
if (-not $PgDatabase) { $PgDatabase = ($envLines | Select-String "^POSTGRES_DB="       | ForEach-Object { $_ -replace "^POSTGRES_DB=", "" }) }

if (-not $PgUser)     { $PgUser     = "postgres" }
if (-not $PgDatabase) { $PgDatabase = "autotfl" }
if (-not $PgPassword) { $PgPassword = "ChangeMe123!" }

Write-Host "  Target: ${PgUser}@${Container}/${PgDatabase}" -ForegroundColor $Gray

# ── 3. file-driven migration runner ──────────────────────────
function Invoke-MigrationFile {
  param([string]$FilePath, [string]$Label)
  Write-Host "  $Label ..." -ForegroundColor $Gray -NoNewline
  $env:PGPASSWORD = $PgPassword
  $out = Get-Content -Path $FilePath -Raw | docker exec -i -e PGPASSWORD=$PgPassword $Container `
    psql -U $PgUser -d $PgDatabase -v ON_ERROR_STOP=1 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Host " OK" -ForegroundColor $Green
    return $true
  } else {
    Write-Host " FAIL" -ForegroundColor $Red
    Write-Host "  $($out -join "`n  ")" -ForegroundColor $Red
    return $false
  }
}

# verify target has analysis_states before proceeding
$env:PGPASSWORD = $PgPassword
$hasTable = docker exec -e PGPASSWORD=$PgPassword $Container psql -U $PgUser -d $PgDatabase -t -A -c "SELECT 1 FROM information_schema.tables WHERE table_name='analysis_states';" 2>&1
if (-not ($hasTable -match "1")) {
  Write-Host "  [SKIP] target database has no analysis_states table" -ForegroundColor $Yellow
  exit 0
}

# ══════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "=== AutoTFL DB Migration ===" -ForegroundColor $Cyan
Write-Host "  Migrations dir: $MigrationsDir" -ForegroundColor $Gray
Write-Host ""

$files = Get-ChildItem -Path $MigrationsDir -Filter "*.sql" -File | Sort-Object Name

if (-not $files -or $files.Count -eq 0) {
  Write-Host "  No migration files found." -ForegroundColor $Yellow
  Write-Host ""
  Write-Host "=== Done: nothing to apply ===" -ForegroundColor $Green
  Write-Host ""
  exit 0
}

$applied = 0
$skipped = 0
$failed  = 0

foreach ($f in $files) {
  $ok = Invoke-MigrationFile -FilePath $f.FullName -Label $f.Name
  if ($ok) {
    $applied++
  } else {
    $failed++
    Write-Host "  [ERR] Stopping: migration $($f.Name) failed" -ForegroundColor $Red
    break
  }
}

# ══════════════════════════════════════════════════════════════
Write-Host ""
$total = $applied + $failed
if ($failed -gt 0) {
  Write-Host "=== Migration FAILED ($applied ok, $failed failed) ===" -ForegroundColor $Red
  exit 1
} elseif ($applied -gt 0) {
  Write-Host "=== Done: $applied file(s) applied ===" -ForegroundColor $Green
} else {
  Write-Host "=== Done: database is up to date ===" -ForegroundColor $Green
}
Write-Host ""
