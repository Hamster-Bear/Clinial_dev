param(
  [string]$EnvFile = ".env.test",
  [string]$RScriptPath = "F:\R-4.5.3\bin\Rscript.exe",
  [string]$ManifestPath = "tests/common/auth/auth_regression_manifest.json"
)

$ErrorActionPreference = "Stop"

function Load-EnvFile {
  param(
    [string]$FilePath
  )

  if (-not (Test-Path $FilePath)) {
    Write-Host "未找到环境文件: $FilePath" -ForegroundColor Red
    Write-Host "请先复制 .env.test.example 为 .env.test 并填写参数" -ForegroundColor Yellow
    exit 1
  }

  Get-Content $FilePath | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $idx = $line.IndexOf("=")
    if ($idx -lt 1) { return }
    $key = $line.Substring(0, $idx).Trim()
    $val = $line.Substring($idx + 1).Trim()
    [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
  }
}

function Assert-RequiredEnvVars {
  param(
    [string[]]$Keys
  )

  $missing = @()
  foreach ($key in $Keys) {
    if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable($key, "Process"))) {
      $missing += $key
    }
  }

  if ($missing.Count -gt 0) {
    Write-Host ("缺少必要环境变量: {0}" -f ($missing -join ", ")) -ForegroundColor Red
    Write-Host "请完善 .env.test 后再执行账号模块回归测试" -ForegroundColor Yellow
    exit 1
  }
}

function Invoke-RTestScript {
  param(
    [string]$ScriptPath
  )

  if (-not (Test-Path $ScriptPath)) {
    Write-Host "未找到测试脚本: $ScriptPath" -ForegroundColor Red
    exit 1
  }

  Write-Host ("`n>>> 执行测试: {0}" -f $ScriptPath) -ForegroundColor Cyan
  & $RScriptPath $ScriptPath
  if ($LASTEXITCODE -ne 0) {
    Write-Host ("测试失败: {0}" -f $ScriptPath) -ForegroundColor Red
    exit $LASTEXITCODE
  }
}

function Get-TestScriptsFromManifest {
  param(
    [string]$FilePath
  )

  if (-not (Test-Path $FilePath)) {
    Write-Host "未找到认证回归清单: $FilePath" -ForegroundColor Red
    exit 1
  }

  $manifestText = Get-Content $FilePath -Raw -Encoding UTF8
  $manifest = $manifestText | ConvertFrom-Json
  if ($null -eq $manifest -or $null -eq $manifest.tests -or $manifest.tests.Count -eq 0) {
    Write-Host "认证回归清单为空或格式无效，请检查 auth_regression_manifest.json" -ForegroundColor Red
    exit 1
  }

  $scripts = @()
  foreach ($item in $manifest.tests) {
    if ([string]::IsNullOrWhiteSpace($item.path)) {
      Write-Host "认证回归清单存在空路径条目，请检查 auth_regression_manifest.json" -ForegroundColor Red
      exit 1
    }
    $scripts += $item.path
  }
  return $scripts
}

if (-not (Test-Path $RScriptPath)) {
  Write-Host "未找到 Rscript 可执行文件: $RScriptPath" -ForegroundColor Red
  exit 1
}

Load-EnvFile -FilePath $EnvFile

Assert-RequiredEnvVars -Keys @(
  "POSTGRES_HOST",
  "POSTGRES_PORT",
  "POSTGRES_DB",
  "POSTGRES_USER",
  "POSTGRES_PASSWORD",
  "APP_ADMIN_USERNAME",
  "APP_ADMIN_EMAIL",
  "APP_ADMIN_PASSWORD"
)

Write-Host "当前账号模块回归环境:"
Write-Host "POSTGRES_HOST=$env:POSTGRES_HOST"
Write-Host "POSTGRES_PORT=$env:POSTGRES_PORT"
Write-Host "POSTGRES_DB=$env:POSTGRES_DB"
Write-Host "POSTGRES_USER=$env:POSTGRES_USER"
Write-Host "APP_ADMIN_USERNAME=$env:APP_ADMIN_USERNAME"
Write-Host "APP_ADMIN_EMAIL=$env:APP_ADMIN_EMAIL"
Write-Host "AUTH_REQUIRE_EMAIL_VERIFICATION=$env:AUTH_REQUIRE_EMAIL_VERIFICATION"
Write-Host "EMAIL_DELIVERY_MODE=$env:EMAIL_DELIVERY_MODE"
Write-Host "EMAIL_FROM_ADDRESS=$env:EMAIL_FROM_ADDRESS"
Write-Host "SMTP_HOST=$env:SMTP_HOST"
Write-Host "SMTP_PORT=$env:SMTP_PORT"
Write-Host "AUTH_DEV_SHOW_EMAIL_CODE=$env:AUTH_DEV_SHOW_EMAIL_CODE"
Write-Host "AUTH_PASSWORD_RESET_EXPIRE_MINUTES=$env:AUTH_PASSWORD_RESET_EXPIRE_MINUTES"
Write-Host "AUTH_REGRESSION_MANIFEST=$ManifestPath"
Write-Host "Rscript=$RScriptPath"

$testScripts = Get-TestScriptsFromManifest -FilePath $ManifestPath

foreach ($script in $testScripts) {
  Invoke-RTestScript -ScriptPath $script
}

Write-Host "`n账号模块回归测试全部通过。" -ForegroundColor Green
exit 0

