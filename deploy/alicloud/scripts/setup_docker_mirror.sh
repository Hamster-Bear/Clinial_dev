#!/bin/bash
set -e

echo "=== 开始配置 Docker Registry 镜像加速 ==="

if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 或 root 用户运行此脚本"
  exit 1
fi

DOCKER_DAEMON_FILE="/etc/docker/daemon.json"
mkdir -p /etc/docker

if [ -f "$DOCKER_DAEMON_FILE" ]; then
  echo "发现已有配置文件，备份为 ${DOCKER_DAEMON_FILE}.bak"
  cp "$DOCKER_DAEMON_FILE" "${DOCKER_DAEMON_FILE}.bak"
fi

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
