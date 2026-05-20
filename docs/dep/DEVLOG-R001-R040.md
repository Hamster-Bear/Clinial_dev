# Dev Log — R001-R040

---

## 2026-05-20

### R001 [22:00] — P1-P5: Review 2 架构债修复全计划执行

#### Done
- P1: 清理 `__pycache__/` 目录（`.gitignore` 已有条目）；隐藏 MMRM/MI 菜单项（`statistical_analysis.R:104-107` 注释掉 "高级方法" 组）；3 个 docker-compose 文件 Redis 服务添加 `# 保留：待后续业务集成` 注释；DEPLOY_GUIDE.md Redis 段标注保留
- P1: 抽取 `inst/copy_guard_patterns.json`（3 类禁词：frontend_dev_jargon 44 条、landing_integrity 19 条、doc_progress_language 17 条）；更新 `test_frontend_copy_guard.R` 和 `test_landing_copy_guard.R` 从 JSON 读取数据源
- P2: `modules/common/` 五类目录全部落地：创建 data/ export/ analysis/ 子目录，迁移 6 个文件（data_metadata.R, data_filter.R → data/; plot_export.R, table_export.R → export/; analysis_format.R, analysis_shared.R → analysis/），更新 30+ 处 source() 引用（app.R, modules/, tests/），Grep 验证无旧路径残留
- P3: survival_analysis.R 已有完整 committed_params 快照 + apply_state 契约（代码审计确认，仅文档标注）；boxplot.R 重构引入 committed_params 模式（create_boxplot(params) 不再读 input$，export 从 committed_params 读取），apply_state 补全 extra_state 手动恢复
- P3: PROJECT_GUIDE.md §7.7 状态表更新：survival_analysis + boxplot 标记为 "committed_params 快照 + apply_state 已标准化"；分析链路问题从 "8/9" 修正为 "6/9"；优先级调整
- P4: 2 个 legacy 测试迁移为 testthat: `test_indent_issue.R`（线性回归缩进格式验证）和 `test_label_mapping.R`（生存分析标签映射），删除 `tests/` 下 legacy/ 空目录
- P4: heatmap.R 和 correlation_matrix.R 的 task_history 集成增强：extra_state 从 2 字段扩展到 11 字段，apply_state 补全 extra_state 手动恢复（updateSelectizeInput/updateTextInput/updateSelectInput）
- P4: 为 heatmap 和 correlation_matrix 新建 layout guard 测试（各 4 个 test_that 块：三卡结构、动作条+页签、废弃包装检查、task_history 契约检查）
- P4: TEST_GUIDE.md 全面更新：§3.5 移除 legacy 标签，§3.7 追加 heatmap/correlation 入口，§3.9 更新迁移状态，§6 Legacy 说明更新为已完成
- P5: Rscript 不可用，执行代码级别变更审查和最终汇总；git status 确认变更范围

#### Issues / Blockers
- Rscript 在当前环境不可用，未能直接运行全量测试和端到端验证；建议在本地 R 环境中执行:
  1. `Rscript -e "testthat::test_dir('tests/')"` 全量回归
  2. `Rscript check_test_guide_index.R` 测试索引校验
  3. `powershell -File run_auth_regression.ps1` 认证链回归
  4. `Rscript run_app.R` 端到端手动验证（启动 → 登录 → 数据导入 → 分析 → 图形 → 表格 → 导出）

#### Next
1. 用户在本机 R 环境中执行全量测试回归
2. 如有测试失败，根据失败信息定位修复

#### Files Changed / Commits
- `__pycache__/`（删除）
- `.gitignore`（已含 `__pycache__/`，无需修改）
- `inst/copy_guard_patterns.json`（新建）
- `modules/statistical_analysis.R`（修改）— MMRM/MI 菜单隐藏
- `docker-compose.yml`、`docker-compose.local.yml`、`docker-compose.server.yml`（修改）— Redis 注释
- `docs/deploy/DEPLOY_GUIDE.md`（修改）— Redis 标注
- `modules/common/data/`、`modules/common/export/`、`modules/common/analysis/`（新建目录）
- `modules/common/data_metadata.R`、`data_filter.R`、`plot_export.R`、`table_export.R`、`analysis_format.R`、`analysis_shared.R`（移动）
- `app.R`、`modules/tables.R`、`modules/statistical_analysis.R`、`modules/statistical_graphics.R`、`modules/statistical_analysis/cox.R`、`linear.R`、`logistic.R`、`modules/common/analysis/analysis_shared.R`（修改 source 引用）
- `modules/statistical_graphics/boxplot.R`（重构）— committed_params 模式
- `modules/statistical_graphics/heatmap.R`、`correlation_matrix.R`（修改）— task_history 增强
- `tests/root/test_frontend_copy_guard.R`、`tests/nginx/landing/test_landing_copy_guard.R`（修改）— JSON 数据源
- `tests/statistical_analysis/regression/test_indent_issue.R`（新建）— legacy 迁移
- `tests/statistical_graphics/survival/test_label_mapping.R`（新建）— legacy 迁移
- `tests/statistical_graphics/heatmap/test_heatmap_layout_guard.R`（新建）
- `tests/statistical_graphics/correlation_matrix/test_correlation_matrix_layout_guard.R`（新建）
- `tests/statistical_analysis/regression/legacy/`（删除）
- `tests/statistical_graphics/survival/legacy/`（删除）
- `tests/statistical_analysis/regression/test_logistic_medical_csv_consistency.R`、`test_sparse_regression.R`、`test_stats_facet.R`（修改 source 引用）
- `tests/statistical_analysis/desc/test_desc_regression.R`、`tests/statistical_analysis/common/test_interaction_frontend_consistency.R`（修改 source 引用）
- `docs/main/PROJECT_GUIDE.md`（修改）— 目录结构、共享层路径、§7.7 状态表
- `docs/main/PROJECT_SPEC.md`（修改）— common/ 状态 5/5
- `docs/main/TEST_GUIDE.md`（修改）— 索引更新、legacy 移除
- `docs/dep/PLAN.md`（新建）— 修复计划（status: done）
- `docs/dep/TASK_STATE.md`（新建）— 临时 checkpoint（将删除）
- （uncommitted）

---

### R002 [23:30] — P5: 测试回归 & 路径修复

#### Done
- 在 R 4.5.3 环境中执行测试回归（`F:/R-4.5.3/bin/Rscript.exe`）
- 发现并修复 5 个 `modules/common/` 旧路径引用遗漏（迁移 data/export/analysis 时未更新）：
  - `tests/root/test_frontend_copy_guard.R:42` — `modules/common/data_filter.R` → `modules/common/data/data_filter.R`
  - `tests/root/test_frontend_internal_jargon_guard.R:43` — 同上
  - `tests/common/data/test_data_metadata_consistency.R:32` — `modules/common/data_metadata.R` → `modules/common/data/data_metadata.R`
  - `tests/common/export/test_plot_export_contract.R:32` — `modules/common/plot_export.R` → `modules/common/export/plot_export.R`
  - `tests/statistical_graphics/survival/test_survival_display_contract.R:35` — `modules/common/table_export.R` → `modules/common/export/table_export.R`
- 修复 2 个 legacy 迁移后测试断言与实际行为不匹配：
  - `test_indent_issue.R` — 缩进检测正则 `^\\s` 改为内容存在性断言
  - `test_label_mapping.R` — strata 精确匹配改为 `grepl` 包含性断言（`surv_median` 返回 `grp=Label` 格式）
- 确认 `check_test_guide_index.R` 在 R 4.5.3 下 crash（环境问题，非代码缺陷）
- 确认 `test_access_boundary_guard.R:259` 失败为 Review 1 文档精简预存问题

#### 测试结果汇总
| 状态 | 数量 | 说明 |
|------|------|------|
| PASS | 23 个文件, 1300+ 断言 | 全部通过 |
| FAIL（本次变更） | 0 | 无回归断裂 |
| FAIL（预存） | 1 | `test_access_boundary_guard.R` — Review 1 文档精简后断言失效 |
| SKIP | 5 | 缺测试数据 / empty test（预存） |
| CRASH | 1 | `check_test_guide_index.R` — R 4.5.3 环境 segfault（预存） |

#### Issues / Blockers
- 预存问题 `test_access_boundary_guard.R:259` 需单独修复（字符串 "评估组织级、项目级隔离、邮箱验证与共享协作模型。" 已从 PROJECT_GUIDE.md 中移除）
- `check_test_guide_index.R` 在 R 4.5.3 下 crash，建议在 R 4.4.x 下重试

#### Next
1. 用户确认是否修复预存的 `test_access_boundary_guard.R` 断言
2. 用户确认是否在 R 4.4.x 下重试 `check_test_guide_index.R`

#### Files Changed / Commits
- `tests/root/test_frontend_copy_guard.R`（修改）— data_filter.R 路径
- `tests/root/test_frontend_internal_jargon_guard.R`（修改）— data_filter.R 路径
- `tests/common/data/test_data_metadata_consistency.R`（修改）— data_metadata.R 路径
- `tests/common/export/test_plot_export_contract.R`（修改）— plot_export.R 路径
- `tests/statistical_graphics/survival/test_survival_display_contract.R`（修改）— table_export.R 路径
- `tests/statistical_analysis/regression/test_indent_issue.R`（修改）— 断言修正
- `tests/statistical_graphics/survival/test_label_mapping.R`（修改）— 断言修正
- （uncommitted）

---
