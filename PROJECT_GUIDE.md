# AutoTFL 项目指南

## 目录

1. [文档定位](#1-文档定位)
2. [系统概览](#2-系统概览)
3. [运行入口与部署形态](#3-运行入口与部署形态)
4. [仓库目录结构](#4-仓库目录结构)
5. [核心模块总览](#5-核心模块总览)
6. [统计分析实现](#6-统计分析实现)
7. [统计图形实现](#7-统计图形实现)
8. [预设图表实现](#8-预设图表实现)
9. [公共能力与共享层](#9-公共能力与共享层)
10. [数据、存储与规范](#10-数据存储与规范)
11. [测试与质量保障](#11-测试与质量保障)
12. [当前未落地项与路线图](#12-当前未落地项与路线图)
13. [研发治理约束](#13-研发治理约束)
14. [交付与运营建议](#14-交付与运营建议)

## 1. 文档定位

### 1.1 目标

- 本文档用于说明 AutoTFL 当前仓库的真实实现，而不是理想设计草案。
- 文档重点覆盖架构边界、模块职责、运行方式、统计口径、部署前置条件和维护约束。
- 所有描述均以当前仓库文件、现有脚本和已存在测试为准；未落地能力单独放在“当前未落地项与路线图”。

### 1.2 名称约定

| 名称                         | 当前含义         | 备注                                         |
| -------------------------- | ------------ | ------------------------------------------ |
| Hamster Analysis           | 平台级命名        | 当前用于 Landing 页与部分部署资源，承载平台入口语义             |
| AutoTFL                    | 当前核心应用名      | 当前已上线并由 Hamster Analysis Landing 页承载入口的主应用 |
| Hamster Analysis · AutoTFL | 当前应用页头与浏览器标题 | 已用于 `app.R` 的 dashboardHeader 与浏览器标题       |

### 1.3 文档使用原则

- 新增或修改功能时，先更新本文件中对应章节，再改代码或同步提交代码变更。
- 本文件描述“当前已实现”，不把占位菜单、计划能力、外部设想写成既成事实。
- 若其他文档与本文件冲突，以当前代码实现和本文件为准，并在后续文档清理中同步收敛。

## 2. 系统概览

### 2.1 产品定位

- AutoTFL 是基于 R Shiny 的医学/临床数据分析应用，覆盖数据准备、探索性分析、统计分析、统计图形和预设 TFL 输出。
- 系统当前是单仓库、单 Shiny 主应用架构，支持通过 Nginx Landing 页面包装为“平台入口”。
- 主工作流依赖数据先进入 PostgreSQL 元数据层和本地/S3 数据存储层，再向下游分析与出图模块广播。

### 2.2 核心技术栈

| 分层     | 当前使用                                                                     |
| ------ | ------------------------------------------------------------------------ |
| UI 与交互 | Shiny、shinydashboard、shinyjs、shinyBS、bslib、shinyWidgets、reactable、plotly |
| 数据处理   | dplyr、tidyr、purrr、stringr、readxl、haven、vroom、memoise                     |
| 统计分析   | survival、broom、gtsummary、rtables、tern、corrplot                           |
| 导出能力   | gt、flextable、officer、rmarkdown、pagedown、r2rtf                            |
| 基础设施   | PostgreSQL、Redis、Nginx、Docker Compose                                    |

### 2.3 架构摘要

- 主入口为 `app.R`，负责加载依赖、source 模块、组装六大业务页签。
- 当前 `app.R` 已接入应用内自注册、登录、退出与会话态用户上下文。
- 登录与注册当前已拆分为两个独立页面，并在注册阶段采集邮箱用于后续协作授权扩展；认证主体区域已抽到 `auth_manager.R`。
- 当前用户信息与退出入口稳定显示在侧边栏卡片中，不再依赖顶栏动态渲染。
- `modules/` 目录采用“路由层 + 子模块 + common 共享层”结构。
- 数据元数据走 PostgreSQL；数据体通过 `modules/common/storage_backend.R` 落到本地目录或 S3。
- 图形与统计模块普遍采用“UI 输入层、公共校验/格式层、分析执行层、导出层”的分层方式。

### 2.4 六步主流程

| 步骤 | 模块                       | 作用                                            |
| -- | ------------------------ | --------------------------------------------- |
| 1  | `database_manager.R`     | 管理 workspace / folder / dataset 元数据，并负责数据入库登记 |
| 2  | `data_preparation.R`     | 上传、加载、筛选、预览、变量元数据整理                           |
| 3  | `exploratory_analysis.R` | 快速探索性图形分析                                     |
| 4  | `statistical_analysis.R` | 统计分析总入口与结果导出                                  |
| 5  | `statistical_graphics.R` | 统计图形总入口与图形导出                                  |
| 6  | `tables.R`               | 预设 Table / Figure / Listing 输出                |

## 3. 运行入口与部署形态

部署细节、目录树、挂载关系、环境变量和分场景操作步骤统一维护在 `DEPLOYMENT_GUIDE.md`；本章仅保留部署矩阵与边界摘要。

### 3.1 运行矩阵

| 场景     | 入口                          | 访问方式                    | 说明                                |
| ------ | --------------------------- | ----------------------- | --------------------------------- |
| 本地开发直跑 | `run_app.R`                 | 默认 `127.0.0.1:8109`     | 自动检查依赖并直接运行 `app.R`               |
| 开发编排   | `docker-compose.yml`        | `http://localhost`      | Nginx 直接反代 Shiny 根路径，不带 Landing 页 |
| 本地联调   | `docker-compose.local.yml`  | `http://localhost:8080` | 含 Landing 页，应用入口为 `/app/`         |
| 服务器生产  | `docker-compose.server.yml` | `https://<domain>`      | HTTPS + Landing 页，应用入口为 `/app/`   |

### 3.2 当前入口规则

- `docker-compose.yml` 使用 `nginx/default.conf`，根路径 `/` 直接转发到 Shiny。
- `docker-compose.local.yml` 使用 `nginx/local-test.conf`，根路径为 Landing 页，应用走 `/app/`。
- `docker-compose.server.yml` 使用 `nginx/server_ssl.conf`，80 自动跳转 443，根路径为 Landing 页，应用走 `/app/`。
- 当前 Landing 页使用 Hamster Analysis 平台口径，对外说明平台定位；AutoTFL 作为当前已上线应用，通过 `/app/` 提供实际分析能力。
- `nginx/landing/index.html` 只保留平台入口与最短访问路径，不在主页展开 AutoTFL 细节。
- `nginx/landing/autotfl.html` 单独承接 AutoTFL 的功能产出、使用指南与结果示意；文案风格继续保持少字、高识别。
- 本地联调 Landing 页的静态资源在 `local-test.conf` 中已设置 no-store/no-cache，减少浏览器缓存导致的“re-up 后页面看起来未更新”问题。

### 3.3 当前部署边界

- 当前仓库已实现 Docker Compose 部署链路。
- 当前仓库未提供 Kubernetes Manifest、Helm Chart 或 Kustomize 配置，因此不应描述为“已支持 Kubernetes 生产部署”。
- Redis 已进入编排层，但当前 Shiny 主应用代码未见显式 Redis 业务读写逻辑，现阶段更适合作为基础设施预留。

### 3.4 依赖与离线仓库前置条件

- `install_dependencies.R` 支持“本地离线仓库优先、在线镜像回退”。
- `download_offline_packages.R` 用于预生成本地 `package/` 仓库及 `PACKAGES` 索引。
- 当前仓库默认未提交 `package/` 目录；如果直接执行当前 `Dockerfile`，需要先生成 `package/`，否则 `COPY package /app/package` 会失败。
- Windows 本地如需从源码构建依赖，仍建议准备 Rtools。

### 3.5 生产环境关键变量

| 变量                   | 默认值                           | 用途              |
| -------------------- | ----------------------------- | --------------- |
| `DB_PASSWORD`        | 无安全默认值，部署时必须覆盖                | PostgreSQL 连接密码 |
| `DATA_ROOT`          | `/data/hamster-analysis`      | 生产持久化根目录        |
| `CERT_ROOT`          | `/etc/hamster-analysis/certs` | 证书目录            |
| `SSL_CERT_FILE`      | `kyyin.xyz.pem`               | 证书文件名           |
| `SSL_KEY_FILE`       | `kyyin.xyz.key`               | 私钥文件名           |
| `APP_STORAGE_ROOT`   | `/app/data_storage`           | 容器内数据体挂载目录      |
| `APP_ADMIN_USERNAME` | 空                             | 可选的预置管理员用户名     |
| `APP_ADMIN_EMAIL`    | 空                             | 可选的预置管理员邮箱      |
| `APP_ADMIN_PASSWORD` | 空                             | 可选的预置管理员密码      |

### 3.6 当前访问控制边界

- 当前仓库已实现应用内自注册、登录、退出与 workspace 级权限控制。
- 登录支持用户名或邮箱；注册阶段会校验邮箱格式，当前登录/注册页已改为上下居中的单列卡片布局，但尚未接入真实邮箱验证或邮件发送。
- 当前用户信息与退出入口稳定显示在侧边栏卡片中；普通用户的权限管理快捷入口也合并在该卡片内。
- 未登录状态下只渲染登录/注册入口，不渲染业务工作台侧边栏。
- 非管理员用户默认按个人空间隔离，只能看到自己拥有或被授权的 workspace。
- 系统管理员可访问全部 workspace，并独占服务器目录导入入口。
- 当前已提供管理员操作入口；workspace、membership、invite 与 owner 迁移能力统一下沉到 service 层。
- workspace 创建与删除也统一通过 `account_service.R` 收口，数据库管理模块不再直接拼装 owner / membership 初始化逻辑。
- 普通用户可对自己拥有的数据空间进行权限管理，且授权、撤销与 owner 迁移统一通过邮箱输入完成。
- 管理员页保持独立系统入口，不并入侧边栏用户卡片；系统级负责人绑定、协作授权与账号状态调整继续集中在管理员页。
- 权限预览表统一改为业务中文列名；数据库管理页按“空间与目录 / 上传与导入 / 结构总览”三段重组。
- 数据库管理功能已增加账号级访问锁：普通账号默认锁定，需由管理员开放数据库管理权限后才可进入与操作。
- 当前尚未实现组织级、项目级隔离，也未提供更细粒度的 folder 或 dataset 权限模型。

### 3.7 当前免责声明

- 当前工具暂不负责数据安全；数据传到服务端后不保证安全，请使用方自行妥善保管数据。
- 如需更高的数据隔离与环境保障，应优先采用独立部署服务，而不是把当前公共部署形态描述为安全托管服务。
- 可通过环境变量预置管理员用户名、邮箱和密码；若未预置，则首个注册用户会自动成为系统管理员。

### 3.8 当前阶段风险与优化建议

- 技术风险：当前权限主边界仍在 workspace 级别，`viewer` / `editor` 对数据写操作的差异尚未完全落实到所有模块；数据库管理锁当前仍是账号级开关。
- 维护风险：邮箱邀请支持未注册用户占位，但尚未提供邀请过期、撤回审计与邮箱真实性校验；普通用户入口与管理员入口的交互规范需要持续同步。
- 项目风险：owner 自助授权已开放给创建者，后续若扩展共享协作，需要同步补齐审计日志与异常回滚策略。
- 立即可做：补充 service 层数据库集成测试，覆盖授权、撤销、owner 迁移、invite 领取与 workspace 删除链路，并验证数据库管理新布局与数据库管理锁的可用性。
- 中长期建议：引入邮箱验证、邀请有效期、组织级 / 项目级协作模型与更细粒度权限矩阵。
- 工具链建议：在 `tests/` 现有守卫测试基础上，引入 PostgreSQL 临时库回归测试与 pre-commit 文档一致性校验。

## 4. 仓库目录结构

```text
AutoTFL/
├── app.R
├── modules/
│   ├── common/
│   │   ├── analysis_format.R
│   │   ├── analysis_shared.R
│   │   ├── account_service.R
│   │   ├── auth.R
│   │   ├── data_filter.R
│   │   ├── data_metadata.R
│   │   ├── graphics_common.R
│   │   ├── graphics_repro.R
│   │   ├── plot_export.R
│   │   ├── storage_backend.R
│   │   └── table_export.R
│   ├── statistical_analysis/
│   │   ├── anova.R
│   │   ├── chisq.R
│   │   ├── cox.R
│   │   ├── desc.R
│   │   ├── linear.R
│   │   └── logistic.R
│   ├── statistical_graphics/
│   │   ├── boxplot.R
│   │   ├── combo_plot.R
│   │   ├── correlation_matrix.R
│   │   ├── forest_plot.R
│   │   ├── heatmap.R
│   │   ├── spider_plot.R
│   │   ├── survival_analysis.R
│   │   ├── swimmer_plot.R
│   │   └── waterfall_plot.R
│   ├── statistical_graphics_ui/
│   │   └── common_ui_shell.R
│   ├── tables/
│   │   ├── ae_sidebyside.R
│   │   ├── listing_general.R
│   │   ├── t_ae_soc_pt.R
│   │   └── t_dm.R
│   ├── data_preparation.R
│   ├── database_manager.R
│   ├── auth_manager.R
│   ├── admin_manager.R
│   ├── exploratory_analysis.R
│   ├── statistical_analysis.R
│   ├── statistical_graphics.R
│   └── tables.R
├── nginx/
│   ├── landing/
│   │   ├── index.html
│   │   ├── autotfl.html
│   │   ├── style.css
│   │   ├── script.js
│   │   └── assets/
│   ├── default.conf
│   ├── local-test.conf
│   └── server_ssl.conf
├── postgres/
│   ├── init.sql
│   └── postgresql.conf
├── deploy/
│   └── alicloud/
├── tests/
├── Dockerfile
├── docker-compose.yml
├── docker-compose.local.yml
├── docker-compose.server.yml
├── docker-compose1.yml
├── download_offline_packages.R
├── install_dependencies.R
├── PROJECT_GUIDE.md
├── run_app.R
├── run_app_test.ps1
└── style.css
```

### 4.1 目录使用约定

- `modules/common/` 只放跨模块共享逻辑，不放单一图形或单一统计方法的专属实现。
- `modules/statistical_graphics_ui/` 用于图形 UI 壳层与公共控件，和 `modules/statistical_graphics/` 的 server/分析逻辑分离。
- `tests/` 为统一测试目录，新增测试文件必须放在这里。
- `nginx/landing/index.html` 作为平台主 Landing，保持精简，只负责入口说明与跳转。
- `nginx/landing/autotfl.html` 作为 AutoTFL 子页，承接功能产出、使用指南与结果示意。
- `nginx/landing/style.css` 与 `nginx/landing/script.js` 为主 Landing 和 AutoTFL 子页共享静态资源，改动时需同时验证两页。
- `deploy/alicloud/` 只存放生产部署辅助资源，不承载应用业务逻辑。

## 5. 核心模块总览

### 5.1 主入口

| 文件                       | 当前职责                                    | 关键说明                |
| ------------------------ | --------------------------------------- | ------------------- |
| `app.R`                  | 加载依赖、source 模块、定义 dashboard UI 与 server | 六个侧边栏页签都在这里挂载       |
| `run_app.R`              | 本地启动脚本                                  | 先执行依赖检查，再启动 `app.R` |
| `install_dependencies.R` | 依赖安装脚本                                  | 支持本地离线仓库优先、在线镜像回退   |

### 5.2 业务模块

| 模块                       | 主要职责                                | 当前状态 |
| ------------------------ | ----------------------------------- | ---- |
| `database_manager.R`     | 管理工作区、文件夹、数据集，支持单文件上传、批量上传、按服务器目录导入 | 已实现  |
| `data_preparation.R`     | 上传或从数据库加载数据，做高级筛选、列选择、数据预览和概览卡片     | 已实现  |
| `exploratory_analysis.R` | 提供基础探索图形与变量映射交互                     | 已实现  |
| `statistical_analysis.R` | 统计分析总入口，路由到描述性统计、回归、组间比较等子模块        | 已实现  |
| `statistical_graphics.R` | 图形总入口，路由到生存图、森林图、泳道图等子模块            | 已实现  |
| `tables.R`               | 预设表格/图形/Listing 总入口                 | 已实现  |

### 5.3 数据流摘要

1. 数据通过数据库管理模块或数据准备模块进入系统。
2. 元数据通过 PostgreSQL 中的 workspaces / folders / datasets 管理。
3. 数据体通过 `storage_backend.R` 保存到本地 `RDS` 或 S3。
4. `data_metadata.R` 与 `data_filter.R` 统一变量标签、类型和筛选逻辑。
5. 下游统计分析、图形和预设图表消费经过筛选后的数据。

## 6. 统计分析实现

### 6.1 模块定位

- `statistical_analysis.R` 是统计分析总入口，不仅仅是“回归面板”。
- 当前实际已接入描述性统计、Cox、Logistic、Linear、ANOVA、卡方和 CMH。
- `MMRM` 与 `多重填补（MI）` 当前仍是菜单占位项，不应视为已交付功能。

### 6.2 子模块清单

| 文件           | 功能          | 当前实现要点                                       |
| ------------ | ----------- | -------------------------------------------- |
| `desc.R`     | 描述性统计       | 基于 `gtsummary` 生成汇总表，支持总计列扩展                 |
| `cox.R`      | Cox 回归      | 使用 `survival::coxph`，支持 strata、split、列分组     |
| `logistic.R` | Logistic 回归 | 使用 `stats::glm(family = binomial())`，支持事件值映射 |
| `linear.R`   | 线性回归        | 使用 `stats::lm`，支持多预测变量和列分组                   |
| `anova.R`    | 方差分析        | 连续变量组间比较                                     |
| `chisq.R`    | 卡方 / CMH    | 分类变量组间比较与分层检验                                |

### 6.3 当前共享引擎

| 文件                           | 核心职责                                | 当前作用                         |
| ---------------------------- | ----------------------------------- | ---------------------------- |
| `analysis_shared.R`          | 回归公共校验、交互项 P 值计算、统一结果整理             | Cox / Logistic / Linear 共享核心 |
| `account_service.R`          | 用户、workspace、membership 与数据入口服务封装   | 管理员入口与数据模块复用服务层              |
| `auth.R`                     | 注册、登录、密码摘要、权限过滤与管理员引导               | `app.R`、数据库管理、数据准备共享认证边界     |
| `auth_manager.R`             | 登录/注册页面、认证交互与 loading 反馈            | 精简 `app.R` 并统一认证入口 UI        |
| `workspace_access_manager.R` | owner 邮箱授权、撤销权限、invite 与 owner 迁移入口 | 用户自助管理自己拥有的数据空间权限            |
| `analysis_format.R`          | 数值格式化、统计值格式化、复现代码模板                 | 控制结果显示和导出文案                  |
| `table_export.R`             | `gt` 风格注入与导出辅助                      | 统一表格样式与 P 值显示                |

### 6.4 统计分析当前约束

- 回归模块已经不适合再概括为“统一采用 gtsummary 引擎”。
- 当前更准确的说法是：描述性统计仍以 `gtsummary` 为主，Cox/Logistic/Linear 的结果表已显著依赖共享回归表引擎和公共格式层。
- 响应变量不能同时作为预测变量；预测变量不能与 split / facet / strata 重复；这部分由 `validate_regression_inputs()` 统一控制。

### 6.5 非标准列名支持

- 变量名推荐使用英文、数字和下划线，便于跨工具协作。
- 当前代码已考虑含空格或特殊字符的列名场景，回归公式需要通过反引号安全包装。
- 因此，文档不再把“禁止空格与特殊符号”写成硬性实现约束，而是保留为数据治理建议。

## 7. 统计图形实现

### 7.1 模块定位

- `statistical_graphics.R` 是统计图形总路由。
- 当前图形模块采用“公共能力 + 子模块逻辑”模式，逐步把 UI 壳层、尺寸配置、图例能力和导出参数抽到共享层。

### 7.2 子模块清单

| 文件                     | 图形类型              | 当前说明                    |
| ---------------------- | ----------------- | ----------------------- |
| `survival_analysis.R`  | Kaplan-Meier 生存曲线 | 支持静态图、交互图、风险表、统计报告和复现代码 |
| `forest_plot.R`        | 森林图               | 用于回归结果或亚组一致性展示          |
| `correlation_matrix.R` | 相关矩阵图             | 支持相关性探索                 |
| `boxplot.R`            | 箱线图               | 用于组间分布比较                |
| `heatmap.R`            | 热图                | 用于矩阵热区展示                |
| `combo_plot.R`         | 组合图               | 复合图层展示                  |
| `spider_plot.R`        | Spider 图          | 肿瘤负荷/时间变化               |
| `swimmer_plot.R`       | Swimmer 图         | 疗程轨迹与事件展示               |
| `waterfall_plot.R`     | Waterfall 图       | 个体疗效下降/上升幅度展示           |

### 7.3 共享图形能力

| 能力      | 当前来源                                        | 说明                                                                                                                                                                                                                                     |
| ------- | ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 尺寸与画布解析 | `graphics_common.R`                         | 统一静态图、交互图和导出尺寸解析，并收口画布边框、页面距、PX/英寸换算与导出高度同步                                                                                                                                                                                            |
| 图形通知    | `graphics_common.R`                         | 统一成功/失败提示                                                                                                                                                                                                                              |
| 辅助线抽象   | `graphics_common.R` + `common_ui_shell.R`   | 统一参考线 UI 原子控件与 plot 层辅助线叠加逻辑                                                                                                                                                                                                           |
| 复现代码    | `graphics_repro.R`                          | 为图形模块生成可复现代码片段                                                                                                                                                                                                                         |
| UI 壳层   | `statistical_graphics_ui/common_ui_shell.R` | 统一页签容器、导出控件、主按钮样式，以及图形输出居中容器                                                                                                                                                                                                           |
| 导出      | `plot_export.R`                             | 图形导出辅助能力                                                                                                                                                                                                                               |
| 任务历史    | `task_history.R` + `account_service.R`      | 共享任务历史模块负责保存/加载入口、最近任务列表、用户自定义 note、删除操作与用户友好提示；底层使用 PostgreSQL `analysis_states` 表持久化图形子模块完整参数、UI 状态与模块类型 JSON 快照，不保存图对象、结果对象或原始数据副本；快照只保留业务参数，不应混入 DT/Plotly 等派生交互输入，也不应保存配置折叠/页签这类导航态；旧任务恢复时也要跳过这些临时字段，避免加载任务触发未定义列、过滤异常或动态 UI 异步崩溃 |

### 7.4 生存分析当前实现口径

| 主题     | 当前实现                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 状态管理   | 采用 view state 与 committed state 分离，只有点击“生成图形”才提交分析参数                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 时间范围   | “处理与筛选”面板中的 X 轴最大值滑轴已统一复用 common 的 `graphics_time_axis_controls_ui()` + `graphics_render_time_range_slider()` 抽象；生存分析模块必须将 `time_range` 同时接入 `view_state`、committed state、任务历史 extra\_state 与回填链路，并同时作用于主图 `xlim`、统计文本定位和结果表时间过滤，不能只渲染滑块 UI 而不串通状态；动态 `renderUI` 重建滑轴时，`selected_range` 必须优先读取 `view_state$time_range` 以避免 UI 回退到默认最大值                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| 风险表    | 风险表主要用于静态图组合输出；交互页并不是“Plotly + 风险表”同页布局。当前已暴露 `risk_table_height_ratio`、`risk_table_plot_gap`、`risk_table_group_gap` 三个参数，分别控制风险表相对高度、主图与风险表之间的垂直留白、风险表分组行之间的额外扩展；默认值收紧为 `0.15 / 0 / 1.2`。风险表数字字号控件 `risk_table_fontsize` 现已统一改为与其他字号控件一致的 pt 口径，默认值为 `10`，内部再通过 common 换算成 `ggsurvplot` 风险表文本 size；风险表数字层、Y轴标签、主图统计文本与辅助图例当前统一复用同一 `base_family` 字体链路，并显式指定 `plain/bold` 字重，避免 risk 表数字出现无法受全局字体控制、比其他文本更粗的视觉偏差。风险表 Y 轴标签样式更新时必须保留 `ggsurvplot` 预设主题元素类型（例如 `element_markdown`），只能更新其字号/字体属性，不能直接用 `element_text` 覆盖，以避免 theme merge 报错；在分层场景下，risk table 顺序应保持 `ggsurvplot` 内置的 `y = rev(strata)` 映射，只允许在保留原 `breaks/labels` 结构的前提下做标签文案映射，不再额外通过 `scale_y_discrete(limits=...)` 重排分组顺序，也不要通过上游直接覆写 factor levels 的方式替换显示名，否则在自定义标签重复时会破坏组别与人数的对应关系；当用户选择 `Arial` 或沿用默认 `sans` 时，内部需先走设备安全解析，并在已注册时优先落到 `Noto Sans SC`，以兼顾 `cowplot/grid` 组合阶段的度量稳定性与中文显示能力 |
| 分层标签   | 主图图例、删失图例、统计文本、风险表与数据表统一复用同一标签格式化链路；比较符号及原始值中的 `=`, `>=`, `<` 必须原样保留并可映射自定义标签                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| 文本输入   | 图例标题、分层标签、中位生存时间标签、坐标轴标题等文本输入，只有真正的空串 `""` 才允许回退默认值；用户显式输入的纯空格 `"   "` 必须按原样保留，不能因 `trimws()` 被吞掉后再回退为默认文案                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| 删失图例   | 交互图中的主图分组图例优先复用 `ggsurvplot` 默认图例能力，仅负责标题与标签定制；静态图则统一改为辅助图例方案：主图分组图例与删失图例都以 common 图例绘制器生成并组合，其中 Censor 图例在分层场景下必须优先复用主图最终 legend 颜色，确保删失符号颜色与曲线颜色一致。曲线上的删失点形状在所有分组中统一取自 `km_censor_shape`，不能因分组再次映射为圆形/三角等离散形状；静态图中主图分组图例固定在前、Censor 图例固定在后，且通过 common 的 inside-anchor/aux-legend 摆放抽象和公共 ratio 滑条控件控制紧凑间距与定位；图例自定义滑轨初始化值统一为 `X/Y/宽/高 = 0.95/0.85/0.13/0.14`，避免重复图例、原始 `变量=取值` 文本泄漏、颜色失配与 `Ignoring unknown labels` 警告。当前 `legend_row_gap` 已暴露到 UI，主图线条图例与删失图例必须共享同一 row-gap 参数，并在叠加时按各自真实行数动态分配高度，禁止再将删失图例行数硬编码为 `1`                                                                                                                                                                                                                                                                                                                |
| 统计文本   | 各组中位生存时间文本改为自由编辑标签，默认使用 `mPFS`，并统一左对齐；其组间距与 Cox 多组文本块保持一致的紧凑行距。统计文本自定义坐标统一复用 common 的比例坐标控件；统计报告中三组以上时需明确 Log-rank 为全局检验，只表示至少一组与其他组存在差异，不代表所有两两比较均显著                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| 坐标轴默认值 | X 轴标签默认填入 `Duration`，除非用户显式改写                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Y轴格式   | 当前已暴露 `y_break_step`、`y_decimals`、`y_as_percent`、`y_show_percent_sign` 参数：支持控制步长、小数位、是否按百分比显示、以及百分比场景下是否带 `%`；普通数值与百分比数值统一走 common 格式化函数，避免三图间显示口径分叉                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 中位线    | 当前已暴露 `surv_median_line` 选项，允许 `none / hv / h / v` 四种模式控制主图中位线显示                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| P值格式   | Log-rank 与生存分析内联 P 值统一采用 AMA 风格：`<0.001`、`>0.99` 或三位小数，避免 `P=0.000`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| 交互页    | 当前以交互主图和单独结果页签为主                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 尺寸配置   | 已接入统一尺寸接口；静态图、交互图与导出图共享同一尺寸模式，并新增页面距、画布边框和 PX/英寸同步换算。默认按 `96 px = 1 in` 保持前端与导出比例一致；包含下方轨道的图形在导出时也需按当前静态画布高度同步扩展导出高度，避免前端不截断但导出截断                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 测试覆盖   | 已有选择解析、中位生存时间基线、view/committed 状态测试，并新增显示契约测试覆盖比较符号/等号标签、Cox 标签映射、删失图例颜色链路、辅助图例布局、删失符号一致性与 P 值格式                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |

### 7.5 图例与样式当前状态

- Survival、Spider、Waterfall、Swimmer、Forest 已逐步接入 common 图例与统一尺寸/画布能力。
- Swimmer 保留事件图例的自绘特例，但标题解析、inside-anchor 摆放与 ratio 滑条控件应继续优先复用 common。
- Swimmer 当前也开始采用 view state 与 committed state 分离的输出口径：点击“生成图形”后，主图、交互图、下方轨道组合高度与导出所依赖的图形参数统一锁定到同一份提交快照，避免生成后继续修改控件导致图形结果与当前面板值漂移；剩余待讨论项应尽量限定在统计/业务语义，而不是状态恢复或 UI 实现分叉。
- Swimmer 在最后一轮语义收口中继续修正文案与实现边界：`end_desc/end_asc` 当前表示按汇总后的“泳道终点”排序，而不是原始日历结束日期；`track_rel_height` 当前控制的是主图与下方轨道区的相对高度，不是数据表控件本身的高度。
- Swimmer 的事件映射恢复链路当前增加了“恢复期间优先读 state、平时优先读当前 input”的短暂切换标志，避免加载任务历史或回填动态 UI 时，事件时间/类型/标签选择框和事件样式面板误读页面残留输入，导致控件选择看起来未正确载入。
- Swimmer 当前进一步约束动态 UI 恢复与归类边界：事件映射、事件样式、泳道颜色、轨道展示方式和轨道颜色映射在配置盒折叠或页签隐藏时也不得挂起；`tracks` 默认不再自动推荐变量，只允许用户显式选择或从历史快照恢复。
- Waterfall 当前与 Swimmer 保持同一条高动态恢复约束：柱颜色映射、符号分组映射、轨道展示方式和轨道颜色映射在配置盒折叠或页签隐藏时也不得挂起；`tracks` 默认不再自动推荐变量，只允许用户显式选择或从历史快照恢复，避免未确认业务字段自动进入下方轨道区。
- Waterfall 当前也开始采用 committed 输出口径：点击“生成图形”后，主图柱体样式、符号映射、RECIST 线、轨道区配色/文本、缺失值文本、轨道区相对高度与底部脚注统一锁定到同一份提交快照，避免生成后继续修改控件造成静态图高度、下方轨道区或导出内容与已生成结果漂移。<mccoremem id="03fyfynhnwuokzwfqrr50glne" />
- Waterfall 第三轮继续收紧实现语义文案：`symbol_by` / `show_symbols` 当前控制的是柱顶文本符号映射，不是点形状图层；`use_percent_label` 只影响 Y 轴标签格式，不会重新换算原始变化值；`legend_title` 仅作用于主图柱分组图例，`track_legend_title` 仅作用于下方轨道区总图例。
- Spider 当前开始采用 committed 输出口径：点击“生成图形”后，时间单位换算、Y 轴刻度与百分比标签、线条样式、点层、末次标签、参考线、分面、标题图例以及静态图/交互图/导出尺寸统一锁定到同一份提交快照，避免生成后继续修改控件导致前端框体尺寸或图形结果与已生成状态漂移。
- Spider 第二轮继续收紧实现语义文案：`use_percent_label` 只影响 Y 轴标签与 tooltip 的显示格式，不会重新换算原始变化值；`add_baseline_zero` 当前为每条轨迹补一个 `(time=0, value=0)` 的基线原点，不代表原始数据里存在该观测；`show_end_labels` 当前显示的是每条轨迹末次点对应的受试者标签，而不是时间点标签或数值标签。
- Spider 第三轮继续做 UI 归类收紧：将右侧参数从“文本与布局 / 配色与比例 / 输出与导出”改为“标题与说明 / 显示与坐标 / 线条与点层 / 输出与导出”，把标题文字、显示行为与图例、时间轴与 Y 轴格式、线条/点层样式明确拆开，避免“显示与图例”“时间轴设置”“Y轴与字号”“线条调色板”继续混在同一分组里。
- Spider 第四轮开始按统一布局规范落地：`输出与导出` 页签只保留尺寸与导出参数，并显式关闭内置 `生成图形` 按钮；结果区顶部统一改用 `graphics_output_action_bar_ui()` 承载 `生成图形 / 下载图形`，从而把“参数配置”和“执行动作”彻底拆开，避免结果区和参数区同时出现动作入口。 
- Survival 的时间范围滑轴已复用 common 的 `graphics_time_axis_controls_ui()` + `graphics_render_time_range_slider()`；Swimmer 当前也接入同一组件，用于控制主图 X 轴最大显示范围。泳道图在时间映射尚未选定时必须保留该 UI 位置并显示提示，不能因 `req()` 中断而整块空白，任务历史恢复后也要继续回填 `time_range`。
- Waterfall 与 Swimmer 的符号/颜色分别指定能力已经存在，但仍属于高复杂 UI，后续应继续抽象公共组件。
- Survival、Spider、Waterfall 当前都已接入统一 Y 轴格式化口径：百分比显示、是否带 `%`、保留小数位数都应优先复用 common 的标签格式化函数。
- Survival 静态图的主图线条图例与删失图例，当前被视为两个独立辅助图例：内部行距使用同一 `legend_row_gap` 参数，叠加拼接时按照各自真实行数分配 `rel_heights`，不得依赖固定比例常量推断高度。
- 涉及 `cowplot` / `grid` 组合测量的文本（如 Survival 静态图、辅助图例、风险表、森林图表头、泳道图事件图例、底部 caption）必须先走 common 的三层字体策略：`graphics_resolve_device_safe_family()` 只负责设备安全映射（如 `Arial -> sans`），`graphics_resolve_font_spec()` / `graphics_resolve_text_family()` 负责拉丁与 CJK 文本分流，`graphics_resolve_layout_family()` 专门处理布局测量链路。`draw_label()`、辅助图例和 common caption 不得再直接吃 `Noto Sans SC` 等自定义字体名。仅依赖 `showtext::font_add_google()` 不能保证离线容器内的中文字体可用。
- 同类规则也适用于非统计图形主入口中的文本层：`exploratory_analysis.R` 的错误占位/标题文本，以及 `tables/ae_sidebyside.R` 的汇总标注，不得再硬编码 `sans` 或依赖设备默认字体。
- 森林图、蜘蛛图、泳道图当前已开始复用 common UI 高阶组件收口坐标范围、刻度格式与时间轴单位换算；经典轴线手动画段也已抽到 `graphics_add_classic_axis_segments()`，减少模块内重复 `annotate("segment")` 逻辑。泳道图在 `classic` 无箭头模式下，X 轴线段终点需保持在面板裁剪边界内侧，避免最右端方头线帽被裁掉后出现“断裂”视觉。
- 森林图当前已补齐任务历史最小契约：统一通过 `graphics_build_task_state()` 保存 `data_mode`、列映射、原始数据分析字段、表格列选择、列显示名/对齐方式及导出参数，并通过 `apply_state()` + `graphics_restore_task_input_state()` 回填；本轮只收口状态快照，不等同于森林图 UI 已完成与蜘蛛图相同级别的页签化重构。

## 8. 预设图表实现

### 8.1 模块定位

- `tables.R` 统一管理临床研究常用模板。
- 当前既包含传统表格，也包含图形型输出，因此它是“预设输出总入口”，不是单纯的表格模块。

### 8.2 子模块清单

| 文件                  | 类型      | 当前说明           |
| ------------------- | ------- | -------------- |
| `t_dm.R`            | Table   | 人口统计学和基线特征表    |
| `t_ae_soc_pt.R`     | Table   | 不良事件 SOC/PT 汇总 |
| `listing_general.R` | Listing | 通用审阅明细清单       |
| `ae_sidebyside.R`   | Figure  | AE 并列对比图       |

### 8.3 当前引擎边界

- `t_dm.R` 以 `gtsummary + gt` 为主。
- `t_ae_soc_pt.R` 依赖 `rtables / tern`。
- `listing_general.R` 依赖 `rlistings / r2rtf`。
- `ae_sidebyside.R` 走 `ggplot2` 图形分支，导出策略与表格分支不同。

## 9. 公共能力与共享层

### 9.1 公共文件清单

| 文件                  | 当前职责                         |
| ------------------- | ---------------------------- |
| `data_metadata.R`   | 统一变量标签、类型推断、元数据回写            |
| `data_filter.R`     | 统一筛选 UI / server 与变量过滤行为     |
| `analysis_shared.R` | 统一回归校验和结果组装                  |
| `analysis_format.R` | 统一统计值、P 值、复现代码模板             |
| `graphics_common.R` | 统一图形变量筛选、尺寸、图例绘制、坐标轴样式和标签格式化 |
| `graphics_repro.R`  | 图形复现代码                       |
| `plot_export.R`     | 图形导出                         |
| `table_export.R`    | 表格导出与样式注入                    |
| `storage_backend.R` | 本地 / S3 数据存储抽象               |

### 9.2 当前共享层原则

- 共享层优先维护“统计口径、格式、元数据、导出、存储”这类跨模块不应分叉的逻辑。
- 子模块遇到公共需求时先扩展 common，再决定是否保留少量局部特例。
- 修改共享层时必须同步检查回归模块、图形模块和导出路径是否受影响。

### 9.3 当前可复用函数清单

| 主题                   | 文件                  | 当前可复用函数                                                                                                                                                                                                                                                                                       | 当前约束                                                                                                                                                                                                                                                              |
| -------------------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 图例标题与位置枚举            | `graphics_common.R` | `graphics_resolve_legend_title()`、`graphics_legend_position_choices()`、`graphics_legend_controls_ui()`                                                                                                                                                                                        | 图例标题统一走 `custom > fallback > default`；位置值只能来自 common 枚举，子模块不得自造私有位置字符串                                                                                                                                                                                            |
| 图例锚点、ratio 滑条与辅助图例摆放 | `graphics_common.R` | `graphics_resolve_inside_anchor()`、`graphics_aux_legend_anchor_controls_ui()`、`graphics_place_aux_legend()`、`graphics_apply_legend_theme()`                                                                                                                                                   | 图内锚点必须先归一化；辅助图例位置、统计文本自定义坐标与 x/y/width/height ratio 控件优先复用 common；隐藏图例统一使用 `"none"`                                                                                                                                                                               |
| 辅助图例绘制器              | `graphics_common.R` | `graphics_aux_legend_compact_defaults`、`graphics_resolve_device_safe_family()`、`graphics_resolve_font_spec()`、`graphics_resolve_text_family()`、`graphics_build_legend_rows()`、`graphics_build_point_legend_plot()`、`graphics_build_line_legend_plot()`、`graphics_compose_stacked_legends()`                                                                   | 自绘辅助图例的行距、标题间距、外边距、组间 spacer 统一由 common 控制；收紧通用规则为所有图例的每个因子之间保持约一个字符大小的间距，且线条图例与删失图例必须复用同一 row-gap 约束；拼接多个辅助图例时必须按真实行数传入 `primary_rows / secondary_rows`，不得硬编码删失图例高度。涉及 `cowplot/grid` 组合测量时先做设备安全映射，再按文本内容选择拉丁/CJK 字体；单个文本 grob 若混排且无法拆分，应优先落到统一 CJK 覆盖字体 |
| 轴线、辅助线与标签格式          | `graphics_common.R` | `graphics_apply_axis_style()`、`graphics_collect_reference_line_spec()`、`graphics_add_reference_lines()`、`graphics_format_percent_labels()`、`graphics_format_number_labels()`                                                                                                                  | 经典 XY 轴样式、用户可配置辅助线、百分比显示、是否带 `%`、保留小数位数统一走 common；模块内不得各写一套刻度/辅助线拼装逻辑                                                                                                                                                                                             |
| 通用 UI 控件             | `common_ui_shell.R` | `graphics_reference_line_ui()`、`graphics_primary_action_button_ui()`、`graphics_output_action_bar_ui()`、`graphics_font_family_ui()`、`graphics_font_family_pair_ui()`、`graphics_export_size_controls_ui()`、`graphics_centered_output_container()`、`graphics_axis_range_controls_ui()`、`graphics_axis_tick_format_controls_ui()`、`graphics_time_axis_settings_ui()` | 高度重复的 UI 块（如参考线配置、主按钮、结果区动作条、字体族选择、尺寸/导出表单、输出区居中容器、坐标范围、刻度格式、时间轴单位换算）必须复用 common 控件，统一参数收集逻辑；复杂图形模块优先改用 `graphics_font_family_pair_ui()` 暴露“西文字体 + 中文字体”双配置，`graphics_font_family_ui()` 保留向后兼容与轻量场景                                                                                                                                                                             |
| 通用 UI 状态收集           | `common_ui_shell.R` | `graphics_collect_axis_range_config()`、`graphics_collect_axis_tick_config()`、`graphics_collect_time_axis_config()`                                                                                                                                                                            | server 端若需收集上述 common UI 的值，应优先复用配套收集函数，避免模块内重复拼装输入解析                                                                                                                                                                                                             |
| 图形尺寸解析               | `graphics_common.R` | `graphics_px_to_in()`、`graphics_in_to_px()`、`graphics_scale_export_height()`、`resolve_plot_size_config()`、`graphics_collect_size_config()`、`graphics_apply_canvas_frame()`                                                                                                                    | 静态图、交互图、导出尺寸与画布边框/页面距统一从 common 解析；默认保持前端像素尺寸与导出英寸尺寸同步，模块内不得各自硬编码三套尺寸或手写导出高度换算                                                                                                                                                                                    |
| 经典坐标轴线段              | `graphics_common.R` | `graphics_add_classic_axis_segments()`、`graphics_apply_axis_style()`                                                                                                                                                                                                                          | 需要自绘经典轴线或箭头轴线时，优先复用 common 线段拼装函数，避免模块继续复制 `annotate("segment") + lineend = "square"` 逻辑                                                                                                                                                                          |
| 图形说明文字               | `graphics_common.R` | `graphics_mapping_caption_line()`、`graphics_compose_caption()`、`graphics_append_bottom_caption()`                                                                                                                                                                                             | caption 统一由 common 拼接，禁止模块内再拼第二套底部说明逻辑                                                                                                                                                                                                                            |
| 元数据标签与类型             | `data_metadata.R`   | `metadata_get_var_label()`、`metadata_get_var_type()`、`metadata_build_column_choices()`、`metadata_attach_to_data()`                                                                                                                                                                            | 标签解析顺序固定为 `override > metadata表 > 列label > var_name`；元数据变更后必须重新回写到数据对象                                                                                                                                                                                            |
| 元数据底层推断              | `data_metadata.R`   | `metadata_determine_var_type()`、`metadata_coerce_var_data()`、`metadata_safe_numeric_range()`                                                                                                                                                                                                  | 字符变量低基数判定与日期/数值转换规则统一由 common 维护，子模块不得各写一套推断逻辑                                                                                                                                                                                                                    |
| 统计格式化与复现模板           | `analysis_format.R` | `format_p_value_regression()`、`format_regression_stat()`、`build_repro_code_template()`                                                                                                                                                                                                        | 回归统计值、缺失占位符、复现代码模板统一走 common，禁止模块各自维护格式                                                                                                                                                                                                                           |
| 图形复现代码               | `graphics_repro.R`  | `graphics_quote_value()`、`graphics_quote_vector()`、`generate_graphics_repro_code()`                                                                                                                                                                                                           | 图形复现代码输入必须来自 committed 状态快照；新增图形类型时必须补 common 入口分支                                                                                                                                                                                                                |
| 表格样式与导出              | `table_export.R`    | `format_p_value_ama()`、`normalize_footnotes()`、`extract_table_dataframe()`、`apply_sci_gt_style()`                                                                                                                                                                                             | P 值显示、脚注清洗、gt 风格统一由 common 注入，禁止模块私有化导出样式                                                                                                                                                                                                                         |
| 图形导出                 | `plot_export.R`     | `build_plot_export_filename()`、`save_plot_export()`                                                                                                                                                                                                                                           | 导出文件名与支持格式统一由 common 维护；业务模块不得扩展不一致的私有导出参数                                                                                                                                                                                                                        |
| 存储抽象                 | `storage_backend.R` | `storage_backend_get()`、`storage_data_key_build()`、`storage_save_dataset()`、`storage_load_dataset()`、`storage_delete_dataset()`                                                                                                                                                               | 数据体读写删除统一走 common；业务模块不得拼接本地/S3 细节路径                                                                                                                                                                                                                              |

### 9.4 后续开发收紧声明

- 发现图例、尺寸、P 值、标签、元数据、导出、存储需求时，先搜索 `modules/common/` 是否已有对应抽象；已有则必须复用，不得平行新建实现。
- 若现有 common 抽象只差少量参数或枚举，应优先扩展 common 函数签名，不得在子模块包一层同义变体长期并存。
- 子模块允许存在的特例，只限表现层细节且必须在指南中明确说明边界；一旦第二个模块需要同类能力，必须上提到 common。
- 新增或改动 common 函数时，至少同步更新本指南中的“可复用函数清单”和相关测试，确保后续开发按同一契约收紧。
- 任务历史当前采用“共享模块先内嵌、一级导航后置”的演进策略：在统计图形/统计分析形成统一 `state/apply_state` 契约前，不直接迁移为左侧一级菜单。
- 任务历史载入的本质是“状态快照恢复”：当前由 `task_history.R` 解析 `state_payload`，再调用各业务模块的 `apply_state()` 回填控件；图形模块需尽量覆盖当前子模块全部参数的保存/回填，但是否自动重新生成结果，仍取决于业务模块自身的交互设计。
- 统一参数面板布局规范已按前端真实形态重置为“3 个顶层功能卡片 + 卡片内部子页签 + 独立结果区”，不允许再把 `数据与变量 / 图形与样式 / 输出与导出` 这 3 个顶层功能卡本身做成并列页签。
- 顶层功能卡固定为：
  - `数据与变量`：内部使用子页签承载 `核心映射` 与 `分组/分面/轨道/附加变量`。
  - `图形与样式`：内部使用子页签承载 `标题与说明 / 显示与坐标 / 图层样式 / 参考线与阈值`。
  - `输出与导出`：内部使用子页签承载 `尺寸与画布 / 导出参数`。
- 结果区固定为：
  - 动作条：`生成图形 / 下载图形`，统一放在结果区顶部，不放在参数区。
  - 结果页签：`静态图 / 交互图 / 数据`。
- “同层级功能卡片优先合并为页签组”这条规则，只适用于每个顶层功能卡片的**内部**，不适用于把顶层功能卡本身折叠成页签导航；只有高动态映射区、强业务算法区或 common 尚无等价抽象时，才允许临时保留卡片内部的非页签结构。

### 7.6 图形参数抽象类

- 第一批抽象类当前限定为“参数卡片层”，不触碰统计计算逻辑，也不直接改写各图形模块的数据准备函数。
- 第一批抽象类命名与职责如下：
  - `graphics_column_mapping_panel_ui()`：承载单列、多列、可选分组列、可选分面列等“数据列映射”控件；适用于生存图、蜘蛛图、泳道图、瀑布图、森林图、热图、相关图。
  - `graphics_time_axis_panel_ui()`：承载时间单位换算、时间范围、刻度步长等“时间轴”控件；适用于生存图、蜘蛛图、泳道图以及后续所有时间序列图。
  - `graphics_export_panel_ui()`：承载导出尺寸、DPI、格式等“输出设置”控件；旧模块可兼容保留生成按钮，但迁移到新规范时应关闭内置生成按钮，由结果区动作条承载执行动作。
  - `graphics_output_action_bar_ui()`：承载结果区顶部的 `生成图形 / 下载图形` 动作条；适用于所有迁移到新规范的统计图形模块。
- 抽象类的接入顺序要求：
  - 先抽共享 UI 组件，再选择 2 到 4 个代表性模块接入验证。
  - 同一抽象类在至少两个模块中稳定复用后，才允许继续向更多模块推广。
  - 抽象类只统一“参数形态”和“布局结构”，不强制统一字段命名；模块级语义差异仍由传入 spec 描述。
- 当前首批验证模块：
  - 列映射块：蜘蛛图、泳道图、热图、相关图。
  - 时间轴块：蜘蛛图、泳道图。
  - 导出块：蜘蛛图、泳道图、热图、相关图。
- 动态事件映射、分组颜色映射、复杂列显示配置等高动态区块暂不纳入第一批抽象类；这类能力需在第二批以“叠加点层/标记层映射组件”单独抽象。
- 对泳道图这类高动态模块，任务历史恢复必须采用“先重建 choices，再回填列字段，最后回填动态映射行”的分阶段恢复策略；不得直接依赖通用全量 `input_state` 回填，以免造成 `selectizeInput` 无法展开或 choices 失效。
- 第二批抽象类当前进入字段定义层第一版：在 `graphics_dynamic_mapping_rows_panel_ui()` 与 `graphics_dynamic_mapping_fields_ui()` 之外，继续引入共享的“叠加点层字段 spec 构造 helper”，用于统一每行字段定义、标签与输入类型；首个接入场景为泳道图事件映射，但语义上不局限于泳道图。当前共享层负责“动态行结构、字段渲染与字段定义模板”，候选列刷新、样式分配与业务含义仍保留在各业务模块。
- “事件”在当前图形抽象中的统一语义应理解为“叠加点层/标记层”，本质上是给主图额外叠上一层或多层 `geom_point`/`geom_text` 数据映射；后续可直接复用于泳道图事件点、蜘蛛图测量点/末次标记、瀑布图符号层，以及组合图中的散点层配置。
- 除叠加点层之外，当前其它已识别且值得继续收敛的公共块包括：
  - `显示与图例块`：蜘蛛图 `show_points/show_end_labels`、泳道图 `show_legend/auto_mapping_caption`、瀑布图 `show_symbols/show_legend` 语义接近，可继续抽象为“显示开关 + 图例位置 + 自动脚注”组合卡片。
  - `文本与标签块`：蜘蛛图末次标签、泳道图事件标签、瀑布图受试者标签与图例标题，本质都是点层/条层的文本标注控制。
  - `符号与样式块`：泳道图事件点 shape/color、瀑布图 `symbol_by`、生存图删失点 shape，本质都是图上标记层的视觉编码控制。
- `文本与标签块` 当前进入共享抽象第一版：先统一主标题、副标题、脚注、轴标签、图例标题这类静态文本输入；标签避让、末次标记位置、事件点文本布局等依赖几何计算的行为，暂不进入 common 层。
- `符号与样式块` 当前进入共享抽象第一版：先统一调色板、默认颜色、默认大小、符号形状选择、图例层标题、样式脚注与随机种子这类视觉编码输入；按分组分别指定颜色/符号、删失点绘制算法、轨道色块渲染等仍保留在各业务模块。
- `按组样式映射块` 当前进入共享抽象第一版：先统一“随机且不重复 / 单一指定 / 分别指定”的模式枚举、单一指定控件和分别指定面板外壳；具体每组颜色/符号值仍继续复用 `graphics_group_symbol_controls_ui()`，业务模块只负责提供 levels、默认值与取值后处理。
- `配色与布局块` 当前进入共享抽象第一版：先统一调色板、透明度、线/柱宽、点大小、默认颜色与基础版式数值输入这类静态视觉控制；分组色阶推断、轨道/条带特殊布局、辅助线算法与轴刻度推断仍保留在各业务模块。
- `坐标与比例块` 当前进入共享抽象第一版：先统一刻度数量、刻度步长、字号、宽高占比、线宽/点大小等静态数值输入；时间轴语义、坐标变换、辅助线算法和自动刻度推断仍保留在各业务模块。
- `参考线与阈值块` 当前进入最小共享壳阶段：只统一显示开关、阈值输入容器、颜色与标签输入的面板结构；参考线收集、临床阈值语义、`annotate()` 文本摆放与实际绘图算法仍保留在各业务模块。
- 当前已落地的抽象块都必须遵循“归纳收紧”原则：
  - `列映射块`：只负责字段选择结构；字段类型推断、默认列猜测和数据清洗不下沉到 UI common。
  - `时间轴块`：只负责单位、范围、步长；时间变量语义和派生刻度算法不下沉到 UI common。
  - `导出块`：只负责尺寸/格式/DPI；导出文件命名、图对象拼装和设备选择不下沉到 UI common。
  - `显示与图例块`：只负责显示开关、图例位置、脚注入口；图例锚点计算和多图例拼接不下沉到 UI common。
  - `文本与标签块`：只负责静态文本输入；标签避让和几何布局不下沉到 UI common。
  - `符号与样式块`：只负责静态视觉编码输入；样式映射算法不下沉到 UI common。
  - `按组样式映射块`：只负责模式枚举与 UI 结构；每组具体值与后处理仍留在模块内。
  - `叠加点层/标记层映射块`：只负责行结构、字段渲染与字段定义模板；候选列刷新、图层语义和绘图行为不下沉到 UI common。
  - `配色与布局块`：只负责静态配色和版式输入；色阶推断、条带布局和绘图几何行为不下沉到 UI common。
  - `坐标与比例块`：只负责静态数值比例输入；坐标变换、自动刻度和统计语义不下沉到 UI common。
  - `参考线与阈值块`：只负责阈值 UI 壳与静态输入；参考线语义、标签定位和绘图算法不下沉到 UI common。
- 模块代码收紧规则：
  - 已有 common 卡片能完整覆盖的 UI 面板，业务模块必须直接调用 common，不得继续保留同语义 `panel panel-default` 手写结构。
  - 模块级 helper 只有在承担 `fields/spec` 构造、候选列推断、状态恢复顺序或绘图语义桥接职责时才允许保留。
  - 纯转发 wrapper、只改标题不改语义的同义 helper、以及仅包一层 `tagList/panel` 的重复结构必须删除。
  - 无法立即收紧的残留面板，需满足至少一条前提：依赖高动态条件 UI、依赖业务算法、或当前 common 尚无等价抽象；后续继续分批收敛。
- 第三轮收紧后的残留面板边界：
  - 允许继续保留的典型面板：`参考线与阈值`、`临床线/RECIST 线`、高动态 `uiOutput` 映射组、依赖数据 levels 即时推断的控制块。
  - 若 `参考线与阈值` 只剩静态输入外壳，则应优先切换为 common 最小共享壳；仅当其与算法或高动态联动紧耦合时才允许保留模块内手写结构。
  - 已要求直接切换 common 的典型面板：核心变量映射、显示与图例、文本与标签、配色与布局、坐标与比例、普通排序与显示、普通轨道与缺失值。
- 阶段性收口清单（代表模块）：
  - `spider_plot.R`：普通设置型面板已全部切换到 common；剩余 raw panel `0`。
  - `waterfall_plot.R`：普通设置型面板已全部切换到 common；剩余 raw panel `0`。
  - `swimmer_plot.R`：普通设置型面板已全部切换到 common；剩余 raw panel `0`。
  - `已统一面板`：核心变量映射、显示与图例、文本与标签、配色与布局、坐标与比例、符号与样式、按组样式映射、参考线与阈值最小共享壳、普通排序与显示、普通轨道与缺失值、动态事件变量组逐行壳。
  - `暂保留面板`：依赖即时 levels 推断的动态控制块、与绘图算法强耦合的业务配置。
  - `下一轮优先级`：从“继续清 raw panel”转为“清理模块内仍可下沉的 spec/helper 与动态控制桥接层”，优先检查泳道图与瀑布图中的动态控制 helper 是否还能继续压薄。
- 子模块逐个排查优化当前进度：
  - `spider_plot.R` 第一轮：新增 committed 参数快照，将时间单位换算、Y 轴刻度/百分比标签、线条样式、点层、末次标签、RECIST 参考线、分面、标题图例以及静态图/交互图/导出尺寸统一改为只读取点击“生成图形”时捕获的参数；避免生成后继续修改时间单位、图例位置、点层、尺寸模式或导出尺寸导致已生成结果与当前面板值漂移。
  - `spider_plot.R` 第二轮：继续做 UI 语义收口，将“Y轴显示百分比”明确为“Y轴标签按百分比格式显示”，并补充说明其只影响标签/tooltip 格式；将“补充基线点(time=0, chg=0)”明确为“为每条轨迹补充基线原点(time=0, value=0)”；将“显示末次标签”明确为“显示每条轨迹末次受试者标签”，避免用户把末次标签误解成末次数值或时间标签。
  - `spider_plot.R` 第三轮：继续做 UI 归类收紧，将 `图形与样式` 顶层功能卡片内部整理为 `标题与说明 / 显示与坐标 / 图层样式 / 参考线与阈值` 子页签；其中“显示与坐标”统一承载图例、坐标轴样式、时间轴、Y轴格式与字号，“图层样式”承载点层开关、末次标签、补基线原点以及线型、调色板、线宽透明度和点大小，避免文本、坐标、图层样式继续混放。
  - `spider_plot.R` 第四轮：按统一布局规范拆分参数区与结果区职责，保留 `输出与导出` 顶层功能卡片，并在其内部拆成 `尺寸与画布 / 导出参数` 子页签；结果区顶部统一使用 `graphics_output_action_bar_ui()` 承载 `生成图形 / 下载图形`，避免参数区继续承载执行动作。
  - `spider_plot.R` 第五轮：按前端真实结构回正为 `数据与变量 / 图形与样式 / 输出与导出` 3 个独立顶层功能卡片，其中 `数据与变量` 内部收敛为 `核心映射 / 分组/分面/附加变量` 子页签；结果区固定为动作条 + `静态图 / 交互图 / 数据` 结果页签，作为当前首个正确遵守“顶层卡片 + 卡片内页签 + 独立结果区”规则的样板模块。
  - `spider_plot.R` 当前剩余未知优先限定在统计/业务概念边界：日期型时间轴当前按每位受试者最早日期换算为相对天数，再按 `time_unit` 转成周/月/年；同一受试者在同一时间点若有多条记录，当前取 `value_var` 的均值；`add_baseline_zero` 当前为展示完整轨迹可选补原点，不代表原始观测存在基线记录；`show_recist` 当前只负责视觉参考线，不直接输出 RECIST 分层结论；`show_end_labels` 当前固定显示受试者ID，不显示末次数值或时间。若这些口径与业务预期不同，应视为概念决策而不是实现缺陷。
  - `swimmer_plot.R` 第一轮：补齐动态样式任务历史重现，将泳道分别指定颜色、轨道展示方式、轨道颜色映射、事件组颜色/符号模式及其分别指定值纳入 `extra_state`，并在动态 UI 刷新后分阶段回填。
  - `swimmer_plot.R` 第二轮：收紧 UI 分类与文案边界，明确“轨道默认展示方式”仅作用于新选轨道默认值，“事件总图例标题”作用于事件整体图例层，“轨道总图例标题”只作用于下方分组轨道区；同时补充缺失值/版式影响范围说明。
  - `swimmer_plot.R` 第三轮：将主图、事件层、下方轨道区、自绘事件图例、底部脚注与静态图高度统一改为只读取点击“生成图形”时捕获的 committed 参数快照；生成后修改线宽、标题、图例位置、轨道占比、缺失值文本或事件样式，不再让已生成结果与当前面板值发生实现漂移。当前剩余未知优先限定为统计/业务概念边界，而不是 UI/状态链路问题。
  - `swimmer_plot.R` 第四轮：继续收紧已确定的语义文案，将排序中的 `end_desc/end_asc` 明确为“泳道终点”而非原始结束日期，并将 `track_rel_height` 的 UI 文案改为“下方轨道区占比”，明确其影响的是主图与下方轨道区的相对高度，不是数据表页签高度。
  - `swimmer_plot.R` 第五轮：修复事件映射控件恢复时序，在任务历史/动态 UI 回填期间临时优先读取 `event_ui_state`，等回填完成后再切回当前 `input`；避免事件时间、事件类型、事件标签和事件组样式面板因为残留输入抢占而出现“选择未正确载入”。
  - `swimmer_plot.R` 第六轮：继续做 UI 归类收紧与恢复补强，将“轨道与排序”改成“轨道变量与排序”，把样式页签细化为“标题与说明 / 显示与坐标 / 事件图例与样式 / 泳道颜色 / 轨道区与版式”；同时取消 `tracks` 的默认推荐变量，避免未确认业务字段自动进入下方轨道区，并对关键动态 `uiOutput` 显式关闭 hidden suspend，修复“需手动展开配置后再次生成才生效”的恢复时序问题。
  - `swimmer_plot.R` 第七轮：按前端真实结构回正为 `数据与变量 / 图形与样式 / 输出与导出` 3 个独立顶层功能卡片；其中 `数据与变量` 内部整理为 `核心映射 / 分组/分面/轨道/附加变量`，`图形与样式` 内部对齐为 `标题与说明 / 显示与坐标 / 图层样式 / 参考线与阈值`，结果区固定为动作条 + `静态图 / 交互图 / 数据`，其中“数据”页签内再分 `泳道数据 / 事件数据 / 分组轨道数据`，只调整 UI 编排与职责边界，不改任务历史恢复和绘图算法。
  - `waterfall_plot.R` 第一轮：对折叠配置盒中的高动态控件补 hidden suspend 保护，将柱颜色映射、符号分组映射、轨道展示方式和轨道颜色映射统一设为隐藏时继续恢复；同时取消 `tracks` 默认自动推荐变量，并把“排序和显示”收紧为“排序与轨道”，将 `track_rel_height` 文案改为“下方轨道区占比”，明确其影响的是主图与下方轨道区的相对高度，不是表格页签高度。
  - `waterfall_plot.R` 第二轮：新增 committed 参数快照，将主图柱宽/边框/图例、符号文本映射、RECIST 线与标签、轨道区布局、缺失值文本和底部脚注统一改为只读取点击“生成图形”时捕获的参数；静态图高度也改为优先跟随 committed 轨道区设置，避免生成后继续修改相关控件导致前端静态图或导出高度与已生成结果漂移。
  - `waterfall_plot.R` 第三轮：继续做 UI 语义收口，将“柱符号分组”明确为“柱顶符号文本分组”，将“Y轴默认显示百分比”明确为“Y轴标签按百分比格式显示”，并补充说明其只影响标签格式；同时把 `legend_title` 收紧为主图柱分组图例标题，把 `track_legend_title` 收紧为下方轨道区总图例标题，避免主图与轨道区图例语义混淆。
  - `waterfall_plot.R` 第四轮：将左侧 `数据映射` 区内部原本并列的 `核心变量映射 / 排序与轨道 / 阈值与临床线` 三块同层功能卡改为并列子页签，继续落实“同层功能卡片优先合并为页签组”规则；本轮只调整页签容器与布局编排，不改变排序方向、轨道展示方式、RECIST 阈值或绘图算法。
  - `waterfall_plot.R` 第五轮：按前端真实结构回正为 `数据与变量 / 图形与样式 / 输出与导出` 3 个独立顶层功能卡片；其中 `数据与变量` 内部整理为 `核心映射 / 分组/分面/轨道/附加变量`，`图形与样式` 内部对齐为 `标题与说明 / 显示与坐标 / 图层样式 / 参考线与阈值`，结果区固定为动作条 + `静态图 / 交互图 / 数据`，其中“数据”页签内再分 `瀑布数据 / 分组轨道数据`，只调整 UI 编排与职责边界，不改 committed 参数、任务历史恢复和绘图算法。
  - `waterfall_plot.R` 当前概念口径已确认：重复 `subject_id` 时保留第一条记录，并通过告警明确后续排序、轨道区和导出结果都基于保留后的记录；排序继续仅按最终保留的 `value_var` 从低到高/从高到低排列；`show_recist` 与阈值标签继续只负责视觉参考线，不直接输出 RECIST 分层结论；`missing_display_mode` 继续只影响轨道区与数据表展示，不改主图柱值；`use_percent_label` 继续只影响 Y 轴标签格式，不重新换算原始变化值。
  - `survival_analysis.R` 第一轮：任务历史显式纳入 `strata_labels` 重现；`数据映射` 与 `标题/坐标轴` 先切换到 common 卡片；UI 文案中将“删失值定义”收紧为“状态变量编码含义”，明确其影响的是生存对象构造而非原始数据。
  - `survival_analysis.R` 第二轮：将 `km_show_censor`、`plot_title`、`plot_caption`、`plot_xlab`、`plot_ylab` 纳入 `committed_params()`，消除“点击生成后又改控件但图局部漂移”的提交态不一致；同时把“曲线/删失点/风险表”和“统计标注与位置”重排为更清晰的参数分组。
  - `survival_analysis.R` 第三轮：将 `survival_report` 从 `graphics_state` 语义切回 `committed_params()`，并让 `show_median`、`show_stats` 同时约束主图与报告摘要，消除“主图关闭但报告仍显示”的实现不一致。
  - `survival_analysis.R` 第四轮：将“图例与文字”拆分为“图形与图例文字”和“风险表文字”，避免主图图例、统计标注、风险表字号混放；此轮属于 UI 分类收紧，不改变统计或绘图算法。
  - `survival_analysis.R` 第五轮：收紧统计语义文案，明确 `surv_median_line` 控制的是中位生存辅助线、`show_median` 控制的是中位生存文本标注、`show_stats` 控制的是 Log-rank 摘要且分层时附加 HR，`overall_group_label` 仅在未分层时生效。
  - `survival_analysis.R` 第六轮：移除 `base_surv_plot()` 中对 `input$time_range` 的提交态回退；在统计报告的方法解释中明确 HR 参考组；交互图默认标题改为中文，保持主图、交互图与报告的实现说明一致。
  - `survival_analysis.R` 第七轮：将 `数据映射 / 分析参数 / 样式主题` 三个主页签内部的同层普通功能卡进一步改为并列子页签，包括 `数据映射 / 处理与筛选`、`曲线、删失点与风险表 / 统计标注与位置`、`标题与坐标轴 / 图形与图例文字 / 风险表文字`；本轮只调整页签容器与参数编排，不改变生存对象构造、风险表算法、HR 计算或 committed 输出链路。
- `survival_analysis.R` 第八轮：按前端真实结构回正为 `数据与变量 / 图形与样式 / 输出与导出` 3 个独立顶层功能卡片；`数据与变量` 内部整理为 `核心映射 / 分组/分面/轨道/附加变量`，`图形与样式` 内部统一为 `标题与说明 / 显示与坐标 / 图层样式 / 参考线与阈值`，结果区固定为动作条 + `静态图 / 交互图 / 数据`，其中“数据”页签内再分 `数据表 / 统计报告`。后续已补一处导航容器修正：顶层 `图形与样式` 卡片不再直接把 helper 返回的 `tagList/list` 作为 `tabsetPanel()` 子项，而改为展开后的 `tabPanel` 集合，避免运行时出现 “Navigation containers expect ... tabPanel()” 报错；该修正只影响 UI 组合方式，不改 committed 输出链路与统计算法。
  - `survival_analysis.R` 暂不下沉内容：KM/COX 模型切换、HR 参考组逻辑、风险表算法、参考线绘制语义、分层标签的计算来源。
- `boxplot.R` 第一轮：将 `样式主题` 页签中的标题标签、线条点样式与配色设置改为并列子页签 `标题与标签 / 线条与点 / 配色`，作为轻量模块的页签化样板；本轮只调整参数编排，不改变箱线图映射、绘图逻辑、导出链路或任务历史契约。
- `boxplot.R` 第二轮：按统一模板回正为 `数据与变量 / 图形与样式 / 输出与导出` 3 个独立顶层功能卡片；结果区固定为动作条 + `静态图 / 交互图 / 数据`，对暂无实际控件的子页签保留空壳说明，只调整 UI 编排，不改箱线图绘制与导出逻辑。
- `heatmap.R` 第一轮：将 `样式主题` 页签中的标题标签、色板和格子文本显示设置改为并列子页签 `标题与标签 / 色板 / 格子与文本`，作为轻量模块页签模板的第二个样板；本轮只调整参数编排，不改变热图计算、聚类开关、导出链路或任务历史契约。
- `heatmap.R` 第二轮：按统一模板回正为 `数据与变量 / 图形与样式 / 输出与导出` 3 个独立顶层功能卡片；结果区固定为动作条 + `静态图 / 交互图 / 数据`，并把原 `标题与标签 / 色板 / 格子与文本` 归并到 `标题与说明 / 图层样式` 等统一子页签，不改热图计算、聚类与导出逻辑。
- `correlation_matrix.R` 第一轮：将 `样式主题` 页签中的标题标签、色板和格子文本显示设置改为并列子页签 `标题与标签 / 色板 / 格子与文本`，与 `heatmap.R` 对齐为同一轻量模块页签模板；本轮只调整参数编排，不改变相关系数计算方法、导出链路或任务历史契约。
- `correlation_matrix.R` 第二轮：按统一模板回正为 `数据与变量 / 图形与样式 / 输出与导出` 3 个独立顶层功能卡片；结果区固定为动作条 + `静态图 / 交互图 / 数据`，并把原 `标题与标签 / 色板 / 格子与文本` 归并到 `标题与说明 / 图层样式` 等统一子页签，不改相关矩阵计算与导出逻辑。
- `forest_plot.R` 当前结构盘点：暂不直接进入页签化代码改造。该模块仍同时存在 `panel panel-default/panel-primary` 旧式容器、`precalculated/raw_data` 双模式混排、右侧表格配置嵌套折叠面板，以及结果区旧版 `生成图形/下载图形` 动作入口；因此后续需先拆清“可直接页签化的普通参数块”和“应先迁到 common 或先做职责拆分的旧结构债务”，再进入正式重构。
- 任务历史保存/恢复要区分“业务输入”与“派生交互输入”：DT 行选择、列过滤、Plotly relayout/hover，以及 `config_tabs` 这类配置页签导航态都不得写入快照；恢复旧任务时若 payload 中仍含这些字段，common 层也必须跳过，避免回填时把表格/交互组件带入异常状态。

## 10. 数据、存储与规范

### 10.1 数据输入来源

| 入口      | 当前支持                                                   |
| ------- | ------------------------------------------------------ |
| 本地文件上传  | `.csv`、`.xlsx`、`.xls`、`.sas7bdat`、`.sav`、`.dta`、`.por` |
| 数据库加载   | 从 PostgreSQL 中按 workspace / folder / dataset 选择已登记数据集  |
| 服务器目录导入 | `database_manager.R` 支持按服务器绝对路径导入工作区                   |
| 批量导入    | `database_manager.R` 支持多文件批量保存                         |

### 10.2 存储架构

| 层级      | 当前实现                                                                           |
| ------- | ------------------------------------------------------------------------------ |
| 元数据     | PostgreSQL 表 `users`、`workspaces`、`workspace_memberships`、`folders`、`datasets` |
| 数据体     | 本地 `RDS` 文件或 S3 对象                                                             |
| 存储切换    | 通过 `STORAGE_BACKEND` 控制 `local` / `s3`                                         |
| S3 前置条件 | 必须安装 `aws.s3`，并设置 `STORAGE_S3_BUCKET`                                          |

### 10.2.1 当前数据接入边界

- `database_manager.R` 当前支持单文件上传、批量上传和服务器目录导入。
- 服务器目录导入要求输入部署机器或容器可见的绝对路径，不等同于浏览器用户电脑上的本地目录。
- 服务器目录导入只面向系统管理员开放；在多用户能力真正落地前，不应向普通用户开放该入口。
- 当前仓库尚未实现 ZIP 数据空间导入；文档与功能描述不得把该能力写成已支持。

### 10.2.2 多用户目标边界

- 当前已支持用户自注册，并保留系统管理员账号。
- 当前首期隔离粒度以“个人空间”为主，每个用户默认拥有独立数据空间边界。
- 架构上需预留后续按组织和项目扩展隔离的能力，但当前文档不得把组织/项目隔离写成既成事实。
- 数据权限首期落到 workspace 级别，再决定是否继续细化到 folder 或 dataset。
- 首次初始化时可通过环境变量预置管理员；若未预置，则首个注册用户自动成为管理员。

### 10.3 当前统计显示规范

| 项目       | 当前规则                                  |
| -------- | ------------------------------------- |
| P 值风格    | AMA 风格                                |
| 极小 P 值   | `<0.001`                              |
| 极大 P 值   | `>0.99`                               |
| 无法计算 P 值 | 显示为 `—`                               |
| 无法计算效应量  | 显示为 `—`                               |
| 效应量保留位数  | `HR / OR / Beta` 及其 95% CI 通常保留 2 位小数 |

### 10.4 回归变量约束

- 响应变量不得同时出现在预测变量中。
- 预测变量不得与 split、facet、model strata 重复。
- split 与 facet 不能相同。
- Cox 分析中的时间变量和状态变量不应进入协变量集合。
- 交互 P 值口径统一为“预测变量 × 亚组变量”的交互项检验，不用组内 P 值替代。

### 10.5 缺失值处理

- 模型拟合基于分析所需字段的 complete cases。
- 结果无法估计时，前端应返回可见错误或占位值，不做静默失败。
- 表格和导出层必须保持与前端同一占位口径。

## 11. 测试与质量保障

### 11.1 当前测试范围

`tests/` 目录当前已覆盖以下主题：

- 回归分析输入校验、稀疏数据和前后端一致性。
- 注册登录、密码摘要与 workspace 权限过滤辅助逻辑。
- 管理员入口、邮箱校验与文档边界守卫。
- 数据元数据一致性与标签映射。
- 生存分析中位生存时间、选择解析、view/committed 状态。
- 图形公共进度、图例/颜色覆盖与 Waterfall 符号选择。
- 计算层与渲染层解耦相关回归。
- Landing 文案、访问控制边界与导入入口文案守卫。
- 图形任务历史持久化守卫、analysis\_states 建表契约、以及 common UI 新增控件。

### 11.2 当前测试契约

- 新增功能或修改现有逻辑时，测试文件统一放在 `tests/`。
- 共享层改动至少要补一条可回归的最小测试。
- 图形或统计口径改动优先补“同口径断言”，避免只测 UI 是否渲染成功。
- `run_app_test.ps1` 依赖 `.env.test`；仓库当前提供 `.env.test.example` 作为测试环境变量模板。若数据库由 `docker-compose1.yml` 拉起，测试端口应使用 `55432`。
- `run_app_test.ps1` 启动前会读取 `SHINY_PORT`（未设置时默认为 `8109`）；若该端口已被占用，脚本会强制关闭占用进程后再拉起应用（且会妥善处理进程在检测后已自行退出的并发情况）。
- 当前仓库已补充 `.pre-commit-config.yaml` 与 `.lintr`，用于在提交前串联 `styler`、`lintr` 与 `tests/` 守卫；`install_dependencies.R` 也已纳入 `jsonlite`、`lintr`、`styler`、`shinytest2` 开发依赖入口。

### 11.3 当前缺口

- 尚未形成完整的部署文档自动校验。
- 文档与实现一致性巡检目前仍以轻量守卫脚本为主，尚未形成统一测试入口。
- `MMRM`、`MI` 等占位菜单没有对应测试，因为尚未落地。

## 12. 当前未落地项与路线图

### 12.1 已确认但未落地

| 项目            | 当前状态 | 说明           |
| ------------- | ---- | ------------ |
| MMRM          | 占位   | 菜单可见，分析链路未实现 |
| 多重填补（MI）      | 占位   | 菜单可见，分析链路未实现 |
| Kubernetes 部署 | 未提供  | 仓库中暂无相关编排或清单 |

### 12.2 下一步优先方向

1. 继续增强共享层，减少图形子模块与回归子模块的重复逻辑。
2. 把高复杂图例、符号和样式配置进一步抽象成可复用组件，并继续把森林图、组合图及轻量图形模块切到统一画布/尺寸容器。
3. 为部署文档、运行入口和关键环境变量增加自动检查。
4. 在现有个人隔离与 workspace 权限基础上，评估组织级、项目级隔离、邮箱验证与共享协作模型。
5. 在高级方法真正落地后，再补充对应章节与测试。
6. **UI 状态隔离与响应式重构**：优化图形模块（如森林图）动态渲染配置项时的循环依赖问题，大规模采用 `isolate()` 技巧防止输入过程中的焦点丢失和异常跳出。
7. **通用 UI 组件 (Common UI Components) \[已落地]**：已继续以 `common_ui_shell.R` 作为真实承载文件，新增 `graphics_axis_range_controls_ui()`、`graphics_axis_tick_format_controls_ui()`、`graphics_time_axis_settings_ui()` 及配套收集函数；森林图、蜘蛛图、泳道图已开始接入这套高阶组件，持续减少模块私有 UI 冗余。
8. **测试工具链引入 \[已落地]**：已引入 `.pre-commit-config.yaml`、`.lintr`、`styler`、`lintr`、`shinytest2` 依赖入口，并通过 pre-commit 串联格式化、静态检查与 `tests/` 守卫；复杂浏览器级交互测试仍保留给后续 `shinytest2` 场景补齐。
9. **分析参数与UI状态持久化 \[已落地增强中]**：已新增 PostgreSQL `analysis_states` 表，并在 `auth_ensure_schema()` 与 `postgres/init.sql` 双处同步建表；任务历史 UI 现抽离为共享 `task_history` 模块，并先嵌入统计图形页，支持按用户保存/加载图形子模块完整参数、UI 状态、模块类型与用户 note，底层将状态序列化为 JSON 存储，并展示最近任务列表与删除操作。当前保存的是状态快照而非结果对象；载入时由各图形模块按 `state/apply_state` 契约恢复字段。当前 workspace 为空时保存为个人任务；在统计图形与统计分析形成统一契约前，暂不升为左侧一级菜单，统计分析模块接入留待下一轮扩展。
10. **精细化图形样式控制 \[已落地首期]**：已将经典坐标轴线段抽到 `graphics_add_classic_axis_segments()`，并把时间轴单位换算/步长配置继续收敛到 common UI；泳道图与蜘蛛图已开始复用统一时间轴控件，森林图也已收敛坐标范围与刻度格式。其余时间序列图形继续按同一公共契约扩展。

## 13. 研发治理约束

### 13.1 架构红线

- 路由层保持轻量，不在 `statistical_analysis.R` 与 `statistical_graphics.R` 内堆叠复杂计算。
- 公共统计口径优先沉淀到 common 层，不允许多个子模块各自维护变体。
- 导出结果与页面结果保持同一语义、同一字段、同一排序逻辑。
- 新需求落地前先检索 common 抽象；若 common 已覆盖，不允许在子模块重写同义逻辑。

### 13.2 文档与测试红线

- 改实现必须同步改文档；改统计口径必须同步补测试。
- 新增测试文件统一进入 `tests/`，不新建 `test/` 目录。
- 共享层变更优先补回归测试，再做模块级功能扩展。
- 共享层新增或扩展函数时，必须同步更新 `PROJECT_GUIDE.md` 中的共享函数清单与使用约束。
- 图形模块如涉及尺寸、导出比例、页面距、画布边框或用户可配置辅助线，必须优先扩展 `graphics_common.R` / `common_ui_shell.R`，禁止在子模块单独维护另一套换算、容器样式或 `geom_hline/geom_vline` 拼装逻辑。

### 13.3 共享层优先级

1. `data_metadata.R` / `data_filter.R`：保证变量标签、类型、筛选逻辑一致。
2. `analysis_shared.R` / `analysis_format.R`：保证统计表口径与显示一致。
3. `graphics_common.R` / `common_ui_shell.R`：保证图形模块体验一致。
4. `storage_backend.R`：保证数据读写介质切换时业务模块无感。

## 14. 交付与运营建议

### 14.1 交付形态建议

- 单机研究环境优先使用 `run_app.R`。
- 团队联调优先使用 `docker-compose.local.yml`。
- 生产或演示环境优先使用 `docker-compose.server.yml`，并通过 Landing 页承接 `/app/`。

### 14.2 运维关注点

- 先确认 PostgreSQL 可用，再排查应用加载问题。
- 证书路径、数据根目录和镜像可用性是生产部署的前三个前置条件。
- 若采用离线部署，必须提前准备应用镜像及基础环境镜像。

### 14.3 当前文档维护建议

- `PROJECT_GUIDE.md` 负责“全局开发事实”。
- 部署细节文档应与 `deploy/alicloud/README.md` 同步清理，避免路径和流程分叉。
- 后续可新增轻量文档巡检脚本，校验关键文件、compose 文件和入口 URL 是否与本文档一致。
- 图形模块后续新增输出样式时，应优先检查是否已接入统一画布配置；尚未切换到公共画布层的模块，需在下一轮收敛中补齐页面距、导出高度同步与居中容器。
- Landing 页文案与视觉改版时，应同步核对平台名与应用名层级、入口 URL、未落地项说明和功能边界，避免再次出现实现与对外叙事脱节。
- 主 Landing 改版时优先检查是否仍然足够精简，避免把 AutoTFL 详细内容重新堆回 `index.html`。
- Landing 页如强调 AutoTFL，应优先说明“能产出什么”“如何开始使用”和“从哪里进入”，避免引入技术栈宣传、兼容性提示或抽象分层说明；应用页头与浏览器标题应统一为 `Hamster Analysis · AutoTFL`。

***

文档校验基线：2026-04-14\
校验范围：仓库结构、核心模块、部署编排、共享层、测试目录\
状态说明：本文仅记录当前仓库已实现或已明确暴露的能力
