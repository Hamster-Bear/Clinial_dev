@echo off
setlocal enabledelayedexpansion

echo Docker Image Builder for AutoTFL Shiny App
echo.

REM 设置默认值
set default_image=autotfl-shiny-app
set default_tag=latest
set default_port=3838

REM 提示输入，如果用户直接回车则使用默认值
set /p "image_name=Enter image name (default: %default_image%): "
if "!image_name!"=="" set image_name=%default_image%
set /p "image_tag=Enter image tag (default: %default_tag%): "
if "!image_tag!"=="" set image_tag=%default_tag%
set /p "port=Enter host port (default: %default_port%): "
if "!port!"=="" set port=%default_port%

echo.
echo Building image !image_name!:!image_tag! ...
echo.

docker build -t !image_name!:!image_tag! .
if errorlevel 1 (
    echo Build failed.
    echo Please check the error messages above.
    pause
    exit /b 1
)

echo Build successful.
echo.

set /p "run_test=Run test container? (y/n, default n): "
if /i "!run_test!"=="y" (
    echo Starting test container...
    docker run -d --name test_!image_name! -p !port!:3838 !image_name!:!image_tag!
    timeout /t 10 /nobreak >nul
    echo Container started. Access http://localhost:!port!
    echo Press any key to stop and remove container...
    pause >nul
    docker stop test_!image_name!
    docker rm test_!image_name!
    echo Test container cleaned up.
)

echo.
echo Deployment completed.
echo You can run the container manually with:
echo docker run -p !port!:3838 !image_name!:!image_tag!
pause