param(
  [string]$EnvFile = ".env.test",
  [string]$RScriptPath = "F:\R-4.5.3\bin\Rscript.exe"
)

if (-not (Test-Path $EnvFile)) {
  Write-Host "未找到环境文件: $EnvFile"
  Write-Host "请先复制 .env.test.example 为 .env.test 并填写参数"
  exit 1
}

Get-Content $EnvFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq "") { return }
  $idx = $line.IndexOf("=")
  if ($idx -lt 1) { return }
  $key = $line.Substring(0, $idx).Trim()
  $val = $line.Substring($idx + 1).Trim()
  [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
}

Write-Host "当前测试环境参数:"
Write-Host "POSTGRES_HOST=$env:POSTGRES_HOST"
Write-Host "POSTGRES_PORT=$env:POSTGRES_PORT"
Write-Host "POSTGRES_DB=$env:POSTGRES_DB"
Write-Host "POSTGRES_USER=$env:POSTGRES_USER"
Write-Host "Rscript=$RScriptPath"

& $RScriptPath "run_app.R"
exit $LASTEXITCODE
