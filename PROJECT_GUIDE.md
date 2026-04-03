# AutoTFL 项目全局开发与维护指南 (Project Guide)

欢迎来到 AutoTFL (Medical Data Analysis Suite) 开发指南。本文档作为整个项目的“灯塔”，极尽详细地说明了系统架构、模块功能、数据流转、统计学计算规范、部署方案及未来改进点，旨在帮助新老开发者快速上手、降低维护成本。

***

## 目录

1. [项目简介与架构概览](#1-项目简介与架构概览)
2. [项目目录结构说明](#2-项目目录结构说明)
3. [核心模块 (Core Modules) 功能详解](#3-核心模块-core-modules-功能详解)
4. [子模块 (Sub-Modules) 功能详解](#4-子模块-sub-modules-功能详解)
5. [公共组件与共享工具 (Common Utils)](#5-公共组件与共享工具-common-utils)
6. [数据格式与统计规范 (Data & Statistical Specs)](#6-数据格式与统计规范-data--statistical-specs)
7. [部署与依赖管理指南 (Deployment & Dependencies)](#7-部署与依赖管理指南-deployment--dependencies)
8. [未来改进点与路线图 (Future Improvements)](#8-未来改进点与路线图-future-improvements)
9. [首席编程视角：架构治理与研发执行](#9-首席编程视角架构治理与研发执行)
10. [首席运营视角：交付运营与增长闭环](#10-首席运营视角交付运营与增长闭环)

***

## 1. 项目简介与架构概览

**AutoTFL** 是一个基于 R Shiny 构建的专业医学数据分析平台，提供从数据准备、探索分析、高级统计分析到可视化和专业表格导出（TFL: Tables, Figures, Listings）的完整工作流。

### 核心技术栈

- **前端与交互**: Shiny, shinydashboard, shinyjs, shinyBS, bslib, reactable, plotly
- **数据处理**: dplyr, tidyr, purrr, stringr, haven, readxl
- **统计建模**: survival, broom, gtsummary
- **存储与数据库**: DBI, RPostgres, pool
- **报表导出**: gt, flextable, officer, rmarkdown

### 架构设计

系统采用 **模块化 (Modular)** 架构，主控程序为 `app.R`，通过 `shinydashboard` 提供 UI 框架。功能被严格拆分到 `modules/` 目录下，各模块通过 Shiny 的 `moduleServer` 进行解耦通信。各步骤具有**状态依赖性**（例如，必须先完成“数据准备”才能解锁“探索与可视化”）。

***

## 2. 项目目录结构说明

```text
AutoTFL/
├── app.R                       # 主应用入口文件（组装 UI 与 Server 逻辑）
├── modules/                    # 所有的 Shiny 模块和业务逻辑
│   ├── common/                 # 跨模块公共组件库（格式化、存储后端等）
│   │   ├── analysis_format.R
│   │   ├── analysis_shared.R
│   │   ├── data_filter.R
│   │   ├── graphics_repro.R
│   │   ├── plot_export.R
│   │   ├── storage_backend.R
│   │   └── table_export.R
│   ├── statistical_analysis/   # 统计分析具体的算法子模块（Cox, Logistic, ANOVA等）
│   ├── statistical_graphics/   # 统计图形子模块（生存曲线、森林图等）
│   │   ├── survival_analysis.R / forest_plot.R / correlation_matrix.R
│   │   ├── boxplot.R / heatmap.R / combo_plot.R
│   │   └── swimmer_plot.R / waterfall_plot.R
│   ├── tables/                 # 预设图表子模块（表格+图形）
│   ├── database_manager.R      # 主模块：数据库管理
│   ├── data_preparation.R      # 主模块：数据导入与预处理
│   ├── exploratory_analysis.R  # 主模块：探索性分析
│   ├── statistical_analysis.R  # 主模块：统计分析路由分配
│   ├── statistical_graphics.R  # 主模块：图形绘制路由分配
│   └── tables.R                # 主模块：表格生成路由分配
├── tests/                      # 单元测试和集成测试目录 (testthat)
├── postgres/                   # 数据库初始化脚本和配置 (init.sql, postgresql.conf)
├── nginx/                      # Nginx 反向代理配置
├── Dockerfile                  # 生产环境 Docker 镜像构建配置
├── docker-compose.yml          # 一键式全栈部署配置 (Nginx+Shiny+PostgreSQL+Redis)
├── docker-compose1.yml         # 兼容/历史编排文件（保留）
├── install_dependencies.R      # R 包依赖安装脚本
├── run_app.R                   # 开发环境启动脚本
├── run_app_test.ps1            # Windows/CI 启动测试脚本
├── download_offline_packages.R # 离线包下载脚本（用于内网/断网部署）
├── PROJECT_GUIDE.md            # 本文档（全局项目指南）
├── README.md                   # 简明说明与快速启动指南
├── AI prompt.md                # AI 输出格式规范文档
└── style.css                   # 全局自定义 CSS 样式表
```

***

## 3. 核心模块 (Core Modules) 功能详解

主模块文件直接位于 `modules/` 目录下，分别对应侧边栏的 6 个核心步骤。

### 3.1 数据库管理 (`database_manager.R`)

- **功能**: 管理 PostgreSQL 数据库连接，维护 Workspaces（工作区）、Folders（文件夹）和 Datasets（数据集）的层级关系。
- **职责**: 负责持久化存储业务元数据，依赖 `modules/common/storage_backend.R` 实现本地或 S3 数据体的存取。

### 3.2 数据准备 (`data_preparation.R`)

- **功能**: 数据清洗与输入。支持从本地上传 (.csv, .xlsx, .sav) 或从数据库提取。
- **职责**: 智能识别变量类型，支持缺失值处理和匿名化。这是整个应用的数据源头，处理后的 `filtered_data` 将作为反应式值向下游所有模块广播。

### 3.3 探索与可视化 (`exploratory_analysis.R`)

- **功能**: 提供数据初探功能。
- **职责**: 基于 Plotly 的动态图形交互。用户可自由将变量映射到 X轴、Y轴、颜色、分面等，系统自动适配散点图、箱线图、直方图或条形图。

### 3.4 统计分析 (`statistical_analysis.R`)

- **功能**: 统一的回归分析控制面板。
- **职责**: 作为路由（Router），收集用户的模型选择（如 Cox, Logistic, Linear），并动态调用 `modules/statistical_analysis/` 下的子模块。

### 3.5 统计图形 (`statistical_graphics.R`)

- **功能**: 出版级图形生成器。
- **职责**: 路由调用 `modules/statistical_graphics/` 下的子模块（生存曲线、森林图、热图等），支持高分辨率图片下载。

### 3.6 预设图表 (`tables.R`)

- **功能**: 临床研究常用模板的统一入口，覆盖 T/F/L（表格、图形、清单）。
- **职责**: 统一路由 DM 表、AE 汇总表、通用 Listing 及 AE 对比图；按对象类型切换渲染与导出分支（表格分支 vs 图形分支）。

***

## 4. 子模块 (Sub-Modules) 功能详解与使用场景

子模块位于各个子文件夹中，实现具体的统计、绘图和制表逻辑。以下对各模块的具体方法、应用场景及关键特性进行深入解读。

### 4.1 `statistical_analysis/` (统计分析)

本目录下的模块统一采用 `gtsummary` 引擎生成 SCI 级别的临床级统计表格，并依托公共模块处理复杂的亚组分析与模型控制。

- **`cox.R`** **(Cox 比例风险回归模型)**
  - **具体方法**: 使用 `survival::coxph` 进行生存数据建模。计算风险比 (HR, Hazard Ratio) 及 95% CI。全局模型假设通过 Schoenfeld 残差检验 (`cox.zph`) 自动评估。
  - **使用场景**: 评估连续或分类协变量（如用药、年龄）对发生某事件（如死亡、复发）时间的影响。
  - **关键特性**:
    - 支持 **基线分层 (Model Strata)**：通过 `strata()` 进入公式，控制非比例风险混杂因素。
    - 支持 **亚组交互 (Split)**：自动计算“协变量 × 亚组变量”的交互作用 P 值 (Interaction P-value)，而非简单的各组单独拟合。
- **`logistic.R`** **(逻辑回归模型)**
  - **具体方法**: 使用 `stats::glm(family = binomial())` 拟合二分类因变量，输出比值比 (OR, Odds Ratio) 及其 95% CI。
  - **使用场景**: 评估各种因素对某二分类结局（如是否有效、是否发生不良反应）发生概率的影响。
  - **关键特性**: 智能映射响应变量（自动选取或用户指定 `event_value` 为 1，其余为 0）；与 Cox 一致，支持亚组分析及交互项 P 值计算。
- **`linear.R`** **(多元线性回归模型)**
  - **具体方法**: 使用 `stats::lm` 建模，输出回归系数 (Beta) 及其 95% CI。
  - **使用场景**: 探究多个自变量对连续型因变量（如血压、生化指标变化量）的线性影响。
- **`desc.R`** **(描述性统计与差异分析)**
  - **具体方法**: 使用 `gtsummary::tbl_summary`。自动识别变量类型（连续变量输出均值/标准差/中位数/四分位距，分类变量输出频数/百分比）。
  - **使用场景**: 生成临床试验中经典的“表1” (Table 1)，即基线特征描述表。
  - **关键特性**: 支持自定义多个“总计列” (Total Columns)，通过动态过滤数据并在底层通过 `tbl_merge` 实现高度灵活的分组汇总。
- **`anova.R`** **&** **`chisq.RF`**
  - **具体方法**: `anova.R` 执行方差分析；`chisq.R` 执行卡方检验及 CMH (Cochran-Mantel-Haenszel) 检验。
  - **使用场景**: 分别用于连续型变量多组均值比较和分类变量多组构成比/分层率比较。

### 4.2 `statistical_graphics/` (统计图形)

专注于输出高质量、出版级别的统计图形，底层高度定制了 `ggplot2` 与 `plotly`，支持静态图与交互图双轨输出。

- **`survival_analysis.R`** **(Kaplan-Meier 生存曲线)**
  - **绘图逻辑**: 基于 `survival::survfit` 和 `survminer::ggsurvplot`。在处理复杂的标签映射与交互图时，手动剥离了 `ggsurvplot` 的底层 `ggplot` 对象，并重构了删失点（Censor）及文本标注逻辑，以消除渲染警告并完美兼容 `plotly`。
  - **使用场景**: 直观展示不同治疗组/特征组的生存概率随时间的变化趋势。
  - **关键特性**:
    - 高度定制的统计标注：可任意拖拽或预设中位生存时间及 Log-rank P 值 / Cox HR 文本的位置。
    - 交互状态解耦：变量下拉选择实时更新，生存拟合与统计计算仅在点击“生成图形”后执行，避免伪点击与选择闪回。
    - 动态风险表 (Risk Table) 的组合与对齐输出仅用于静态图流程，交互图页默认不再渲染风险表。
- **`forest_plot.R`** **(森林图)**
  - **绘图逻辑**: 解析回归模型输出的 HR/OR 及置信区间数据，转换为标准森林图格式。
  - **使用场景**: 直观展示多因素回归分析的结果，或亚组分析（Subgroup Analysis）中治疗效应的一致性。
- **`correlation_matrix.R`** **(相关性热图)**
  - **绘图逻辑**: 计算 Pearson 或 Spearman 相关系数矩阵。
  - **使用场景**: 探索性分析阶段，快速发现多重共线性问题或变量间的潜在关联。
- **`boxplot.R`** **/** **`heatmap.R`** **/** **`combo_plot.R`**
  - **绘图逻辑**: 分别处理分布比较、矩阵热区展示与复合图层叠加。
  - **使用场景**: 临床变量分布对比、模式识别、报告中多图组合展示。
- **`swimmer_plot.R`** **/** **`waterfall_plot.R`**
  - **绘图逻辑**: 面向临床研究常见个体疗程轨迹与肿瘤负荷变化场景的专用图形实现。
  - **使用场景**: 肿瘤学疗效展示、个体随访进展与治疗持续性解读。
  - **关键特性**: 支持对轨道区域按“轨道名:具体值”逐项指定颜色，并覆盖默认调色板分配；当轨道切换为文本填充时不再显示颜色映射控件。瀑布图柱符号分组支持按组分别指定具体符号与颜色。

#### 4.2.1 UI 管理章节（生存分析）

- **双状态模型**
  - `view state`：承载临时输入（下拉当前选择、分层/分面、分面值），用于界面交互预览。
  - `committed state`：仅在点击“生成图形”时写入，作为本次模型拟合、统计、图例、风险表与报告的唯一分析口径。
- **触发机制**
  - 非点击操作只更新 `view state`，不触发生存对象拟合与统计重算。
  - 点击“生成图形”后统一提交参数并触发计算链路，避免伪点击和下拉闪回。
- **展示一致性**
  - 未分层时“总体分组标签”必须同时作用于主图图例、风险表、数据表与统计报告，不允许出现默认 `all/ALL` 残留。
  - 生存曲线线条样式必须直接作用于当前图层，禁止依赖全局默认值修改。
  - 生存分析必须接入统一尺寸配置，静态图、交互图与导出尺寸共用同一组参数，不允许模块内写死显示/导出尺寸。
- **进度反馈**
  - 点击“生成图形”必须显示可见进度提示，覆盖参数提交、模型拟合、统计计算、图形完成四阶段。
  - 进度提示统一复用 `modules/common/graphics_common.R` 中的进度函数，禁止子模块各自定义提示样式与文案。
- **测试契约**
  - 固定保留 `shiny::testServer` 回归用例，验证“未点击生成时切筛选后下拉不闪回”。
  - 任何输入同步逻辑改动都必须先通过该回归测试。
  - KM 可复现代码必须与 UI 计算链路同源（含 `km_censor_value` 状态重编码与 `median/0.95LCL/0.95UCL` 提取逻辑）。
  - KM 拟合与中位生存CI提取统一采用 `conf.type = "log-log"` 口径，R与对照系统需保持同一 CI 算法。
  - 固定保留中位生存时间基准样例测试，自动校验 `median/LCL/UCL` 输出一致性。
  - 生存选择解析函数在 `choices` 为空时必须优先回退 `default_value`，仅在默认值缺失时返回 `NULL`。

#### 4.2.2 统计图形模块 C/D/E 优化策略与进度

按 **C → D → E** 顺序执行，避免并行改动导致回归风险。

- **C. 组件复用度低**
  - 目标：抽离通用导出与尺寸配置，减少子模块重复代码。
  - 动作：新增统一导出/尺寸公共组件；统一变量类型筛选工具；子模块仅保留业务绘图逻辑。
  - 验收：导出行为一致，重复样板代码显著下降。
- **D. 异常处理未标准化**
  - 目标：统一“可见、可读、可定位”的错误反馈。
  - 动作：`req()` 仅用于前置依赖；业务校验统一走 `validate(need(...))`；`tryCatch()` 仅做系统异常兜底。
  - 验收：变量缺失/类型错误/空数据场景均返回一致提示，不再静默失败。
- **E. 交互式兼容性瓶颈（KM 风险表）**
  - 目标：交互主图与风险表同时可见且口径一致。
  - 动作：交互 Tab 拆分为 `plotly` 主图 + 风险表（DT 或静态表）；统一使用同一 `fit()` 数据源并联动时间范围。
  - 验收：交互图不丢风险表信息，图表与表格同步更新。

**执行进度（持续更新）**

| 项 | 状态  | 当前进展                                                                        | 下一步                                    |
| - | --- | --------------------------------------------------------------------------- | -------------------------------------- |
| C | 已完成 | 已新增 `graphics_common.R`，并在图形主模块接入；`boxplot/survival/swimmer` 已复用变量分类与尺寸解析能力 | 下一轮扩展到 forest/heatmap/correlation 等子模块 |
| D | 已完成 | `boxplot/survival/swimmer` 关键输出已统一采用 `validate(need(...))`，形成可见错误提示         | 下一轮统一导出链路与错误文案字典                       |
| E | 已完成 | KM 交互 Tab 已改为“交互主图 + 风险表”，风险表与 `time_range` 同步                              | 下一轮补充交互导出与版式优化                         |

**更新规则**

- 每完成一项（C/D/E）即更新本表“状态/当前进展/下一步”。
- 每次仅保留最新进展，避免冗余历史描述。

#### 4.2.3 统计图形 UI 整合方案（已确认）

- **目标**
  - 解决“单卡片选项过多、定位困难”的可用性问题。
  - 在不改变现有功能与统计结果的前提下，提升配置效率与一致性。
- **统一信息架构（IA）**
  - 复杂图形模块统一为一级选项卡：`数据映射`、`分析参数`、`样式主题`、`输出与导出`、`统计报告`（按需显示）。
  - 将高密度配置（如轨道、标注、图例、导出）从单卡拆分到对应选项卡，避免同屏堆叠。
  - 保持“生成图形”入口位置一致，降低跨图形切换学习成本。
  - **UI规范（强制）**：同一页签下所有“功能区卡片”必须并列放置（`fluidRow + column`）；且单页签并列功能区卡片最多 **4** 个，超出时必须合并为“子卡片”或“子切换”。
  - **控件密度规则（强制）**：下拉框/数值框优先双列或多列并排，避免单控件独占整行；仅长文本、动态映射表、说明区允许全宽。
  - **子页签继承规则（强制）**：子页签内部同样适用“并列功能区卡片+最多4卡片”规则，超出必须继续下沉为子卡片。
  - **输出动作规范（强制）**：输出区域只保留动作控件，`生成图形`左对齐、`下载图形`右对齐；导出参数（格式、DPI、尺寸）统一放在`输出与导出`页签。
- **术语约定（UI）**
  - **一级页签**：数据映射 / 分析参数 / 样式主题 / 输出与导出 / 统计报告。
  - **功能区卡片**：一级页签中承载同类配置的并列主卡片。
  - **子卡片**：当功能区选项过多时，在卡片内部继续拆分的二级卡片。
  - **子切换**：同一卡片内通过 `tabsetPanel` 切换细分配置（如“排序与轨道/显示与图例”）。
  - **输出操作条**：输出区顶部动作条（左生成、右下载）。
- **命名模板（建议统一）**
  - 功能区卡片命名优先使用：`数据映射`、`显示与图例`、`坐标与尺寸`、`文本与脚注`、`颜色与配色`、`布局与比例`、`参考线与阈值`。
  - 同类功能在不同模块中逐步收敛到同一标题，降低认知切换成本。
- **公共函数（本任务相关）**
  - `graphics_config_tabs_box()`：统一配置页签壳层。
  - `graphics_export_size_controls_ui()`：统一导出参数控件（格式/DPI/尺寸）。
  - `graphics_primary_action_button_ui()`：统一“生成图形”按钮样式。
  - `get_numeric_vars()/get_categorical_vars()/get_time_vars()`：统一变量筛选工具。
  - `resolve_plot_size_config()`：统一静态/交互/导出尺寸解析。
  - `graphics_notify_success()/graphics_notify_error()`：统一成功/失败提示文案。
- **模块化边界**
  - UI 建议独立为专门层：`statistical_graphics_ui/*`（布局壳层 + 公共控件 + 子模块特有面板）。
  - 现有 `statistical_graphics/*` 中 server 与统计逻辑保持不变，只做 UI 接线改造。
- **技术路线决策**
  - **当前采用 A（已确认）**：继续基于 Shiny 体系做 UI 重构与组件化，不更换后端。
  - **后续评估 B**：在局部高复杂区域引入前端组件（嵌入式）以提升交互体验。
  - **暂不采用 C**：当前阶段不做前后端完全分离重构。
- **实施顺序**
  - 先改 IA 与分组结构，再抽公共 UI 组件，最后逐步迁移高复杂模块（Survival / Forest / Swimmer / Waterfall）。
  - 每轮迁移后进行一致性回归（变量映射、图形输出、导出、报告）。

**4.2.2 执行进度（方案A）**

| 阶段                                            | 状态  | 本轮结果                                                                                                          | 下一步                       |
| --------------------------------------------- | --- | ------------------------------------------------------------------------------------------------------------- | ------------------------- |
| UI壳层组件                                        | 已完成 | 已新增通用配置选项卡容器，补充公共导出/尺寸与公共生成按钮组件；并完成默认折叠精细化（Survival/Forest展开，Swimmer/Waterfall折叠）                             | 下一轮持续巡检“单页签最多4个并列功能区卡片”规范 |
| Survival UI整合                                 | 已完成 | 已按“并列功能区卡片”重排数据映射/分析参数/样式主题；过多选项拆入子卡片；输出区已统一为“左生成、右下载”动作条                                                         | 下一轮继续收敛子页签控件密度           |
| Forest UI整合                                   | 已完成 | 样式主题已统一为4个并列功能区卡片（同排），超载内容下沉为子卡片；输出区保持“左生成、右下载”                                                             | 下一轮继续优化原始数据分析路径的分步引导      |
| Swimmer/Waterfall UI整合                        | 已完成 | 已完成并列卡片迁移；过载区域拆分子卡片/子切换；导出参数保留在“输出与导出”；泳道图设置区残留“生成图形”已移除并统一到输出动作条（左生成、右下载）                 | 下一轮继续收敛子页签控件密度                 |
| 其余模块一致化（Box/Heatmap/Correlation/Spider/Combo） | 已完成 | 已统一主操作按钮组件与文案；Box/Heatmap/Correlation已迁移到分组选项卡配置骨架并统一提示；Spider子页签已按并列卡片重构且设置区生成按钮已移至输出动作条；Combo输出动作条已统一“左生成、右下载”，导出参数归入配置区 | 下一轮继续收敛布局细节并统一导出异常提示 |

### 4.3 `tables/` (预设图表)

聚焦于临床研究常见输出模板，统一管理表格与图形。当前实现为“单模块多引擎”：不同子模块按目标对象采用不同渲染与导出链路。

- **`t_dm.R`** **(人口统计学和基线特征表)**
  - **生成逻辑**: 基于 `gtsummary + gt` 生成 Demographic 风格表，支持变量类型自动识别与统计摘要格式化。
  - **使用场景**: 基线特征汇总、分组对照、研究报告“表1”输出。
- **`t_ae_soc_pt.R`** **(不良事件汇总表)**
  - **生成逻辑**: 基于 `rtables/tern` 生成 SOC/PT 分层汇总结构，强调临床统计口径的一致性。
  - **临床规范**: 支持按受试者维度的汇总思路，满足不良事件汇总展示需求。
- **`listing_general.R`** **(通用 Listing)**
  - **生成逻辑**: 基于 `rlistings/r2rtf` 生成可配置明细清单，支持审阅友好输出。
  - **使用场景**: 数据核查、病例逐行审阅、监管审评材料准备。
- **`ae_sidebyside.R`** **(AE 并列对比图)**
  - **生成逻辑**: 基于 `ggplot2` 生成 TEAE/TRAE 并排对比图，属于图形分支而非纯表格分支。
  - **使用场景**: 治疗组间不良事件结构差异的可视化对照展示。
- **导出策略（当前版本）**
  - 表格对象与图形对象采用不同导出格式集合：表格侧偏文档/排版导出，图形侧偏矢量/位图导出。

### 5. 公共组件与共享工具 (Common Utils)

位于 `modules/common/` 目录下，是保证全平台逻辑一致性和代码复用性的基石。

- **`graphics_common.R`** **(图形公共函数库)**
  - **核心函数**: `get_numeric_vars()/get_categorical_vars()/get_time_vars()`、`resolve_plot_size_config()`、`graphics_notify_success()/graphics_notify_error()`。
  - **用途**: 统一变量筛选、尺寸解析、图形生成通知文案。
- **`statistical_graphics_ui/common_ui_shell.R`** **(图形UI公共壳层)**
  - **核心函数**: `graphics_config_tabs_box()`、`graphics_export_size_controls_ui()`、`graphics_primary_action_button_ui()`。
  - **用途**: 统一配置页签壳层、导出参数区、主操作按钮样式与行为。

- **`analysis_shared.R`** **(统计共享核心库)**
  - **核心函数**:
    - `build_unified_regression_table()`: **全新重构的核心引擎**。彻底摒弃了 `gtsummary` 在多级表头导出时的脆弱性，采用“手动组装扁平 Data.frame + 纯文本空格缩进”的策略，确保前端 HTML 与后端 Word/PDF 导出格式的 100% 一致。它统一接管了 Cox, Logistic, Linear 的模型切割、自定义总计列（Total Columns）组装及交互作用 P 值的独立列/行排版。
    - `compute_interaction_p_map()`: 统一提取“预测变量 × 亚组变量”的交互项检验 P 值，确保口径一致。
  - **调用关系**: 被所有回归分析子模块调用，是实现代码 DRY (Don't Repeat Yourself) 原则的典范。
- **`analysis_format.R`** **(格式化与代码引擎)**
  - **核心函数**:
    - `format_p_value_regression()`: 强制所有 P 值符合 AMA 规范（如 `<0.001`）。
    - `format_regression_stat()`: 统一学术界标准（HR/OR/Beta 保留两位小数，优雅处理稀疏数据导致的 NA 极值为 `—`）。
    - `build_repro_code_template()`: 组装分段的 R 脚本字符串，将 UI 上的点击操作逆向工程为可复现的 R 代码供用户下载。
- **`table_export.R`** **(表格导出器)**
  - **核心函数**: `apply_sci_gt_style()` 统一给 `gt` 对象注入三线表边框、加粗表头及脚注样式。
- **`storage_backend.R`** **(存储抽象层)**
  - 抽象了本地文件系统与 S3 对象存储的底层接口，使得应用具备云原生平滑迁移能力。

***

## 6. 数据格式与统计规范 (Data & Statistical Specs)

AutoTFL 对输入数据及输出结果有着严格的标准化要求，以下是开发时必须遵循的规范：

### 6.1 变量命名与类型规范

1. **命名**: 变量名应仅包含英文字母、数字和下划线，禁止空格与特殊符号。
2. **类型**: 连续变量应为数值型 (`numeric`)；分类变量应为 `factor` 或 `character`；逻辑变量进入分析前必须统一转换为 0/1 或 Yes/No。

### 6.2 回归分析变量选择规范

1. **排他性**: 响应变量（Y）不得同时出现在预测变量（X）中。
2. **互斥性**: 预测变量不得与亚组变量（Split）、分组变量、分层控制变量（Strata）重复；亚组变量与分组变量不得相同。
3. **生存分析**: Cox 回归中的时间（Time）与状态（Status）变量不得进入协变量列表。

### 6.3 P 值与效应量显示规范

1. **风格**: 全部统一采用 AMA (American Medical Association) 风格。
2. **缺失**: 缺失或无法计算的 P 值显示为 `NA`，无法计算的效应量（极值、稀疏）显示为 `—`。
3. **阈值**: $P < 0.001$ 显示为 `<0.001`；$P > 0.99$ 显示为 `>0.99`；其余保留 3 位小数。
4. **效应量**: `HR/OR/Beta (95% CI)`，点估计与置信区间严格保留 2 位小数以保持列对齐。

### 6.4 亚组差异 P 值 (Interaction P-value) 规范

**极其重要**：亚组差异 P 值的口径必须是 **“预测变量 × 亚组变量”的交互项检验 P 值 (Effect Modification)**，而非简单的亚组间均值差。

1. **逻辑**: 无亚组变量时不显示该列/行。
2. **计算**: 有列分组时，按列分组的子数据集独立计算，**绝不**共用全局 P 值。
3. **展示**:
   - **堆叠亚组展示 (无列分组)**：交互 P 值在当前变量的最后一个亚组底部，作为独立的斜体行 (`*P for interaction*`) 呈现。
   - **并排分组展示 (有列分组)**：交互 P 值作为独立列 `P for interaction`，且仅在变量名的标题行或总体列中单次显示，杜绝各水平行重复显示。

### 6.5 缺失值处理规范

- 模型拟合按涉及变量的 `complete cases`（完全观测记录）计算有效样本量 $N$。
- 缺失导致模型退化无法估计时，返回 `NA` 并在 UI 提示框中说明原因。

***

## 7. 部署与依赖管理指南 (Deployment & Dependencies)

AutoTFL 提供了高度兼容的部署方案，适配单机研发、内网服务器及云原生 Kubernetes。

### 7.1 依赖管理策略

系统采用“本地离线包优先，在线镜像回退”的策略：

- **`install_dependencies.R`**: 安装所需 R 包的主脚本。
- **`download_offline_packages.R`**: 离线仓库维护脚本。在有网环境将依赖同步到 `package/` 目录，并自动生成 `PACKAGES` 索引；在无网部署环境由 `install_dependencies.R` 优先从本地仓库安装，再在线补齐缺失依赖。

### 7.2 Docker 与 Docker Compose 部署（开发/联调）

- **构建镜像**: 运行 `docker build -t autotfl-shiny-app:latest .`。Dockerfile 会将 `package/` 复制进容器并优先使用本地源码仓库安装依赖。
- **一键启动（开发编排）**: 使用 `docker compose -f docker-compose.yml up -d --build`，系统将自动拉起 **Nginx (反向代理)**、**Shiny 应用容器**、**PostgreSQL 数据库** 与 **Redis 缓存服务**。
- **环境变量**: 建议在部署前通过系统环境变量设置 `DB_PASSWORD` 提升安全性。

### 7.3 阿里云 Ubuntu 22.04 生产部署（HTTPS 反向代理 + 离线镜像）

当前仓库已形成阿里云可用部署链路：

- 主编排：`docker-compose.server.yml`
- 反向代理：`nginx/server_ssl.conf`
- 首屏入口：`nginx/landing/index.html` + `nginx/landing/style.css`
- 生产环境模板：`deploy/alicloud/env/.env.example`
- 生产环境生成脚本：`deploy/alicloud/scripts/init_env.sh`
- 离线部署脚本：`deploy/alicloud/scripts/deploy_from_tar.sh`

#### 7.3.1 文件位置与职责（必须文件）

1. **根目录编排文件**
   - `docker-compose.server.yml`: 服务器编排入口，包含 `postgres`、`redis`、`app`、`nginx` 四服务。
   - 关键约定：
     - 数据目录由 `DATA_ROOT` 控制（默认 `/data/autotfl`）。
     - 证书目录由 `CERT_ROOT` 控制（建议 `/etc/autotfl/certs`）。
     - 证书文件名由 `SSL_CERT_FILE` / `SSL_KEY_FILE` 控制。
2. **Nginx 文件**
   - `nginx/server_ssl.conf`: 域名 `kyyin.xyz` / `www.kyyin.xyz`，80 跳转 443，`/` 首屏静态页，`/app/` 进入 Shiny。
   - `nginx/landing/index.html`: 部署入口页（不直接跳应用）。
   - `nginx/landing/style.css`: 入口页样式。
3. **阿里云部署辅助目录（deploy/alicloud）**
   - `deploy/alicloud/env/.env.example`: 环境变量模板。
   - `deploy/alicloud/env/.env`: 生产环境变量实文件（由脚本生成，不入库）。
   - `deploy/alicloud/scripts/init_env.sh`: 自动生成 `.env` 并注入随机 `DB_PASSWORD`。
   - `deploy/alicloud/scripts/deploy_from_tar.sh`: 导入 tar 镜像并执行 compose 启动。

#### 7.3.2 服务器目录规划（最佳实践）

1. **代码目录**：`/opt/autotfl/current`
2. **证书目录**：`/etc/autotfl/certs`
3. **持久化目录**：`/data/autotfl`
   - `/data/autotfl/postgres`
   - `/data/autotfl/redis`
   - `/data/autotfl/storage`
4. **环境变量文件**：`/opt/autotfl/current/deploy/alicloud/env/.env`

#### 7.3.3 .env 生成与使用

1. 在服务器进入项目目录后执行：
   - `bash deploy/alicloud/scripts/init_env.sh`
2. 生成文件位置：
   - `deploy/alicloud/env/.env`
3. 按需调整以下字段：
   - `DB_PASSWORD`
   - `DATA_ROOT`
   - `CERT_ROOT`
   - `SSL_CERT_FILE`
   - `SSL_KEY_FILE`
4. 启动时显式指定 env 文件：
   - `docker compose --env-file deploy/alicloud/env/.env -f docker-compose.server.yml up -d`

#### 7.3.4 离线镜像（tar）部署流程

1. **本地构建镜像**：`docker build -t autotfl-shiny-app:server .`
2. **本地导出镜像**：`docker save -o autotfl-shiny-app_server.tar autotfl-shiny-app:server`
3. **上传 tar 到服务器并导入**：`docker load -i autotfl-shiny-app_server.tar`
4. **执行部署脚本**：`bash deploy/alicloud/scripts/deploy_from_tar.sh autotfl-shiny-app_server.tar`

#### 7.3.5 上线验收

1. 访问 `https://kyyin.xyz` 与 `https://www.kyyin.xyz`，应先显示静态入口页。
2. 点击“进入 AutoTFL”后进入 `/app/` 并完成页面与交互加载。
3. 自签名证书在浏览器告警属于预期，正式环境建议替换为受信任证书。

### 7.4 部署辅助目录（deploy/alicloud）总览

```text
deploy/alicloud/
├── README.md
├── certs/
│   └── .gitkeep
├── env/
│   ├── .env.example
│   └── .env            # 运行期生成，不入库
└── scripts/
    ├── init_env.sh
    └── deploy_from_tar.sh
```

### 7.5 Windows 快捷部署

运行 `run_app.R` / `run_app_test.ps1`：

- `run_app.R` 用于本地开发启动；`run_app_test.ps1` 用于自动化/测试场景启动验证。
- 若使用 `package/` 源码仓库安装依赖，Windows 侧仍建议准备 Rtools 以提升兼容性。

***

## 8. 未来改进点与路线图 (Future Improvements)

随着业务场景拓展，AutoTFL 拟在后续阶段实施以下改进：

### 8.1 已完成升级（2026Q1）

1. **回归参考组配置**: Cox/Logistic/Linear 已支持参考组选择与映射。
2. **回归表引擎重构**: 已引入 `build_unified_regression_table` 作为统一表格引擎，并推动计算与渲染职责分离。
3. **部署编排扩展**: Docker Compose 已升级为 Nginx + App + PostgreSQL + Redis 四服务结构。
4. **测试覆盖增强**: 已补充解耦测试、稀疏数据测试与交互一致性测试。

### 8.2 下一步重点（2026Q2+）

1. **全局交互联合检验**: 为 Cox/Logistic/Linear 增加全局交互检验输出区，与局部比较 P 值联动展示。
2. **高级方法落地**: 将“MMRM / 多重填补（MI）”从菜单占位推进到可运行分析链路。
3. **声明式表头映射**: 引入模板字典配置，减少硬编码列名与人工维护成本。
4. **防御性建模阀门**: 在建模前增加事件数/稀疏度预检查，提供“可解释失败”状态返回。
5. **可复现代码沙盒**: 为导出代码内置最小可运行示例数据。
6. 下一步可以把“随机不重复”加一个 随机种子输入 ，保证每次导出复现图符号分配一致。

***

## 9. 首席编程视角：架构治理与研发执行

本节从首席编程（Chief Programmer / CTO）角度定义项目的技术治理框架，目标是让 AutoTFL 在功能持续扩展时仍保持可维护、可测试、可迁移。

### 9.1 架构治理原则

1. **先稳定共享内核，再扩展功能外层**: `modules/common/` 属于一级核心资产，新增统计方法应优先复用共享函数，禁止在子模块复制交互 P 值、P 值格式化、表格拼接逻辑。
2. **保持“路由层薄、计算层厚”**: `modules/statistical_analysis.R`、`modules/statistical_graphics.R` 仅负责参数路由，不承载复杂统计计算。
3. **UI 与计算解耦**: 推进 `compute_*()` 与 `render_*()` 分层，先输出结构化元数据，再执行视图渲染，避免巨型过程式函数持续膨胀。

### 9.2 工程质量红线

1. **回归模型输入校验必须统一走公共校验器**（如 `validate_regression_inputs`），不得在各模块形成隐式规则分叉。
2. **亚组差异 P 值口径不得变体化**：始终基于交互项检验，不接受“组内 P 值替代交互 P 值”的实现。
3. **导出一致性优先级高于局部 UI 漂亮性**：前端展示与 Word/PDF 导出结果需保持语义一致、字段一致、顺序一致。
4. **新增模块必须附最小测试用例**：至少覆盖成功路径、缺失值路径、样本不足路径三类场景。

### 9.3 研发流程建议（单人/小团队可执行版）

1. **变更分级**:
   - A级（高风险）：公共模块、统计口径、导出逻辑变更，必须先更新文档再改代码。
   - B级（中风险）：子模块新增参数或新图形类型，必须补充回归测试。
   - C级（低风险）：文案、样式、小交互微调，可快速发布。
2. **发布前检查清单**:
   - 统计口径一致性检查（Cox/Logistic/Linear）
   - 导出格式一致性检查（页面与离线导出）
   - Docker Compose 健康性检查（PostgreSQL、Redis、App、Nginx）
3. **技术债管理**: 每月固定一次“公共模块债务清理窗口”，优先清理重复逻辑、硬编码列名、不可复用拼接代码。

### 9.4 下一阶段技术里程碑

1. 完成 `build_unified_regression_table` 的计算层/渲染层拆分。
2. 为交互项计算与列分组展开建立声明式配置（模板字典化）。
3. 建立回归测试基线数据集，覆盖常见临床统计场景（生存、二分类、连续变量、AE 汇总）。
4. 为关键模块增加性能基准（大样本下建模耗时、导出耗时、首屏渲染耗时）。

***

## 10. 首席运营视角：交付运营与增长闭环

本节从首席运营（COO）角度定义交付、服务、运营与商业闭环，目标是保证“可卖、可交付、可续费”。

### 10.1 交付模式分层

1. **本地交付（研究环境）**: 适合单研究者与离线场景，强调安装简易与数据可控。
2. **容器交付（团队环境）**: 通过 `docker-compose.yml` 统一交付 Nginx + App + PostgreSQL + Redis，降低环境漂移风险。
3. **企业交付（内网/合规）**: 采用离线包仓库策略与私有镜像仓库，满足弱网与内网隔离要求。

### 10.2 运维与服务质量指标

1. **可用性指标**: 应用可访问率、关键页面错误率、数据库连接失败率。
2. **性能指标**: 首次分析响应时延、导出任务成功率、峰值并发下平均响应时间。
3. **稳定性指标**: 容器重启频次、异常告警修复时长、版本回滚次数。
4. **数据安全指标**: 异常访问拦截、备份成功率、恢复演练通过率。

### 10.3 运营闭环（功能到收入）

1. **需求闭环**: 用户反馈进入需求池后，按“高频+高价值+低实现成本”优先级排序。
2. **交付闭环**: 每次版本发布同步更新 `PROJECT_GUIDE.md`、`README.md` 和部署说明，减少交付沟通损耗。
3. **价值闭环**: 以“分析效率提升、错误率下降、导出可复现性提升”作为核心价值指标，支撑续费与扩容。
4. **客户成功闭环**: 建立典型临床场景模板（如生存分析模板、AE 表模板），降低新用户上手门槛。

### 10.4 运营风险与应对

1. **单点人员风险**: 通过文档化、模板化和自动化测试降低知识集中风险。
2. **环境差异风险**: 强制生产交付走容器化路径，弱化“本机可运行但线上失败”问题。
3. **统计口径争议风险**: 将核心统计口径写入项目规范并在 UI 文案中显式提示。
4. **扩展失控风险**: 严格执行模块准入标准，新功能必须说明业务价值、维护成本与淘汰策略。

### 10.5 运营优先级建议（未来两个迭代）

1. 优先完成“高频功能模板化”与“常见报错标准化提示”。
2. 建立轻量运维看板：服务状态、错误日志、导出任务统计。
3. 发布面向客户成功的“场景化操作手册”，与本指南形成“开发版 + 业务版”双文档体系。

***

*文档更新于：2026-03*
