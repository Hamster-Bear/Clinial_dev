---
status: done
created: 2026-06-03
updated: 2026-06-03
---

# AutoTFL 质量收敛计划（第二期）

## 目标

基于 Review 6（2026-06-03）代码级核查结果，修复 combo_plot 状态管理缺口，同步修正多份文档中与实际代码不符的过时描述，并推进 Tables 子模块测试覆盖。

## 背景

Review 6 对 PROJECT_GUIDE.md / PROJECT_SPEC.md / TEST_GUIDE.md 与实际代码库做了全面交叉比对。在起草本计划前，额外对所有图形模块和 Tables 模块做了逐文件 Grep 核查，发现**先前评估中多项"待完成"工作实际已落地**：

| 先前评估 | 实际状态 | 证据 |
|----------|----------|------|
| heatmap / correlation_matrix task_history "待接入" | ✅ 已接入 | 两个模块均有 `apply_state` + `graphics_build_task_state`，通过路由器 `statistical_graphics.R:231` 的 `task_history_server` 统一委托 |
| spider/swimmer/waterfall apply_state "需标准化" | ✅ 已标准化 | 三个模块均有 `committed_params`（5-13 处引用）+ `apply_state` 函数 |
| Tables 无 committed_params / task_history | ✅ 已接入 | `tables.R` 有 `committed_params`（8 处引用）+ 完整 `task_history_server` 集成（含 4 个子模块分发） |
| combo_plot "双阶段回填" | ⚠️ 部分完成 | 有 `apply_state` 但无 `committed_params`，Generate 后改控件仍可能漂移 |

**真正剩余的工作**比先前评估小得多，集中在 combo_plot 和文档同步。

## Phase 总览

| Phase | 目标 | 预估轮数 | 依赖 | 状态 |
|-------|------|---------|------|------|
| P1 | combo_plot 引入 committed_params 模式 | 1-2 | 无 | done |
| P2 | 文档修正：消除过时的"待接入""后续接入"描述 | 1 | P1 | done |
| P3 | Tables 子模块回归测试补全 | 2-3 | P2 | done |

---

## P1 — combo_plot 引入 committed_params 模式

### 输入条件

- combo_plot.R 当前无 `committed_params`，是 9 个图形模块中唯一缺失此模式的模块
- 生成逻辑直接读取 `generated_plot_obj()` reactive，该 reactive 依赖 `input$` 值
- 参照模板：`boxplot.R`（5 处 `committed_params` 引用，结构最简洁）

### 交付物

| 操作 | 文件 | 说明 |
|------|------|------|
| 修改 | `modules/statistical_graphics/combo_plot.R` | 新增 `committed_params <- reactiveVal(NULL)`，Generate 时快照参数，导出和结果读取改为从 committed_params 读取 |
| 修改 | `modules/statistical_graphics/combo_plot.R` | `apply_state` 恢复链路对齐 boxplot 模式 |
| 修改 | `tests/statistical_graphics/combo/test_combo_layout_guard.R` | 补充 committed state 契约断言 |
| 修改 | `docs/main/PROJECT_GUIDE.md` §7.7 | 更新 combo_plot 状态行 |

### 完成标准

- [ ] `combo_plot.R` 含 `committed_params <- reactiveVal(NULL)`
- [ ] Generate 按钮点击后将当前参数快照写入 committed_params
- [ ] 导出逻辑读取 committed_params 而非实时 input
- [ ] "改控件不 Generate → 图不变"行为成立
- [ ] `test_combo_layout_guard.R` 含 committed_params 断言且通过
- [ ] PROJECT_GUIDE.md §7.7 combo_plot 行已更新

### 边界

- **不做**：修改组合图的绘图算法或图层结构
- **不做**：修改组合图的 UI 布局（三卡外层已回正）
- **不做**：调整导出尺寸（固定 12×8 英寸是当前设计决策，非缺陷）

### 涉及文件

- `modules/statistical_graphics/combo_plot.R`（修改）
- `tests/statistical_graphics/combo/test_combo_layout_guard.R`（修改）
- `docs/main/PROJECT_GUIDE.md`（修改）

---

## P2 — 文档修正

### 输入条件

- P1 完成后 combo_plot 状态已更新
- Review 6 已修正 PROJECT_GUIDE.md §4 目录树、§7.6 heatmap/correlation_matrix 描述、TEST_GUIDE.md 重复条目
- 以下文档描述仍与代码不符，需在本轮一并修正

### 交付物

| 操作 | 文件 | 修正内容 |
|------|------|----------|
| 修改 | `docs/main/PROJECT_GUIDE.md` §7.7.1 状态表 | heatmap / correlation_matrix 任务历史列从"后续接入"改为"已接入（路由器统一委托）" |
| 修改 | `docs/main/PROJECT_GUIDE.md` §7.7.1 状态表 | combo_plot 任务历史列从"需扩展双阶段恢复"改为"已接入，committed_params 待补齐（P1）" |
| 修改 | `docs/main/PROJECT_GUIDE.md` §7.7.2 分析链路问题现状 | 更新"其余 6 个模块"描述，反映当前实际状态（多数已标准化） |
| 修改 | `docs/main/PROJECT_GUIDE.md` §7.7.3 核心矛盾与改进优先级 | 更新优先级建议，移除已完成项 |
| 修改 | `docs/main/PROJECT_GUIDE.md` §8.3 | 确认 Tables 引擎边界描述与实际一致 |

### 完成标准

- [ ] PROJECT_GUIDE.md 中不再出现与代码不符的"待接入""后续接入""需标准化"描述
- [ ] §7.7 状态表每行与代码实际状态一致
- [ ] `check_test_guide_index.R` 通过（无测试文件增减）

### 边界

- **不做**：修改 PROJECT_SPEC.md（其描述仍为准确的功能边界声明，不含实现状态）
- **不做**：修改 CODE_STYLE.md 或 TEST_GUIDE.md（无相关内容需更新）

### 涉及文件

- `docs/main/PROJECT_GUIDE.md`（修改）

---

## P3 — Tables 子模块回归测试补全

### 输入条件

- P2 文档修正完成
- 当前 Tables 测试覆盖：

| 子模块 | 现有测试 | 缺口 |
|--------|----------|------|
| `t_dm.R` | `test_t_dm_contract.R`（3 个函数测试） | 无 committed_params 断言 |
| `t_ae_soc_pt.R` | `test_t_ae_soc_pt_contract.R`（3 个函数测试） | 无 committed_params 断言 |
| `listing_general.R` | `test_listing_general_contract.R`（3 个函数测试） | 无 committed_params 断言 |
| `ae_sidebyside.R` | `test_ae_sidebyside_contract.R` | 无 committed_params 断言 |
| `tables.R`（总入口） | `test_tables_layout_guard.R` + `test_tables_committed_state.R` | 已有 committed state 测试 |

### 交付物

| 操作 | 文件 | 说明 |
|------|------|------|
| 修改 | `tests/tables/test_t_dm_contract.R` | 补充 committed_params 契约断言 |
| 修改 | `tests/tables/test_t_ae_soc_pt_contract.R` | 同上 |
| 修改 | `tests/tables/test_listing_general_contract.R` | 同上 |
| 修改 | `tests/tables/test_ae_sidebyside_contract.R` | 同上 |

### 完成标准

- [ ] 4 个 Tables 子模块测试文件各含 committed_params 契约断言
- [ ] 所有 Tables 相关测试通过
- [ ] `check_test_guide_index.R` 通过

### 边界

- **不做**：为 Tables 子模块补充完整的端到端集成测试（超出本轮）
- **不做**：补齐 `generate_*_code()` 占位符（独立议题）

### 涉及文件

- `tests/tables/test_t_dm_contract.R`（修改）
- `tests/tables/test_t_ae_soc_pt_contract.R`（修改）
- `tests/tables/test_listing_general_contract.R`（修改）
- `tests/tables/test_ae_sidebyside_contract.R`（修改）

---

## 风险提示

| 类型 | 内容 |
|------|------|
| 低风险 | P1 combo_plot committed_params 改动范围有限，参照 boxplot 模式即可 |
| 低风险 | P2 纯文档修正，不影响代码 |
| 低风险 | P3 仅补充测试断言，不改业务代码 |

## 非本期范围（记录备查）

| 项目 | 来源 | 说明 |
|------|------|------|
| MMRM / 多重填补分析链路 | PROJECT_SPEC.md §5 | 菜单已隐藏，分析链路未实现，属新功能开发 |
| 组织级/项目级隔离 | PROJECT_SPEC.md §5 | 需架构设计，非质量收敛范畴 |
| Tables `generate_*_code()` 占位符 | Review 5 | 3/4 子模块代码生成返回占位字符串 |
| ae_sidebyside 字体链路 | Review 5 | `exists("graphics_resolve_font_spec")` 软引用可能回退到 sans |
| combo_plot 导出高度同步 | PROJECT_GUIDE §7.7.2 | 固定 12×8 是当前设计决策，需产品确认是否改为动态 |
