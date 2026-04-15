# AutoTFL 项目技术规格书 (PROJECT\_SPEC.md)

## 1. 项目愿景

AutoTFL 旨在为医学和临床数据分析提供一套自动化、可复现的 TFL (Table, Figure, Listing) 生成方案。它是 Hamster Analysis 平台的核心应用，支持从数据导入到报表导出的全流程闭环。

## 2. 核心架构

- **表现层**: R Shiny (shinydashboard + bslib)，采用模块化 (Shiny Modules) 开发。
- **逻辑层**: 纯 R 驱动，核心统计依赖 `survival`, `gtsummary`, `rtables`；图形渲染采用 `showtext` 以确保跨平台（如 Docker/Windows/Linux）中文字体显示一致性。对于经 `cowplot` / `grid` 组合的图形，字体选择还需经过设备安全映射；`Arial` 在组合测量阶段会回退为 `sans`，避免 `PostScript` 字体数据库告警。
- **图形共享层**: `graphics_common.R` 与 `common_ui_shell.R` 统一维护图形尺寸模式、画布边框、页面距、前端居中容器、参考线抽象以及 PX/英寸换算；默认按 `96 px = 1 in` 同步前端与导出比例，避免页面不截断但导出截断。
- **持久层**:
  - 元数据：PostgreSQL (管理 Workspace, Folder, Dataset 关系)。
  - 数据体：本地 RDS 文件或 AWS S3 对象存储。
- **网关层**: Nginx 处理反向代理、SSL 卸载及静态 Landing 页。

## 3. 功能模块

- **数据管理 (Database Manager)**: 支持单文件上传、批量上传及服务器目录导入。
- **数据准备 (Data Prep)**: 负责数据筛选、列映射及变量元数据（Label/Type）推断。
- **统计分析 (Statistical Analysis)**: 覆盖描述性统计、Cox/Logistic/线性回归、ANOVA 等。
- **统计图形 (Statistical Graphics)**: 提供生存分析图、森林图、泳道图等医学常用图形。
- **图形输出一致性**: 统计图形模块需保证前端静态图、交互图与导出尺寸模式一致；带轨道/风险表的组合图在导出时需按当前前端画布高度同步扩展导出高度。
- **报表导出**: 支持 Word (RTF/DOCX), PDF, HTML 格式。
- **分析状态管理 (Analysis State Manager)**: 当前已为统计图形模块落地 `analysis_states` 持久化底座，并抽离共享 `task_history` 模块承载任务历史 UI/加载逻辑；现阶段仍嵌入统计图形页内，不单列左侧一级菜单。当前支持按用户保存/加载图形子模块的完整参数、UI 状态、模块类型与用户自定义 note；不保存图对象、分析结果对象或原始数据副本，载入后由各模块按 `state/apply_state` 契约恢复控件状态。状态快照只应包含业务参数，不应持久化 DT/Plotly 等输出组件派生的临时交互输入，也不应保存配置页签等纯导航态；恢复旧快照时也需跳过这些字段。任务历史同时支持删除。workspace 为空时保存为个人任务。后续再继续扩展到统计分析模块与更完整的任务资产管理。

## 3.1 研发工具链

- 当前仓库已补充 `.pre-commit-config.yaml`，用于串联 `styler`、`lintr` 与 `testthat` 守卫测试。
- `install_dependencies.R` 已将 `jsonlite`、`lintr`、`styler`、`shinytest2` 纳入开发依赖入口，便于本地和容器环境统一安装。

## 4. 权限模型

- 采用基于 Workspace 的隔离机制。
- 系统管理员 (Admin) 拥有服务器目录导入及全局管理权限；普通用户仅限个人 Workspace。

## 5. 部署形态

- 容器化部署：提供 Docker Compose 编排文件（Local/Server 场景）。
- 离线支持：通过 `download_offline_packages.R` 支持内网环境依赖安装。

