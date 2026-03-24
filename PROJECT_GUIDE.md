# AutoTFL 项目全局开发与维护指南 (Project Guide)

欢迎来到 AutoTFL (Medical Data Analysis Suite) 开发指南。本文档作为整个项目的“灯塔”，极尽详细地说明了系统架构、模块功能、数据流转、统计学计算规范、部署方案及未来改进点，旨在帮助新老开发者快速上手、降低维护成本。

---

## 目录

1. [项目简介与架构概览](#1-项目简介与架构概览)
2. [项目目录结构说明](#2-项目目录结构说明)
3. [核心模块 (Core Modules) 功能详解](#3-核心模块-core-modules-功能详解)
4. [子模块 (Sub-Modules) 功能详解](#4-子模块-sub-modules-功能详解)
5. [公共组件与共享工具 (Common Utils)](#5-公共组件与共享工具-common-utils)
6. [数据格式与统计规范 (Data & Statistical Specs)](#6-数据格式与统计规范-data--statistical-specs)
7. [部署与依赖管理指南 (Deployment & Dependencies)](#7-部署与依赖管理指南-deployment--dependencies)
8. [未来改进点与路线图 (Future Improvements)](#8-未来改进点与路线图-future-improvements)

---

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

---

## 2. 项目目录结构说明

```text
AutoTFL/
├── app.R                       # 主应用入口文件（组装 UI 与 Server 逻辑）
├── modules/                    # 所有的 Shiny 模块和业务逻辑
│   ├── common/                 # 跨模块公共组件库（格式化、存储后端等）
│   ├── statistical_analysis/   # 统计分析具体的算法子模块（Cox, Logistic, ANOVA等）
│   ├── statistical_graphics/   # 统计图形子模块（生存曲线、森林图等）
│   ├── tables/                 # 专业表格子模块（AE 表、DM 表等）
│   ├── database_manager.R      # 主模块：数据库管理
│   ├── data_preparation.R      # 主模块：数据导入与预处理
│   ├── exploratory_analysis.R  # 主模块：探索性分析
│   ├── statistical_analysis.R  # 主模块：统计分析路由分配
│   ├── statistical_graphics.R  # 主模块：图形绘制路由分配
│   └── tables.R                # 主模块：表格生成路由分配
├── test/                       # 单元测试和集成测试目录 (testthat)
├── postgres/                   # 数据库初始化脚本和配置 (init.sql, postgresql.conf)
├── nginx/                      # Nginx 反向代理配置
├── Dockerfile                  # 生产环境 Docker 镜像构建配置
├── docker-compose.yml          # 一键式全栈部署配置 (Nginx+Shiny+PostgreSQL)
├── install_dependencies.R      # R 包依赖安装脚本
├── run_app.R                   # 开发环境启动脚本
├── deploy-windows.cmd          # Windows 环境一键启动/部署脚本
├── download_offline_packages.R # 离线包下载脚本（用于内网/断网部署）
├── PROJECT_GUIDE.md            # 本文档（全局项目指南）
├── README.md                   # 简明说明与快速启动指南
└── style.css                   # 全局自定义 CSS 样式表
```

---

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

### 3.6 专业表格 (`tables.R`)
- **功能**: 临床试验标准表格 (TFL中的 T & L) 生成器。
- **职责**: 生成如人口学特征表 (DM 表)、不良事件表 (AE 表) 及通用清单，使用 `gt` 和 `reactable` 进行渲染和导出。

---

## 4. 子模块 (Sub-Modules) 功能详解与使用场景

子模块位于各个子文件夹中，实现具体的统计、绘图和制表逻辑。以下对各模块的具体方法、应用场景及关键特性进行深入解读。

### 4.1 `statistical_analysis/` (统计分析)
本目录下的模块统一采用 `gtsummary` 引擎生成 SCI 级别的临床级统计表格，并依托公共模块处理复杂的亚组分析与模型控制。

- **`cox.R` (Cox 比例风险回归模型)**
  - **具体方法**: 使用 `survival::coxph` 进行生存数据建模。计算风险比 (HR, Hazard Ratio) 及 95% CI。全局模型假设通过 Schoenfeld 残差检验 (`cox.zph`) 自动评估。
  - **使用场景**: 评估连续或分类协变量（如用药、年龄）对发生某事件（如死亡、复发）时间的影响。
  - **关键特性**:
    - 支持 **基线分层 (Model Strata)**：通过 `strata()` 进入公式，控制非比例风险混杂因素。
    - 支持 **亚组交互 (Split)**：自动计算“协变量 × 亚组变量”的交互作用 P 值 (Interaction P-value)，而非简单的各组单独拟合。

- **`logistic.R` (逻辑回归模型)**
  - **具体方法**: 使用 `stats::glm(family = binomial())` 拟合二分类因变量，输出比值比 (OR, Odds Ratio) 及其 95% CI。
  - **使用场景**: 评估各种因素对某二分类结局（如是否有效、是否发生不良反应）发生概率的影响。
  - **关键特性**: 智能映射响应变量（自动选取或用户指定 `event_value` 为 1，其余为 0）；与 Cox 一致，支持亚组分析及交互项 P 值计算。

- **`linear.R` (多元线性回归模型)**
  - **具体方法**: 使用 `stats::lm` 建模，输出回归系数 (Beta) 及其 95% CI。
  - **使用场景**: 探究多个自变量对连续型因变量（如血压、生化指标变化量）的线性影响。

- **`desc.R` (描述性统计与差异分析)**
  - **具体方法**: 使用 `gtsummary::tbl_summary`。自动识别变量类型（连续变量输出均值/标准差/中位数/四分位距，分类变量输出频数/百分比）。
  - **使用场景**: 生成临床试验中经典的“表1” (Table 1)，即基线特征描述表。
  - **关键特性**: 支持自定义多个“总计列” (Total Columns)，通过动态过滤数据并在底层通过 `tbl_merge` 实现高度灵活的分组汇总。

- **`anova.R` & `chisq.R`**
  - **具体方法**: `anova.R` 执行方差分析；`chisq.R` 执行卡方检验及 CMH (Cochran-Mantel-Haenszel) 检验。
  - **使用场景**: 分别用于连续型变量多组均值比较和分类变量多组构成比/分层率比较。

### 4.2 `statistical_graphics/` (统计图形)
专注于输出高质量、出版级别的统计图形，底层高度定制了 `ggplot2` 与 `plotly`，支持静态图与交互图双轨输出。

- **`survival_analysis.R` (Kaplan-Meier 生存曲线)**
  - **绘图逻辑**: 基于 `survival::survfit` 和 `survminer::ggsurvplot`。在处理复杂的标签映射与交互图时，手动剥离了 `ggsurvplot` 的底层 `ggplot` 对象，并重构了删失点（Censor）及文本标注逻辑，以消除渲染警告并完美兼容 `plotly`。
  - **使用场景**: 直观展示不同治疗组/特征组的生存概率随时间的变化趋势。
  - **关键特性**: 
    - 高度定制的统计标注：可任意拖拽或预设中位生存时间及 Log-rank P 值 / Cox HR 文本的位置。
    - 动态风险表 (Risk Table) 的组合与对齐输出。

- **`forest_plot.R` (森林图)**
  - **绘图逻辑**: 解析回归模型输出的 HR/OR 及置信区间数据，转换为标准森林图格式。
  - **使用场景**: 直观展示多因素回归分析的结果，或亚组分析（Subgroup Analysis）中治疗效应的一致性。

- **`correlation_matrix.R` (相关性热图)**
  - **绘图逻辑**: 计算 Pearson 或 Spearman 相关系数矩阵。
  - **使用场景**: 探索性分析阶段，快速发现多重共线性问题或变量间的潜在关联。

### 4.3 `tables/` (专业表格)
聚焦于临床试验数据标准（如 CDISC ADaM 数据结构）的定制化报表生成，强依赖于 `gt` 与 `reactable`。

- **`t_dm.R` (人口统计学和基线特征表)**
  - **生成逻辑**: 与 `desc.R` 类似，但更贴近临床标准规范（如要求特定格式的 N 和百分比），用于展示 Demographic 数据。
  
- **`t_ae_soc_pt.R` & `ae_sidebyside.R` (不良事件表)**
  - **生成逻辑**: 针对不良事件（Adverse Events）数据的嵌套层级结构，按系统器官分类 (SOC) 和首选语汇 (PT) 进行频数汇总与降序排列。
  - **临床规范**: 严格处理同一患者多次发生相同不良事件的去重计数逻辑（患者例数 vs 事件频次）。

### 5. 公共组件与共享工具 (Common Utils)

位于 `modules/common/` 目录下，是保证全平台逻辑一致性和代码复用性的基石。

- **`analysis_shared.R` (统计共享核心库)**
  - **核心函数**: 
    - `build_regression_split_facet_gt()`: **核心引擎**。它接管了 Cox, Logistic, Linear 等模块中极其复杂的“亚组分组(Split) + 列分组(Facet)”数据循环切割、独立拟合及结果宽表转换逻辑。
    - `compute_interaction_p_map()`: 统一提取“预测变量 × 亚组变量”的交互项检验 P 值，确保口径一致。
  - **调用关系**: 被所有回归分析子模块调用，是实现代码 DRY (Don't Repeat Yourself) 原则的典范。

- **`analysis_format.R` (格式化与代码引擎)**
  - **核心函数**: 
    - `format_p_value_regression()`: 强制所有 P 值符合 AMA 规范（如 `<0.001`）。
    - `build_repro_code_template()`: 组装分段的 R 脚本字符串，将 UI 上的点击操作逆向工程为可复现的 R 代码供用户下载。

- **`table_export.R` (表格导出器)**
  - **核心函数**: `apply_sci_gt_style()` 统一给 `gt` 对象注入三线表边框、加粗表头及脚注样式。

- **`storage_backend.R` (存储抽象层)**
  - 抽象了本地文件系统与 S3 对象存储的底层接口，使得应用具备云原生平滑迁移能力。

---

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
2. **缺失**: 缺失或无法计算的值显示为 `NA`。
3. **阈值**: $P < 0.001$ 显示为 `<0.001`；$P > 0.99$ 显示为 `>0.99`；其余保留 3 位小数。
4. **效应量**: `HR/OR/Beta (95% CI)`，区间与点估计统一保留 4 位小数并去除无意义的尾零。

### 6.4 亚组差异 P 值 (Interaction P-value) 规范
**极其重要**：亚组差异 P 值的口径必须是 **“预测变量 × 亚组变量”的交互项检验 P 值 (Effect Modification)**，而非简单的亚组间均值差。
1. **逻辑**: 无亚组变量时不显示该列。
2. **计算**: 有列分组时，按列分组的子数据集独立计算，**绝不**共用全局 P 值。
3. **展示**: 参考亚组行必须留空，仅在比较亚组行显示交互 P 值。

### 6.5 缺失值处理规范
- 模型拟合按涉及变量的 `complete cases`（完全观测记录）计算有效样本量 $N$。
- 缺失导致模型退化无法估计时，返回 `NA` 并在 UI 提示框中说明原因。

---

## 7. 部署与依赖管理指南 (Deployment & Dependencies)

AutoTFL 提供了高度兼容的部署方案，适配单机研发、内网服务器及云原生 Kubernetes。

### 7.1 依赖管理策略
系统采用“本地离线包优先，在线镜像回退”的策略：
- **`install_dependencies.R`**: 安装所需 R 包的主脚本。
- **`download_offline_packages.R` / `deploy_packages.py`**: 离线仓库方案。在有网环境下载包到 `vendor/cran/src`，在无网部署环境直接从本地构建安装，大幅提升 Docker 构建速度并解决企业内网隔离问题。

### 7.2 Docker 与 Docker Compose 部署 (推荐)
- **构建镜像**: 运行 `docker build -t autotfl-shiny-app:latest .`。Dockerfile 会将 `vendor/` 复制进容器以加速依赖编译。
- **一键启动 (Compose)**: 使用 `docker-compose up -d --build`，系统将自动拉起 **Nginx (反向代理)**、**Shiny 应用容器** 和 **PostgreSQL 数据库**。
- **环境变量**: 建议在部署前通过系统环境变量设置 `DB_PASSWORD` 提升安全性。

### 7.3 Windows 快捷部署
运行 `deploy-windows.cmd` / `deploy_menu.bat`：
- 提供互动式菜单，支持下载离线包、在线安装包和启动应用程序。注意，Windows 平台安装源码包需要 Rtools 支持。

---

## 8. 未来改进点与路线图 (Future Improvements)

随着业务场景拓展，AutoTFL 拟在后续阶段实施以下改进：

### 8.1 统计与算法增强
1. **参考亚组灵活配置**: 目前亚组分析默认第一水平为参考组，未来需在 UI 暴露“参考组选择”下拉框。
2. **全局交互联合检验**: 为三大回归（Cox/Logistic/Linear）新增全局交互联合检验输出区（补充局部的水平对比 P 值）。
3. **模型诊断可视化**: 自动运行如 `cox.zph()` 检验，并为不满足比例风险假设的变量提供预警或可视化残差图。
4. **机器学习扩展**: 引入随机森林、LASSO 等变量筛选与惩罚回归算法。

### 8.2 工程化与可复现性
1. **可复现代码沙盒**: 为自动生成的 R 代码片段增加“内置最小示例数据集”开关，方便用户一键复制并在本地 RStudio 成功运行。
2. **测试覆盖率提升**: 完善 `test/` 目录，增加对交互项计算模块 (`analysis_shared.R`) 的高压边界条件测试（如极端稀疏数据的容错）。
3. **微服务演进**: 平台计划在中长期从 R Shiny 单体应用拆分为 React 前端 + Python/R 混合计算微服务，本指南定义的格式规范应平滑过渡至 API 契约设计中。

---
*文档更新于：2026-03*
