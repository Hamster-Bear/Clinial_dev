# AutoTFL 项目技术规格书 (PROJECT\_SPEC.md)

## 1. 项目愿景

AutoTFL 旨在为医学和临床数据分析提供一套自动化、可复现的 TFL (Table, Figure, Listing) 生成方案。它是 Hamster Analysis 平台的核心应用，支持从数据导入到报表导出的全流程闭环。

## 2. 核心架构

- **表现层**: R Shiny (shinydashboard + bslib)，采用模块化 (Shiny Modules) 开发。
- **逻辑层**: 纯 R 驱动，核心统计依赖 `survival`, `gtsummary`, `rtables`；图形渲染采用 `showtext` 以确保跨平台（如 Docker/Windows/Linux）中文字体显示一致性。
- **持久层**:
  - 元数据：PostgreSQL (管理 Workspace, Folder, Dataset 关系)。
  - 数据体：本地 RDS 文件或 AWS S3 对象存储。
- **网关层**: Nginx 处理反向代理、SSL 卸载及静态 Landing 页。

## 3. 功能模块

- **数据管理 (Database Manager)**: 支持单文件上传、批量上传及服务器目录导入。
- **数据准备 (Data Prep)**: 负责数据筛选、列映射及变量元数据（Label/Type）推断。
- **统计分析 (Statistical Analysis)**: 覆盖描述性统计、Cox/Logistic/线性回归、ANOVA 等。
- **统计图形 (Statistical Graphics)**: 提供生存分析图、森林图、泳道图等医学常用图形。
- **报表导出**: 支持 Word (RTF/DOCX), PDF, HTML 格式。
- **分析状态管理 (Analysis State Manager) [规划中]**: 负责将各个分析模块的 UI 参数与 `reactiveValues` 序列化为 JSON 并持久化到数据库，支持按用户与工作空间读取历史预设配置，实现分析任务的复用与沉淀。

## 4. 权限模型

- 采用基于 Workspace 的隔离机制。
- 系统管理员 (Admin) 拥有服务器目录导入及全局管理权限；普通用户仅限个人 Workspace。

## 5. 部署形态

- 容器化部署：提供 Docker Compose 编排文件（Local/Server 场景）。
- 离线支持：通过 `download_offline_packages.R` 支持内网环境依赖安装。

