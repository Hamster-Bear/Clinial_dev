# 阿里云 Ubuntu 22.04 部署目录说明

`deploy/alicloud/` 用于生产部署辅助文件，和主编排 `docker-compose.server.yml` 配合使用。

## 目录与用途

- `deploy/alicloud/env/.env.example`：生产环境变量模板。
- `deploy/alicloud/env/.env`：生产环境变量文件（由脚本生成，不提交仓库）。
- `deploy/alicloud/scripts/init_env.sh`：从模板生成 `.env`，并自动填充随机数据库密码。
- `deploy/alicloud/scripts/deploy_from_tar.sh`：服务器离线导入 tar 镜像并启动容器。
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
