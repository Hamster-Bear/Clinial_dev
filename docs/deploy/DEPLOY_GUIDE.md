# AutoTFL 部署细节指南

## 目录

1. [文档定位](#1-文档定位)
2. [部署矩阵总览](#2-部署矩阵总览)
3. [部署相关文件总览](#3-部署相关文件总览)
4. [通用前置条件](#4-通用前置条件)
5. [方案 A：本地直接运行](#5-方案-a本地直接运行)
6. [方案 B：基础 Docker Compose 开发编排](#6-方案-b基础-docker-compose-开发编排)
7. [方案 C：带 Landing 页的本地联调编排](#7-方案-c带-landing-页的本地联调编排)
8. [方案 D：服务器生产部署](#8-方案-d服务器生产部署)
9. [服务器目录结构与文件挂载](#9-服务器目录结构与文件挂载)
10. [数据库与存储初始化细节](#10-数据库与存储初始化细节)
11. [上线验收与运维检查](#11-上线验收与运维检查)
12. [常见问题与边界说明](#12-常见问题与边界说明)
13. [维护要求](#13-维护要求)

## 1. 文档定位

### 1.1 目标

- 本文档专门记录 AutoTFL 当前仓库的部署方案、部署差异、目录结构、环境变量、挂载关系和运维要点。
- 本文档补足 `PROJECT_GUIDE.md` 中的高层说明，承接详细的部署操作与文件级别说明。
- 本文档只描述当前仓库已存在的部署链路，不把未落地能力写成可直接执行的方案。

### 1.2 适用范围

| 场景                            | 是否适用 | 说明                                                 |
| ----------------------------- | ---- | -------------------------------------------------- |
| Windows / macOS / Linux 本地开发  | 是    | 适合直接运行 `run_app.R`                                 |
| Docker 开发编排                   | 是    | 适合本地联调或多服务验证                                       |
| 服务器生产部署                       | 是    | 当前以 Docker Compose + Nginx + PostgreSQL + Redis 为主 |
| Kubernetes / Helm / Kustomize | 否    | 当前仓库未提供相关部署清单                                      |

## 2. 部署矩阵总览

### 2.1 当前支持的部署形态

| 方案 | 入口文件                        | 对外地址                       | 根路径行为                       | 适用目标            |
| -- | --------------------------- | -------------------------- | --------------------------- | --------------- |
| A  | `run_app.R`                 | 默认 `http://127.0.0.1:8190` | 直接进入 Shiny 应用               | 单机开发、问题定位       |
| B  | `docker-compose.yml`        | `http://localhost`         | `/` 直接反代到 Shiny             | 基础开发编排          |
| C  | `docker-compose.local.yml`  | `http://localhost:8080`    | `/` 为 Landing 页，应用在 `/app/` | 本地联调、Landing 验证 |
| D  | `docker-compose.server.yml` | `https://<domain>`         | `/` 为 Landing 页，应用在 `/app/` | 服务器生产部署         |

### 2.2 当前不纳入正式主流程的编排

| 文件                    | 当前定位                                                   | 是否作为正式部署入口 |
| --------------------- | ------------------------------------------------------ | ---------- |
| `docker-compose1.yml` | 轻量测试基础设施栈，仅包含 PostgreSQL 和 Redis，并复用 `5432/6379` 供本机直连 | 否          |

## 3. 部署相关文件总览

### 3.1 根目录关键文件

| 文件                            | 作用                                  |
| ----------------------------- | ----------------------------------- |
| `app.R`                       | Shiny 主应用入口                         |
| `run_app.R`                   | 本地开发推荐启动脚本                          |
| `config/required_packages.R`  | R 依赖单一清单，供安装与离线包脚本共用              |
| `install_dependencies.R`      | 依赖安装脚本                              |
| `download_offline_packages.R` | 生成本地离线 `package/` 仓库与 `PACKAGES` 索引 |
| `Dockerfile`                  | 应用镜像构建文件                            |
| `docker-compose.yml`          | 基础开发编排                              |
| `docker-compose.local.yml`    | 带 Landing 页的本地联调编排                  |
| `docker-compose.server.yml`   | 生产服务器编排                             |
| `docker-compose1.yml`         | 轻量测试基础设施栈                           |

### 3.2 Nginx 相关文件

| 文件                           | 作用                                |
| ---------------------------- | --------------------------------- |
| `nginx/default.conf`         | 根路径直接反代到 Shiny 的最简配置              |
| `nginx/local-test.conf`      | 本地联调配置，包含 Landing 和 `/app/` 子路径代理 |
| `nginx/server_ssl.conf`      | 生产 HTTPS 配置，包含 80→443 跳转          |
| `nginx/landing/index.html`   | Medev 首页                          |
| `nginx/landing/autotfl.html` | Medev 产品介绍子页                   |
| `nginx/landing/style.css`    | Landing 共享样式                      |
| `nginx/landing/script.js`    | Landing 共享脚本                      |
| `nginx/landing/assets/`      | Landing 静态资源                      |

### 3.3 数据与部署辅助文件

| 文件                                                   | 作用                                 |
| ---------------------------------------------------- | ---------------------------------- |
| `postgres/init.sql`                                  | 初始化 PostgreSQL 表结构                 |
| `postgres/migrations/001_analysis_states_schema.sql` | 已部署实例的 `analysis_states` schema 迁移 |
| `postgres/postgresql.conf`                           | PostgreSQL 配置文件                    |
| `deploy/alicloud/env/.env.example`                   | 生产环境变量模板                           |
| `deploy/alicloud/scripts/init_env.sh`                | 生成 `.env` 并填充随机数据库密码               |
| `deploy/alicloud/scripts/deploy_from_tar.sh`         | 离线导入镜像并启动生产编排                      |
| `scripts/offline-ops.sh`                             | 宿主机离线部署/运维交互菜单与非交互 action 入口     |
| `deploy/alicloud/scripts/setup_docker_mirror.sh`     | 配置 Docker 镜像加速源                    |

### 3.4 仓库内与部署直接相关的目录结构

```text
AutoTFL/
├── Dockerfile
├── docker-compose.yml
├── docker-compose.local.yml
├── docker-compose.server.yml
├── docker-compose1.yml
├── config/
│   └── required_packages.R
├── install_dependencies.R
├── download_offline_packages.R
├── app.R
├── run_app.R
├── postgres/
│   ├── init.sql
│   ├── migrations/
│   │   └── 001_analysis_states_schema.sql
│   └── postgresql.conf
├── nginx/
│   ├── default.conf
│   ├── local-test.conf
│   ├── server_ssl.conf
│   └── landing/
│       ├── index.html
│       ├── autotfl.html
│       ├── style.css
│       ├── script.js
│       └── assets/
└── deploy/
    └── alicloud/
        ├── README.md
        ├── certs/
        │   └── .gitkeep
        ├── env/
        │   └── .env.example
        └── scripts/
            ├── init_env.sh
            ├── deploy_from_tar.sh
            └── setup_docker_mirror.sh
```

## 4. 通用前置条件

### 4.1 依赖前提

- 本地直跑依赖可用的 R 环境。
- 容器部署依赖 Docker 与 Docker Compose。
- 生产 HTTPS 部署依赖可读的证书和私钥文件。

### 4.2 离线包前提

- 当前 `Dockerfile` 会先执行 `COPY package /app/package` 与 `COPY config /app/config`。
- 因此，如果要按当前 `Dockerfile` 构建镜像，必须先在项目根目录准备好 `package/` 目录。
- `package/` 目录由 `download_offline_packages.R` 生成，并应包含 `PACKAGES` 索引；依赖列表来自 `config/required_packages.R`。
- 如果没有先生成 `package/`，当前 Docker 构建流程会在复制阶段失败。

### 4.3 数据与网络前提

- PostgreSQL 是当前应用的必需依赖，因为 workspace / folder / dataset 元数据保存在数据库中。
- Redis 已进入编排层，但当前业务代码未显式依赖 Redis，现阶段属于基础设施预留（保留，待后续业务集成）。
- 应用数据体默认保存在本地存储目录；代码层支持 S3，但现有 Compose 模板未直接提供 S3 所需变量。

### 4.4 当前环境变量清单

| 变量                 | 默认值                           | 使用位置                        | 说明        |
| ------------------ | ----------------------------- | --------------------------- | --------- |
| `DB_PASSWORD`      | 无安全默认值                        | Compose / PostgreSQL        | 生产环境必须覆盖  |
| `DATA_ROOT`        | `/data/hamster-analysis`      | `docker-compose.server.yml` | 服务器持久化根目录 |
| `CERT_ROOT`        | `/etc/hamster-analysis/certs` | `docker-compose.server.yml` | 证书目录      |
| `SSL_CERT_FILE`    | `kyyin.xyz.pem`               | `docker-compose.server.yml` | 证书文件名     |
| `SSL_KEY_FILE`     | `kyyin.xyz.key`               | `docker-compose.server.yml` | 私钥文件名     |
| `APP_STORAGE_ROOT` | `/app/data_storage`           | `docker-compose.server.yml` | 容器内数据目录   |
| `SHINY_PORT`       | `8190`                        | `run_app.R`                 | 本地直跑端口    |
| `SHINY_HOST`       | `127.0.0.1`                   | `run_app.R`                 | 本地直跑监听地址  |

### 4.5 应用内部消费的关键变量

| 应用变量                                                                                      | 用途                  |
| ----------------------------------------------------------------------------------------- | ------------------- |
| `POSTGRES_DB` / `POSTGRES_HOST` / `POSTGRES_PORT` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | 数据库连接               |
| `STORAGE_ROOT`                                                                            | 本地数据体存储目录           |
| `STORAGE_BACKEND`                                                                         | 存储后端，`local` 或 `s3` |
| `STORAGE_S3_BUCKET`                                                                       | S3 模式下的桶名           |
| `APP_ADMIN_USERNAME`                                                                      | 可选的预置管理员用户名         |
| `APP_ADMIN_EMAIL`                                                                         | 可选的预置管理员邮箱          |
| `APP_ADMIN_PASSWORD`                                                                      | 可选的预置管理员密码          |

### 4.6 部署相关访问控制要点

- 管理员账号必须通过 `APP_ADMIN_USERNAME`、`APP_ADMIN_EMAIL` 与 `APP_ADMIN_PASSWORD` 环境变量预置；未配置时不自动提升首个注册用户。启动时若数据库中已存在同邮箱或同用户名账号，会同步校准；若邮箱与用户名分别命中不同账号，则拒绝静默同步。
- 邮件投递通过 `EMAIL_DELIVERY_MODE` 控制：`console`（测试环境输出验证码到日志）、`disabled`（默认关闭）、`smtp`（需额外配置 SMTP 变量）。生产环境切到 `smtp` 前，必须补齐 `EMAIL_FROM_ADDRESS`、`SMTP_HOST`、`SMTP_PORT`、`SMTP_USERNAME`、`SMTP_PASSWORD`、`SMTP_USE_SSL`。
- 服务器目录导入要求部署机器或容器可见的绝对路径，仅对系统管理员开放。ZIP 数据空间导入未实现。
- 普通用户未开通数据空间功能时仅允许单文件临时上传，数据不持久化。
- 完整的权限模型与访问控制说明见 [PROJECT_SPEC.md](../main/PROJECT_SPEC.md) §4。

### 4.7 部署安全与免责

- 当前工具暂不负责数据安全；数据传到服务端后不保证安全，使用方需自行妥善保管数据。如需更高的数据隔离或运行保障，应优先提供独立部署服务。
- 数据权限首期落到 workspace 级别；部署与对外说明中不得把更细粒度权限写成已落地能力。

### 4.8 当前部署风险

- 技术风险：`viewer` / `editor` 写操作差异尚未完全落实到所有模块；数据库管理锁当前仍是账号级开关。
- 维护风险：邮箱邀请链路尚未接入真实邮箱验证、过期时间与审计日志。
- 立即可做：部署前把管理员账号、邮箱配置和测试库连通性纳入检查清单。
- 中长期建议：补齐邮箱验证、邀请有效期、审计日志。

## 5. 方案 A：本地直接运行

### 5.1 适用场景

- 调试 Shiny 模块。
- 快速验证本地修改。
- 不需要 Nginx、Landing 页和 HTTPS。

### 5.2 测试环境变量

- `run_app_test.ps1` 会读取 `.env.test`；可先从 `.env.test.example` 复制。
- `run_app_test.ps1` 会读取 `SHINY_PORT`；若未设置则默认占用检查与启动 `8190`。
- 本地若数据库由 `docker-compose.local.yml` 或 `docker-compose1.yml` 拉起，应用应连接 `localhost:5432`。
- `docker-compose.local.yml` 现直接读取 `.env.test`，以统一本地联调与 `run_app_test.ps1` 使用的 PostgreSQL 与管理员参数；其中 app 容器仍会在内部网络中覆盖 `POSTGRES_HOST=postgres`。
- `docker-compose1.yml` 只提供 PostgreSQL 与 Redis 基础设施，适用于项目更新期间避免重建整套应用镜像时，继续让本机 `run_app.R` / `run_app_test.ps1` 复用同一组 `5432/6379` 端口做业务测试。
- 测试环境管理员示例为 `APP_ADMIN_USERNAME=admin`、`APP_ADMIN_EMAIL=admin@example.com`、`APP_ADMIN_PASSWORD=admin123`。
- 测试与回归入口详见 [TEST_GUIDE.md](../main/TEST_GUIDE.md) §4。

### 5.2 启动链路

1. 执行 `run_app_test.ps1`。
2. 脚本检查 `app.R` 和 `install_dependencies.R` 是否存在。
3. 脚本加载 `.env.test` 并打印 PostgreSQL、管理员账号与 `SHINY_PORT` 参数。
4. 若目标 `SHINY_PORT` 已被占用，脚本会强制关闭占用进程并确认端口已释放。
5. 脚本调用 `run_app.R`，由其继续安装/校验依赖并设置 `SHINY_PORT` 与 `SHINY_HOST`。
6. 通过 `shiny::runApp("app.R")` 启动应用。

### 5.3 当前默认地址

| 项目   | 当前默认值                   |
| ---- | ----------------------- |
| Host | `127.0.0.1`             |
| Port | `8190`                  |
| URL  | `http://127.0.0.1:8190` |

### 5.4 本地运行注意事项

- 本地直跑不会自动提供 PostgreSQL 容器；若数据库未就绪，数据库模块相关功能会失败。
- 如需完整验证数据库链路，建议改用 Docker Compose。
- Windows 下若需要从源码编译部分依赖，建议准备 Rtools。

## 6. 方案 B：基础 Docker Compose 开发编排

### 6.1 入口文件

- 使用 `docker-compose.yml`。
- 使用 `nginx/default.conf`。

### 6.2 服务组成

| 服务         | 作用       | 外部端口                  |
| ---------- | -------- | --------------------- |
| `postgres` | 元数据数据库   | `5432`                |
| `redis`    | 预留缓存组件   | `6379`                |
| `app`      | Shiny 应用 | 不直接对外，仅 `expose 3838` |
| `nginx`    | 反向代理     | `80`                  |

### 6.3 访问路径

| 路径  | 行为               |
| --- | ---------------- |
| `/` | 直接代理到 `app:3838` |

### 6.4 启动顺序

1. 确认已准备好 `package/` 目录。
2. 在项目根目录执行 `docker compose -f docker-compose.yml up -d --build`。
3. 访问 `http://localhost`。
4. 用 `docker compose -f docker-compose.yml ps` 查看服务状态。

### 6.5 当前特点

- 这是最简开发编排。
- 不带 Landing 页。
- 不带 HTTPS。
- 适合验证基础反向代理、数据库连接和应用容器构建。

## 7. 方案 C：带 Landing 页的本地联调编排

### 7.1 入口文件

- 使用 `docker-compose.local.yml`。
- 使用 `nginx/local-test.conf`。

### 7.2 服务组成

| 服务         | 作用                | 外部端口                  |
| ---------- | ----------------- | --------------------- |
| `postgres` | 元数据数据库            | `5432`                |
| `redis`    | 预留缓存组件            | `6379`                |
| `app`      | Shiny 应用          | 不直接对外，仅 `expose 3838` |
| `nginx`    | 本地 Landing + 反向代理 | `8080`                |

### 7.3 访问路径

| 路径            | 行为             |
| ------------- | -------------- |
| `/`           | Medev Landing 页 |
| `/landing/`   | Landing 静态资源目录 |
| `/app/`       | AutoTFL 应用入口   |
| `/shared/`    | Shiny 共享资源代理   |
| `/session/`   | Shiny 会话代理     |
| `/websocket/` | WebSocket 代理   |
| `/sockjs/`    | SockJS 代理      |

### 7.4 为什么必须保留这些代理路径

- `/app/` 用于把 Shiny 应用挂到子路径。
- `/shared/` 负责共享前端资源。
- `/session/` 负责会话生命周期。
- `/websocket/` 和 `/sockjs/` 负责实时交互与连接升级。
- 删除其中任一路由，都可能导致 Shiny 在子路径模式下出现静态资源加载失败或交互异常。

### 7.5 启动顺序

1. 确认已准备好 `package/` 目录。
2. 在项目根目录执行 `docker compose -f docker-compose.local.yml up -d --build`。
3. 访问 `http://localhost:8080` 检查 Landing。
4. 打开 `http://localhost:8080/app/` 检查应用。

### 7.6 当前特点

- 适合验证 Landing 页、应用入口路径和前端资源缓存策略。
- 本地联调配置使用 no-cache / no-store 相关头，便于前端页面改版后快速验证。

## 8. 方案 D：服务器生产部署

### 8.1 入口文件

- 主编排文件：`docker-compose.server.yml`
- Nginx 配置：`nginx/server_ssl.conf`
- 变量模板：`deploy/alicloud/env/.env.example`
- 变量生成脚本：`deploy/alicloud/scripts/init_env.sh`
- 离线部署脚本：`deploy/alicloud/scripts/deploy_from_tar.sh`

### 8.2 服务组成

| 服务         | 作用            | 对外暴露          |
| ---------- | ------------- | ------------- |
| `postgres` | 业务元数据数据库      | 不对外显式暴露宿主机端口  |
| `redis`    | 预留缓存组件        | 不对外显式暴露宿主机端口  |
| `app`      | Shiny 应用      | 仅容器内暴露 `3838` |
| `nginx`    | HTTPS 入口与反向代理 | `80`、`443`    |

### 8.3 关键差异

- 生产编排不会构建 `app` 镜像。
- 生产编排固定使用本地已有镜像 `autotfl-shiny-app:latest`。
- 如果服务器本地没有该镜像，必须先 `docker load` 或先在服务器构建镜像。
- `pull_policy: never` 表示生产编排不主动从公网拉取该应用镜像。

### 8.4 HTTPS 与域名

| 项目           | 当前配置                          |
| ------------ | ----------------------------- |
| 域名           | `kyyin.xyz` / `www.kyyin.xyz` |
| 80 端口        | 强制跳转到 443                     |
| 443 端口       | 提供 HTTPS 服务                   |
| 根路径 `/`      | Landing 页                     |
| 应用路径 `/app/` | AutoTFL 应用入口                 |

### 8.5 标准启动顺序

1. 在服务器放置项目代码。
2. 准备证书目录和证书文件。
3. 准备离线镜像或本地已有 `autotfl-shiny-app:latest` 镜像，并统一放到 `/opt/hamster-analysis/current/apps`。
4. 执行 `bash deploy/alicloud/scripts/init_env.sh` 生成 `.env`。
5. 按需编辑 `.env`。
6. 如采用离线镜像，执行 `bash deploy/alicloud/scripts/deploy_from_tar.sh <镜像tar路径或文件名>`。
7. 或手动执行 `docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml up -d --pull never`。
8. 检查 `docker compose ... ps` 和 Nginx / app 日志。

### 8.6 推荐的离线镜像构建与保存流程

#### 8.6.1 在构建机准备前置条件

1. 确认项目根目录已存在 `package/` 离线仓库。
2. 确认 Docker 可正常构建镜像。
3. 如计划做完整离线部署，先准备基础镜像：

```bash
docker pull postgres:14-alpine
docker pull redis:7-alpine
docker pull nginx:1.27-alpine
```

#### 8.6.2 构建应用镜像

```bash
docker build -t autotfl-shiny-app:latest .
```

构建完成后建议先确认镜像存在：

```bash
docker image ls autotfl-shiny-app
docker image inspect autotfl-shiny-app:latest
```

#### 8.6.3 保存镜像

如果服务器无法稳定访问公网，推荐将应用镜像与基础镜像一起保存为一个离线包，并按约定输出到本地 `apps/` 目录：

```bash
docker save -o apps/autotfl-offline-bundle.tar ^
  autotfl-shiny-app:latest ^
  postgres:14-alpine ^
  redis:7-alpine ^
  nginx:1.27-alpine
```

在 Linux / macOS 下可写为：

```bash
docker save -o apps/autotfl-offline-bundle.tar \
  autotfl-shiny-app:latest \
  postgres:14-alpine \
  redis:7-alpine \
  nginx:1.27-alpine
```

如果只保存应用镜像，也可以单独导出：

```bash
docker save -o apps/autotfl-shiny-app_latest.tar autotfl-shiny-app:latest
```

#### 8.6.4 传输镜像到服务器

常见做法包括：

- 使用 `scp apps/autotfl-offline-bundle.tar root@223.4.178.138:/opt/hamster-analysis/current/apps/`
- 使用 `rsync -avP apps/autotfl-offline-bundle.tar root@223.4.178.138:/opt/hamster-analysis/current/apps/`
- 通过制品仓库、中转盘或堡垒机传输后再落到目标目录

如果离线包较大，建议在传输后先校验文件大小或摘要，再执行导入。

### 8.7 服务器侧准备步骤

#### 8.7.1 准备目录

推荐先在服务器创建目录：

```bash
sudo mkdir -p /opt/hamster-analysis/current
sudo mkdir -p /opt/hamster-analysis/current/apps
sudo mkdir -p /etc/hamster-analysis/certs
sudo mkdir -p /data/hamster-analysis/postgres
sudo mkdir -p /data/hamster-analysis/redis
sudo mkdir -p /data/hamster-analysis/storage
```

如需避免容器因权限不足无法写入，可先按服务器策略授予目录写权限。

#### 8.7.2 放置代码与证书

1. 上传项目代码到 `/opt/hamster-analysis/current`
2. 上传离线镜像 tar 到 `/opt/hamster-analysis/current/apps`
3. 上传证书到 `/etc/hamster-analysis/certs`
4. 确认证书文件名与 `.env` 中的 `SSL_CERT_FILE`、`SSL_KEY_FILE` 一致

#### 8.7.3 生成环境变量文件

在项目根目录执行：

```bash
bash deploy/alicloud/scripts/init_env.sh
```

脚本会：

- 自动创建 `deploy/alicloud/env/.env`
- 如仍使用占位密码，则自动生成随机 `DB_PASSWORD`

随后应至少检查以下字段：

- `DB_PASSWORD`
- `DATA_ROOT`
- `CERT_ROOT`
- `SSL_CERT_FILE`
- `SSL_KEY_FILE`
- `APP_STORAGE_ROOT`

### 8.8 服务器侧导入与启动

#### 8.8.1 导入镜像

```bash
docker load -i /opt/hamster-analysis/current/apps/autotfl-offline-bundle.tar
```

导入后建议确认镜像已就绪：

```bash
docker image ls | grep -E "autotfl-shiny-app|postgres|redis|nginx"
```

#### 8.8.2 启动服务

方式一：使用项目内脚本

```bash
bash deploy/alicloud/scripts/deploy_from_tar.sh autotfl-offline-bundle.tar
```

方式二：手动分步执行

```bash
docker load -i /opt/hamster-analysis/current/apps/autotfl-offline-bundle.tar
docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml up -d --pull never
docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml ps
```

#### 8.8.3 查看日志

```bash
docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml logs -f nginx
docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml logs -f app
docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml logs -f postgres
```

### 8.9 服务器升级发布建议流程

当代码有更新时，推荐按以下顺序操作：

1. 在构建机更新代码。
2. 重新生成或确认 `package/` 离线仓库。
3. 运行轻量发布脚本，自动串联构建、打包、摘要、上传和远端部署；或按下述手动流程执行。
4. 如采用手动流程，先重新构建应用镜像：

```bash
docker build -t autotfl-shiny-app:latest .
```

1. 重新导出离线镜像包到 `apps/`：

```bash
docker save -o apps/autotfl-offline-bundle.tar autotfl-shiny-app:latest postgres:14-alpine redis:7-alpine nginx:1.27-alpine
```

1. 将新的离线包传到服务器 `/opt/hamster-analysis/current/apps/`。
2. 在服务器重新执行：

```bash
bash deploy/alicloud/scripts/deploy_from_tar.sh autotfl-offline-bundle.tar
```

1. 或手动执行：

```bash
docker load -i /opt/hamster-analysis/current/apps/autotfl-offline-bundle.tar
docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml up -d --pull never
```

1. 检查容器状态、日志和页面访问情况。

### 8.10 轻量发布脚本

当前仓库已提供：

```text
deploy/alicloud/scripts/publish_release.sh
```

该脚本用于串联以下步骤：

1. 构建应用镜像
2. 保存离线 tar 到本地 `apps/`
3. 生成 `.sha256` 与 `.summary.txt`
4. 上传到服务器 `/opt/hamster-analysis/current/apps`
5. 远端调用 `scripts/offline-ops.sh --action image`
6. 导入镜像并重建 `app/nginx`

#### 8.10.1 典型用法

```bash
bash deploy/alicloud/scripts/publish_release.sh --server user@your-server
```

#### 8.10.2 常用参数

| 参数                             | 作用                                         | <br /> |
| ------------------------------ | ------------------------------------------ | :----- |
| `--server <user@host>`         | 远端服务器 SSH 目标（例如 `root@223.4.178.138`）      | <br /> |
| `--remote-root <path>`         | 远端项目根目录，默认 `/opt/hamster-analysis/current` | <br /> |
| `--remote-apps-dir <path>`     | 远端离线包目录，默认 `<remote-root>/apps`            | <br /> |
| `--upload-method <scp\|rsync>` | 上传方式，默认 `scp`。推荐网络不稳定时使用 `rsync` 断点续传      | <br /> |
| `--skip-upload`                | 只在本地构建和导出，不上传                              | <br /> |
| `--skip-remote-deploy`         | 上传但不远端启动                                   | <br /> |
| `--skip-base-pull`             | 缺失基础镜像时不自动 `docker pull`                   | <br /> |
| `--use-latest-tar`             | 跳过本地镜像构建与打包，直接上传本地 `apps/` 下最新生成的 `tar` 包  | <br /> |

#### 8.10.3 本地产物

脚本会在本地 `apps/` 目录生成：

- `*.tar`：离线镜像包
- `*.sha256`：sha256 摘要
- `*.summary.txt`：构建与上传说明

#### 8.10.4 远端行为

脚本远端会执行：

1. 创建 `/opt/hamster-analysis/current/apps`
2. 上传 tar、摘要和说明文件
3. 调用 `deploy/alicloud/scripts/init_env.sh`
4. 调用 `scripts/offline-ops.sh --action image --target <remote-root> --image-tar <remote-tar>`

#### 8.10.5 宿主机离线菜单

`scripts/offline-ops.sh` 可直接放在宿主机部署目录中运行。无参数时进入交互菜单；带 `--action` 时可用于自动化。

常用 action：

| action | 作用 |
| ------ | ---- |
| `install` | 首次部署或全量部署；保留已有 `.env`，只在缺失时从 `.env.example` 生成 |
| `load` | 只执行 `docker load` |
| `up` | 启动或更新全部服务 |
| `image` | 加载镜像并重建 `app/nginx` |
| `status` | 查看服务状态 |
| `logs` | 查看服务日志，可配合 `--service app` |
| `backup` | 逻辑备份 PostgreSQL 数据库到 `backups/` |
| `backup-volume` | 短暂停止 `app/postgres`，打包 PostgreSQL 数据目录到 `backups/` |
| `migrate` | 执行 `postgres/migrations/*.sql`，用于已部署实例 schema 迁移 |
| `reset-db` | 先执行逻辑备份，再把旧 PostgreSQL 数据目录移动到 `backups/` 并重建数据目录 |
| `uninstall` | 停止服务并按确认删除本地数据 |

示例：

```bash
bash scripts/offline-ops.sh
bash scripts/offline-ops.sh --action image --image-tar apps/autotfl-offline-bundle.tar
bash scripts/offline-ops.sh --action migrate
bash scripts/offline-ops.sh --action reset-db
```

### 8.11 生产环境变量模板

```dotenv
DB_PASSWORD=__CHANGE_ME_DB_PASSWORD__
DATA_ROOT=/data/hamster-analysis
CERT_ROOT=/etc/hamster-analysis/certs
SSL_CERT_FILE=kyyin.xyz.pem
SSL_KEY_FILE=kyyin.xyz.key
APP_STORAGE_ROOT=/app/data_storage
```

### 8.12 生产部署辅助目录结构

```text
deploy/alicloud/
├── README.md
├── certs/
│   └── .gitkeep
├── env/
│   ├── .env.example
│   └── .env
└── scripts/
    ├── init_env.sh
    ├── deploy_from_tar.sh
    ├── publish_release.sh
    └── setup_docker_mirror.sh
```

## 9. 服务器目录结构与文件挂载

### 9.1 推荐服务器目录

| 目录                                                       | 当前建议用途                   |
| -------------------------------------------------------- | ------------------------ |
| `/opt/hamster-analysis/current`                          | 项目代码目录                   |
| `/opt/hamster-analysis/current/apps`                     | 统一存放所有应用离线镜像 tar、摘要与发布说明 |
| `/opt/hamster-analysis/current/deploy/alicloud/env/.env` | 生产环境变量文件                 |
| `/etc/hamster-analysis/certs`                            | 证书目录                     |
| `/data/hamster-analysis`                                 | 持久化根目录                   |
| `/data/hamster-analysis/postgres`                        | PostgreSQL 数据目录          |
| `/data/hamster-analysis/redis`                           | Redis 数据目录               |
| `/data/hamster-analysis/storage`                         | 应用数据体目录                  |

### 9.2 推荐服务器目录树

```text
/opt/hamster-analysis/
└── current/
    ├── apps/
    │   ├── *.tar
    │   ├── *.sha256
    │   └── *.summary.txt
    ├── docker-compose.server.yml
    ├── Dockerfile
    ├── nginx/
    ├── postgres/
    ├── deploy/
    │   └── alicloud/
    │       ├── README.md
    │       ├── env/
    │       │   ├── .env.example
    │       │   └── .env
    │       └── scripts/
    │           ├── init_env.sh
    │           ├── deploy_from_tar.sh
    │           ├── publish_release.sh
    │           └── setup_docker_mirror.sh
    └── package/

/etc/hamster-analysis/
└── certs/
    ├── kyyin.xyz.pem
    └── kyyin.xyz.key

/data/hamster-analysis/
├── postgres/
├── redis/
└── storage/
```

### 9.3 生产挂载关系

| Compose 服务 | 宿主机路径                           | 容器路径                             | 作用               |
| ---------- | ------------------------------- | -------------------------------- | ---------------- |
| `postgres` | `${DATA_ROOT}/postgres`         | `/var/lib/postgresql/data`       | PostgreSQL 数据持久化 |
| `redis`    | `${DATA_ROOT}/redis`            | `/data`                          | Redis 数据持久化      |
| `app`      | `${DATA_ROOT}/storage`          | `${APP_STORAGE_ROOT}`            | 应用数据体持久化         |
| `nginx`    | `${CERT_ROOT}/${SSL_CERT_FILE}` | `/etc/nginx/certs/kyyin.xyz.pem` | 证书               |
| `nginx`    | `${CERT_ROOT}/${SSL_KEY_FILE}`  | `/etc/nginx/certs/kyyin.xyz.key` | 私钥               |
| `nginx`    | `./nginx/landing`               | `/usr/share/nginx/html/landing`  | Landing 静态页      |

## 10. 数据库与存储初始化细节

### 10.1 PostgreSQL 初始化

- PostgreSQL 容器启动时会挂载 `postgres/init.sql`。
- 当前初始化脚本会创建以下表：

| 表名           | 作用     |
| ------------ | ------ |
| `workspaces` | 工作区元数据 |
| `folders`    | 文件夹元数据 |
| `datasets`   | 数据集元数据 |

### 10.2 analysis\_states 迁移

- `postgres/init.sql` 只适用于首次初始化数据目录；如果部署复用了旧 PostgreSQL 数据卷，它不会自动修复历史 `analysis_states` schema。
- 当前仓库已新增 `postgres/migrations/001_analysis_states_schema.sql`，用于将旧 `analysis_states` 表迁移到当前契约。
- 该迁移会补齐缺失字段、统一 `state_payload/state_note` 为 `TEXT`、回填时间戳默认值、删除自然键重复的旧记录，并重建唯一索引。
- 当前唯一性口径为：
  - workspace 任务：`user_id + workspace_id + scope + module_type + state_name`
  - 个人任务：`user_id + scope + module_type + state_name` 且 `workspace_id IS NULL`
- 应用层同名保存语义仍按“覆盖”处理；当前 service 会先查询同名任务再显式 update/insert，因此即使旧库尚未完成唯一索引迁移，用户侧保存链路也不应因为 `ON CONFLICT` 推断失败而中断。
- 删除重复记录时保留最近更新的一条，因此生产库执行前必须先备份。
- 应用启动时 `auth_ensure_schema()` 也会执行对应运行时迁移，但生产发布仍建议在维护窗口手工执行该 SQL 文件，避免应用首启承担历史数据清理压力。

### 10.3 应用内部数据库连接

- 应用通过 `POSTGRES_DB`、`POSTGRES_HOST`、`POSTGRES_PORT`、`POSTGRES_USER`、`POSTGRES_PASSWORD` 建立连接。
- 当前数据库模块与数据准备模块都依赖 PostgreSQL 连接池。
- 如果数据库不可用，数据集登记、加载和基于数据库的选择器都会失败。

### 10.4 数据体存储

- 当前默认后端是 `local`。
- 本地模式下，数据会被序列化为 `RDS` 文件，保存到 `STORAGE_ROOT` 下。
- 生产编排通过 `${DATA_ROOT}/storage:${APP_STORAGE_ROOT}` 挂载，把容器内存储目录映射到宿主机。

### 10.5 S3 模式说明

- 当前代码支持 `STORAGE_BACKEND=s3`。
- 启用 S3 时还需要：
  - 安装 `aws.s3`
  - 设置 `STORAGE_S3_BUCKET`
  - 提供 AWS 访问凭证
- 现有 Compose 模板未直接给出 S3 所需变量，因此 S3 属于可扩展能力，不属于默认部署链路。

## 11. 上线验收与运维检查

### 11.1 本地验收

| 方案 | 必查项                                                 |
| -- | --------------------------------------------------- |
| A  | 应用能否在 `127.0.0.1:8190` 打开                           |
| B  | `http://localhost` 是否直接进入应用                         |
| C  | `http://localhost:8080` 是否显示 Landing，`/app/` 是否进入应用 |

### 11.2 生产验收

1. 访问 `https://kyyin.xyz` 或 `https://www.kyyin.xyz`，确认显示 Landing 页。
2. 从 Landing 进入 `/app/`，确认 Shiny 主应用成功打开。
3. 检查数据库管理模块是否能读取/创建 workspace。
4. 检查数据准备模块是否能上传并保存数据集。
5. 检查应用容器、Nginx 容器和 PostgreSQL 容器健康状态。

### 11.3 运维排查顺序

1. 先检查证书文件是否存在、路径是否可读。
2. 再检查 `docker compose ps` 中四个服务是否全部运行。
3. 再检查 PostgreSQL 初始化是否成功。
4. 最后检查 Nginx 反向代理和 Shiny 日志。

## 12. 常见问题与边界说明

### 12.1 Docker Hub 无法连接

- 在国内服务器场景下，`docker pull` 或 `docker compose up` 可能出现 `connection refused`。
- 当前仓库提供 `deploy/alicloud/scripts/setup_docker_mirror.sh` 作为在线拉镜像时的兜底方案。
- 生产环境更推荐离线导入镜像，再使用 `--pull never` 启动。

### 12.2 `package/` 目录缺失

- 这是当前最容易踩的构建问题。
- 如果项目根目录不存在 `package/`，`Dockerfile` 的 `COPY package /app/package` 会直接失败。
- 正确做法是在构建前先准备本地离线仓库，或调整 Dockerfile 后再使用无离线仓库模式。

### 12.3 生产镜像不存在

- `docker-compose.server.yml` 不会帮你构建应用镜像。
- 必须先让服务器拥有 `autotfl-shiny-app:latest` 镜像。
- 推荐使用 tar 离线导入，再执行 `scripts/offline-ops.sh --action image`。

### 12.4 Redis 当前边界

- Redis 已在三套正式 Compose 中出现。
- 当前业务代码未见显式 Redis 读写。
- 文档中应将其视为“预留基础设施”，而不是“已落地缓存能力”。

### 12.5 当前不支持的部署方式

- 当前仓库未提供 Kubernetes、Helm、Kustomize、systemd 单服务安装脚本、CI/CD 发布流水线。
- 若后续新增上述能力，应在本文件新增独立章节，而不是挤进现有 Compose 章节。

## 13. 维护要求

### 13.1 文档更新要求

- 只要 Dockerfile、Compose、Nginx、`.env.example`、`deploy/alicloud` 脚本有改动，必须同步更新本文档。
- `PROJECT_GUIDE.md` 负责记录部署矩阵和高层边界，本文档负责记录细节。
- `deploy/alicloud/README.md` 保持“快速提示”定位，详细说明以本文档为准。

### 13.2 变更时必查清单

1. 访问地址是否变化。
2. Compose 服务数量或挂载关系是否变化。
3. 环境变量名称或默认值是否变化。
4. Nginx 路由是否变化。
5. 数据目录、证书目录、镜像前置条件是否变化。
6. 是否新增或删除部署辅助脚本。

### 13.3 当前文档边界

- 本文档记录的是当前仓库实现与推荐部署路径。
- 本文档不替代真实证书、域名、密码和服务器安全策略。
- 本文档不包含 CI/CD、云厂商专有服务和对象存储密钥配置细节。

***

文档用途：部署细节单一真相源\
适用版本：当前仓库主线实现\
维护原则：实现变更即同步修订



