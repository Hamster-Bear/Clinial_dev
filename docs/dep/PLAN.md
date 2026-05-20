---
status: done
created: 2026-05-20
updated: 2026-05-20
---

# AutoTFL 架构债修复计划

## 目标

修复 Review 2 问题清单中 6 个未解决架构/质量问题：完成 `modules/common/` 五类目录归类，标准化 survival_analysis 和 boxplot 的 committed 参数边界，清理目录残留和 UI 占位，补全测试资产，并执行全量回归验证。

## 背景

Review 2（2026-05-20）全面评审发现：
- `modules/common/` 仅完成 auth/ 和部分 graphics/ 归类（2/5，违反架构红线）
- 9 个图形模块中 8 个存在 UI/分析链路耦合，仅 forest_plot 达标
- 2 个 legacy 测试未迁移，heatmap/correlation_matrix 缺 task_history 集成
- 目录结构残留（`__pycache__/`、`statistical_graphics_ui/` 与 `common/` 关系不清）
- MMRM/MI 菜单占位但无实现，Redis 在 compose 中无业务使用

## Phase 总览

| Phase | 目标 | 预估轮数 | 依赖 | 状态 |
|-------|------|---------|------|------|
| P1 | 立即可做项：清理残留 + 隐藏占位菜单 + Redis 文档 + copy_guard JSON 抽取 | 2-3 | 无 | done |
| P2 | `modules/common/` 目录归类：data/ → export/ → analysis/ 迁移 | 2-3 | P1 | done |
| P3 | 图形模块标准化：survival_analysis + boxplot 引入 committed 参数边界 | 2-3 | P2 | done |
| P4 | 测试资产修复：legacy 迁移 + task_history 补全 + 测试完整性审计 | 2-3 | P3 | done |
| P5 | 全量回归 + 端到端验证 | 2-3 | P4 | done |

---

## P1 — 立即可做项

### 输入条件
- 无前置依赖
- 当前 `__pycache__/` 目录存在（含 `autotfl-offline-bundle_*.tar`），`modules/statistical_analysis.R` 中 MMRM/MI 菜单可见
- 禁词规则已归位到 CODE_STYLE.md §3，但无结构化数据源

### 交付物

| 文件 | 操作 | 说明 |
|------|------|------|
| `__pycache__/` | 删除 | 整个目录及离线包文件 |
| `.gitignore` | 修改 | 追加 `__pycache__/` |
| `modules/statistical_analysis.R:105-106` | 修改 | MMRM/MI 菜单项注释隐藏 |
| `modules/admin_manager.R` | 修改 | 若有 MMRM/MI 引用同步隐藏 |
| `modules/common/auth/account_service.R` | 修改 | 同上 |
| `modules/common/auth/auth.R` | 修改 | 同上 |
| `modules/common/auth/email_service.R` | 修改 | 同上 |
| `inst/copy_guard_patterns.json` | 新建 | 禁词列表 JSON，作为守卫测试统一数据源 |
| `tests/` 相关 copy guard 测试文件 | 修改 | 数据源改为从 JSON 读取 |
| `docker-compose.yml` | 修改 | Redis 服务加注释 `# 保留：待后续业务集成` |
| `docker-compose.local.yml` | 修改 | 同上 |
| `docker-compose.server.yml` | 修改 | 同上 |
| `docs/deploy/DEPLOY_GUIDE.md` | 修改 | Redis 段标注"保留待后续业务集成" |

### 完成标准
- [ ] `__pycache__/` 目录不存在，`.gitignore` 包含 `__pycache__/`
- [ ] MMRM/MI 菜单在 UI 中不可见（`shiny::conditionalPanel` 或注释隐藏）
- [ ] `inst/copy_guard_patterns.json` 存在，格式为 JSON 数组，每项含 `pattern` + `category`
- [ ] 所有 copy guard 测试通过（断言不变，仅改数据源读取方式）
- [ ] 3 个 docker-compose 文件中 Redis 服务均有 `# 保留：待后续业务集成` 注释
- [ ] DEPLOY_GUIDE.md 中 Redis 说明已更新

### 边界
- **不做**：删除 MMRM/MI 相关 server 处理代码（仅隐藏 UI entry）
- **不做**：从 docker-compose 中移除 Redis 配置
- **不做**：新增禁词（仅从 CODE_STYLE.md 现有列表抽取到 JSON）

### 涉及文件
- `__pycache__/`（删除）、`.gitignore`（修改）
- `modules/statistical_analysis.R`（修改）
- `modules/admin_manager.R`、`modules/common/auth/account_service.R`、`modules/common/auth/auth.R`、`modules/common/auth/email_service.R`（修改，条件性）
- `inst/copy_guard_patterns.json`（新建）
- `tests/root/test_copy_guard_*.R` 系列（修改）
- `docker-compose.yml`、`docker-compose.local.yml`、`docker-compose.server.yml`（修改）
- `docs/deploy/DEPLOY_GUIDE.md`（修改）

### 关键决策
- 已确认：Redis 保留在 compose 中，加注释标注
- 已确认：MMRM/MI 菜单隐藏（注释掉 `menuItem`），保留 server 代码
- 已确认：copy_guard JSON 仅抽取现有规则，不新增

---

## P2 — modules/common/ 目录归类

### 输入条件
- P1 已完成（建议先合入减少合并冲突）
- 当前 state：

| 目标目录 | 状态 | 待迁移文件 |
|---------|------|-----------|
| `auth/` | 已落地 | — |
| `graphics/` | 部分 | 4 helper + 核心文件已在 graphics/ 或 common/ 根 |
| `data/` | 未创建 | `data_metadata.R`, `data_filter.R` |
| `export/` | 未创建 | `plot_export.R`, `table_export.R` |
| `analysis/` | 未创建 | `analysis_format.R`, `analysis_shared.R` |

### 交付物

**Step 1 — 迁移顺序：data/ → export/ → analysis/**

| 文件 | 操作 | 新路径 |
|------|------|--------|
| `modules/common/data_metadata.R` | 移动 | `modules/common/data/data_metadata.R` |
| `modules/common/data_filter.R` | 移动 | `modules/common/data/data_filter.R` |
| `modules/common/plot_export.R` | 移动 | `modules/common/export/plot_export.R` |
| `modules/common/table_export.R` | 移动 | `modules/common/export/table_export.R` |
| `modules/common/analysis_format.R` | 移动 | `modules/common/analysis/analysis_format.R` |
| `modules/common/analysis_shared.R` | 移动 | `modules/common/analysis/analysis_shared.R` |

**Step 2 — 更新所有 `source()` 引用**

全局搜索替换以下路径模式（影响 `app.R`、所有 `modules/` 子模块、`tests/` 中 source 引用、`run_app.R` 等入口脚本）：
- `modules/common/data_metadata.R` → `modules/common/data/data_metadata.R`
- `modules/common/data_filter.R` → `modules/common/data/data_filter.R`
- `modules/common/plot_export.R` → `modules/common/export/plot_export.R`
- `modules/common/table_export.R` → `modules/common/export/table_export.R`
- `modules/common/analysis_format.R` → `modules/common/analysis/analysis_format.R`
- `modules/common/analysis_shared.R` → `modules/common/analysis/analysis_shared.R`

**Step 3 — 文档同步**

| 文件 | 操作 | 说明 |
|------|------|------|
| `docs/main/PROJECT_GUIDE.md` | 修改 | §4 目录树更新 + §9 共享层文件路径更新 |
| `docs/main/PROJECT_SPEC.md` | 修改 | §3 更新 common/ 分类状态为 5/5 |
| `CLAUDE.md` | 修改 | 确认 common/ 路径描述正确 |

### 完成标准
- [ ] `modules/common/data/`、`modules/common/export/`、`modules/common/analysis/` 目录存在
- [ ] 6 个文件已迁移至各自子目录
- [ ] `modules/common/` 根目录不包含上述 6 个文件
- [ ] Grep 确认无旧路径 `source("modules/common/data_metadata.R")` 等引用残留
- [ ] 全部现有测试通过（含 `check_test_guide_index.R`）
- [ ] PROJECT_GUIDE.md、PROJECT_SPEC.md、CLAUDE.md 已同步

### 边界
- **不做**：修改任何迁移文件的内部实现
- **不做**：为 data/export/analysis 目录创建额外接口文件（`__init__` 等）
- **不做**：调整 `modules/common/graphics/` 目录（已存在，不动）
- **不做**：合并 `modules/statistical_graphics_ui/` 到 `common/graphics/`

### 涉及文件
- `modules/common/data/`、`modules/common/export/`、`modules/common/analysis/`（新建目录）
- `modules/common/data_metadata.R`、`data_filter.R`、`plot_export.R`、`table_export.R`、`analysis_format.R`、`analysis_shared.R`（移动）
- `app.R`、`modules/*.R`、`modules/**/*.R`、`tests/**/*.R`、`run_app.R`（修改 source 引用）
- `docs/main/PROJECT_GUIDE.md`、`docs/main/PROJECT_SPEC.md`、`CLAUDE.md`（修改）

### 关键决策
- 已确认：迁移顺序 data/ → export/ → analysis/
- 已确认：仅移动文件 + 更新引用，不做接口整理
- 每完成一个子目录迁移立即跑测试验证，不批量迁移后统一验证

---

## P3 — 图形模块标准化（survival_analysis + boxplot）

### 输入条件
- P2 已完成（common 归类就位，source 引用正确）
- 目标模块当前状态（来自 PROJECT_GUIDE.md §7.7）：

| 模块 | 外层壳 | 核心问题 |
|------|-------|---------|
| `survival_analysis.R` | 已标准化 | committed 参数边界模糊，view state 泄漏到分析逻辑 |
| `boxplot.R` | 已标准化 | 同上，`apply_state` 实现与 forest_plot 不一致 |

- 参照模板：`forest_plot.R` — 已有 4 个 common helper + 统一 result schema + committed 参数清晰边界

### 交付物

**Step 1 — survival_analysis.R 引入 committed 参数边界**

| 操作 | 文件 | 说明 |
|------|------|------|
| 修改 | `modules/statistical_graphics/survival_analysis.R` | 分离 view state（UI 控件 live 值）和 committed state（Generate 时快照），分析逻辑只读 committed state |
| 修改 | `modules/statistical_graphics/survival_analysis.R` | 引入 `extra_state` 桥接变量，统一 `apply_state` 恢复契约（对齐 forest_plot） |
| 修改 | `tests/statistical_graphics/survival/` 相关测试 | 新增 committed/view state 分离测试用例 |

**Step 2 — boxplot.R 引入 committed 参数边界**

| 操作 | 文件 | 说明 |
|------|------|------|
| 修改 | `modules/statistical_graphics/boxplot.R` | 同上：view/committed state 分离 |
| 修改 | `modules/statistical_graphics/boxplot.R` | `apply_state` 契约对齐 forest_plot |
| 修改 | `tests/statistical_graphics/boxplot/` 相关测试 | 新增 committed state 边界测试 |

**Step 3 — 文档同步**

| 操作 | 文件 | 说明 |
|------|------|------|
| 修改 | `docs/main/PROJECT_GUIDE.md` §7.7 | 更新状态表：survival_analysis + boxplot 从"链路混沌"改为"已标准化" |
| 修改 | `docs/main/PROJECT_GUIDE.md` §7.2 + §7.5 | 补充 committed state 设计说明 |

### 完成标准
- [ ] `survival_analysis.R` 中分析逻辑不再直接读取 `input$` 值，只读 committed state
- [ ] `boxplot.R` 中分析逻辑同上
- [ ] 两个模块的 `apply_state` 参数结构与 forest_plot 一致（`state` + `extra_state`）
- [ ] "改控件不 Generate → 图不变"行为有测试覆盖
- [ ] 两个模块的 Generate/Download 流程完整可用
- [ ] 现有 survival + boxplot 相关测试全部通过
- [ ] PROJECT_GUIDE.md 状态表已更新

### 边界
- **不做**：修改生存分析的统计算法（KM、Cox 等不变）
- **不做**：修改 boxplot 的图形渲染逻辑（仅解耦参数来源）
- **不做**：改动 forest_plot（它是参照模板）
- **不做**：为其他 6 个图形模块做标准化（combo、spider、swimmer、waterfall、heatmap、correlation）

### 涉及文件
- `modules/statistical_graphics/survival_analysis.R`（修改）
- `modules/statistical_graphics/boxplot.R`（修改）
- `tests/statistical_graphics/survival/` 目录下相关测试文件（修改/新建）
- `tests/statistical_graphics/boxplot/` 目录下相关测试文件（修改/新建）
- `docs/main/PROJECT_GUIDE.md`（修改）

### 关键决策
- 参照 forest_plot 的 committed state 模式
- 不改分析算法，仅做 UI/逻辑参数边界解耦
- `extra_state` 桥接模式参照 forest_plot 中的实现

---

## P4 — 测试资产修复 + 完整性审计

### 输入条件
- P3 已完成（survival + boxplot 标准化后的测试已更新）
- 当前已知技术债：

| 项目 | 当前状态 |
|------|---------|
| `tests/.../legacy/test_indent_issue.R` | 遗留脚本，非 testthat 格式 |
| `tests/.../legacy/test_label_mapping.R` | 遗留脚本，非 testthat 格式 |
| `heatmap` task_history | 缺失集成 |
| `correlation_matrix` task_history | 缺失集成 |

### 交付物

**Step 1 — legacy 测试迁移**

| 操作 | 文件 | 说明 |
|------|------|------|
| 新建 | `tests/statistical_analysis/regression/test_indent_issue.R` | legacy 脚本改写为 testthat 标准格式 |
| 删除 | `tests/statistical_analysis/regression/legacy/test_indent_issue.R` | 迁移后移除 |
| 新建 | `tests/statistical_graphics/survival/test_label_mapping.R` | legacy 脚本改写为 testthat 标准格式 |
| 删除 | `tests/statistical_graphics/survival/legacy/test_label_mapping.R` | 迁移后移除 |
| 删除 | `tests/statistical_analysis/regression/legacy/` | 空目录清理 |
| 删除 | `tests/statistical_graphics/survival/legacy/` | 空目录清理 |

**Step 2 — task_history 集成补全**

| 操作 | 文件 | 说明 |
|------|------|------|
| 修改 | `modules/statistical_graphics/heatmap.R` | 添加 state 快照保存 / `apply_state` 恢复（参照已集成模块如 forest_plot） |
| 修改 | `modules/statistical_graphics/correlation_matrix.R` | 同上 |
| 新建/修改 | `tests/statistical_graphics/heatmap/` 相关测试 | 新增 task_history save/restore 测试 |
| 新建/修改 | `tests/statistical_graphics/correlation_matrix/` 相关测试 | 同上 |

**Step 3 — 测试完整性审计**

检查范围：所有基础模块 + 输出模块

| 检查维度 | 检查范围 |
|---------|---------|
| layout guard 测试 | 所有 `modules/` 子模块 |
| compute/math 测试 | 所有统计分析和图形模块 |
| task_history 测试 | 所有图形模块 |
| copy guard 测试 | 所有模块入口文本 |

### 完成标准
- [ ] 2 个 legacy 测试已转为 testthat 标准用例，断言通过
- [ ] `tests/` 下无 `legacy/` 目录残留
- [ ] heatmap 和 correlation_matrix 具备 task_history save/restore 功能
- [ ] 新增 task_history 测试通过
- [ ] 测试完整性审计完成，生成的缺口清单不超过本期规划范围
- [ ] TEST_GUIDE.md §3 索引更新，`check_test_guide_index.R` 通过

### 边界
- **不做**：为 legacy 测试补充超出原覆盖范围的额外用例（仅迁移，不扩展）
- **不做**：为 task_history 之外的 feature 补测试（不含 heatmap 新图形参数测试等）
- **不做**：pool 模式全面回归（独立议题，超出本轮）

### 涉及文件
- `tests/statistical_analysis/regression/test_indent_issue.R`（新建）
- `tests/statistical_graphics/survival/test_label_mapping.R`（新建）
- `tests/statistical_analysis/regression/legacy/`（删除）
- `tests/statistical_graphics/survival/legacy/`（删除）
- `modules/statistical_graphics/heatmap.R`（修改）
- `modules/statistical_graphics/correlation_matrix.R`（修改）
- `tests/statistical_graphics/heatmap/`（修改/新建）
- `tests/statistical_graphics/correlation_matrix/`（修改/新建）
- `docs/main/TEST_GUIDE.md`（修改）

### 关键决策
- legacy 迁移仅转换格式，不扩展覆盖
- task_history 集成参照 forest_plot 模式

---

## P5 — 全量回归 + 端到端验证

### 输入条件
- P4 已完成（测试资产修复 + 审计完成）
- 所有模块代码变更已完毕

### 交付物

| 操作 | 范围 | 说明 |
|------|------|------|
| 全量测试运行 | 全部 `tests/testthat/` 测试文件 | 全量回归，记录通过/失败 |
| 索引校验 | `check_test_guide_index.R` | 确认测试索引一致 |
| 认证回归 | `run_auth_regression.ps1` | 账户/权限链回归 |
| 端到端验证 | 手动或脚本驱动 | 启动 → 登录 → 数据导入 → 分析 → 图形 → 表格 → 导出 |
| 断裂修复 | 按需回到 P1-P4 | 若验证发现断裂则修复并重跑 |

### 端到端验证路径

```
1. 启动 app (run_app.R, port 8109)
2. 登录 (admin 预设账户)
3. 数据导入 (上传测试 CSV)
4. 统计分析 (至少走 desc + cox + logistic)
5. 图形生成 (survival + boxplot + forest_plot，含 Generate 提交)
6. 表格输出 (listing + summary table)
7. 导出 (Word/PDF 下载验证)
```

### 完成标准
- [ ] 全部测试文件通过（0 failure, 0 error）
- [ ] `check_test_guide_index.R` 通过
- [ ] `run_auth_regression.ps1` 通过
- [ ] 端到端 7 步流程可走完，每步输出预期结果
- [ ] 若有测试失败，已定位并修复，全部重跑通过

### 边界
- **不做**：新增测试覆盖范围（超出 P4 审计范围的留到后续）
- **不做**：性能或负载测试
- **不做**：Docker Compose 部署级端到端验证

### 涉及文件
- 无新增或修改（纯验证阶段）
- 若发现断裂，修复文件按需记录到 DEVLOG

---
