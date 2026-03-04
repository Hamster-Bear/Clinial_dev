#!/usr/bin/env pwsh
# R Shiny医学数据分析应用 Docker镜像构建脚本 (PowerShell版本)
# 作者: AutoTFL
# 功能: 自动构建Docker镜像并将日志输出到log目录

# 设置UTF-8编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 定义颜色输出函数
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# 创建日志目录
$LogDir = "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# 生成带时间戳的日志文件名
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "build_log_$Timestamp.log"

# 开始记录
Write-Info "开始构建R Shiny医学数据分析应用Docker镜像"
Write-Info "日志文件: $LogFile"
Write-Info "时间戳: $Timestamp"

# 检查Docker是否已安装
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker未安装或未在PATH中找到"
    exit 1
}

Write-Info "Docker已安装，版本: $(docker --version)"

# 检查Docker是否正在运行
try {
    docker info 2>&1 | Out-Null
} catch {
    Write-Error "Docker守护进程未运行，请启动Docker Desktop或服务"
    exit 1
}

Write-Info "Docker服务正在运行"

# 检查Dockerfile是否存在
if (-not (Test-Path "Dockerfile")) {
    Write-Error "Dockerfile不存在于当前目录"
    exit 1
}

Write-Info "找到Dockerfile"

# 检查必要的文件
$RequiredFiles = @("install_dependencies.R", "app.R", "run_app.R")
foreach ($file in $RequiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Error "必需文件 $file 不存在"
        exit 1
    }
}
Write-Info "所有必需文件都存在"

# 提示输入镜像名称和标签
Write-Info "请输入镜像名称和标签（默认：autotfl-shiny-app:latest）"
$ImageName = Read-Host "镜像名称 (默认为 autotfl-shiny-app)"
if ([string]::IsNullOrWhiteSpace($ImageName)) { $ImageName = "autotfl-shiny-app" }
$ImageTag = Read-Host "镜像标签 (默认为 latest)"
if ([string]::IsNullOrWhiteSpace($ImageTag)) { $ImageTag = "latest" }
$FullImageName = "${ImageName}:${ImageTag}"

# 提示输入容器映射端口
$Port = Read-Host "请输入容器映射端口 (默认为 3838)"
if ([string]::IsNullOrWhiteSpace($Port)) { $Port = "3838" }

# 提供构建选项
Write-Info "可用的构建选项:"
Write-Info "1) 构建新镜像 (默认)"
Write-Info "2) 重新构建（不使用缓存）"
Write-Info "3) 构建并推送镜像（如果需要）"
Write-Info "4) 仅检查Dockerfile语法"
$BuildOption = Read-Host "请选择构建选项 (1-4, 默认为1)"
if ([string]::IsNullOrWhiteSpace($BuildOption)) { $BuildOption = "1" }

switch ($BuildOption) {
    "1" {
        Write-Info "开始构建Docker镜像: $FullImageName"
        $BuildCmd = "docker build -t $FullImageName ."
    }
    "2" {
        Write-Info "开始重新构建Docker镜像（不使用缓存）: $FullImageName"
        $BuildCmd = "docker build --no-cache -t $FullImageName ."
    }
    "3" {
        $RepoUrl = Read-Host "请输入要推送的仓库地址（留空则使用本地）"
        if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
            $RepoUrl = $FullImageName
        }
        $FullImageName = "${RepoUrl}:${ImageTag}"
        Write-Info "开始构建并准备推送Docker镜像: $FullImageName"
        $BuildCmd = "docker build -t $FullImageName ."
    }
    "4" {
        Write-Info "检查Dockerfile语法..."
        if (Get-Command dockerfile-utils -ErrorAction SilentlyContinue) {
            dockerfile-utils validate Dockerfile
            Write-Success "Dockerfile语法检查通过"
        } else {
            Write-Warning "dockerfile-utils未安装，跳过语法检查"
        }
        exit 0
    }
    default {
        Write-Warning "无效的选项，使用默认选项1"
        $BuildCmd = "docker build -t $FullImageName ."
    }
}

# 执行构建命令
Write-Info "执行命令: $BuildCmd"
try {
    Invoke-Expression $BuildCmd 2>&1 | Tee-Object -FilePath $LogFile -Append
    Write-Success "Docker镜像构建成功: $FullImageName"
} catch {
    Write-Error "Docker镜像构建失败"
    exit 1
}

# 验证镜像是否创建成功
$Images = docker images --format "{{.Repository}}:{{.Tag}}" 2>&1
if ($Images -contains $FullImageName) {
    Write-Info "验证: 镜像已成功创建"
    docker images | Select-String $ImageName | Out-Host
} else {
    Write-Error "验证失败: 镜像未找到"
    exit 1
}

# 可选：运行容器测试
$RunTest = Read-Host "是否要运行容器测试? (y/n, 默认为n)"
if ($RunTest -eq 'y' -or $RunTest -eq 'Y') {
    $ContainerName = "test_${ImageName}_${Timestamp}"
    Write-Info "启动测试容器: $ContainerName"
    
    # 运行容器并在后台运行
    docker run -d --name $ContainerName -p ${Port}:3838 $FullImageName 2>&1 | Out-Null
    
    # 等待几秒让应用启动
    Write-Info "等待应用启动..."
    Start-Sleep -Seconds 10
    
    # 检查容器状态
    $ContainerStatus = docker ps --filter "name=$ContainerName" --format "{{.Status}}" 2>&1
    if ($ContainerStatus -match "Up") {
        Write-Success "容器启动成功: $ContainerStatus"
        Write-Info "应用可在 http://localhost:${Port} 访问"
        
        # 显示容器日志
        Write-Info "容器日志:"
        docker logs $ContainerName 2>&1 | Out-Host
    } else {
        Write-Error "容器启动失败或已停止"
        docker logs $ContainerName 2>&1 | Out-Host
    }
    
    # 停止并删除测试容器
    Write-Info "停止测试容器"
    docker stop $ContainerName 2>&1 | Out-Null
    docker rm $ContainerName 2>&1 | Out-Null
    Write-Info "测试容器已清理"
}

# 显示构建统计信息
Write-Info "构建统计信息:"
try {
    $ImageSize = docker inspect --format='{{.Size}}' $FullImageName 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ImageSizeHuman = if ($ImageSize -ge 1GB) {
            "{0:N2} GB" -f ($ImageSize / 1GB)
        } elseif ($ImageSize -ge 1MB) {
            "{0:N2} MB" -f ($ImageSize / 1MB)
        } else {
            "{0:N2} KB" -f ($ImageSize / 1KB)
        }
        Write-Info "镜像大小: $ImageSizeHuman ($ImageSize 字节)"
    }
} catch {}

Write-Info "Docker镜像构建完成"
Write-Success "镜像: $FullImageName"
Write-Info "日志文件: $LogFile"

Write-Info "要运行容器，请使用以下命令:"
Write-Info "docker run -p ${Port}:3838 $FullImageName"