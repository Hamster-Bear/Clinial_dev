# AutoTFL 项目技术规格书 (PROJECT\_SPEC.md)

## 1. 项目愿景

AutoTFL 旨在为医学和临床数据分析提供一套自动化、可复现的 TFL (Table, Figure, Listing) 生成方案。它是 Hamster Analysis 平台的核心应用，支持从数据导入到报表导出的全流程闭环。

## 2. 核心架构

- **表现层**: R Shiny (shinydashboard + bslib)，采用模块化 (Shiny Modules) 开发。
- **逻辑层**: 纯 R 驱动，核心统计依赖 `survival`, `gtsummary`, `rtables`；图形渲染采用 `showtext` 以确保跨平台（如 Docker/Windows/Linux）中文字体显示一致性。应用入口需优先注册本地 CJK 字体别名 `Noto Sans SC`，Docker 镜像需内置 `fonts-noto-cjk` / `fonts-wqy-zenhei` 等离线可用字体；字体策略上需拆为三层：拉丁字体 `latin_family`、中文字体 `cjk_family`、版式测量字体 `layout_family`。`Arial` 等在 `cowplot` / `grid` 组合测量阶段先回退到 `layout_family`，包含 CJK 的绘图文本再优先选择已注册的 CJK 字体，避免同时出现 `PostScript` 字体告警与中文缺字。
- **图形共享层**: `graphics_common.R` 与 `common_ui_shell.R` 统一维护图形尺寸模式、画布边框、页面距、前端居中容器、参考线抽象以及 PX/英寸换算；默认按 `96 px = 1 in` 同步前端与导出比例，避免页面不截断但导出截断。
- **持久层**:
  - 元数据：PostgreSQL (管理 Workspace, Folder, Dataset 关系)。
  - 数据体：本地 RDS 文件或 AWS S3 对象存储。
- **网关层**: Nginx 处理反向代理、SSL 卸载及静态 Landing 页。

## 3. 功能模块

- **数据管理 (Database Manager)**: 支持单文件上传、批量上传及服务器目录导入。
- **数据准备 (Data Prep)**: 负责数据筛选、列映射及变量元数据（Label/Type）推断。
- **统计分析 (Statistical Analysis)**: 覆盖描述性统计、Cox/Logistic/线性回归、ANOVA 等。
- **统计图形 (Statistical Graphics)**: 提供生存分析图、森林图、泳道图等医学常用图形；其中生存分析的统计摘要当前区分主开关 `show_stats` 与细粒度开关 `show_cox_p`，后者仅控制分层时 Cox 摘要行中的 P 值显示，不影响 HR 与 95%CI 计算。
- **图形输出一致性**: 统计图形模块需保证前端静态图、交互图与导出尺寸模式一致；带轨道/风险表的组合图在导出时需按当前前端画布高度同步扩展导出高度。
- **报表导出**: 支持 Word (RTF/DOCX), PDF, HTML 格式。
- **分析状态管理 (Analysis State Manager)**: 当前已为统计图形模块落地 `analysis_states` 持久化底座，并抽离共享 `task_history` 模块承载任务历史 UI/加载逻辑；现阶段仍嵌入统计图形页内，不单列左侧一级菜单。当前支持按用户保存/加载图形子模块的完整参数、UI 状态、模块类型与用户自定义 note；不保存图对象、分析结果对象或原始数据副本，载入后由各模块按 `state/apply_state` 契约恢复控件状态。状态快照只应包含业务参数，不应持久化 DT/Plotly 等输出组件派生的临时交互输入，也不应保存配置页签等纯导航态；恢复旧快照时也需跳过这些字段。任务历史同时支持删除。workspace 为空时保存为个人任务；service 层需通过 `service_normalize_analysis_state_workspace_id()` 将空字符串/NULL 以及带 `id` 字段的 list/data.frame 统一归一为数据库中的 `NULL` 或单一 workspace id。`analysis_states` 的数据库约束需保证“同一用户 + 同一任务作用域 + 同一模块 + 同一任务名”在 workspace 内唯一，个人任务与 workspace 任务分别使用独立唯一索引；但运行时覆盖保存不能依赖 `ON CONFLICT` 成为前置条件，service 层必须先按自然键查找同名任务，命中时显式更新 `payload/note/updated_at`，未命中才插入新记录，从而兼容尚未完成迁移的旧库。对已部署旧库的 schema 变更必须提供显式迁移脚本与运行时迁移逻辑，避免旧 UNIQUE 约束、重复数据或字段漂移导致上线后失败。后续再继续扩展到统计分析模块与更完整的任务资产管理。
- **图形参数抽象层 (Graphics Parameter Abstractions)**: 首批共享参数卡片限定为列映射块、时间轴块、导出块三类，统一沉淀在 `common_ui_shell.R`；它们只负责高重复 UI 结构和布局规范，不直接承载业务计算。动态事件映射、复杂颜色映射、列显示配置等高动态区块留待下一批单独抽象。
- **组合图当前收口状态**: `combo_plot.R` 已按统一“3 个顶层功能卡片 + 结果区动作条”布局回正，结果区固定为 `静态图 / 交互图 / 数据`；其高动态图层参数仍保留模块内动态页签，任务历史恢复采用“基础输入先回填、动态图层参数后回填”的分阶段策略。本轮不改组合图绘图算法、自动标题生成与固定 `12 x 8` 英寸导出逻辑。
- **森林图当前收口状态**: `forest_plot.R` 已完成首轮外层 UI 收口，回正为 `数据与变量 / 图形与样式 / 输出与导出` + 结果区动作条；结果区统一为 `静态图 / 交互图 / 数据`，其中“数据”内继续保留 `数据预览 / 统计报告`。第二轮已将预处理列映射、标题文本、坐标显示、配色样式和导出参数切到 common helper；当前 `precalculated/raw_data` 双模式、表格列配置与绘图算法仍保留模块内实现，后续再继续下沉 common 抽象与职责拆分。
- **森林图状态恢复边界**: 动态列配置输入（如 `name_*` / `align_*`）不再作为直接任务输入恢复对象，而是通过 `selected_table_cols + display_names + alignments` 的 `extra_state` 统一桥接恢复，避免在动态 UI 尚未创建时直接回填输入值导致恢复顺序不稳定。
- **森林图结果 schema 边界**: `forest_plot.R` 已引入统一结果 normalizer，将 `precalculated` 与 `raw_data` 两条链路都映射到同一 forest result schema，再由预览与绘图层消费；表格列选择与列配置的 UI 壳层则统一复用 common 的 `graphics_table_panel_ui()`。后续 service 拆分应围绕这套统一 schema 继续推进，而不是再按双模式分叉扩展消费逻辑。
- **森林图 helper 拆分边界**: 森林图已完成真实文件迁移，不再使用过渡文件 `forest_plot_helpers.R`。当前 helper 已按职责拆到 `modules/common/graphics/forest_table_state_helpers.R`、`forest_result_schema_helpers.R`、`forest_model_helpers.R`、`forest_analysis_pipeline.R`；`forest_plot.R` 仅负责模块编排、输入输出桥接和绘图消费。
- **森林图分析结果拼装边界**: `analysis_results()` 中与模型结果整形相关的逻辑，当前由 `modules/common/graphics/forest_result_schema_helpers.R` 与 `forest_analysis_pipeline.R` 承担，包括结果提取与最终结果汇总格式化；`forest_plot.R` 保留触发、通知与后续消费职责。
- **森林图模型执行边界**: 输入预处理、公式构造与模型拟合执行当前由 `modules/common/graphics/forest_model_helpers.R` 承担；`forest_plot.R` 负责输入校验、流程控制、通知与结果消费。后续若继续 service 化，应优先围绕这些 common helper 再做聚合，而非回流到主模块。
- **森林图分析流水线边界**: `analysis_results()` 的循环调度和结果汇总触发已进一步收口到 `forest_run_analysis_pipeline()`。当前 helper 层已覆盖“预处理、公式构造、模型拟合、结果提取、汇总格式化”整条流水线；`forest_plot.R` 主要承担触发、输入校验、通知与后续消费。后续真正 service 化时，应优先围绕该 pipeline helper 拆分，而不是回到主模块重新拼装流程。
- **森林图列选择稳定性边界**: `selected_table_cols` 在进入 observer 中的 `sort()`、`intersect()` 或等价比较前，必须先经 `forest_normalize_selected_columns()` 归一化为原子字符向量；这条约束同时覆盖手工选择、任务历史恢复与 `selectizeInput` 回填路径，避免出现 `sort.int: 'x'必需为基元`。
- **森林图列映射恢复边界**: 列映射类选择器在任务历史恢复时必须采用“数据模式/普通输入先恢复，列 choices 更新后再回填映射值”的顺序；不得在 choices 尚未建立时直接恢复 `subgroup_col / study_col / estimate_col / lower_col / upper_col / time_col / status_col / outcome_col / covariates`，否则会导致预处理数据列映射错位。当前实现采用 pending restore：先缓存历史映射快照，待当前数据列可解析保存列名后再消费恢复。
- **森林图参考线语义边界**: `参考线` 页签只承载参考线语义，并统一走公共参考线控件；参考线位置、颜色、线型、线宽必须真实传递到绘图层。误差线宽和端帽长度属于图层样式参数，不属于参考线参数。
- **森林图目标目录收口**: 为保持 `modules/statistical_graphics/` 目录干净，森林图后续按“1 个模块主文件 + 4 个 common helper 文件”推进，不再在 `modules/statistical_graphics/` 下继续新增辅助文件。目标 helper 归档到 `modules/common/graphics/`，暂定拆分为 `forest_table_state_helpers.R`、`forest_result_schema_helpers.R`、`forest_model_helpers.R`、`forest_analysis_pipeline.R`。
- **common 目标归类**: `modules/common/` 后续按 `auth / data / analysis / graphics / export` 五类清爽收口。这里的“后端服务域”优先指账号认证、权限、会话、workspace 与持久化服务，而不是图形模块内部 `server` 函数拆分。
- **森林图图形 server 拆分暂缓**: 当前只收紧 helper 与目录声明，不直接改动图形模块内部 `server` 实现；后续若拆后端服务域，也优先进入 `modules/common/auth/` 等服务域目录，不再单独新增图形专属的 server 目录层级。
- **测试执行策略**: 对长输出守卫测试或联调脚本，优先采用“静态定位 + 最小验证”流程：先用代码检索定位失败范围，再使用 `testthat::test_file(..., reporter = "summary")` 执行目标测试文件，避免整份长输出脚本占满终端或造成沙盒卡住。

## 3.1 研发工具链

- 当前仓库已补充 `.pre-commit-config.yaml`，用于串联 `styler`、`lintr` 与 `testthat` 守卫测试。
- `install_dependencies.R` 已将 `jsonlite`、`lintr`、`styler`、`shinytest2` 纳入开发依赖入口，便于本地和容器环境统一安装。

## 4. 权限模型

- 采用基于 Workspace 的隔离机制。
- 系统管理员 (Admin) 拥有服务器目录导入及全局管理权限；普通用户仅限个人 Workspace。

## 5. 部署形态

- 容器化部署：提供 Docker Compose 编排文件（Local/Server 场景）。
- 离线支持：通过 `download_offline_packages.R` 支持内网环境依赖安装。

