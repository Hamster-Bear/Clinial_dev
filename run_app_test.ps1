param(
  [string]$EnvFile = ".env.test",
  [string]$RScriptPath = "F:\R-4.5.3\bin\Rscript.exe"
)

function Resolve-ShinyPort {
  param(
    [string]$RawPort
  )

  if ([string]::IsNullOrWhiteSpace($RawPort)) {
    return 8109
  }

  $parsedPort = 0
  if (-not [int]::TryParse($RawPort, [ref]$parsedPort) -or $parsedPort -le 0 -or $parsedPort -gt 65535) {
    Write-Host "SHINY_PORT 无效: $RawPort，回退为 8109" -ForegroundColor Yellow
    return 8109
  }

  return $parsedPort
}

function Get-PortOwningProcesses {
  param(
    [int]$Port
  )

  @(Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
    Where-Object { $_.OwningProcess -gt 0 } |
    Select-Object -ExpandProperty OwningProcess -Unique)
}

function Stop-ProcessesByPort {
  param(
    [int]$Port
  )

  $processIds = Get-PortOwningProcesses -Port $Port
  if ($processIds.Count -eq 0) {
    Write-Host "端口 $Port 未被占用"
    return
  }

  Write-Host "检测到端口 $Port 已被占用，准备强制关闭相关进程..." -ForegroundColor Yellow
  foreach ($processId in $processIds) {
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($null -eq $process) {
      Write-Host ("进程 PID={0} 已不存在，跳过。" -f $processId) -ForegroundColor DarkGray
      continue
    }

    try {
      Write-Host ("停止进程 PID={0} Name={1}" -f $process.Id, $process.ProcessName)
      Stop-Process -Id $processId -Force -ErrorAction Stop
    } catch {
      if ($_.Exception.Message -match "Cannot find a process|找不到具有进程标识符") {
        Write-Host ("进程 PID={0} 已不存在，跳过。" -f $processId) -ForegroundColor DarkGray
      } else {
        Write-Host ("无法停止端口 {0} 对应进程 PID={1}: {2}" -f $Port, $processId, $_.Exception.Message) -ForegroundColor Red
        exit 1
      }
    }
  }

  Start-Sleep -Seconds 1
  $remainingProcessIds = Get-PortOwningProcesses -Port $Port
  if ($remainingProcessIds.Count -gt 0) {
    Write-Host ("端口 {0} 仍被占用，剩余 PID: {1}" -f $Port, ($remainingProcessIds -join ", ")) -ForegroundColor Red
    exit 1
  }

  Write-Host "端口 $Port 已释放"
}

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

$shinyPort = Resolve-ShinyPort -RawPort $env:SHINY_PORT

Write-Host "当前测试环境参数:"
Write-Host "POSTGRES_HOST=$env:POSTGRES_HOST"
Write-Host "POSTGRES_PORT=$env:POSTGRES_PORT"
Write-Host "POSTGRES_DB=$env:POSTGRES_DB"
Write-Host "POSTGRES_USER=$env:POSTGRES_USER"
Write-Host "APP_ADMIN_USERNAME=$env:APP_ADMIN_USERNAME"
Write-Host "APP_ADMIN_EMAIL=$env:APP_ADMIN_EMAIL"
Write-Host "SHINY_PORT=$shinyPort"
Write-Host "Rscript=$RScriptPath"

if (
  $env:POSTGRES_HOST -eq "localhost" -and
  $env:POSTGRES_PORT -ne "5432" -and
  ((Test-Path "docker-compose.local.yml") -or (Test-Path "docker-compose1.yml"))
) {
  Write-Host "警告: 若数据库由 docker-compose.local.yml 或 docker-compose1.yml 拉起，请确认 POSTGRES_PORT 使用 5432" -ForegroundColor Yellow
}

Stop-ProcessesByPort -Port $shinyPort

& $RScriptPath "run_app.R"
exit $LASTEXITCODE
