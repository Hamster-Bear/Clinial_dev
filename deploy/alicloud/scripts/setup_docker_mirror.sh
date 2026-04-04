#!/bin/bash
# 阿里云 Ubuntu 22.04 Docker 镜像加速源配置脚本
# 用于解决 "connection refused" 或 "dial tcp ... 443" 无法连接 Docker Hub 的问题

set -e

echo "=== 开始配置 Docker Registry 镜像加速 ==="

# 确保以 root 身份运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 或 root 用户运行此脚本"
  exit 1
fi

DOCKER_DAEMON_FILE="/etc/docker/daemon.json"
mkdir -p /etc/docker

# 备份原有配置
if [ -f "$DOCKER_DAEMON_FILE" ]; then
  echo "发现已有配置文件，备份为 ${DOCKER_DAEMON_FILE}.bak"
  cp "$DOCKER_DAEMON_FILE" "${DOCKER_DAEMON_FILE}.bak"
fi

# 写入新的镜像源（当前可用的公开加速源）
# 提示：公共镜像源由于政策原因可能会不稳定，如遇失效可更换。
# 更稳定的方案是使用阿里云私有镜像服务 (ACR) 或自建 Proxy。
echo "正在写入配置文件 $DOCKER_DAEMON_FILE ..."
cat > "$DOCKER_DAEMON_FILE" << 'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://dockerpull.com",
    "https://docker.1panel.live",
    "https://hub-mirror.c.163.com",
    "https://registry.cn-hangzhou.aliyuncs.com"
  ],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

echo "配置写入完成，正在重启 Docker 服务..."
systemctl daemon-reload
systemctl restart docker

echo "=== 配置完成 ==="
echo "您可以使用 'docker info | grep -i mirrors -A 5' 验证是否生效。"
echo "现在可以重试 docker compose 命令拉取镜像了。"
