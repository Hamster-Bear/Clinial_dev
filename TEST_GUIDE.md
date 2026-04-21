# AutoTFL 测试指南

## 1. 文档定位

- 本文档用于按项目架构整理当前测试资产，作为 `tests/` 目录的总索引。
- 整体性、跨模块、跨部署链路的测试说明统一放在项目根目录的 `TEST_GUIDE.md`。
- `tests/` 目录继续只放测试代码、测试数据和少量专项验证脚本，不把测试说明文档散落进去。
- `PROJECT_GUIDE.md` 只保留测试策略摘要；部署相关测试前置条件继续放在 `DEPLOYMENT_GUIDE.md`。

## 2. 落位规则

- 根目录文档:
  - `TEST_GUIDE.md`: 测试架构索引、归类规则、整体回归入口。
  - `PROJECT_GUIDE.md`: 测试范围摘要、质量约束、维护边界。
  - `DEPLOYMENT_GUIDE.md`: 测试环境变量、联调环境、部署前验证事项。
- `tests/` 目录:
  - 自动化测试文件统一使用 `test_*.R` 命名，并按项目架构放入对应子目录。
  - 当前建议子目录与项目结构保持同层语义，例如 `tests/common/auth/`、`tests/statistical_analysis/`、`tests/statistical_graphics/`、`tests/nginx/landing/`、`tests/root/`。
  - 测试夹具和示例数据统一放在 `tests/fixtures/`，当前为 `medical_test_data.csv`。
  - 历史专项验证脚本若暂未迁移到 `testthat`，也先留在 `tests/`，但要在本文档中显式标记。

## 3. 按架构归类的测试索引

### 3.1 全局与跨架构

- 文档与规范守卫:
  - `tests/root/test_project_docs_guard.R`
  - `tests/root/test_test_guide_index_contract.R`
- 访问边界与对外口径:
  - `tests/root/test_access_boundary_guard.R`
  - `tests/nginx/landing/test_landing_copy_guard.R`
- 应用入口与认证页整体布局:
  - `tests/root/test_app_auth_layout_guard.R`
- 运行与回归脚本契约:
  - `tests/root/test_run_app_test_script_contract.R`
  - `tests/root/test_run_auth_regression_script_contract.R`
- 部署脚本与发布辅助契约:
  - `tests/root/test_deploy_scripts_contract.R`

### 3.2 认证、权限与任务状态持久化

- 认证基础 helper:
  - `tests/common/auth/test_auth_helpers.R`
  - `tests/common/auth/test_email_service_helpers.R`
- 账号与服务层 helper:
  - `tests/common/auth/test_account_service_helpers.R`
  - `tests/common/auth/test_account_service_analysis_states.R`
- 权限边界与协作入口:
  - `tests/workspace_access_manager/test_workspace_access_manager_guard.R`
  - `tests/common/auth/test_auth_access_postgres_integration.R`
- `analysis_states` 契约:
  - `tests/common/auth/test_auth_analysis_states_schema_contract.R`
- 管理员入口 smoke:
  - `tests/admin_manager/test_admin_manager_smoke_shinytest2.R`

### 3.3 数据接入、数据准备与数据库管理

- 数据元数据与标签一致性:
  - `tests/common/data/test_data_metadata_consistency.R`
- 数据准备 UI 守卫:
  - `tests/data_preparation/test_data_preparation_card_ui_guard.R`
- 数据库管理布局守卫:
  - `tests/database_manager/test_database_manager_layout_guard.R`

### 3.4 统计分析总入口与分析共享层

- 总入口与结果区 UI 守卫:
  - `tests/statistical_analysis/ui/test_statistical_analysis_layout_guard.R`
  - `tests/statistical_analysis/ui/test_statistical_analysis_result_ui_guard.R`
- 子模块 UI 守卫:
  - `tests/statistical_analysis/ui/test_statistical_analysis_submodule_ui_guard.R`
  - `tests/statistical_analysis/ui/test_statistical_analysis_regression_submodule_ui_guard.R`
  - `tests/statistical_analysis/ui/test_statistical_analysis_basic_submodule_ui_guard.R`
- 分析共享层与前后端一致性:
  - `tests/statistical_analysis/common/test_compute_render_decoupling.R`
  - `tests/statistical_analysis/common/test_interaction_frontend_consistency.R`

### 3.5 统计分析算法与业务回归

- 描述性统计:
  - `tests/statistical_analysis/desc/test_desc_regression.R`
- Logistic / Linear / Cox 回归:
  - `tests/statistical_analysis/regression/test_logistic_medical_csv_consistency.R`
  - `tests/statistical_analysis/regression/test_logistic_regression.R`
  - `tests/statistical_analysis/regression/test_regression_formula_validation.R`
  - `tests/statistical_analysis/regression/test_regression_ratio_by_subgroup.R`
  - `tests/statistical_analysis/regression/test_sparse_regression.R`
  - `tests/statistical_analysis/regression/test_stats_facet.R`
- 历史专项验证脚本:
  - `tests/statistical_analysis/regression/legacy/test_indent_issue.R`

### 3.6 统计图形共享层与公共契约

- common UI、导出与命名空间:
  - `tests/common/graphics/test_graphics_common_ui.R`
  - `tests/common/export/test_plot_export_contract.R`
  - `tests/common/graphics/test_graphics_module_ns_guard.R`
  - `tests/common/graphics/test_graphics_validate_namespace_guard.R`
- 图形公共行为与错误提示:
  - `tests/common/graphics/test_graphics_progress_common.R`
  - `tests/common/graphics/test_graphics_user_error_guard.R`
  - `tests/common/graphics/test_graphics_preset_guard.R`
  - `tests/common/graphics/test_graphics_override_colors.R`
- 字体、任务历史与状态恢复:
  - `tests/common/graphics/test_graphics_font_support_guard.R`
  - `tests/common/graphics/test_graphics_task_state_helpers.R`

### 3.7 统计图形子模块

- Survival:
  - `tests/statistical_graphics/survival/test_survival_display_contract.R`
  - `tests/statistical_graphics/survival/test_survival_median_ci_baseline.R`
  - `tests/statistical_graphics/survival/test_survival_selection_resolution.R`
  - `tests/statistical_graphics/survival/test_survival_view_committed_state.R`
  - `tests/statistical_graphics/survival/legacy/test_label_mapping.R`
- Forest:
  - `tests/common/graphics/test_forest_table_state_helpers.R`
- Waterfall:
  - `tests/statistical_graphics/waterfall/test_waterfall_symbol_choices.R`

### 3.8 预设输出、导出与外部页面

- Listing / 表格导出:
  - `tests/tables/test_listing_general_contract.R`
- Landing 与外部入口:
  - `tests/nginx/landing/test_landing_copy_guard.R`

### 3.9 测试数据与特殊说明

- 共享测试数据:
  - `tests/fixtures/medical_test_data.csv`
- 当前仍属脚本式验证、后续建议继续标准化到 `testthat` 的文件:
  - `tests/statistical_analysis/regression/legacy/test_indent_issue.R`
  - `tests/statistical_graphics/survival/legacy/test_label_mapping.R`

## 4. 当前回归入口

- 账号与权限链路:
  - `run_auth_regression.ps1`
- 本地应用联调与集成回归:
  - `run_app_test.ps1`
- 测试索引一致性校验:
  - `check_test_guide_index.R`
- 长输出问题定位:
  - 优先采用“静态定位 + 最小验证”，先锁定目标文件，再执行单文件测试。

## 5. 维护约束

- 新增测试文件后，除更新 `tests/` 外，还要同步更新本文件的架构分类索引。
- 若新增的是跨模块、跨部署或跨环境的整体性测试，优先补到本文件和根目录规范文档，不额外在 `tests/` 下堆新的说明文档。
- 若某个测试文件已经演变成长期维护的验证脚本，应优先迁移为 `testthat` 风格，并补充清晰的归属分类。
- 若某个模块未来需要更细的专项测试说明，可在本文档下继续追加子章节，但仍以“按项目架构归类”作为第一层组织原则。

## 6. 新增测试更新清单

- 新增测试文件后，先确认其归属模块，再放入与项目结构语义一致的子目录，而不是继续堆在 `tests/` 根目录。
- 在本文件登记该测试的架构归属、完整相对路径，以及它属于 UI 守卫、契约测试、集成测试还是专项回归。
- 若测试依赖夹具、示例数据、环境变量、数据库 schema 或管理员账号，需同步登记依赖前置条件。
- 若测试被纳入统一回归入口，如 `run_auth_regression.ps1`，需同步更新脚本列表与对应契约测试。
- 若测试路径被产品文档、部署文档或守卫测试引用，需同步更新 `README.md`、`PROJECT_GUIDE.md`、`DEPLOYMENT_GUIDE.md` 与相关守卫断言。
- 调整测试目录后，至少执行一次 `check_test_guide_index.R` 或对应守卫测试，确认 `TEST_GUIDE.md` 与 `tests/` 实际文件保持一致。

