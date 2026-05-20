# AutoTFL (Medev) — Quick Start

## 前提条件

- R 4.3+ （Windows 需 Rtools）
- PostgreSQL 14+
- （可选）Docker + Docker Compose

## 快速运行

```bash
# 本地直接运行
Rscript run_app.R
# 默认 http://127.0.0.1:8109

# Docker 开发编排
docker compose up -d
# http://localhost

# 本地联调（含 Landing 页）
docker compose -f docker-compose.local.yml up -d
# http://localhost:8080
```

## 常用命令

```bash
# 依赖安装
Rscript install_dependencies.R

# 代码格式化
R -e "styler::style_dir()"

# 测试执行
Rscript -e "testthat::test_file('tests/path/to/test_file.R', reporter='summary')"

# 测试索引校验
Rscript tests/check_test_guide_index.R

# 认证链路回归
./run_auth_regression.ps1

# 集成联调
./run_app_test.ps1
```

## 文档导航

| 文档 | 位置 | 用途 |
|------|------|------|
| PROJECT_GUIDE.md | [docs/main/](docs/main/PROJECT_GUIDE.md) | 架构全貌、模块职责、共享层 |
| PROJECT_SPEC.md | [docs/main/](docs/main/PROJECT_SPEC.md) | 技术规格、架构决策、功能边界 |
| CODE_STYLE.md | [docs/main/](docs/main/CODE_STYLE.md) | 编码规范、命名约定、UI/UX 文案 |
| TEST_GUIDE.md | [docs/main/](docs/main/TEST_GUIDE.md) | 测试索引、归类、回归入口 |
| DEPLOY_GUIDE.md | [docs/deploy/](docs/deploy/DEPLOY_GUIDE.md) | 部署方案、环境变量、运维 |

## 技术栈

R Shiny + PostgreSQL + Nginx + Docker Compose — 医学/临床数据分析 TFL 生成

## 环境变量（关键）

| 变量 | 用途 |
|------|------|
| `DB_PASSWORD` | PostgreSQL 连接密码 |
| `APP_ADMIN_USERNAME/EMAIL/PASSWORD` | 预置管理员 |
| `EMAIL_DELIVERY_MODE` | console / disabled / smtp |
