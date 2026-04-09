# 阿里云 Ubuntu 22.04 部署目录说明

`deploy/alicloud/` 用于生产部署辅助文件，和主编排 `docker-compose.server.yml` 配合使用。详细流程统一以项目根目录 `DEPLOYMENT_GUIDE.md` 为准。

## 快速入口

1. 将项目代码放到 `/opt/hamster-analysis/current`，并确保离线镜像 tar 统一上传到 `/opt/hamster-analysis/current/apps`，证书放到 `/etc/hamster-analysis/certs`。
2. 在项目根目录执行 `bash deploy/alicloud/scripts/init_env.sh` 生成 `.env`，确认 `DATA_ROOT`、`CERT_ROOT`、证书文件名和数据库密码。
3. 执行 `bash deploy/alicloud/scripts/deploy_from_tar.sh <镜像tar文件名或绝对路径>` 导入离线镜像并拉起 `docker-compose.server.yml`。
4. 如需一键发布，直接在构建机执行 `bash deploy/alicloud/scripts/publish_release.sh --server user@host`，脚本会完成构建、打包、上传与远端部署。
5. 如遇 Docker Hub 连接问题，可执行 `sudo bash deploy/alicloud/scripts/setup_docker_mirror.sh`；更多排查与目录结构说明请查看 `DEPLOYMENT_GUIDE.md`。

