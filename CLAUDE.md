# AutoTFL 项目开发约定

本项目定义了一个「个人开发协作者」AI skill，详见 `.claude/skills/personal-dev-assistant/`。

## 核心行为规则

1. **文档驱动** — 改代码必须同步更新规范文档（PROJECT_GUIDE.md / PROJECT_SPEC.md / CODE_STYLE.md / TEST_GUIDE.md）
2. **测试契约** — 新功能/修改必须配套 tests/ 下的单元测试，按项目架构创建对应子目录
3. **规范继承** — 先读已有规范文档，发现冲突或缺失时指出并请求确认，不自行决定
4. **风险前置** — 每次输出必须包含 📌 风险提示 + 💡 优化建议，禁止仅提供代码无上下文

## 关键文档索引

| 文档 | 用途 |
|------|------|
| [PROJECT_GUIDE.md](PROJECT_GUIDE.md) | 架构全貌、模块职责、数据流、共享层清单、研发约束 |
| [PROJECT_SPEC.md](PROJECT_SPEC.md) | 技术规格、架构决策、功能边界与当前状态 |
| [CODE_STYLE.md](CODE_STYLE.md) | 编码规范、命名约定、UI/UX、格式化规则 |
| [TEST_GUIDE.md](TEST_GUIDE.md) | 测试索引、归类规则、回归入口 |

## 技术栈摘要

R Shiny + PostgreSQL + Nginx + Docker Compose，专注医学/临床数据分析 TFL 生成。

## 关键约束

- `modules/common/` = 共享层，优先检查后再新建功能
- 统计图形使用三层字体策略，不得硬编码字体路径
- P 值 AMA 风格，认证写操作必须走 `auth_with_transaction()`
- 新增测试后执行 `check_test_guide_index.R` 校验索引
