#!/bin/bash

# R Shiny医学数据分析应用 Docker镜像构建脚本
# 作者: AutoTFL
# 功能: 自动构建Docker镜像并将日志输出到log目录

set -e  # 遇到错误时退出

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检测是否在交互式终端中运行
if [ -t 0 ]; then
    INTERACTIVE=1
else
    INTERACTIVE=0
    echo -e "${BLUE}[INFO]${NC} 非交互式模式，使用默认值"
fi

# 创建日志目录
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# 生成带时间戳的日志文件名
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/build_log_$TIMESTAMP.log"

# 函数：打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# 开始记录
print_info "开始构建R Shiny医学数据分析应用Docker镜像"
print_info "日志文件: $LOG_FILE"
print_info "时间戳: $TIMESTAMP"

# 检查Docker是否已安装
if ! command -v docker &> /dev/null; then
    print_error "Docker未安装或未在PATH中找到"
    exit 1
fi

print_info "Docker已安装，版本: $(docker --version)"

# 检查Docker是否正在运行
if ! docker info &> /dev/null; then
    print_error "Docker守护进程未运行，请启动Docker服务"
    exit 1
fi

print_info "Docker服务正在运行"

# 检查Dockerfile是否存在
if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile不存在于当前目录"
    exit 1
fi

print_info "找到Dockerfile"

# 检查必要的文件
REQUIRED_FILES=("install_dependencies.R" "app.R" "run_app.R")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "必需文件 $file 不存在"
        exit 1
    fi
done

print_info "所有必需文件都存在"

# 设置镜像名称和标签
if [ $INTERACTIVE -eq 1 ]; then
    print_info "请输入镜像名称和标签（默认：autotfl-shiny-app:latest）"
    read -p "镜像名称 (默认为 autotfl-shiny-app): " IMAGE_NAME
    IMAGE_NAME=${IMAGE_NAME:-autotfl-shiny-app}
    read -p "镜像标签 (默认为 latest): " IMAGE_TAG
    IMAGE_TAG=${IMAGE_TAG:-latest}
else
    IMAGE_NAME="autotfl-shiny-app"
    IMAGE_TAG="latest"
    print_info "非交互式模式，使用默认镜像名称: $IMAGE_NAME:$IMAGE_TAG"
fi
FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"

# 设置容器端口
if [ $INTERACTIVE -eq 1 ]; then
    read -p "请输入容器映射端口 (默认为 3838): " PORT
    PORT=${PORT:-3838}
else
    PORT=3838
    print_info "非交互式模式，使用默认端口: $PORT"
fi
# 提供构建选项
if [ $INTERACTIVE -eq 1 ]; then
    print_info "可用的构建选项:"
    print_info "1) 构建新镜像 (默认)"
    print_info "2) 重新构建（不使用缓存）"
    print_info "3) 构建并推送镜像（如果需要）"
    print_info "4) 仅检查Dockerfile语法"

    read -p "请选择构建选项 (1-4, 默认为1): " BUILD_OPTION
    BUILD_OPTION=${BUILD_OPTION:-1}
else
    BUILD_OPTION=1
    print_info "非交互式模式，使用默认构建选项: 1 (构建新镜像)"
fi

case $BUILD_OPTION in
    1)
        print_info "开始构建Docker镜像: $FULL_IMAGE_NAME"
        BUILD_CMD="docker build -t $FULL_IMAGE_NAME ."
        ;;
    2)
        print_info "开始重新构建Docker镜像（不使用缓存）: $FULL_IMAGE_NAME"
        BUILD_CMD="docker build --no-cache -t $FULL_IMAGE_NAME ."
        ;;
    3)
        read -p "请输入要推送的仓库地址（留空则使用本地）: " REPO_URL
        if [ -z "$REPO_URL" ]; then
            REPO_URL=$FULL_IMAGE_NAME
        fi
        FULL_IMAGE_NAME="$REPO_URL:$IMAGE_TAG"
        print_info "开始构建并准备推送Docker镜像: $FULL_IMAGE_NAME"
        BUILD_CMD="docker build -t $FULL_IMAGE_NAME ."
        ;;
    4)
        print_info "检查Dockerfile语法..."
        if command -v dockerfile-utils &> /dev/null; then
            dockerfile-utils validate Dockerfile
            print_success "Dockerfile语法检查通过"
        else
            print_warning "dockerfile-utils未安装，跳过语法检查"
        fi
        exit 0
        ;;
    *)
        print_error "无效的选项，使用默认选项1"
        BUILD_CMD="docker build -t $FULL_IMAGE_NAME ."
        ;;
esac

# 执行构建命令
print_info "执行命令: $BUILD_CMD"
if eval "$BUILD_CMD" 2>&1 | tee -a "$LOG_FILE"; then
    print_success "Docker镜像构建成功: $FULL_IMAGE_NAME"
else
    print_error "Docker镜像构建失败"
    exit 1
fi

# 验证镜像是否创建成功
if docker images | grep -q "$IMAGE_NAME"; then
    print_info "验证: 镜像已成功创建"
    docker images | grep "$IMAGE_NAME" | tee -a "$LOG_FILE"
else
    print_error "验证失败: 镜像未找到"
    exit 1
fi

# 可选：运行容器测试
if [ $INTERACTIVE -eq 1 ]; then
    print_info "是否要运行容器测试? (y/n)"
    read -p "选择 (默认为n): " RUN_TEST
    RUN_TEST=${RUN_TEST:-n}
else
    RUN_TEST=n
    print_info "非交互式模式，跳过容器测试"
fi

if [ "$RUN_TEST" = "y" ] || [ "$RUN_TEST" = "Y" ]; then
    CONTAINER_NAME="test_${IMAGE_NAME}_${TIMESTAMP}"
    print_info "启动测试容器: $CONTAINER_NAME"
    
    # 运行容器并在后台运行
    docker run -d --name "$CONTAINER_NAME" -p $PORT:3838 "$FULL_IMAGE_NAME"
    
    # 等待几秒让应用启动
    print_info "等待应用启动..."
    sleep 10
    
    # 检查容器状态
    CONTAINER_STATUS=$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}" 2>/dev/null)
    if [[ "$CONTAINER_STATUS" == *"Up"* ]]; then
        print_success "容器启动成功: $CONTAINER_STATUS"
        print_info "应用可在 http://localhost:$PORT 访问"
        
        # 显示容器日志
        print_info "容器日志:"
        docker logs "$CONTAINER_NAME" 2>&1 | tee -a "$LOG_FILE"
    else
        print_error "容器启动失败或已停止"
        docker logs "$CONTAINER_NAME" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # 停止并删除测试容器
    print_info "停止测试容器"
    docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
    print_info "测试容器已清理"
fi

# 显示构建统计信息
print_info "构建统计信息:"
IMAGE_SIZE=$(docker inspect --format='{{.Size}}' "$FULL_IMAGE_NAME" 2>/dev/null)
if [ $? -eq 0 ]; then
    IMAGE_SIZE_HUMAN=$(numfmt --to=iec --format="%.2f" $IMAGE_SIZE 2>/dev/null || echo $IMAGE_SIZE)
    print_info "镜像大小: $IMAGE_SIZE_HUMAN ($IMAGE_SIZE 字节)"
fi

print_info "Docker镜像构建完成"
print_success "镜像: $FULL_IMAGE_NAME"
print_info "日志文件: $LOG_FILE"

print_info "要运行容器，请使用以下命令:"
print_info "docker run -p 3838:3838 $FULL_IMAGE_NAME"