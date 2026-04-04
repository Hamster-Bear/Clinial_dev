# 阿里云 Ubuntu 22.04 部署目录说明

`deploy/alicloud/` 用于生产部署辅助文件，和主编排 `docker-compose.server.yml` 配合使用。

## 目录与用途

- `deploy/alicloud/env/.env.example`：生产环境变量模板。
- `deploy/alicloud/env/.env`：生产环境变量文件（由脚本生成，不提交仓库）。
- `deploy/alicloud/scripts/init_env.sh`：从模板生成 `.env`，并自动填充随机数据库密码。
- `deploy/alicloud/scripts/deploy_from_tar.sh`：服务器离线导入 tar 镜像并启动容器。
- `deploy/alicloud/scripts/setup_docker_mirror.sh`：一键配置国内 Docker 镜像加速源（修复 `connection refused` 错误）。
- `deploy/alicloud/certs/`：可选的证书存放占位目录。

## 服务器建议路径

- 代码目录：`/opt/autotfl/current`
- 环境变量：`/opt/autotfl/current/deploy/alicloud/env/.env`
- 证书目录：`/etc/autotfl/certs`
- 数据目录：`/data/autotfl`

## 最小部署顺序

1. 上传代码到 `/opt/autotfl/current`
2. 上传证书到 `/etc/autotfl/certs`
3. 执行 `bash deploy/alicloud/scripts/init_env.sh`
4. 执行 `bash deploy/alicloud/scripts/deploy_from_tar.sh <镜像tar路径>`

## 常见问题与排查 (Troubleshooting)

### Docker Hub `connection refused` 错误

**现象**：
```
✘ app Error Get "https://registry-1.docker.io/v2/": dial tcp 103.42.176.244:443: connect: connection refused
```

**原因**：
国内阿里云服务器由于网络限制，无法直接连接 Docker 官方镜像仓库。

**解决方案**：
1. 运行预置的镜像加速脚本（若需在线拉取基础环境）：
   ```bash
   sudo bash deploy/alicloud/scripts/setup_docker_mirror.sh
   ```
2. **（当前场景推荐）离线拉起服务**：由于是离线部署，且已导入镜像，请在启动时追加 `--pull never` 参数，强制 Docker 不连接公网校验：
   ```bash
   docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml up -d --pull never
   ```

