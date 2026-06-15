<#
.SYNOPSIS
  AutoTFL 发布脚本 (交互式 CLI)
.DESCRIPTION
  无需命令行参数，启动后通过菜单选择发布选项。
  流程: 选择服务器 → 选择模式 → 确认 → 执行
#>

$ErrorActionPreference = "Stop"
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir    = Resolve-Path "$ScriptDir\..\..\.."
$AppsDir    = "$RootDir\apps"
$RemoteRoot = "/opt/hamster-analysis/current"
$RemoteApps = "$RemoteRoot/apps"
$ImageName  = "autotfl-shiny-app:latest"
$BundlePre  = "autotfl-offline-bundle"
$BaseImages = @("postgres:14-alpine", "redis:7-alpine", "nginx:1.27-alpine")

# ── 已知服务器列表 ────────────────────────────────────────────
$KnownServers = @(
  @{ Label = "阿里云生产 (223.4.178.138)";  Target = "root@223.4.178.138" }
  @{ Label = "自定义输入";                  Target = "__CUSTOM__" }
)

# ══════════════════════════════════════════════════════════════
#  UI helpers
# ══════════════════════════════════════════════════════════════
$C  = "Cyan"
$G  = "Green"
$Y  = "Yellow"
$W  = "White"
$R  = "Red"
$Gr = "DarkGray"

function c { param([string]$t, [string]$color = $W) Write-Host $t -ForegroundColor $color }
function banner {
  Clear-Host
  c ""
  c "  ╔══════════════════════════════════════════╗" $C
  c "  ║     AutoTFL 快速发布工具                 ║" $C
  c "  ╚══════════════════════════════════════════╝" $C
  c ""
}

function menu {
  param([string]$title, [string[]]$items)
  c "  $title" $Y
  for ($i = 0; $i -lt $items.Count; $i++) {
    $n = $i + 1
    c "    [$n] $($items[$i])"
  }
  c ""
  while ($true) {
    $choice = Read-Host "  请选择 [1-$($items.Count)]"
    $idx = -1
    if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $items.Count) {
      return $idx - 1
    }
    c "  输入无效，请重新选择" $Y
  }
}

function confirm {
  param([string]$msg)
  c "  $msg" $Y
  $ans = Read-Host "  确认执行? [Y/n]"
  return ($ans -eq "" -or $ans -eq "y" -or $ans -eq "Y")
}

function info   { param([string]$t) c "  [*] $t" $Gr }
function ok     { param([string]$t) c "  [OK] $t" $G }
function warn   { param([string]$t) c "  [!!] $t" $Y }
function fail   { param([string]$t) c "  [ERR] $t" $R; throw $t }

# ══════════════════════════════════════════════════════════════
#  交互式选择流程
# ══════════════════════════════════════════════════════════════

banner

# ── Step 1: 选择服务器 ────────────────────────────────────────
$serverLabels = $KnownServers | ForEach-Object { $_.Label }
$serverIdx = menu "选择目标服务器:" $serverLabels
if ($KnownServers[$serverIdx].Target -eq "__CUSTOM__") {
  $Server = Read-Host "  输入服务器地址 (如 root@1.2.3.4)"
  if (-not $Server) { fail "服务器地址不能为空" }
} else {
  $Server = $KnownServers[$serverIdx].Target
}
c ""

# ── Step 2: 选择发布模式 ──────────────────────────────────────
$modes = @(
  "完整发布 (构建 → 打包 → 上传 → 远端部署)",
  "仅构建打包 (不执行上传和部署)",
  "构建 + 上传 (上传后不自动部署)",
  "复用已有 tar 包 (跳过构建，直接上传部署)",
  "仅远端部署 (tar 已在服务器上，直接 load + compose up)"
)
$modeIdx = menu "选择发布模式:" $modes

$SkipUpload       = ($modeIdx -eq 1)
$SkipRemoteDeploy = ($modeIdx -eq 2)
$UseLatestTar     = ($modeIdx -eq 3)
$RemoteDeployOnly = ($modeIdx -eq 4)
$SkipBasePull     = $false
c ""

# ── Step 3: 确认 ──────────────────────────────────────────────
if ($RemoteDeployOnly) {
  info "目标服务器: $Server"
  info "模式: 仅远端部署（跳过构建和上传）"
  # 远端路径 —— 默认值，支持用户自定义
  $customPath = Read-Host "  远端 tar 包路径 [回车默认: $RemoteApps]"
  if ($customPath) { $RemoteApps = $customPath }
  # 列出服务器上已有的 tar 包
  info "查询: $Server`:$RemoteApps"
  $remoteTars = ssh $sshOpts $Server "ls -1t '$RemoteApps'/*.tar 2>/dev/null || echo ''" 2>$null
  if (-not $remoteTars -or $remoteTars -notmatch "\.tar") {
    c ""
    c "  [!!] 未找到 .tar 包，请检查:" $Y
    c "      1. SSH 是否能连接: ssh $Server" $Y
    c "      2. 远端路径是否正确: $RemoteApps" $Y
    c "      3. 是否已有 tar 包上传到该路径" $Y
    c ""
    $manualFallback = Read-Host "  手动输入 tar 文件名或完整路径 (取消按 Ctrl+C)"
    if ($manualFallback -match "/") {
      $bundleFullPath = $manualFallback
      $bundleLeaf = Split-Path $manualFallback -Leaf
    } else {
      $bundleFullPath = "$RemoteApps/$manualFallback"
      $bundleLeaf = $manualFallback
    }
  } else {
    $tarLines = @($remoteTars -split "`n" | Where-Object { $_ -match "\.tar$" } | Select-Object -First 10)
    c ""
    c "  服务器上最近的 tar 包:" $Y
    for ($i = 0; $i -lt $tarLines.Count; $i++) {
      c "    [$($i+1)] $(Split-Path $tarLines[$i] -Leaf)"
    }
    c "    [N] 手动输入文件名"
    c ""
    $choice = Read-Host "  选择要部署的包 [1-$($tarLines.Count)/N]"
    if ($choice -eq "N" -or $choice -eq "n") {
      $manualName = Read-Host "  输入 tar 文件名或完整路径"
      if ($manualName -match "/") {
        $bundleFullPath = $manualName
        $bundleLeaf = Split-Path $manualName -Leaf
      } else {
        $bundleFullPath = "$RemoteApps/$manualName"
        $bundleLeaf = $manualName
      }
    } else {
      $idx = [int]$choice
      if ($idx -ge 1 -and $idx -le $tarLines.Count) {
        $bundleFullPath = $tarLines[$idx-1]
        $bundleLeaf = Split-Path $tarLines[$idx-1] -Leaf
      } else {
        $bundleFullPath = $tarLines[0]
        $bundleLeaf = Split-Path $tarLines[0] -Leaf
      }
    }
  }
  info "将部署: $bundleLeaf"
} elseif ($UseLatestTar) {
  $latest = Get-ChildItem "$AppsDir\$BundlePre*.tar" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($latest) {
    $bundlePath = $latest.FullName
    info "将复用: $($latest.Name) ($([math]::Round($latest.Length/1MB,1)) MB)"
  } else {
    fail "apps/ 目录下没有找到 $BundlePre*.tar 包，请先执行一次完整构建"
  }
} else {
  info "将构建镜像: $ImageName"
}

if (-not $SkipUpload -and -not $RemoteDeployOnly) {
  info "目标服务器: $Server"
  info "远端路径:   $RemoteApps"
  if ($SkipRemoteDeploy) {
    warn "上传后不会自动部署，需手动执行远端 compose up"
  }
} elseif ($SkipUpload) {
  warn "仅本地构建打包，不执行上传"
}

$sshOpts = "-o ConnectTimeout=5"
$shhTest = $false
if (-not $SkipUpload -or $RemoteDeployOnly) {
  $shhTest = ssh $sshOpts $Server "echo ok" 2>$null
  if ($shhTest -match "ok") {
    ok "SSH 可达: $Server"
  } else {
    warn "SSH 连接测试超时，请检查网络和服务器地址"
  }
}

if (-not (confirm "以上配置正确？")) {
  c "  已取消" $Y
  exit 0
}

# ══════════════════════════════════════════════════════════════
#  执行
# ══════════════════════════════════════════════════════════════

c ""
c "  ═══ 开始执行 ═══" $C
c ""

# ══════════════════════════════════════════════════════════════
#  执行
# ══════════════════════════════════════════════════════════════

c ""
c "  ═══ 开始执行 ═══" $C
c ""

# ── 1. 基础镜像 (非远端部署模式) ──────────────────────────────
if (-not $RemoteDeployOnly -and -not $SkipBasePull) {
  foreach ($img in $BaseImages) {
    $exists = docker image inspect $img 2>$null
    if (-not $exists) {
      info "拉取基础镜像: $img"
      docker pull $img
    }
  }
}

# ── 2. 构建 / 复用 tar (非远端部署模式) ────────────────────────
if (-not $RemoteDeployOnly) {
  New-Item -ItemType Directory -Force -Path $AppsDir | Out-Null

  if ($UseLatestTar) {
    ok "复用: $(Split-Path $bundlePath -Leaf)"
  } else {
    $stamp      = Get-Date -Format "yyyyMMdd_HHmmss"
    $bundleName = "${BundlePre}_${stamp}.tar"
    $bundlePath = "$AppsDir\$bundleName"

    info "开始 Docker 构建..."
    docker build -t $ImageName $RootDir
    if ($LASTEXITCODE -ne 0) { fail "docker build 失败" }
    ok "镜像构建完成"

    info "导出离线包 (可能需要几分钟)..."
    docker save -o $bundlePath $ImageName $BaseImages
    if ($LASTEXITCODE -ne 0) { fail "docker save 失败" }
    $sizeMB = [math]::Round((Get-Item $bundlePath).Length / 1MB, 1)
    ok "导出: $bundleName ($sizeMB MB)"
  }

  if ($SkipUpload) {
    ok "完成 (仅本地构建)"
    exit 0
  }
}

# ── 3. 上传 (非远端部署模式) ──────────────────────────────────
if (-not $RemoteDeployOnly) {
  info "上传到 $Server ..."
  ssh $sshOpts $Server "mkdir -p '$RemoteRoot' '$RemoteApps'"
  if ($LASTEXITCODE -ne 0) { fail "SSH 连接失败" }

  $bundleLeaf = Split-Path $bundlePath -Leaf
  scp $bundlePath ${Server}:${RemoteApps}/
  if ($LASTEXITCODE -ne 0) { fail "上传失败" }
  ok "上传完成"

  if ($SkipRemoteDeploy) {
    ok "完成 (上传后未自动部署)"
    exit 0
  }
}

# ── 4. 远端部署 ──────────────────────────────────────────────
info "远端导入镜像并启动服务..."
$remoteCmd = @"
set -e
cd '$RemoteRoot'
bash deploy/alicloud/scripts/init_env.sh >/dev/null 2>&1
docker load -i '$($bundleFullPath ?? "$RemoteApps/$bundleLeaf")'
docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml up -d --pull never
echo '---CONTAINERS---'
docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml ps
"@

ssh $sshOpts $Server $remoteCmd
if ($LASTEXITCODE -ne 0) { fail "远端部署失败" }

c ""
c "  ═══ 部署完成 ═══" $G
c ""
