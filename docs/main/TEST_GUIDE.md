# AutoTFL 测试指南

## 1. 文档定位

- 本文档用于按项目架构整理当前测试资产，作为 `tests/` 目录的总索引。
- 整体性、跨模块、跨部署链路的测试说明统一放在 `docs/main/TEST_GUIDE.md`。
- `tests/` 目录继续只放测试代码、测试数据和少量专项验证脚本，不把测试说明文档散落进去。
- `docs/main/PROJECT_GUIDE.md` 只保留测试策略摘要；部署相关测试前置条件继续放在 `docs/deploy/DEPLOY_GUIDE.md`。

## 2. 落位规则

- 规范文档:
  - `docs/main/TEST_GUIDE.md`: 测试架构索引、归类规则、整体回归入口。
  - `docs/main/PROJECT_GUIDE.md`: 测试范围摘要、质量约束、维护边界。
  - `docs/deploy/DEPLOY_GUIDE.md`: 测试环境变量、联调环境、部署前验证事项。
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
- 工具链与入口层文案守卫:
  - `tests/root/test_precommit_contract.R`
  - `tests/root/test_entry_copy_guard.R`
- 统计分析子模块文案守卫:
  - `tests/statistical_analysis/ui/test_statistical_analysis_copy_guard.R`
- 统计图形结果区文案守卫:
  - `tests/statistical_graphics/ui/test_graphics_result_copy_guard.R`
- 统计图形导出卡文案守卫:
  - `tests/statistical_graphics/ui/test_graphics_export_copy_guard.R`
- 核心统计图形开发口径守卫:
  - `tests/statistical_graphics/ui/test_graphics_dev_copy_guard.R`
- 前端用户文案守卫:
  - `tests/root/test_frontend_copy_guard.R`
- 前端内部实现视角文案守卫:
  - `tests/root/test_frontend_internal_jargon_guard.R`
- 源码注释过程口径守卫:
  - `tests/root/test_source_comment_process_guard.R`
- 前端实现保持型文案守卫:
  - `tests/root/test_frontend_implementation_copy_guard.R`
- 账号入口与数据准备文案守卫:
  - `tests/root/test_frontend_auth_data_copy_guard.R`
- 管理员页与数据库管理页文案守卫:
  - `tests/root/test_frontend_admin_database_copy_guard.R`
- 账号页与数据库锁定态灰区文案守卫:
  - `tests/root/test_frontend_user_lock_copy_guard.R`
- 核心文档灰区进度口径守卫:
  - `tests/root/test_docs_grey_copy_guard.R`
- 核心文档公共壳与样板推进口径守卫:
  - `tests/root/test_docs_ui_progress_copy_guard.R`
- 核心文档 helper 与守卫新增口径守卫:
  - `tests/root/test_docs_helper_guard_copy_guard.R`
- PROJECT_GUIDE 状态型过程口径守卫:
  - `tests/root/test_project_guide_status_terms_guard.R`
- 访问边界与对外口径:
  - `tests/root/test_access_boundary_guard.R`
  - `tests/nginx/landing/test_landing_copy_guard.R`
- 应用入口与认证页整体布局:
  - `tests/root/test_app_auth_layout_guard.R`
  - `tests/root/test_app_loading_smoke_shinytest2.R`
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
- 账号入口共享文案守卫:
  - `tests/common/auth/test_auth_copy_guard.R`
- 账号设置与协作入口:
  - `tests/account_access/test_sidebar_account_card_guard.R`
  - `tests/account_access/test_user_profile_guard.R`
  - `tests/account_access/test_permission_manager_guard.R`
  - `tests/account_access/test_account_access_smoke_shinytest2.R`
  - `tests/common/auth/test_auth_access_postgres_integration.R`
- `analysis_states` 契约:
  - `tests/common/auth/test_auth_analysis_states_schema_contract.R`
- 管理员入口 smoke:
  - `tests/admin_manager/test_admin_manager_smoke_shinytest2.R`
- 管理员入口布局守卫:
  - `tests/admin_manager/test_admin_manager_layout_guard.R`

### 3.3 数据接入、数据准备与数据库管理

- 数据元数据与标签一致性:
  - `tests/common/data/test_data_metadata_consistency.R`
- 存储后端契约:
  - `tests/common/storage/test_storage_backend.R`
- 公共筛选与任务历史 UI 守卫:
  - `tests/common/ui/test_data_filter_card_ui_guard.R`
  - `tests/common/ui/test_task_history_card_ui_guard.R`
- 数据准备 UI 守卫:
  - `tests/data_preparation/test_data_preparation_card_ui_guard.R`
- 数据准备数据集路径回退守卫:
  - `tests/data_preparation/test_data_preparation_dataset_path_guard.R`
- 数据库管理布局守卫:
  - `tests/database_manager/test_database_manager_layout_guard.R`
- 数据读取 I/O:
  - `tests/common/data/test_data_io_upload_extension.R`

### 3.4 统计分析总入口与分析共享层

- 分析格式化与共享逻辑:
  - `tests/common/analysis/test_analysis_format.R`
  - `tests/common/analysis/test_analysis_shared.R`
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
- 缩进格式专项验证:
  - `tests/statistical_analysis/regression/test_indent_issue.R`

### 3.6 统计图形共享层与公共契约

- common UI、导出与命名空间:
  - `tests/common/graphics/test_graphics_common_ui.R`
  - `tests/common/export/test_plot_export_contract.R`
  - `tests/common/export/test_table_export_contract.R`
  - `tests/common/graphics/test_graphics_module_ns_guard.R`
  - `tests/common/graphics/test_graphics_validate_namespace_guard.R`
- 图形公共行为与错误提示:
  - `tests/common/graphics/test_graphics_progress_common.R`
  - `tests/common/graphics/test_graphics_user_error_guard.R`
  - `tests/common/graphics/test_graphics_preset_guard.R`
  - `tests/common/graphics/test_graphics_override_colors.R`
- 字体、任务历史与状态恢复:
  - `tests/common/graphics/test_graphics_font_support_guard.R`
  - `tests/common/graphics/test_font_warning_suppression.R`（PostScript 字体警告防回归 + 生存分析默认参数守卫）
  - `tests/common/graphics/test_graphics_task_state_helpers.R`

### 3.7 统计图形子模块

- 入口层 UI 守卫:
  - `tests/statistical_graphics/ui/test_statistical_graphics_layout_guard.R`
- Survival:
  - `tests/statistical_graphics/survival/test_survival_layout_guard.R`
  - `tests/statistical_graphics/survival/test_survival_display_contract.R`
  - `tests/statistical_graphics/survival/test_survival_median_ci_baseline.R`
  - `tests/statistical_graphics/survival/test_survival_selection_resolution.R`
  - `tests/statistical_graphics/survival/test_survival_view_committed_state.R`
  - `tests/statistical_graphics/survival/test_label_mapping.R`
- Combo:
  - `tests/statistical_graphics/combo/test_combo_layout_guard.R`
- Boxplot:
  - `tests/statistical_graphics/boxplot/test_boxplot_layout_guard.R`
- Spider:
  - `tests/statistical_graphics/spider/test_spider_layout_guard.R`
- Swimmer:
  - `tests/statistical_graphics/swimmer/test_swimmer_layout_guard.R`
- Forest:
  - `tests/statistical_graphics/forest/test_forest_layout_guard.R`
  - `tests/common/graphics/test_forest_table_state_helpers.R`
  - `tests/common/graphics/test_forest_result_schema_helpers.R`
- Waterfall:
  - `tests/statistical_graphics/waterfall/test_waterfall_layout_guard.R`
  - `tests/statistical_graphics/waterfall/test_waterfall_symbol_choices.R`
- Heatmap:
  - `tests/statistical_graphics/heatmap/test_heatmap_layout_guard.R`
- Correlation Matrix:
  - `tests/statistical_graphics/correlation_matrix/test_correlation_matrix_layout_guard.R`

### 3.8 预设输出、导出与外部页面

- 探索分析入口:
  - `tests/exploratory_analysis/test_exploratory_analysis_layout_guard.R`
- Listing / 表格导出:
  - `tests/tables/test_tables_layout_guard.R`
  - `tests/tables/test_listing_general_contract.R`
  - `tests/tables/test_t_dm_contract.R`
  - `tests/tables/test_t_ae_soc_pt_contract.R`
  - `tests/tables/test_ae_sidebyside_contract.R`
  - `tests/tables/test_tables_committed_state.R`
- Landing 与外部入口:
  - `tests/nginx/landing/test_landing_copy_guard.R`

### 3.9 测试数据与特殊说明

- 共享测试数据:
  - `tests/fixtures/medical_test_data.csv`
- 已迁移至 testthat 标准格式的遗留测试:
  - `tests/statistical_analysis/regression/test_indent_issue.R`（原 legacy）
  - `tests/statistical_graphics/survival/test_label_mapping.R`（原 legacy）

## 4. 当前回归入口

- 账号与权限链路:
  - `run_auth_regression.ps1`
  - `tests/common/auth/auth_regression_manifest.json`
- 本地应用联调与集成回归:
  - `run_app_test.ps1`
- 测试索引一致性校验:
  - `Rscript tests/check_test_guide_index.R`
- 长输出问题定位:
  - 优先采用“静态定位 + 最小验证”，先锁定目标文件，再执行单文件测试。

## 5. 测试维护规则

- 新增测试文件后，同步更新本文档 §3 的架构分类索引。
- 新增测试后至少执行一次 `Rscript tests/check_test_guide_index.R` 校验索引一致性，该检查已纳入 pre-commit。
- 测试依赖夹具、环境变量或数据库 schema 时，需在本文档登记前置条件。
- 若测试被纳入 `run_auth_regression.ps1`，需同步更新 `tests/common/auth/auth_regression_manifest.json`。
- 涉及文案变更时，同步检查对应的文案守卫测试（详见 §3.1 列表）。

### 新增测试更新清单

- 将新增 `tests/**/test_*.R` 或 `tests/fixtures/**` 登记到 §3 对应架构分类。
- 执行 `Rscript tests/check_test_guide_index.R` 校验索引覆盖。
- 若新增测试依赖数据库、环境变量、外部服务或按需 smoke 开关，在 §4 或对应分类下注明入口与前置条件。

## 6. Legacy 说明

2 个历史脚本式验证文件已在 Review 2 整改中迁移为标准 `testthat` 用例（详见 §3.5 和 §3.7），原 `legacy/` 目录已移除。

