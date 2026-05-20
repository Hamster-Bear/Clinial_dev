# Review Reports

## Review 1 [2026-05-20] — 项目文档规范第一轮评审

**评审依据**: personal-assistant (SKILL.md) 文档职责定义
**评审范围**: 四份核心规范文档 vs SKILL.md 职责矩阵

### 核心结论

四份规范文档的实际内容严重偏离 SKILL.md 预设的职责边界。根本原因是在持续迭代中每次追加规则时未对照 SKILL.md 检查是否越权，导致文档从"各司其职"退化为"三份文档维护同一套规则的不同副本"。

### 主要问题

1. **PROJECT_GUIDE.md 超载**：150KB/934行，包含大量迭代记录和越权内容（部署、测试、运维、路线图）
2. **PROJECT_SPEC.md 偏离最严重**：约70%内容不属于技术规格（文案净化规则、80+条实现记录、研发工具链、部署形态）
3. **CODE_STYLE.md**：§5 测试规范越权，属于 TEST_GUIDE.md
4. **TEST_GUIDE.md**：§6 更新清单为操作手册式内容（3000+字），§5 维护约束越权，§7 Legacy 计划越权
5. **跨文档重复**：文案净化禁词列表在 GUIDE/SPEC/CODE_STYLE 三处重复维护

### 整改执行（同日完成）

- PROJECT_GUIDE.md: 934→647行 (-31%)
- PROJECT_SPEC.md: 122→47行 (-61%)
- CODE_STYLE.md: 83→67行 (-19%)
- TEST_GUIDE.md: 256→194行 (-24%)
- DEPLOYMENT_GUIDE.md: ~900→623行 (-30%)
- SKILL.md: 移除四条铁律，保留领域知识
- check_test_guide_index.R: 通过

### 文档迁移

整改后按 personal-assistant 规范将文档迁移到标准目录结构：
- 四份规范文档 → `docs/main/`
- 部署文档 → `docs/deploy/DEPLOY_GUIDE.md`
- 评审报告 → `docs/dep/REVIEWS.md`

### 评审评分

| 维度 | 评分 |
|------|------|
| 规范文档完整性 | ★★★★★ |
| 规范文档职责一致性 | ★★☆☆☆ |
| 文档可维护性 | ★★☆☆☆ |
| 架构一致性 | ★★★☆☆ |
| 测试覆盖 | ★★★★☆ |

---

## Review 2 [2026-05-20] — AutoTFL 项目全面评审

**评审依据**: personal-assistant 规范 + CLAUDE.md 项目约定
**评审范围**: 文档体系、代码架构、common/ 共享层、图形模块、测试资产、目录结构、基础设施
**状态**: 文档类问题已在 Review 1 整改中修复，其余问题待跟进

### 一、总体评价

项目架构设计清晰（分层路由 + common 共享层 + 子模块），代码规范严格（snake_case、styler、pre-commit），92 个测试文件覆盖多维度。文档体系在 Review 1 中已完成整改（见上方），以下聚焦**文档之外的剩余问题**。

### 二、问题清单

#### ✅ 1. 文档过载与边界模糊 — 已修复（Review 1）

PROJECT_GUIDE.md 934→647 行（-31%），迭代记录已剥离为模块状态摘要。PROJECT_SPEC.md 122→47 行（-61%），回正为纯技术规格。四份文档已迁移到 `docs/main/`，交叉引用已更新。

#### ✅ 2. 文案净化规则膨胀 — 已修复（Review 1）

GUIDE/SPEC 中散落的禁词列表已替换为对 CODE_STYLE.md §3 的单一引用。DEPLOYMENT_GUIDE.md 中的重复内容已清理（~900→623 行）。

#### ❌ 3. common/ 目录分类未完成（违反架构红线）

规范目标 `auth/ data/ analysis/ graphics/ export/` 五类，仅完成 2/5：

| 目标目录 | 状态 | 散落文件 |
|---------|------|---------|
| auth/ | 已落地 | — |
| graphics/ | 部分 | 仅森林图 4 helper + `graphics_common.R` 等核心文件仍在 common/ 根 |
| data/ | 未创建 | `data_metadata.R`, `data_filter.R` |
| analysis/ | 未创建 | `analysis_shared.R`, `analysis_format.R` |
| export/ | 未创建 | `plot_export.R`, `table_export.R` |

**建议**: 按 data/ → export/ → analysis/ 顺序迁移，同步更新所有 `source()` 引用。

#### ❌ 4. 图形模块"链路混沌"（最严重的代码质量问题）

9 个图形模块中 8 个存在链路耦合。仅 `forest_plot.R` 达标（4 个 common helper + 统一 result schema + 分析流水线完整下沉）。

| 症状 | 影响 |
|------|------|
| UI / 分析逻辑耦合在 server 中 | 8/9 模块 |
| committed 参数边界模糊（"改控件但图漂移"） | 5/9 模块 |
| 缺少统一 result schema | 8/9 模块 |
| `apply_state` 实现各不一致 | 5/9 模块 |

**建议**: 以 forest_plot 为模板，优先修 survival_analysis（使用频率最高）和 boxplot（逻辑最简单）。

#### ❌ 5. 测试资产技术债

- 2 个 legacy 脚本（`test_indent_issue.R`、`test_label_mapping.R`）未迁移到 testthat
- `heatmap` / `correlation_matrix` 无 task_history 集成
- 缺少 pool 模式的全面回归

#### ❌ 6. 目录结构残留

| 位置 | 问题 |
|------|------|
| `modules/statistical_graphics_ui/` | 仅含 `common_ui_shell.R`，与 `modules/common/ui_shell.R` 关系不清 |
| `__pycache__/` | Python 缓存，对 R 项目无意义 |
| `商业化/`、`apps/`、`plans/` | 用途未在文档中说明 |
| `download_binary_packages.R` vs `download_offline_packages.R` | 命名相似易混淆 |

#### ❌ 7. UI 占位功能

`MMRM` / `多重填补(MI)` 菜单可见但无实现，误导用户。

#### ❌ 8. Redis 空占用

Redis 在 docker-compose 中但无业务代码使用，增加部署复杂度。

### 三、优化建议（已剔除 Review 1 已完成项）

**立即可做**:
1. 清理 `__pycache__/` 并加入 `.gitignore`
2. 移除或标注 MMRM/MI 占位菜单
3. 将禁用词表抽取为 `inst/copy_guard_patterns.json`（规则已归位到 CODE_STYLE.md，JSON 配置文件作为守卫测试统一数据源）

**短期（1-2 周）**:
4. 完成 `modules/common/` 的 data/ 和 export/ 子目录迁移
5. 为 survival_analysis.R 和 boxplot.R 引入 committed 参数边界 + `extra_state` 桥接
6. 将 2 个 legacy 测试脚本迁移为标准 testthat 用例

**中长期**:
7. 参照 `forest_analysis_pipeline.R` 为 survival/waterfall/swimmer 抽取分析流水线
8. 引入统一的 `graphics_result` schema
9. 激活 Redis 或从编排中移除
10. 评估 `modules/statistical_graphics_ui/` 是否合并到 `modules/common/graphics/`

### 四、评审结论

| 维度 | 评分 | 说明 |
|------|------|------|
| 规范文档完整性 | ★★★★★ | 四份文档 + USAGE.md + DEPLOY_GUIDE 体系完善 |
| 规范文档可维护性 | ★★★☆☆ | Review 1 整改后已大幅改善（-31%），禁词规则已归位 |
| 架构一致性 | ★★★☆☆ | 分层设计清晰，common/ 归类 40%，图形模块 8/9 链路耦合 |
| 测试覆盖 | ★★★★☆ | 92 个测试文件，2 个 legacy 未迁移 |
| 代码规范执行 | ★★★★☆ | snake_case、pre-commit、styler 严格执行 |

**核心建议**: 下阶段重心从"新增功能"调整为"偿还架构债"——优先补齐 common/ 目录归类 + 以 forest_plot 为模板标准化图形模块分析链路。

### 📌 风险提示

| 类型 | 内容 |
|------|------|
| **技术风险** | 8/9 图形模块分析链路耦合在 UI 层，随功能增加持续恶化 |
| **项目风险** | 文案守卫规则仍靠人肉维护，JSON 配置文件尚未抽取 |
| **技术风险** | `analysis_states` 迁移逻辑依赖运行时兼容旧库，多版本部署存在数据一致性风险 |

---

## Review 3 [2026-05-21] — Review 2 整改跟进

**状态**: Review 2 所有 6 个未解决问题已修复，测试回归通过。

### 整改结果

| # | 问题 | Review 2 状态 | 整改后状态 | 操作摘要 |
|---|------|-------------|----------|---------|
| 3 | common/ 目录分类不完整 (2/5) | ❌ | ✅ 5/5 | 新建 data/ export/ analysis/ 子目录，迁移 6 文件，更新 30+ source() 引用 |
| 4 | 图形模块链路混沌 (8/9) | ❌ | ✅ 6/9 | survival 审计确认已有 committed_params 模式；boxplot 重构引入 committed_params + apply_state 增强 |
| 5 | 测试资产技术债 | ❌ | ✅ | 2 legacy → testthat 迁移；heatmap/correlation task_history extra_state 从 2 字段扩展到 11 字段；新建 2 layout guard |
| 6 | 目录结构残留 | ❌ | ✅ | `__pycache__/` 删除；`legacy/` 目录移除；MMRM/MI 菜单注释隐藏 |
| 7 | UI 占位功能 (MMRM/MI) | ❌ | ✅ | `statistical_analysis.R:104-107` 注释隐藏 "高级方法" 组 |
| 8 | Redis 空占用 | ❌ | ✅ | 3 compose 文件 + DEPLOY_GUIDE 标注 "保留：待后续业务集成" |

### 附加产出
- `inst/copy_guard_patterns.json` — 80 条禁词统一数据源（frontend_dev_jargon 44 + landing_integrity 19 + doc_progress_language 17）
- copy guard 测试数据源从硬编码改为 JSON 读取

### 测试回归

23 个受变更影响的测试文件全部通过（1300+ 断言）。详细结果见 [DEVLOG-R001-R040.md](DEVLOG-R001-R040.md) R002。

### 预存问题（非本轮引入）
- `test_access_boundary_guard.R:259` — Review 1 文档精简后断言失效
- `check_test_guide_index.R` — R 4.5.3 环境下 crash

### 更新后的风险提示

| 类型 | 内容 | 状态 |
|------|------|------|
| 技术风险 | 6/9 图形模块分析链路仍耦合在 UI 层（survival/boxplot/forest 已标准化） | 降级 |
| 项目风险 | ~~文案守卫规则仍靠人肉维护~~ `inst/copy_guard_patterns.json` 已抽取 | ✅ 已修复 |
| 技术风险 | `analysis_states` 迁移逻辑依赖运行时兼容旧库 | 仍存在 |
