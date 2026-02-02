@echo off
REM R Shiny医学数据分析应用 Docker镜像构建脚本 (Windows版本)
REM 作者: AutoTFL
REM 功能: 自动构建Docker镜像并将日志输出到log目录

setlocal enabledelayedexpansion

REM 设置颜色代码 (仅在支持的终端中有效)
for /F "delims= eol=:" %%i in ('"prompt $H & echo on & for %%j in (1) do rem"') do set "BS=%%i"

REM 创建日志目录
if not exist "logs" mkdir logs

REM 生成带时间戳的日志文件名
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "TIMESTAMP=%YYYY%%MM%%DD%_%HH%%Min%%Sec%"

set "LOG_FILE=logs\build_log_%TIMESTAMP%.log"

REM 开始记录
echo [INFO] 开始构建R Shiny医学数据分析应用Docker镜像 >> "!LOG_FILE!"
echo [INFO] 日志文件: !LOG_FILE! >> "!LOG_FILE!"
echo [INFO] 时间戳: %TIMESTAMP% >> "!LOG_FILE!"
echo [INFO] 开始构建R Shiny医学数据分析应用Docker镜像
echo [INFO] 日志文件: !LOG_FILE!
echo [INFO] 时间戳: %TIMESTAMP%

REM 检查Docker是否已安装
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker未安装或未在PATH中找到 >> "!LOG_FILE!"
    echo [ERROR] Docker未安装或未在PATH中找到
    exit /b 1
) else (
    for /f "usebackq tokens=*" %%i in (`docker --version`) do set "DOCKER_VERSION=%%i"
    echo [INFO] Docker已安装，版本: !DOCKER_VERSION! >> "!LOG_FILE!"
    echo [INFO] Docker已安装，版本: !DOCKER_VERSION!
)

REM 检查Docker是否正在运行
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker守护进程未运行，请启动Docker Desktop或服务 >> "!LOG_FILE!"
    echo [ERROR] Docker守护进程未运行，请启动Docker Desktop或服务
    exit /b 1
) else (
    echo [INFO] Docker服务正在运行 >> "!LOG_FILE!"
    echo [INFO] Docker服务正在运行
)

REM 检查Dockerfile是否存在
if not exist "Dockerfile" (
    echo [ERROR] Dockerfile不存在于当前目录 >> "!LOG_FILE!"
    echo [ERROR] Dockerfile不存在于当前目录
    exit /b 1
) else (
    echo [INFO] 找到Dockerfile >> "!LOG_FILE!"
    echo [INFO] 找到Dockerfile
)

REM 检查必要的文件
set "REQUIRED_FILES=install_dependencies.R app.R run_app.R"
for %%f in (%REQUIRED_FILES%) do (
    if not exist "%%f" (
        echo [ERROR] 必需文件 %%f 不存在 >> "!LOG_FILE!"
        echo [ERROR] 必需文件 %%f 不存在
        exit /b 1
    )
)
echo [INFO] 所有必需文件都存在 >> "!LOG_FILE!"
echo [INFO] 所有必需文件都存在

REM 设置镜像名称和标签
set "IMAGE_NAME=autotfl-shiny-app"
set "IMAGE_TAG=latest"
set "FULL_IMAGE_NAME=!IMAGE_NAME!:!IMAGE_TAG!"

REM 提供构建选项
echo [INFO] 可用的构建选项: >> "!LOG_FILE!"
echo [INFO] 可用的构建选项:
echo [INFO] 1) 构建新镜像 (默认) >> "!LOG_FILE!"
echo [INFO] 1) 构建新镜像 (默认):
echo [INFO] 2) 重新构建（不使用缓存） >> "!LOG_FILE!"
echo [INFO] 2) 重新构建（不使用缓存）:
echo [INFO] 3) 构建并推送镜像（如果需要） >> "!LOG_FILE!"
echo [INFO] 3) 构建并推送镜像（如果需要）:
set /p BUILD_OPTION="请选择构建选项 (1-3, 默认为1): "

if "!BUILD_OPTION!"=="" set "BUILD_OPTION=1"

if "!BUILD_OPTION!"=="1" (
    echo [INFO] 开始构建Docker镜像: !FULL_IMAGE_NAME! >> "!LOG_FILE!"
    echo [INFO] 开始构建Docker镜像: !FULL_IMAGE_NAME!
    set "BUILD_CMD=docker build -t !FULL_IMAGE_NAME! ."
) else if "!BUILD_OPTION!"=="2" (
    echo [INFO] 开始重新构建Docker镜像（不使用缓存）: !FULL_IMAGE_NAME! >> "!LOG_FILE!"
    echo [INFO] 开始重新构建Docker镜像（不使用缓存）: !FULL_IMAGE_NAME!
    set "BUILD_CMD=docker build --no-cache -t !FULL_IMAGE_NAME! ."
) else if "!BUILD_OPTION!"=="3" (
    set /p REPO_URL="请输入要推送的仓库地址（留空则使用本地）: "
    if "!REPO_URL!"=="" set "REPO_URL=!IMAGE_NAME!"
    set "FULL_IMAGE_NAME=!REPO_URL!:!IMAGE_TAG!"
    echo [INFO] 开始构建并准备推送Docker镜像: !FULL_IMAGE_NAME! >> "!LOG_FILE!"
    echo [INFO] 开始构建并准备推送Docker镜像: !FULL_IMAGE_NAME!
    set "BUILD_CMD=docker build -t !FULL_IMAGE_NAME! ."
) else (
    echo [ERROR] 无效的选项，使用默认选项1 >> "!LOG_FILE!"
    echo [ERROR] 无效的选项，使用默认选项1
    set "BUILD_CMD=docker build -t !FULL_IMAGE_NAME! ."
)

REM 执行构建命令
echo [INFO] 执行命令: !BUILD_CMD! >> "!LOG_FILE!"
echo [INFO] 执行命令: !BUILD_CMD!
!BUILD_CMD! 2>&1 | tee -a "!LOG_FILE!"

REM 检查构建结果
if errorlevel 1 (
    echo [ERROR] Docker镜像构建失败 >> "!LOG_FILE!"
    echo [ERROR] Docker镜像构建失败
    exit /b 1
) else (
    echo [SUCCESS] Docker镜像构建成功: !FULL_IMAGE_NAME! >> "!LOG_FILE!"
    echo [SUCCESS] Docker镜像构建成功: !FULL_IMAGE_NAME!
)

REM 验证镜像是否创建成功
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" --filter "reference=!IMAGE_NAME!" > temp_images.txt
if exist temp_images.txt (
    set "IMAGE_EXISTS=0"
    for /f "skip=1 tokens=*" %%a in (temp_images.txt) do (
        if not "%%a"=="" set "IMAGE_EXISTS=1"
    )
    if "!IMAGE_EXISTS!"=="1" (
        echo [INFO] 验证: 镜像已成功创建 >> "!LOG_FILE!"
        echo [INFO] 验证: 镜像已成功创建
        type temp_images.txt >> "!LOG_FILE!"
        type temp_images.txt
    ) else (
        echo [ERROR] 验证失败: 镜像未找到 >> "!LOG_FILE!"
        echo [ERROR] 验证失败: 镜像未找到
    )
    del temp_images.txt
) else (
    echo [ERROR] 验证失败: 无法获取镜像列表 >> "!LOG_FILE!"
    echo [ERROR] 验证失败: 无法获取镜像列表
)

REM 可选：运行容器测试
set /p RUN_TEST="是否要运行容器测试? (y/n, 默认为n): "
if /i "!RUN_TEST!"=="y" (
    set "CONTAINER_NAME=test_!IMAGE_NAME!_%TIMESTAMP%"
    echo [INFO] 启动测试容器: !CONTAINER_NAME! >> "!LOG_FILE!"
    echo [INFO] 启动测试容器: !CONTAINER_NAME!
    
    REM 运行容器并在后台运行
    docker run -d --name "!CONTAINER_NAME!" -p 3838:3838 "!FULL_IMAGE_NAME!" >nul
    
    REM 等待几秒让应用启动
    echo [INFO] 等待应用启动... >> "!LOG_FILE!"
    echo [INFO] 等待应用启动...
    timeout /t 10 /nobreak >nul
    
    REM 检查容器状态
    for /f "skip=1 tokens=*" %%a in ('docker ps --format "table {{.Names}}\t{{.Status}}" ^| findstr "!CONTAINER_NAME!"') do (
        set "CONTAINER_STATUS=%%a"
    )
    if not "!CONTAINER_STATUS!"=="" (
        if not "!CONTAINER_STATUS!"=="!CONTAINER_NAME!  Exited (0) " (
            echo [SUCCESS] 容器启动成功: !CONTAINER_STATUS! >> "!LOG_FILE!"
            echo [SUCCESS] 容器启动成功: !CONTAINER_STATUS!
            echo [INFO] 应用可在 http://localhost:3838 访问 >> "!LOG_FILE!"
            echo [INFO] 应用可在 http://localhost:3838 访问
        ) else (
            echo [ERROR] 容器已退出 >> "!LOG_FILE!"
            echo [ERROR] 容器已退出
        )
        
        REM 显示容器日志
        echo [INFO] 容器日志: >> "!LOG_FILE!"
        echo [INFO] 容器日志:
        docker logs "!CONTAINER_NAME!" >> "!LOG_FILE!"
        docker logs "!CONTAINER_NAME!"
    ) else (
        echo [ERROR] 无法获取容器状态 >> "!LOG_FILE!"
        echo [ERROR] 无法获取容器状态
    )
    
    REM 停止并删除测试容器
    echo [INFO] 停止测试容器 >> "!LOG_FILE!"
    echo [INFO] 停止测试容器
    docker stop "!CONTAINER_NAME!" >nul 2>&1
    docker rm "!CONTAINER_NAME!" >nul 2>&1
    echo [INFO] 测试容器已清理 >> "!LOG_FILE!"
    echo [INFO] 测试容器已清理
)

REM 显示构建统计信息
echo [INFO] 构建统计信息: >> "!LOG_FILE!"
echo [INFO] 构建统计信息:
for /f "skip=1 tokens=3" %%a in ('docker images --format "table {{.Size}}" --filter "reference=!IMAGE_NAME!"') do (
    set "IMAGE_SIZE=%%a"
    echo [INFO] 镜像大小: !IMAGE_SIZE! >> "!LOG_FILE!"
    echo [INFO] 镜像大小: !IMAGE_SIZE!
    goto :size_done
)
:size_done

echo [INFO] Docker镜像构建完成 >> "!LOG_FILE!"
echo [INFO] Docker镜像构建完成
echo [SUCCESS] 镜像: !FULL_IMAGE_NAME! >> "!LOG_FILE!"
echo [SUCCESS] 镜像: !FULL_IMAGE_NAME!
echo [INFO] 日志文件: !LOG_FILE! >> "!LOG_FILE!"
echo [INFO] 日志文件: !LOG_FILE!

echo [INFO] 要运行容器，请使用以下命令: >> "!LOG_FILE!"
echo [INFO] 要运行容器，请使用以下命令:
echo docker run -p 3838:3838 !FULL_IMAGE_NAME! >> "!LOG_FILE!"
echo docker run -p 3838:3838 !FULL_IMAGE_NAME!