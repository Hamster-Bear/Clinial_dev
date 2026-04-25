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
- 公共筛选与任务历史 UI 守卫:
  - `tests/common/ui/test_data_filter_card_ui_guard.R`
  - `tests/common/ui/test_task_history_card_ui_guard.R`
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

- 入口层 UI 守卫:
  - `tests/statistical_graphics/ui/test_statistical_graphics_layout_guard.R`
  - `tests/statistical_graphics/ui/test_graphics_dev_copy_guard.R`
- Survival:
  - `tests/statistical_graphics/survival/test_survival_layout_guard.R`
  - `tests/statistical_graphics/survival/test_survival_display_contract.R`
  - `tests/statistical_graphics/survival/test_survival_median_ci_baseline.R`
  - `tests/statistical_graphics/survival/test_survival_selection_resolution.R`
  - `tests/statistical_graphics/survival/test_survival_view_committed_state.R`
  - `tests/statistical_graphics/survival/legacy/test_label_mapping.R`
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
- Waterfall:
  - `tests/statistical_graphics/waterfall/test_waterfall_layout_guard.R`
  - `tests/statistical_graphics/waterfall/test_waterfall_symbol_choices.R`

### 3.8 预设输出、导出与外部页面

- 探索分析入口:
  - `tests/exploratory_analysis/test_exploratory_analysis_layout_guard.R`
- Listing / 表格导出:
  - `tests/tables/test_tables_layout_guard.R`
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
  - `tests/common/auth/auth_regression_manifest.json`
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
- `run_auth_regression.ps1` 当前通过 `tests/common/auth/auth_regression_manifest.json` 读取固定执行顺序；新增或移除认证链路测试时，需同步更新清单与契约测试。
- 账号设置与协作入口的 UI 守卫，优先验证“侧边栏个人信息卡快捷入口 + 隐藏页签接线 + 模块挂载”，不再把侧边栏菜单可见性作为主断言。
- 账号入口展示文案调整后，除更新模块代码外，还需同步检查 `modules/common/auth/auth_copy.R`、对应守卫测试以及 `PROJECT_GUIDE.md` / `PROJECT_SPEC.md` 中的结构约束描述是否仍一致。
- 账号页聚合布局若涉及标签页切换、卡片可见性或登录后真实跳转，优先补充 `shinytest2` smoke；当前 `tests/account_access/test_account_access_smoke_shinytest2.R` 仅在显式设置 `RUN_ACCOUNT_ACCESS_SMOKE=1` 且提供普通用户 smoke 账号环境变量时执行。
- 若测试路径被产品文档、部署文档或守卫测试引用，需同步更新 `README.md`、`PROJECT_GUIDE.md`、`DEPLOYMENT_GUIDE.md` 与相关守卫断言。
- Landing 页改动需同步校验 `tests/nginx/landing/test_landing_copy_guard.R`：对外命名应保持 Medev，禁止引入虚构图表示意、项目进度文案，并保留真实截图的图片占位结构。
- 调整前端用户可见说明文案后，需同步检查 `tests/root/test_frontend_copy_guard.R`，确保 `subtitle`、`app_card_note`、`helpText`、`note` 等位置未回流开发阶段口径。
- 调整入口层共享文案、公共筛选卡、任务历史卡或入口页结果说明后，需同步检查 `tests/root/test_frontend_internal_jargon_guard.R`，确保“工作台复用”“总入口内”“动态 UI”“类型分支”“代码草稿”等内部实现视角词未回流到用户文案。
- 调整 `tables.R`、`statistical_analysis.R` 或 `modules/common/stat_analysis_submodule_copy.R` 中的参数说明、结果 `note` 与共享 copy 后，需同步检查 `tests/root/test_frontend_implementation_copy_guard.R`，确保“保持原有逻辑”“server 校验”“统一空状态提示”“原有处理方式”等实现保持型表述未回流到用户文案。
- 调整 `auth_manager.R`、`modules/common/auth/auth_copy.R`、`data_preparation.R`、`permission_manager.R` 或 `user_profile.R` 的用户说明后，需同步检查 `tests/root/test_frontend_auth_data_copy_guard.R`，确保“统一认证入口”“后续扩展”“聚合展示”“协作工作台”“不改变原有加载能力”等结构或开发口径未回流。
- 调整 `admin_manager.R` 或 `database_manager.R` 的主卡标题、副标题、说明文案后，需同步检查 `tests/root/test_frontend_admin_database_copy_guard.R`，确保“系统管理入口”“集中处理”“统一筛查”“数据空间工作台”“统一完成整理与导入”“阶段二将 ...”等结构或阶段口径未回流。
- 调整 `user_profile.R` 或 `database_manager.R` 锁定态中的说明文案后，需同步检查 `tests/root/test_frontend_user_lock_copy_guard.R`，确保“集中到同一张功能卡片”“改为登录后自助完成”“仅保留基础密码修改”“不扩展其它账号管理能力”“开放前”等灰区结构口径未回流。
- 调整 `README.md`、`PROJECT_GUIDE.md` 或 `DEPLOYMENT_GUIDE.md` 中的认证、入口和管理员说明后，需同步检查 `tests/root/test_docs_grey_copy_guard.R`，确保“当前显式提供”“当前已改为更明显的”“当前已抽成独立模块”“当前已提供管理员操作入口”“继续看到 ...”等进度口径未回流。
- 调整 `README.md`、`PROJECT_GUIDE.md` 或 `DEPLOYMENT_GUIDE.md` 中的公共壳接入、样板覆盖和结果区统一说明后，需同步检查 `tests/root/test_docs_ui_progress_copy_guard.R`，确保“接入推进”“样板落到”“继续统一”这类研发推进口径未回流。
- 调整 `PROJECT_GUIDE.md`、`README.md` 或 `DEPLOYMENT_GUIDE.md` 中的共享 helper、共享 copy 源、smoke test 或布局/UI 守卫说明后，需同步检查 `tests/root/test_docs_helper_guard_copy_guard.R`，确保“新增共享源”“收口到”“补充守卫”“补充 smoke test”这类实施记录式口径未回流。
- 调整 `PROJECT_GUIDE.md` 中的模块现状、能力矩阵或章节标题后，需同步检查 `tests/root/test_project_guide_status_terms_guard.R`，确保“已完成”“已落地”“增强中”“已开始接入”这类状态型过程口径未回流。
- 调整统计分析、统计图形、Tables 或探索分析入口层文案后，需同步检查 `tests/root/test_entry_copy_guard.R`，确保入口模块仍从 `modules/common/entry_copy.R` 读取共享文案。
- 调整 `statistical_graphics.R` 的入口共享文案接线或 `renderUI()` 结果区时，需同步检查 `tests/statistical_graphics/ui/test_statistical_graphics_layout_guard.R`，确保 server 侧也在本作用域内读取 `ENTRY_COPY$statistical_graphics`，避免运行时报 `找不到对象 'copy'`。
- 调整 `desc`、`cox`、`logistic`、`linear`、`anova`、`chisq` 的说明块后，需同步检查 `tests/statistical_analysis/ui/test_statistical_analysis_copy_guard.R`，确保子模块继续从 `modules/common/stat_analysis_submodule_copy.R` 读取共享说明文案。
- 调整 `survival_analysis`、`forest_plot`、`combo_plot`、`waterfall_plot`、`swimmer_plot`、`spider_plot` 结果区通用文案后，需同步检查 `tests/statistical_graphics/ui/test_graphics_result_copy_guard.R`，确保模块继续从 `modules/common/graphics_result_copy.R` 读取共享结果区文案。
- 调整 `survival_analysis`、`forest_plot`、`combo_plot`、`waterfall_plot`、`swimmer_plot`、`spider_plot` 导出卡通用文案后，需同步检查 `tests/statistical_graphics/ui/test_graphics_export_copy_guard.R`，确保模块继续从 `modules/common/graphics_export_copy.R` 读取共享导出卡文案。
- 调整 `combo_plot`、`forest_plot`、`swimmer_plot`、`waterfall_plot`、`spider_plot` 的 `helpText()`、`help_text` 或局部 `note` 后，需同步检查 `tests/statistical_graphics/ui/test_graphics_dev_copy_guard.R`，确保高风险开发阶段口径未回流到核心图形模块。
- 调整 `.pre-commit-config.yaml` 或新增快速守卫入口后，需同步检查 `tests/root/test_precommit_contract.R`，确保独立的前端文案守卫 hook 未被移除。
- 调整测试目录后，至少执行一次 `check_test_guide_index.R` 或对应守卫测试，确认 `TEST_GUIDE.md` 与 `tests/` 实际文件保持一致。

## 7. Legacy 收口计划

- 当前 `legacy` 目录仅保留两类历史脚本式验证：
  - `tests/statistical_analysis/regression/legacy/test_indent_issue.R`
  - `tests/statistical_graphics/survival/legacy/test_label_mapping.R`
- 迁移目标：逐步改写为标准 `testthat` 用例，并移动回对应模块主目录，避免长期保留“脚本式验证”分支。
- 迁移优先级：先迁移被业务逻辑频繁触达、且已经有相邻 `testthat` 套件可复用夹具的文件。
- 迁移完成后：从 `legacy/` 移除原脚本，同时更新本文件索引、相关回归入口和守卫断言。
