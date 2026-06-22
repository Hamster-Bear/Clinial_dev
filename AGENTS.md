# AutoTFL 项目开发约定

本项目定义了一个「个人开发协作者」AI skill，详见 `.Codex/skills/project-skill/`。

## 规范文档索引

| 文档 | 路径 | 职责 |
|------|------|------|
| PROJECT_GUIDE.md | [docs/main/](docs/main/PROJECT_GUIDE.md) | 项目架构、模块职责、数据流、共享层清单、研发约束 |
| PROJECT_SPEC.md | [docs/main/](docs/main/PROJECT_SPEC.md) | 技术规格、架构决策、功能边界 |
| CODE_STYLE.md | [docs/main/](docs/main/CODE_STYLE.md) | 编码规范、命名约定、UI/UX 文案规范、格式化规则 |
| TEST_GUIDE.md | [docs/main/](docs/main/TEST_GUIDE.md) | 测试索引、归类规则、回归入口 |
| DEPLOY_GUIDE.md | [docs/deploy/](docs/deploy/DEPLOY_GUIDE.md) | 部署方案、环境变量、Docker Compose、运维 |

详见 [USAGE.md](USAGE.md) 快速入门。

## 技术栈摘要

R Shiny + PostgreSQL + Nginx + Docker Compose，专注医学/临床数据分析 TFL 生成。

## 关键约束

- `modules/common/` = 共享层，优先检查后再新建功能
- `modules/common/` 按 `auth/ data/ analysis/ graphics/ export/` 五类收口
- 统计图形使用三层字体策略，不得硬编码字体路径
- P 值 AMA 风格，认证写操作必须走 `auth_with_transaction()`
- 新增测试后执行 `check_test_guide_index.R` 校验索引
- 改动代码需同步更新对应规范文档
