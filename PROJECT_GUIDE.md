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

| 名称 | 当前含义 | 备注 |
| --- | --- | --- |
| Hamster Analysis | 平台级命名 | 当前用于 Landing 页与部分部署资源，承载平台入口语义 |
| AutoTFL | 当前核心应用名 | 当前已上线并由 Hamster Analysis Landing 页承载入口的主应用 |
| Hamster Analysis · AutoTFL | 当前应用页头与浏览器标题 | 已用于 `app.R` 的 dashboardHeader 与浏览器标题 |

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

| 分层 | 当前使用 |
| --- | --- |
| UI 与交互 | Shiny、shinydashboard、shinyjs、shinyBS、bslib、shinyWidgets、reactable、plotly |
| 数据处理 | dplyr、tidyr、purrr、stringr、readxl、haven、vroom、memoise |
| 统计分析 | survival、broom、gtsummary、rtables、tern、corrplot |
| 导出能力 | gt、flextable、officer、rmarkdown、pagedown、r2rtf |
| 基础设施 | PostgreSQL、Redis、Nginx、Docker Compose |

### 2.3 架构摘要

- 主入口为 `app.R`，负责加载依赖、source 模块、组装六大业务页签。
- 当前 `app.R` 已接入应用内自注册、登录、退出与会话态用户上下文。
- 登录与注册当前已拆分为两个独立页面，并在注册阶段采集邮箱用于后续协作授权扩展；认证主体区域已抽到 `auth_manager.R`。
- 当前用户信息与退出入口稳定显示在侧边栏卡片中，不再依赖顶栏动态渲染。
- `modules/` 目录采用“路由层 + 子模块 + common 共享层”结构。
- 数据元数据走 PostgreSQL；数据体通过 `modules/common/storage_backend.R` 落到本地目录或 S3。
- 图形与统计模块普遍采用“UI 输入层、公共校验/格式层、分析执行层、导出层”的分层方式。

### 2.4 六步主流程

| 步骤 | 模块 | 作用 |
| --- | --- | --- |
| 1 | `database_manager.R` | 管理 workspace / folder / dataset 元数据，并负责数据入库登记 |
| 2 | `data_preparation.R` | 上传、加载、筛选、预览、变量元数据整理 |
| 3 | `exploratory_analysis.R` | 快速探索性图形分析 |
| 4 | `statistical_analysis.R` | 统计分析总入口与结果导出 |
| 5 | `statistical_graphics.R` | 统计图形总入口与图形导出 |
| 6 | `tables.R` | 预设 Table / Figure / Listing 输出 |

## 3. 运行入口与部署形态

部署细节、目录树、挂载关系、环境变量和分场景操作步骤统一维护在 `DEPLOYMENT_GUIDE.md`；本章仅保留部署矩阵与边界摘要。

### 3.1 运行矩阵

| 场景 | 入口 | 访问方式 | 说明 |
| --- | --- | --- | --- |
| 本地开发直跑 | `run_app.R` | 默认 `127.0.0.1:8109` | 自动检查依赖并直接运行 `app.R` |
| 开发编排 | `docker-compose.yml` | `http://localhost` | Nginx 直接反代 Shiny 根路径，不带 Landing 页 |
| 本地联调 | `docker-compose.local.yml` | `http://localhost:8080` | 含 Landing 页，应用入口为 `/app/` |
| 服务器生产 | `docker-compose.server.yml` | `https://<domain>` | HTTPS + Landing 页，应用入口为 `/app/` |

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

| 变量 | 默认值 | 用途 |
| --- | --- | --- |
| `DB_PASSWORD` | 无安全默认值，部署时必须覆盖 | PostgreSQL 连接密码 |
| `DATA_ROOT` | `/data/hamster-analysis` | 生产持久化根目录 |
| `CERT_ROOT` | `/etc/hamster-analysis/certs` | 证书目录 |
| `SSL_CERT_FILE` | `kyyin.xyz.pem` | 证书文件名 |
| `SSL_KEY_FILE` | `kyyin.xyz.key` | 私钥文件名 |
| `APP_STORAGE_ROOT` | `/app/data_storage` | 容器内数据体挂载目录 |
| `APP_ADMIN_USERNAME` | 空 | 可选的预置管理员用户名 |
| `APP_ADMIN_EMAIL` | 空 | 可选的预置管理员邮箱 |
| `APP_ADMIN_PASSWORD` | 空 | 可选的预置管理员密码 |

### 3.6 当前访问控制边界

- 当前仓库已实现应用内自注册、登录、退出与 workspace 级权限控制。
- 登录支持用户名或邮箱；注册阶段会校验邮箱格式，但当前尚未接入真实邮箱验证或邮件发送。
- 当前用户信息与退出入口稳定显示在侧边栏卡片中；普通用户的权限管理快捷入口也合并在该卡片内。
- 未登录状态下只渲染登录/注册入口，不渲染业务工作台侧边栏。
- 非管理员用户默认按个人空间隔离，只能看到自己拥有或被授权的 workspace。
- 系统管理员可访问全部 workspace，并独占服务器目录导入入口。
- 当前已提供管理员操作入口；workspace、membership、invite 与 owner 迁移能力统一下沉到 service 层。
- workspace 创建与删除也统一通过 `account_service.R` 收口，数据库管理模块不再直接拼装 owner / membership 初始化逻辑。
- 普通用户可对自己拥有的数据空间进行权限管理，且授权、撤销与 owner 迁移统一通过邮箱输入完成。
- 管理员页保持独立系统入口，不并入侧边栏用户卡片；系统级负责人绑定、协作授权与账号状态调整继续集中在管理员页。
- 权限预览表统一改为业务中文列名；数据库管理页按“空间与目录 / 上传与导入 / 结构总览”三段重组。
- 当前尚未实现组织级、项目级隔离，也未提供更细粒度的 folder 或 dataset 权限模型。

### 3.7 当前免责声明

- 当前工具暂不负责数据安全；数据传到服务端后不保证安全，请使用方自行妥善保管数据。
- 如需更高的数据隔离与环境保障，应优先采用独立部署服务，而不是把当前公共部署形态描述为安全托管服务。
- 可通过环境变量预置管理员用户名、邮箱和密码；若未预置，则首个注册用户会自动成为系统管理员。

### 3.8 当前阶段风险与优化建议

- 技术风险：当前权限主边界仍在 workspace 级别，`viewer` / `editor` 对数据写操作的差异尚未完全落实到所有模块。
- 维护风险：邮箱邀请支持未注册用户占位，但尚未提供邀请过期、撤回审计与邮箱真实性校验；普通用户入口与管理员入口的交互规范需要持续同步。
- 项目风险：owner 自助授权已开放给创建者，后续若扩展共享协作，需要同步补齐审计日志与异常回滚策略。
- 立即可做：补充 service 层数据库集成测试，覆盖授权、撤销、owner 迁移、invite 领取与 workspace 删除链路，并验证阶段二数据库管理新布局的可用性。
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

| 文件 | 当前职责 | 关键说明 |
| --- | --- | --- |
| `app.R` | 加载依赖、source 模块、定义 dashboard UI 与 server | 六个侧边栏页签都在这里挂载 |
| `run_app.R` | 本地启动脚本 | 先执行依赖检查，再启动 `app.R` |
| `install_dependencies.R` | 依赖安装脚本 | 支持本地离线仓库优先、在线镜像回退 |

### 5.2 业务模块

| 模块 | 主要职责 | 当前状态 |
| --- | --- | --- |
| `database_manager.R` | 管理工作区、文件夹、数据集，支持单文件上传、批量上传、按服务器目录导入 | 已实现 |
| `data_preparation.R` | 上传或从数据库加载数据，做高级筛选、列选择、数据预览和概览卡片 | 已实现 |
| `exploratory_analysis.R` | 提供基础探索图形与变量映射交互 | 已实现 |
| `statistical_analysis.R` | 统计分析总入口，路由到描述性统计、回归、组间比较等子模块 | 已实现 |
| `statistical_graphics.R` | 图形总入口，路由到生存图、森林图、泳道图等子模块 | 已实现 |
| `tables.R` | 预设表格/图形/Listing 总入口 | 已实现 |

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

| 文件 | 功能 | 当前实现要点 |
| --- | --- | --- |
| `desc.R` | 描述性统计 | 基于 `gtsummary` 生成汇总表，支持总计列扩展 |
| `cox.R` | Cox 回归 | 使用 `survival::coxph`，支持 strata、split、列分组 |
| `logistic.R` | Logistic 回归 | 使用 `stats::glm(family = binomial())`，支持事件值映射 |
| `linear.R` | 线性回归 | 使用 `stats::lm`，支持多预测变量和列分组 |
| `anova.R` | 方差分析 | 连续变量组间比较 |
| `chisq.R` | 卡方 / CMH | 分类变量组间比较与分层检验 |

### 6.3 当前共享引擎

| 文件 | 核心职责 | 当前作用 |
| --- | --- | --- |
| `analysis_shared.R` | 回归公共校验、交互项 P 值计算、统一结果整理 | Cox / Logistic / Linear 共享核心 |
| `account_service.R` | 用户、workspace、membership 与数据入口服务封装 | 管理员入口与数据模块复用服务层 |
| `auth.R` | 注册、登录、密码摘要、权限过滤与管理员引导 | `app.R`、数据库管理、数据准备共享认证边界 |
| `auth_manager.R` | 登录/注册页面、认证交互与 loading 反馈 | 精简 `app.R` 并统一认证入口 UI |
| `workspace_access_manager.R` | owner 邮箱授权、撤销权限、invite 与 owner 迁移入口 | 用户自助管理自己拥有的数据空间权限 |
| `analysis_format.R` | 数值格式化、统计值格式化、复现代码模板 | 控制结果显示和导出文案 |
| `table_export.R` | `gt` 风格注入与导出辅助 | 统一表格样式与 P 值显示 |

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

| 文件 | 图形类型 | 当前说明 |
| --- | --- | --- |
| `survival_analysis.R` | Kaplan-Meier 生存曲线 | 支持静态图、交互图、风险表、统计报告和复现代码 |
| `forest_plot.R` | 森林图 | 用于回归结果或亚组一致性展示 |
| `correlation_matrix.R` | 相关矩阵图 | 支持相关性探索 |
| `boxplot.R` | 箱线图 | 用于组间分布比较 |
| `heatmap.R` | 热图 | 用于矩阵热区展示 |
| `combo_plot.R` | 组合图 | 复合图层展示 |
| `spider_plot.R` | Spider 图 | 肿瘤负荷/时间变化 |
| `swimmer_plot.R` | Swimmer 图 | 疗程轨迹与事件展示 |
| `waterfall_plot.R` | Waterfall 图 | 个体疗效下降/上升幅度展示 |

### 7.3 共享图形能力

| 能力 | 当前来源 | 说明 |
| --- | --- | --- |
| 尺寸解析 | `graphics_common.R` | 统一静态图、交互图和导出尺寸解析 |
| 图形通知 | `graphics_common.R` | 统一成功/失败提示 |
| 复现代码 | `graphics_repro.R` | 为图形模块生成可复现代码片段 |
| UI 壳层 | `statistical_graphics_ui/common_ui_shell.R` | 统一页签容器、导出控件、主按钮样式 |
| 导出 | `plot_export.R` | 图形导出辅助能力 |

### 7.4 生存分析当前实现口径

| 主题 | 当前实现 |
| --- | --- |
| 状态管理 | 采用 view state 与 committed state 分离，只有点击“生成图形”才提交分析参数 |
| 风险表 | 风险表主要用于静态图组合输出；交互页并不是“Plotly + 风险表”同页布局 |
| 分层标签 | 主图图例、删失图例、统计文本、风险表与数据表统一复用同一标签格式化链路；比较符号及原始值中的 `=`, `>=`, `<` 必须原样保留并可映射自定义标签 |
| 删失图例 | 交互图中的主图分组图例优先复用 `ggsurvplot` 默认图例能力，仅负责标题与标签定制；静态图则统一改为辅助图例方案：主图分组图例与删失图例都以独立辅助图例绘制，其中 Censor 图例在分层场景下使用 `Censor` 标题并按分组显示与曲线上实际删失点一致的形状和颜色。曲线上的删失点形状在所有分组中统一取自 `km_censor_shape`，不能因分组再次映射为圆形/三角等离散形状；静态图中主图分组图例固定在前、Censor 图例固定在后，且通过 common 的 inside-anchor/aux-legend 摆放抽象控制紧凑间距与定位，避免重复图例、原始 `变量=取值` 文本泄漏、颜色失配与 `Ignoring unknown labels` 警告 |
| P值格式 | Log-rank 与生存分析内联 P 值统一采用 AMA 风格：`<0.001`、`>0.99` 或三位小数，避免 `P=0.000` |
| 交互页 | 当前以交互主图和单独结果页签为主 |
| 尺寸配置 | 已接入统一尺寸接口，不在模块内写死静态/交互/导出尺寸 |
| 测试覆盖 | 已有选择解析、中位生存时间基线、view/committed 状态测试，并新增显示契约测试覆盖比较符号/等号标签、Cox 标签映射、删失图例颜色链路、辅助图例布局、删失符号一致性与 P 值格式 |

### 7.5 图例与样式当前状态

- Survival、Spider、Waterfall、Swimmer 已逐步接入 common 图例能力。
- Swimmer 保留事件图例的自绘特例，但标题解析与摆放逻辑应继续优先复用 common。
- Waterfall 与 Swimmer 的符号/颜色分别指定能力已经存在，但仍属于高复杂 UI，后续应继续抽象公共组件。

## 8. 预设图表实现

### 8.1 模块定位

- `tables.R` 统一管理临床研究常用模板。
- 当前既包含传统表格，也包含图形型输出，因此它是“预设输出总入口”，不是单纯的表格模块。

### 8.2 子模块清单

| 文件 | 类型 | 当前说明 |
| --- | --- | --- |
| `t_dm.R` | Table | 人口统计学和基线特征表 |
| `t_ae_soc_pt.R` | Table | 不良事件 SOC/PT 汇总 |
| `listing_general.R` | Listing | 通用审阅明细清单 |
| `ae_sidebyside.R` | Figure | AE 并列对比图 |

### 8.3 当前引擎边界

- `t_dm.R` 以 `gtsummary + gt` 为主。
- `t_ae_soc_pt.R` 依赖 `rtables / tern`。
- `listing_general.R` 依赖 `rlistings / r2rtf`。
- `ae_sidebyside.R` 走 `ggplot2` 图形分支，导出策略与表格分支不同。

## 9. 公共能力与共享层

### 9.1 公共文件清单

| 文件 | 当前职责 |
| --- | --- |
| `data_metadata.R` | 统一变量标签、类型推断、元数据回写 |
| `data_filter.R` | 统一筛选 UI / server 与变量过滤行为 |
| `analysis_shared.R` | 统一回归校验和结果组装 |
| `analysis_format.R` | 统一统计值、P 值、复现代码模板 |
| `graphics_common.R` | 统一图形变量筛选、尺寸和通知 |
| `graphics_repro.R` | 图形复现代码 |
| `plot_export.R` | 图形导出 |
| `table_export.R` | 表格导出与样式注入 |
| `storage_backend.R` | 本地 / S3 数据存储抽象 |

### 9.2 当前共享层原则

- 共享层优先维护“统计口径、格式、元数据、导出、存储”这类跨模块不应分叉的逻辑。
- 子模块遇到公共需求时先扩展 common，再决定是否保留少量局部特例。
- 修改共享层时必须同步检查回归模块、图形模块和导出路径是否受影响。

### 9.3 当前可复用函数清单

| 主题 | 文件 | 当前可复用函数 | 当前约束 |
| --- | --- | --- | --- |
| 图例标题与位置枚举 | `graphics_common.R` | `graphics_resolve_legend_title()`、`graphics_legend_position_choices()`、`graphics_legend_controls_ui()` | 图例标题统一走 `custom > fallback > default`；位置值只能来自 common 枚举，子模块不得自造私有位置字符串 |
| 图例锚点与辅助图例摆放 | `graphics_common.R` | `graphics_resolve_inside_anchor()`、`graphics_place_aux_legend()`、`graphics_apply_legend_theme()` | 图内锚点必须先归一化；辅助图例优先复用 common 摆放；隐藏图例统一使用 `"none"` |
| 图形尺寸解析 | `graphics_common.R` | `resolve_plot_size_config()` | 静态图、交互图、导出尺寸统一从 common 解析；模块内不得各自硬编码三套尺寸 |
| 图形说明文字 | `graphics_common.R` | `graphics_mapping_caption_line()`、`graphics_compose_caption()`、`graphics_append_bottom_caption()` | caption 统一由 common 拼接，禁止模块内再拼第二套底部说明逻辑 |
| 元数据标签与类型 | `data_metadata.R` | `metadata_get_var_label()`、`metadata_get_var_type()`、`metadata_build_column_choices()`、`metadata_attach_to_data()` | 标签解析顺序固定为 `override > metadata表 > 列label > var_name`；元数据变更后必须重新回写到数据对象 |
| 元数据底层推断 | `data_metadata.R` | `metadata_determine_var_type()`、`metadata_coerce_var_data()`、`metadata_safe_numeric_range()` | 字符变量低基数判定与日期/数值转换规则统一由 common 维护，子模块不得各写一套推断逻辑 |
| 统计格式化与复现模板 | `analysis_format.R` | `format_p_value_regression()`、`format_regression_stat()`、`build_repro_code_template()` | 回归统计值、缺失占位符、复现代码模板统一走 common，禁止模块各自维护格式 |
| 图形复现代码 | `graphics_repro.R` | `graphics_quote_value()`、`graphics_quote_vector()`、`generate_graphics_repro_code()` | 图形复现代码输入必须来自 committed 状态快照；新增图形类型时必须补 common 入口分支 |
| 表格样式与导出 | `table_export.R` | `format_p_value_ama()`、`normalize_footnotes()`、`extract_table_dataframe()`、`apply_sci_gt_style()` | P 值显示、脚注清洗、gt 风格统一由 common 注入，禁止模块私有化导出样式 |
| 图形导出 | `plot_export.R` | `build_plot_export_filename()`、`save_plot_export()` | 导出文件名与支持格式统一由 common 维护；业务模块不得扩展不一致的私有导出参数 |
| 存储抽象 | `storage_backend.R` | `storage_backend_get()`、`storage_data_key_build()`、`storage_save_dataset()`、`storage_load_dataset()`、`storage_delete_dataset()` | 数据体读写删除统一走 common；业务模块不得拼接本地/S3 细节路径 |

### 9.4 后续开发收紧声明

- 发现图例、尺寸、P 值、标签、元数据、导出、存储需求时，先搜索 `modules/common/` 是否已有对应抽象；已有则必须复用，不得平行新建实现。
- 若现有 common 抽象只差少量参数或枚举，应优先扩展 common 函数签名，不得在子模块包一层同义变体长期并存。
- 子模块允许存在的特例，只限表现层细节且必须在指南中明确说明边界；一旦第二个模块需要同类能力，必须上提到 common。
- 新增或改动 common 函数时，至少同步更新本指南中的“可复用函数清单”和相关测试，确保后续开发按同一契约收紧。

## 10. 数据、存储与规范

### 10.1 数据输入来源

| 入口 | 当前支持 |
| --- | --- |
| 本地文件上传 | `.csv`、`.xlsx`、`.xls`、`.sas7bdat`、`.sav`、`.dta`、`.por` |
| 数据库加载 | 从 PostgreSQL 中按 workspace / folder / dataset 选择已登记数据集 |
| 服务器目录导入 | `database_manager.R` 支持按服务器绝对路径导入工作区 |
| 批量导入 | `database_manager.R` 支持多文件批量保存 |

### 10.2 存储架构

| 层级 | 当前实现 |
| --- | --- |
| 元数据 | PostgreSQL 表 `users`、`workspaces`、`workspace_memberships`、`folders`、`datasets` |
| 数据体 | 本地 `RDS` 文件或 S3 对象 |
| 存储切换 | 通过 `STORAGE_BACKEND` 控制 `local` / `s3` |
| S3 前置条件 | 必须安装 `aws.s3`，并设置 `STORAGE_S3_BUCKET` |

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

| 项目 | 当前规则 |
| --- | --- |
| P 值风格 | AMA 风格 |
| 极小 P 值 | `<0.001` |
| 极大 P 值 | `>0.99` |
| 无法计算 P 值 | 显示为 `—` |
| 无法计算效应量 | 显示为 `—` |
| 效应量保留位数 | `HR / OR / Beta` 及其 95% CI 通常保留 2 位小数 |

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

### 11.2 当前测试契约

- 新增功能或修改现有逻辑时，测试文件统一放在 `tests/`。
- 共享层改动至少要补一条可回归的最小测试。
- 图形或统计口径改动优先补“同口径断言”，避免只测 UI 是否渲染成功。
- `run_app_test.ps1` 依赖 `.env.test`；仓库当前提供 `.env.test.example` 作为测试环境变量模板。若数据库由 `docker-compose1.yml` 拉起，测试端口应使用 `55432`。
- `run_app_test.ps1` 启动前会读取 `SHINY_PORT`（未设置时默认为 `8109`）；若该端口已被占用，脚本会强制关闭占用进程后再拉起应用。

### 11.3 当前缺口

- 尚未形成完整的部署文档自动校验。
- 文档与实现一致性巡检目前仍以轻量守卫脚本为主，尚未形成统一测试入口。
- `MMRM`、`MI` 等占位菜单没有对应测试，因为尚未落地。

## 12. 当前未落地项与路线图

### 12.1 已确认但未落地

| 项目 | 当前状态 | 说明 |
| --- | --- | --- |
| MMRM | 占位 | 菜单可见，分析链路未实现 |
| 多重填补（MI） | 占位 | 菜单可见，分析链路未实现 |
| Kubernetes 部署 | 未提供 | 仓库中暂无相关编排或清单 |

### 12.2 下一步优先方向

1. 继续增强共享层，减少图形子模块与回归子模块的重复逻辑。
2. 把高复杂图例、符号和样式配置进一步抽象成可复用组件。
3. 为部署文档、运行入口和关键环境变量增加自动检查。
4. 在现有个人隔离与 workspace 权限基础上，评估组织级、项目级隔离、邮箱验证与共享协作模型。
5. 在高级方法真正落地后，再补充对应章节与测试。

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
- Landing 页文案与视觉改版时，应同步核对平台名与应用名层级、入口 URL、未落地项说明和功能边界，避免再次出现实现与对外叙事脱节。
- 主 Landing 改版时优先检查是否仍然足够精简，避免把 AutoTFL 详细内容重新堆回 `index.html`。
- Landing 页如强调 AutoTFL，应优先说明“能产出什么”“如何开始使用”和“从哪里进入”，避免引入技术栈宣传、兼容性提示或抽象分层说明；应用页头与浏览器标题应统一为 `Hamster Analysis · AutoTFL`。

---

文档校验基线：2026-04-07  
校验范围：仓库结构、核心模块、部署编排、共享层、测试目录  
状态说明：本文仅记录当前仓库已实现或已明确暴露的能力
