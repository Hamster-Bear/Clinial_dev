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
12. [研发治理约束](#12-研发治理约束)

## 1. 文档定位

### 1.1 目标

- 本文档用于说明 AutoTFL 当前仓库的真实实现，而不是理想设计草案。
- 文档重点覆盖架构边界、模块职责、运行方式、统计口径、部署前置条件和维护约束。
- 所有描述均以当前仓库文件、现有脚本和已存在测试为准；未落地能力单独放在“当前未落地项与路线图”。

### 1.2 名称约定

| 名称            | 当前含义           | 备注                                                       |
| ------------- | -------------- | -------------------------------------------------------- |
| Medev         | Landing 对外名称   | 当前用于 `nginx/landing/*.html` 的前端产品文案与浏览器标题               |
| AutoTFL       | 仓库与应用内部名称     | 当前仍用于仓库目录、`/app/` 实际应用入口与部分 legacy 文件名                  |
| `autotfl.html` | Landing 子页文件名 | 当前继续保留旧文件名以减少部署与路由改动，但对外文案不再直接展示 AutoTFL               |

### 1.3 文档使用原则

- 新增或修改功能时，先更新本文件中对应章节，再改代码或同步提交代码变更。
- 本文件描述“当前已实现”，不把占位菜单、计划能力、外部设想写成既成事实。
- 若其他文档与本文件冲突，以当前代码实现和本文件为准，并在后续文档清理中同步收敛。
- 测试目录结构、回归入口或测试归类发生变化时，需同步更新 `docs/main/TEST_GUIDE.md`。

## 2. 系统概览

### 2.1 产品定位

- AutoTFL 是基于 R Shiny 的医学/临床数据分析应用，覆盖数据准备、探索性分析、统计分析、统计图形和预设 TFL 输出。
- 系统当前是单仓库、单 Shiny 主应用架构，支持通过 Nginx Landing 页面包装为“平台入口”。
- 主工作流依赖数据先进入 PostgreSQL 元数据层和本地/S3 数据存储层，再向下游分析与出图模块广播。

### 2.2 核心技术栈

| 分层     | 当前使用                                                                     |
| ------ | ------------------------------------------------------------------------ |
| UI 与交互 | Shiny、shinydashboard、shinyjs、shinyBS、bslib、shinyWidgets、reactable、plotly |
| 数据处理   | dplyr、tidyr、purrr、stringr、readxl、haven、memoise                            |
| 统计分析   | survival、broom、gtsummary、rtables、tern、corrplot                           |
| 导出能力   | gt、flextable、officer、rmarkdown、pagedown、r2rtf                            |
| 基础设施   | PostgreSQL、Redis、Nginx、Docker Compose                                    |

### 2.3 架构摘要

- 主入口为 `app.R`，负责加载依赖、source 模块、组装六大业务页签。
- 当前 `app.R` 已接入应用内自注册、登录、退出与会话态用户上下文。
- 登录与注册当前已拆分为两个独立页面，并在注册阶段采集邮箱用于后续协作授权扩展；认证主体区域已抽到 `auth_manager.R`。
- 当前用户信息与退出入口稳定显示在侧边栏卡片中，不再依赖顶栏动态渲染。
- `modules/` 目录采用“路由层 + 子模块 + common 共享层”结构。
- 数据元数据走 PostgreSQL；数据体通过 `modules/common/data/storage_backend.R` 落到本地目录或 S3。
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

部署细节、目录树、挂载关系、环境变量和分场景操作步骤统一维护在 `docs/deploy/DEPLOY_GUIDE.md`；本章仅保留部署矩阵与边界摘要。

### 3.1 运行矩阵

| 场景     | 入口                          | 访问方式                    | 说明                                |
| ------ | --------------------------- | ----------------------- | --------------------------------- |
| 本地开发直跑 | `run_app.R`                 | 默认 `127.0.0.1:8190`     | 自动检查依赖并直接运行 `app.R`               |
| 开发编排   | `docker-compose.yml`        | `http://localhost`      | Nginx 直接反代 Shiny 根路径，不带 Landing 页 |
| 本地联调   | `docker-compose.local.yml`  | `http://localhost:8080` | 含 Landing 页，应用入口为 `/app/`         |
| 服务器生产  | `docker-compose.server.yml` | `https://<domain>`      | HTTPS + Landing 页，应用入口为 `/app/`   |

### 3.2 当前入口规则

- `docker-compose.yml` 使用 `nginx/default.conf`，根路径 `/` 直接转发到 Shiny。
- `docker-compose.local.yml` 使用 `nginx/local-test.conf`，根路径为 Landing 页，应用走 `/app/`。
- `docker-compose.server.yml` 使用 `nginx/server_ssl.conf`，80 自动跳转 443，根路径为 Landing 页，应用走 `/app/`。
- Landing 页当前统一使用 Medev 对外口径；`/app/` 继续指向仓库内的实际 Shiny 应用入口。
- `nginx/landing/index.html` 作为 Medev 首页，只保留简洁入口说明与跳转，不展开大段功能细节。
- `nginx/landing/autotfl.html` 作为 Medev 产品介绍子页，承接真实功能范围、最短使用路径与结果图片占位；当前继续保留旧文件名以避免额外路由改动。
- Landing 文案必须保持少字、真实、可验证：不插入虚构图表、不描述未落地能力、不出现项目进度口径。
- 前端用户可见说明文案、源码注释、核心文档说明的编写规范，统一见 [CODE_STYLE.md](CODE_STYLE.md) §3（UI/UX 规范）。
- 本地联调 Landing 页的静态资源在 `local-test.conf` 中已设置 no-store/no-cache，减少浏览器缓存导致的问题。

### 3.3 当前部署边界

- 当前仓库已实现 Docker Compose 部署链路。
- 当前仓库未提供 Kubernetes Manifest、Helm Chart 或 Kustomize 配置，因此不应描述为“已支持 Kubernetes 生产部署”。
- Redis 已进入编排层，但当前 Shiny 主应用代码未见显式 Redis 业务读写逻辑，现阶段更适合作为基础设施预留。

### 3.4 依赖与离线仓库前置条件

- `config/required_packages.R` 是安装脚本与离线包脚本的 R 依赖单一清单；新增安装依赖先改该文件。
- `install_dependencies.R` 支持“本地离线仓库优先、在线镜像回退”。
- `download_offline_packages.R` 用于预生成本地 `package/` 仓库及 `PACKAGES` 索引，依赖列表来自 `config/required_packages.R`。
- 当前仓库默认未提交完整 `package/` 离线仓库；如果直接执行当前 `Dockerfile`，需要先生成 `package/`，否则 `COPY package /app/package` 会失败。Docker 构建会在安装依赖前复制 `config/`，保证容器内可读取统一依赖清单。
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
- 登录支持用户名或邮箱；注册阶段会校验邮箱格式，当前登录、注册与忘记密码已拆为独立页面状态：登录页仅保留登录主流程，注册页只负责创建账号，忘记密码改为独立找回流程。
- 登录页底部提供“注册账号 / 忘记密码”入口；“忘记密码”通过隐藏页签切到独立找回页，避免首页堆叠多张卡片。
- 登录页底部的“注册账号 / 忘记密码”采用更明显的按钮式次级操作，提升首屏可发现性。
- 当前邮箱验证已移到登录后的用户信息区，改为用户自行触发和完成，不再阻断注册或登录；本地/测试环境默认通过 `EMAIL_DELIVERY_MODE=console` 输出验证码，可配合 `AUTH_DEV_SHOW_EMAIL_CODE=1` 直接在日志与提示中查看验证码。
- 认证写操作当前统一通过 `modules/common/auth/auth.R` 中的 `auth_with_transaction()` 收口事务入口：应用运行时若传入 `pool::dbPool()`，必须走 `pool::poolWithTransaction()`；测试或脚本若传入普通连接，则继续兼容 `DBI::dbWithTransaction()`，避免注册、邮箱验证、邮箱换绑与密码重置出现“实际已提交但前端误报失败”。
- 登录后的侧边栏当前保留“用户和权限”这一概念入口，但入口标签、卡片摘要与快捷按钮等对外展示文案，统一以 `modules/common/auth/auth_copy.R` 中的 `ACCOUNT_ENTRY_COPY` 为唯一源。`PROJECT_GUIDE.md` 只描述结构职责，不再重复维护按钮或摘要原句。结构上，侧边栏入口继续收口到个人信息卡；`user_profile` 只保留基础用户信息与少量信息变更控件，如绑定邮箱、邮箱换绑和修改密码；`access_permissions` 按权限分支展示协作权限或“我的已授权空间”，且无可管理空间时必须提供非空态说明。
- 侧边栏个人信息卡必须由独立模块承载，并在模块内维护隐藏内部页签的 CSS 守卫；`user_profile` 与 `access_permissions` 仅作为内部路由存在，禁止再次直接暴露为侧边栏菜单项。
- `用户信息` 与 `权限管理` 必须采用文件夹级模块拆分并分别独立输出、独立兜底，禁止再用单个 `renderUI` 同时包裹两类职责内容；权限查询异常或组件渲染失败时，不得影响用户信息页继续显示。
- 账号页前端当前统一采用“概览优先 + 功能集中”布局：`user_profile` 首屏主卡需直接展示页面说明与账号概览统计，避免进入后只看到空标题卡；随后再用单一“安全与验证”区域承接邮箱验证、邮箱换绑与修改密码。`access_permissions` 顶部先展示空间/权限概览，再用单一“协作管理”区域承接成员协作、负责人迁移与成员/邀请预览，降低纵向滚动与重复标题。
- 账号页聚合布局的标题、工作台名称与标签页文案也应继续复用 `modules/common/auth/auth_copy.R`，避免新一轮前端优化后再次在 `user_profile.R`、`permission_manager.R` 与规范文档中平行维护相似文案。
- 账号页工作台卡片中的动作按钮应与输入控件保持同一视觉节奏：默认使用公共紧凑动作区样式，优先横向紧凑排列并保留适度最小宽度，仅在窄屏下再自动切到整行堆叠，避免桌面端出现”按钮单独占满一个框”的割裂感。
- 当前忘记密码已改为独立找回页：用户可申请 6 位重置验证码并完成重置；本地/测试环境同样通过 `EMAIL_DELIVERY_MODE=console` 输出验证码，过期时间由 `AUTH_PASSWORD_RESET_EXPIRE_MINUTES` 控制。
- 当前已支持登录后邮箱换绑：用户需先输入当前密码，再向新邮箱发送 6 位换绑验证码，验证成功后才会正式切换主邮箱；换绑成功后应自动尝试认领该邮箱名下待领取的协作邀请。
- 当前邮件投递已抽象为 `modules/common/auth/email_service.R`：默认保留 `console/disabled` 模式，并新增 `smtp` 模式；启用真实发信时需补齐 `EMAIL_FROM_ADDRESS`、`SMTP_HOST`、`SMTP_PORT`、`SMTP_USERNAME`、`SMTP_PASSWORD`、`SMTP_USE_SSL`。
- 管理员页现已补充 `SMTP 连通性测试` 卡片，可向测试邮箱发送探针邮件；建议在预发环境先验证 `smtp` 投递成功、失败提示和收件链路，再切正式环境。
- `SMTP 连通性测试` 卡片当前会保留最近一次探针结果，展示成功/失败状态、目标邮箱、执行时间与结果说明，方便部署验收和排障留痕。
- 当前用户信息与退出入口稳定显示在侧边栏卡片中；普通用户的两个快捷入口标签直接复用 `ACCOUNT_ENTRY_COPY$actions`，并继续合并在同一张侧边栏卡片内。
- 登录页、找回密码页与侧边栏账号设置区现已对齐到与管理员页一致的公共卡片壳风格；后续凡新增认证、账号设置或系统入口相关 UI，默认都应复用 `modules/common/ui_shell.R` 的公共卡片壳与按钮语言，不再新增平行风格。
- 当前登录态会定时从数据库刷新用户状态与数据库管理开关；管理员调整账号状态或数据空间功能开关后，用户侧菜单、默认落点与卡片快捷按钮会在当前会话内跟进，不再长期停留在旧登录快照。
- 侧边栏用户卡片右上角快捷按钮现统一收口：按钮实际展示文案统一复用 `ACCOUNT_ENTRY_COPY$actions`，管理员、已开通普通用户与未开通普通用户分别映射到内部路由 `admin`、`db_manage` 与 `data_prep`；若用户名下已有可管理数据空间，卡片底部继续保留权限入口。
- 未登录状态下只渲染登录/注册入口，不渲染业务工作台侧边栏。
- 非管理员用户默认按个人空间隔离，只能看到自己拥有或被授权的 workspace。
- 当前系统角色口径仅保留系统管理员与普通用户。
- 系统管理员负责账号状态、数据空间功能开通和服务器目录导入等系统级能力；可查看数据库信息与 workspace 元信息，但不得读取、浏览或导出其他用户数据空间中的实际数据，这条约束是上线后的服务层保密底线。
- 管理员操作入口位于系统管理页；workspace、membership、invite、账号状态切换、数据库功能开关与任务历史覆盖保存能力统一下沉到 `modules/common/auth/account_service.R` 等 service 层。
- workspace 创建与删除也统一通过 `modules/common/auth/account_service.R` 收口，数据库管理模块不再直接拼装 owner / membership 初始化逻辑。
- 普通用户可对自己拥有的数据空间进行权限管理，且授权、撤销与 owner 迁移统一通过邮箱输入完成。
- 管理员页保持独立系统入口，不并入侧边栏用户卡片；账号状态调整与数据空间功能开关继续集中在管理员页，数据空间负责人迁移与协作授权现统一收口到单一“数据空间管理”卡片，且仍仅限当前管理员自己名下可管理的数据空间。
- 管理员页现补充信息型增强：顶部系统概览、运行环境摘要、目标账号状态卡片、操作影响预览，以及“我名下数据空间概览”；这些信息只用于管理判断与排障，不扩大现有权限边界。
- 管理员页前端展示现按“摘要优先、明细随后”收拢：顶部优先展示系统概览、异常态势与运行环境，中段展示注册账号总览，底部再承接具体管理动作与空间明细。
- 系统概览、异常态势摘要与账号状态管理中的状态卡现统一切到紧凑统计卡布局，在同等信息量下压缩留白并提高首屏可读性。
- 管理员页使用 `modules/common/ui_shell.R` 公共卡片壳：统一系统入口卡、摘要卡、说明块与主要管理卡片视觉，但保持现有“摘要优先、明细随后”的信息结构、账号总览联动逻辑与协作预览 tab 结构不变。
- 管理员页中的账号状态管理已与“所有注册账号总览”联动：系统管理员在总览表中选中账号后即可直接启用、停用或开关数据空间功能，不再手工输入邮箱定位账号。
- 管理员页统一空间选择器 `selected_manage_workspace_id()` 在回退默认空间前，必须先处理零长度 `workspace_ids`；即使 `list_manageable_workspaces()` 返回了非零行数据，只要提取后的 id 向量为空，也应返回空字符串而不是直接取首项。
- `app.R` 当前通过 `modules/common/ui_shell.R` 提供的公共 helper 挂载全局 loading overlay：应用首屏连接与首次 UI 挂载期间默认显示仓鼠 loading 主视觉与“应用加载中”，并按“正在连接服务 -> 正在初始化模块 -> 正在进入工作台”的阶段文案减轻误判；待浏览器收到首次 `shiny:idle` 后自动隐藏，认证链路仍继续通过 `hamster-loading` 自定义消息复用同一 overlay，避免应用初始化期间前端出现长时间空白。
- loading 静态资源当前收口到 `www/assets/loading/`：`hamster.svg` 提供主视觉，`loading.css` 提供覆盖层、轨道流动和浮动动效；`modules/common/ui_shell.R` 只负责挂载资源和控制状态，不再内联维护整套 loading 样式。
- 登录成功链路的“正在进入工作台”文案不得与同一 `observeEvent` 内的立即 `hide` 冲突；当前约定为成功后发送 `hide_delayed` 延迟隐藏，让用户能实际看到进入工作台提示，失败分支则立即隐藏。
- 管理员页现已补充“异常态势摘要”，集中展示停用账号、未设置邮箱账号、未开通数据空间功能账号、待领取邀请与未注册邀请邮箱等风险项；该摘要只基于元信息，不应越界展示其他用户实际数据内容。
- 管理员页的异常态势摘要现支持页内快捷跳转，可直接定位到账号状态管理、数据空间管理与我名下数据空间概览；在数据空间管理场景下可进一步聚焦负责人邮箱或协作者邮箱输入框，并在协作相关场景切换到相关预览 tab，不新增任何权限入口。
- 管理员页现已补充“所有注册账号总览”，通过摘要卡、预设筛选按钮与总览表结合的方式展示所有已注册账号的元信息、数据空间功能状态、待领取邀请、名下数据空间数与当前可访问空间数；该总览只基于元信息，不应越界展示其他用户实际数据内容。
- 权限预览表统一改为业务中文列名；数据库管理页按“空间与目录 / 上传与导入 / 结构总览”三段重组。
- 数据库管理功能已增加账号级访问锁：普通账号默认锁定，需由管理员开放数据库管理权限后才可进入与操作。
- 未开通数据空间功能的普通用户登录后默认落到“数据准备”页；侧边栏“数据空间”显示“需授权”，“数据准备”显示“临时上传”，数据库管理锁定卡片会提示改走临时上传链路。
- 普通用户在未开通数据空间功能时，只允许单文件临时上传；上传数据仅用于当前会话分析，不写入持久化数据空间。
- 前端卡片样式开始收口到新的公共 UI 壳 `modules/common/ui_shell.R`；当前已从数据预备模块先接入，统一卡片标题、说明区、边框和留白，但暂不改变原有布局结构。
- 统计分析、统计图形、Tables 与探索分析四个入口层使用共享文案源 `modules/common/entry_copy.R`：只收口入口层标题、副标题与说明文案，避免这些高频入口卡片继续在多个模块文件里平行硬编码；按钮文案、结果页签名与子模块内部说明暂不纳入该 helper。
- 统计分析子模块使用共享说明文案源 `modules/common/analysis/stat_analysis_submodule_copy.R`：覆盖 `desc`、`cox`、`logistic`、`linear`、`anova`、`chisq`、`cmh` 内部的 `app_card_note()` 参数说明块；字段标签、`helpText()`、`bsTooltip()` 和结果解释由各模块维护。
- 统计图形结果区通用文案收口到 `modules/common/graphics/graphics_result_copy.R`：覆盖 `boxplot`、`survival_analysis`、`forest_plot`、`heatmap`、`correlation_matrix`、`combo_plot`、`waterfall_plot`、`swimmer_plot`、`spider_plot` 的结果卡 `subtitle`、结果卡 `app_card_note()` 与结果页 `note`。模块专属结果提示可继续保留在原模块内，不强行共享化。
- 统计图形第一批导出卡通用文案收口到 `modules/common/graphics/graphics_export_copy.R`：覆盖 `survival_analysis`、`forest_plot`、`combo_plot`、`waterfall_plot`、`swimmer_plot`、`spider_plot` 的导出卡 `subtitle` 与 `app_card_note()`；导出区 `helpText()`、固定画布、宽高比和分层标签等模块专属语义继续保留在原模块中。
- 数据库管理页使用公共卡片壳：统一主卡片、说明块、锁定提示、上下文摘要与结构总览摘要卡，但保持原有”空间与目录 / 上传与导入 / 结构总览”页签结构不变。
- 统计分析总入口使用公共卡片壳：统一全局筛选卡、方法选择卡、参数设置卡、结果卡与导出说明面板，但保持原有“统计表格 / 统计报告 / 可复现代码”结果结构，以及各统计子模块参数 UI 与分析逻辑不变。
- 统计分析子模块样板覆盖 `desc.R` 与 `cox.R`：统一参数区说明块与分组面板，但保留原有输入项、动态输出、tooltip、建模逻辑与结果链路不变。
- 统计分析回归类子模块样板覆盖 `logistic.R` 与 `linear.R`：统一响应/分层、总计列或事件映射、预测变量与参考组分区，但保留原有输入项、动态输出、tooltip、建模逻辑与结果链路不变。
- 统计分析基础检验子模块覆盖 `anova.R` 与 `chisq.R`：ANOVA 输出 `项目 / 自由度 / 平方和 / 均方 / F值 / P值`；卡方与 CMH 输出 `检验 / 统计量 / 自由度 / P值`，P 值均使用 AMA 风格。
- 统计分析结果区已统一：`统计表格 / 统计报告 / 可复现代码` 三个 tab 现统一使用结果 panel 和空状态 helper，导出区也统一为结果区说明面板，但不调整结果对象、报告生成与导出逻辑。
- 第一批 UI 归一已接入公共扩散源：`modules/common/data_filter.R` 与 `modules/task_history.R` 已统一到公共壳下的可折叠工作台卡片，减少旧式 `box()` 壳继续扩散到统计分析、统计图形与 Tables 入口。
- 统计图形总入口使用公共卡片壳：统一图形类型选择卡，直接复用已收口的全局筛选卡与任务历史卡；可复现代码改为收口到各图形子模块结果区页签，保持原有图形子模块切换、任务历史回填和代码生成链路不变。
- 统计图形总入口当前要求在 UI 与 server 各自作用域内独立读取 `ENTRY_COPY$statistical_graphics`；凡在 `renderUI()`、`renderText()` 等服务端渲染中继续使用入口共享文案时，不得依赖 `statistical_graphics_ui()` 内部局部变量，避免运行时出现 `找不到对象 'copy'`。
- 统计图形子模块保存任务历史与生成可复现代码时，必须优先使用点击“生成图形”时的 committed 参数快照；若模块允许生成后继续编辑控件，`state()$input_state` 与 `extra_state` 均不得漂移到未生成的 live input。`boxplot.R`、`heatmap.R`、`correlation_matrix.R`、`combo_plot.R` 当前通过 `graphics_build_committed_task_state()` 覆盖已提交输入，并由 `tests/statistical_graphics/committed_state/test_basic_graphics_committed_state.R` 做 server 级回归。
- 箱线图外层使用公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有 X/Y 映射、固定 `10 x 8` 英寸导出与任务历史契约不变。
- 组合图外层使用公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有高动态图层参数页签、两阶段任务历史恢复与固定 `12 x 8` 英寸导出链路不变。
- 生存分析外层使用公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有风险表、统计报告、提交态快照与导出链路不变。
- 森林图外层使用公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有 `precalculated/raw_data` 双模式、列配置、统计报告与导出链路不变。
- 蜘蛛图外层使用公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有时间轴换算、点层/末次标签、RECIST 阈值与 committed 参数快照链路不变。
- 泳道图外层使用公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有事件映射、轨道变量、committed 参数快照与导出链路不变。
- 瀑布图外层使用公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有排序/轨道、RECIST 阈值、committed 参数快照与导出链路不变。
- Tables 总入口使用公共卡片壳：直接复用已收口的全局筛选卡，并统一参数设置卡、结果卡与导出区说明块，但保持原有表格类型切换、动态参数 UI、生成与导出链路不变。
- 探索分析总入口使用公共卡片壳：统一变量托盘、图形控制器与图形输出三块入口卡片，并补充说明块与结果 panel，但保持原有变量映射、Plotly 输出与重置链路不变。
- 当前尚未实现组织级、项目级隔离，也未提供更细粒度的 folder 或 dataset 权限模型。

### 3.7 当前免责声明

- 当前工具暂不负责数据安全；数据传到服务端后不保证安全，请使用方自行妥善保管数据。
- 如需更高的数据隔离与环境保障，应优先采用独立部署服务，而不是把当前公共部署形态描述为安全托管服务。
- 管理员账号必须通过环境变量预置 `APP_ADMIN_USERNAME`、`APP_ADMIN_EMAIL` 与 `APP_ADMIN_PASSWORD`；未配置时不自动提升首个注册用户。
- 管理员环境变量当前视为引导权威输入：启动时若数据库中已存在同邮箱或同用户名账号，会同步校准用户名、邮箱、密码摘要、管理员身份、数据库管理开关与 `active` 状态；若邮箱与用户名分别命中不同账号，则拒绝静默同步并要求先清理历史记录。

### 3.8 当前阶段风险与优化建议

- 技术风险：当前权限主边界仍在 workspace 级别，`viewer` / `editor` 对数据写操作的差异尚未完全落实到所有模块；数据库管理锁当前仍是账号级开关。
- 技术风险：认证链路同时服务应用运行时 `pool` 与测试脚本直连两种数据库入口；后续若新增事务型写操作但未复用 `auth_with_transaction()`，仍可能再次出现“数据库已写入但前端提示失败”的假异常。
- 维护风险：邮箱邀请支持未注册用户占位，但尚未提供邀请过期、撤回审计与邮箱真实性校验；普通用户入口与管理员入口的交互规范需要持续同步。
- 项目风险：owner 自助授权已开放给创建者，后续若扩展共享协作，需要同步补齐审计日志与异常回滚策略。
- 立即可做：继续沿 `modules/common/auth/` 服务域补齐剩余认证/用户管理 service 拆分，并在管理员状态调整、邀请领取、Owner 迁移等链路维持 `pool` 模式回归。
- 立即可做：补充 service 层数据库集成测试，覆盖授权、撤销、owner 迁移、invite 领取与 workspace 删除链路，并验证数据库管理新布局与数据库管理锁的可用性。
- 立即可做：将 `run_auth_regression.ps1` 继续收口为清单驱动入口，统一从 `tests/common/auth/auth_regression_manifest.json` 读取固定顺序，减少后续新增认证测试时的手工同步成本。
- 中长期建议：引入邮箱验证、邀请有效期、组织级 / 项目级协作模型与更细粒度权限矩阵。
- 中长期建议：继续将 `tests/.../legacy/` 下的脚本式验证迁移为标准 `testthat` 用例，并回收到对应模块主目录，逐步消除长期并行维护成本。
- 工具链建议：在 `tests/` 现有守卫测试基础上，持续维护 PostgreSQL 隔离 schema 回归测试、`pool` 模式回归与 pre-commit 文档一致性校验；账号权限链路可优先参考 `tests/common/auth/test_auth_access_postgres_integration.R`，并将 `Rscript tests/check_test_guide_index.R` 作为固定质量闸门。

## 4. 仓库目录结构

```text
AutoTFL/
├── app.R
├── modules/
│   ├── common/
│   │   ├── auth/
│   │   │   ├── account_service.R
│   │   │   ├── auth.R
│   │   │   ├── auth_copy.R
│   │   │   └── email_service.R
│   │   ├── data/
│   │   │   ├── data_filter.R
│   │   │   ├── data_io.R
│   │   │   ├── data_metadata.R
│   │   │   ├── data_registry.R
│   │   │   └── storage_backend.R
│   │   ├── analysis/
│   │   │   ├── analysis_format.R
│   │   │   ├── analysis_shared.R
│   │   │   └── stat_analysis_submodule_copy.R
│   │   ├── graphics/
│   │   │   ├── forest_analysis_pipeline.R
│   │   │   ├── forest_model_helpers.R
│   │   │   ├── forest_result_schema_helpers.R
│   │   │   ├── forest_table_state_helpers.R
│   │   │   ├── graphics_common.R
│   │   │   ├── graphics_export_copy.R
│   │   │   ├── graphics_repro.R
│   │   │   └── graphics_result_copy.R
│   │   ├── export/
│   │   │   ├── plot_export.R
│   │   │   └── table_export.R
│   │   ├── entry_copy.R
│   │   └── ui_shell.R
│   ├── account_access/
│   │   ├── permission_manager.R
│   │   ├── sidebar_account_card.R
│   │   └── user_profile.R
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
│   ├── task_history.R
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
│   ├── postgresql.conf
│   ├── migrate.ps1
│   └── migrations/
│       └── 001_analysis_states_schema.sql
├── deploy/
│   └── alicloud/
├── docs/
│   ├── main/
│   │   ├── CODE_STYLE.md
│   │   ├── PROJECT_GUIDE.md
│   │   ├── PROJECT_SPEC.md
│   │   └── TEST_GUIDE.md
│   ├── deploy/
│   │   └── DEPLOY_GUIDE.md
│   ├── dep/
│   │   ├── DEVLOG-R001-R040.md
│   │   ├── PLAN.md
│   │   └── REVIEWS.md
│   ├── AI prompt.md
│   └── app_design.md
├── tests/
│   └── check_test_guide_index.R
├── Dockerfile
├── config/
│   └── required_packages.R
├── docker-compose.yml
├── docker-compose.local.yml
├── docker-compose.server.yml
├── docker-compose1.yml
├── download_offline_packages.R
├── install_dependencies.R
├── run_app.R
└── run_app_test.ps1
```

### 4.1 目录使用约定

- `modules/common/` 只放跨模块共享逻辑，不放单一图形或单一统计方法的专属实现；根层只保留 `entry_copy.R` 与 `ui_shell.R` 两个跨域入口例外。
- 为保持 `modules/statistical_graphics/` 目录干净，图形子模块主文件之外的辅助类、结果整形器、状态桥接器和分析流水线 helper，后续不得继续堆回 `modules/statistical_graphics/`；应优先下沉到 `modules/common/graphics/` 这类按图形域归类的共享目录中。
- `modules/common/` 已统一收敛为 `modules/common/auth/`、`modules/common/data/`、`modules/common/analysis/`、`modules/common/graphics/`、`modules/common/export/` 五类；新增共享逻辑必须进入 auth/data/analysis/graphics/export 对应子目录，根层例外不承载领域逻辑。
- 这里所说的“后端服务层/服务域”优先指账号认证、权限、会话、workspace 与持久化服务，不指图形模块内部的 `server` 函数拆分；图形模块当前仍优先按 common helper 下沉，不单独引入新的图形 server 目录。
- `modules/statistical_graphics_ui/` 用于图形 UI 壳层与公共控件，和 `modules/statistical_graphics/` 的 server/分析逻辑分离。
- `tests/` 为统一测试目录，新增测试文件必须放在这里。
- `tests/` 内部目录应尽量与项目结构同层语义对齐，例如 `tests/common/auth/`、`tests/statistical_analysis/`、`tests/statistical_graphics/`、`tests/nginx/landing/`、`tests/root/`；测试夹具统一收口到 `tests/fixtures/`。
- `docs/main/TEST_GUIDE.md` 为测试索引文档，按项目架构维护测试归类；整体性测试说明优先收口到这里，不散落到 `tests/`。
- `nginx/landing/index.html` 作为 Medev 首页，保持精简，只负责入口说明与跳转。
- `nginx/landing/autotfl.html` 作为 Medev 产品介绍子页，承接真实功能说明、使用路径与图片占位。
- `nginx/landing/style.css` 与 `nginx/landing/script.js` 为 Medev 首页和产品介绍子页共享静态资源，改动时需同时验证两页。
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
4. 数据准备模块在数据库记录仍在但物理数据文件缺失、路径失配或旧记录缺少 `folder_id` 时，应优先返回可见错误提示，不得因路径回退分支异常导致会话中断。
5. `data_metadata.R` 与 `data_filter.R` 统一变量标签、类型和筛选逻辑。
6. 下游统计分析、图形和预设图表消费经过筛选后的数据。

## 6. 统计分析实现

### 6.1 模块定位

- `statistical_analysis.R` 是统计分析总入口，不仅仅是“回归面板”。
- 当前提供描述性统计、Cox、Logistic、Linear、ANOVA、卡方和 CMH。
- `MMRM` 与 `多重填补（MI）` 当前仍是菜单占位项，不应视为已交付功能。

### 6.2 子模块清单

| 文件           | 功能          | 当前实现要点                                       |
| ------------ | ----------- | -------------------------------------------- |
| `desc.R`     | 描述性统计       | 手工构造 `gt` 汇总表，支持总计列扩展与自动小数位识别          |
| `cox.R`      | Cox 回归      | 使用 `survival::coxph`，支持 strata、split、列分组     |
| `logistic.R` | Logistic 回归 | 使用 `stats::glm(family = binomial())`，支持事件值映射 |
| `linear.R`   | 线性回归        | 使用 `stats::lm`，支持多预测变量和列分组                   |
| `anova.R`    | 方差分析        | 连续变量组间比较，基于完整观测输出 AMA 风格 P 值             |
| `chisq.R`    | 卡方 / CMH    | 分类变量组间比较与分层检验，支持字符/因子分类变量              |

线性回归结果中的 `N` 表示人数/有效样本人数口径，用于保持与现有统计表口径一致；该列不按二分类事件率解释。
回归类 `model_strata` 参与模型 complete cases 与结果表 N/Event-N 口径计算；多水平亚组的 `P for interaction` 使用主效应模型与交互模型的整体比较结果。
Logistic 列分组表保留 `gt` spanner 与展示标签，内部列名可保持 `A__N` 等结构化名称，页面展示为 `Event/N`。

### 6.3 当前共享引擎

| 文件                           | 核心职责                                | 当前作用                         |
| ---------------------------- | ----------------------------------- | ---------------------------- |
| `analysis_shared.R`          | 回归公共校验、交互项 P 值计算、统一结果整理             | Cox / Logistic / Linear 共享核心 |
| `modules/common/auth/account_service.R` | 用户、workspace、membership 与数据入口服务封装   | 管理员入口、任务历史与数据模块复用服务层        |
| `modules/common/auth/auth.R`            | 注册、登录、密码摘要、权限过滤、事务 helper 与管理员引导 | `app.R`、数据库管理、数据准备共享认证边界     |
| `auth_manager.R`             | 登录/注册页面、认证交互与 loading 反馈            | 精简 `app.R` 并承载认证页 UI；认证动作继续复用公共 loading overlay |
| `modules/account_access/sidebar_account_card.R` | 侧边栏个人信息卡、快捷入口与隐藏页签 CSS 守卫 | 收口账号入口并降低 `app.R` 拼装复杂度 |
| `modules/account_access/user_profile.R` | 用户基础资料、邮箱验证、邮箱换绑与密码修改入口 | 统一承接登录后的个人信息与少量账号设置 |
| `modules/account_access/permission_manager.R` | owner 邮箱授权、撤销权限、invite 与 owner 迁移入口 | 用户自助管理自己拥有的数据空间权限 |
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
| 任务历史    | `task_history.R` + `modules/common/auth/account_service.R` | 共享任务历史模块负责保存/加载入口、最近任务列表、用户自定义 note、删除操作与用户友好提示；底层使用 PostgreSQL `analysis_states` 表持久化模块完整参数、UI 状态与模块类型 JSON 快照，不保存图对象、结果对象或原始数据副本；快照只保留业务参数，不应混入 DT/Plotly 等派生交互输入，也不应保存配置折叠/页签这类导航态；旧任务恢复时也要跳过这些临时字段，避免加载任务触发未定义列、过滤异常或动态 UI 异步崩溃。`source_info`（JSONB）字段记录任务创建时使用的来源数据集信息（数据集名称、数据空间、行数/列数等），保存时由调用模块通过 `task_history_server(source_info = ...)` 传入，历史表格中展示"来源数据"列 |

### 7.4 生存分析当前实现口径

| 主题     | 当前实现                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 状态管理   | 采用 view state 与 committed state 分离，只有点击“生成图形”才提交分析参数                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 时间范围   | “处理与筛选”面板中的 X 轴最大值滑轴已统一复用 common 的 `graphics_time_axis_controls_ui()` + `graphics_render_time_range_slider()` 抽象；生存分析模块必须将 `time_range` 同时接入 `view_state`、committed state、任务历史 extra\_state 与回填链路，并同时作用于主图 `xlim`、统计文本定位和结果表时间过滤，不能只渲染滑块 UI 而不串通状态；动态 `renderUI` 重建滑轴时，`selected_range` 必须优先读取 `view_state$time_range` 以避免 UI 回退到默认最大值                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| 风险表    | 风险表主要用于静态图组合输出；交互页并不是“Plotly + 风险表”同页布局。当前已暴露 `risk_table_height_ratio`、`risk_table_plot_gap`、`risk_table_group_gap` 三个参数，分别控制风险表相对高度、主图与风险表之间的垂直留白、风险表分组行之间的额外扩展；默认值收紧为 `0.15 / 0 / 1.2`。风险表数字字号控件 `risk_table_fontsize` 现已统一改为与其他字号控件一致的 pt 口径，默认值为 `10`，内部再通过 common 换算成 `ggsurvplot` 风险表文本 size；风险表数字层、Y轴标签、主图统计文本与辅助图例当前统一复用同一 `base_family` 字体链路，并显式指定 `plain/bold` 字重，避免 risk 表数字出现无法受全局字体控制、比其他文本更粗的视觉偏差。风险表 Y 轴标签样式更新时必须保留 `ggsurvplot` 预设主题元素类型（例如 `element_markdown`），只能更新其字号/字体属性，不能直接用 `element_text` 覆盖，以避免 theme merge 报错；在分层场景下，risk table 顺序应保持 `ggsurvplot` 内置的 `y = rev(strata)` 映射，只允许在保留原 `breaks/labels` 结构的前提下做标签文案映射，不再额外通过 `scale_y_discrete(limits=...)` 重排分组顺序，也不要通过上游直接覆写 factor levels 的方式替换显示名，否则在自定义标签重复时会破坏组别与人数的对应关系；当用户选择 `Arial` 或沿用默认 `sans` 时，内部需先走设备安全解析，并在已注册时优先落到 `Noto Sans SC`，以兼顾 `cowplot/grid` 组合阶段的度量稳定性与中文显示能力 |
| 分层标签   | 主图图例、删失图例、统计文本、风险表与数据表统一复用同一标签格式化链路；比较符号及原始值中的 `=`, `>=`, `<` 必须原样保留并可映射自定义标签                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| 文本输入   | 图例标题、分层标签、中位生存时间标签、坐标轴标题等文本输入，只有真正的空串 `""` 才允许回退默认值；用户显式输入的纯空格 `"   "` 必须按原样保留，不能因 `trimws()` 被吞掉后再回退为默认文案                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 删失图例   | 交互图中的主图分组图例优先复用 `ggsurvplot` 默认图例能力，仅负责标题与标签定制；静态图则统一改为辅助图例方案：主图分组图例与删失图例都以 common 图例绘制器生成并组合，其中 Censor 图例在分层场景下必须优先复用主图最终 legend 颜色，确保删失符号颜色与曲线颜色一致。曲线上的删失点形状在所有分组中统一取自 `km_censor_shape`，不能因分组再次映射为圆形/三角等离散形状；静态图中主图分组图例固定在前、Censor 图例固定在后，且通过 common 的 inside-anchor/aux-legend 摆放抽象和公共 ratio 滑条控件控制紧凑间距与定位；图例自定义滑轨初始化值统一为 `X/Y/宽/高 = 0.95/0.85/0.13/0.14`，避免重复图例、原始 `变量=取值` 文本泄漏、颜色失配与 `Ignoring unknown labels` 警告。当前 `legend_row_gap` 已暴露到 UI，主图线条图例与删失图例必须共享同一 row-gap 参数，并在叠加时按各自真实行数动态分配高度，禁止再将删失图例行数硬编码为 `1`                                                                                                                                                                                                                                                                                                                                        |
| 统计文本   | 各组中位生存时间文本改为自由编辑标签，默认使用 `mPFS`，并统一左对齐；其组间距与 Cox 多组文本块保持一致的紧凑行距。统计文本自定义坐标统一复用 common 的比例坐标控件；统计摘要主开关 `show_stats` 统一控制 Log-rank 与 Cox HR 摘要是否显示，新增细粒度开关 `show_cox_p` 仅控制分层时 Cox 摘要行内的 P 值是否展示，不影响 HR 与 95%CI 计算；统计报告中三组以上时需明确 Log-rank 为全局检验，只表示至少一组与其他组存在差异，不代表所有两两比较均显著                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 坐标轴默认值 | X 轴标签默认填入 `Duration`，除非用户显式改写                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Y轴格式   | 当前已暴露 `y_break_step`、`y_decimals`、`y_as_percent`、`y_show_percent_sign` 参数：支持控制步长、小数位、是否按百分比显示、以及百分比场景下是否带 `%`；普通数值与百分比数值统一走 common 格式化函数，避免三图间显示口径分叉                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 中位线    | 当前已暴露 `surv_median_line` 选项，允许 `none / hv / h / v` 四种模式控制主图中位线显示                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| P值格式   | Log-rank 与生存分析内联 P 值统一采用 AMA 风格：`<0.001`、`>0.99` 或三位小数，避免 `P=0.000`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 交互页    | 当前以交互主图和单独结果页签为主                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| 尺寸配置   | 已接入统一尺寸接口；静态图、交互图与导出图共享同一尺寸模式，并新增页面距、画布边框和 PX/英寸同步换算。默认按 `96 px = 1 in` 保持前端与导出比例一致；包含下方轨道的图形在导出时也需按当前静态画布高度同步扩展导出高度，避免前端不截断但导出截断                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| 测试覆盖   | 已有选择解析、中位生存时间基线、view/committed 状态测试，并新增显示契约测试覆盖比较符号/等号标签、Cox 标签映射、删失图例颜色链路、辅助图例布局、删失符号一致性与 P 值格式                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |

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
- 森林图当前已补齐任务历史最小契约：统一通过 `graphics_build_task_state()` 保存 `data_mode`、列映射、原始数据分析字段、表格列选择、列显示名/对齐方式及导出参数，并通过 `apply_state()` + `graphics_restore_task_input_state()` 回填；当前进一步补齐首轮 UI 格局收口，外层已回正为 `数据与变量 / 图形与样式 / 输出与导出` + 结果区动作条。第二轮已开始把预处理列映射、标题文本、坐标显示、配色样式和导出参数切到 common helper，但 `precalculated/raw_data` 双模式与表格配置仍保留模块内业务结构，尚未达到蜘蛛图那种更深层 common 化程度。

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

| 文件                             | 当前职责                         |
| ------------------------------ | ---------------------------- |
| `data/data_io.R`               | 统一文件读取（CSV/Excel/SAS/SPSS），含 GBK 编码支持 |
| `data/data_registry.R`         | 统一数据空间注册表、池初始化和选择器刷新逻辑      |
| `data/data_metadata.R`         | 统一变量标签、类型推断、元数据回写            |
| `data/data_filter.R`           | 统一筛选 UI / server 与变量过滤行为     |
| `analysis/analysis_shared.R`   | 统一回归校验和结果组装                  |
| `analysis/analysis_format.R`   | 统一统计值、P 值、复现代码模板             |
| `graphics_common.R`            | 统一图形变量筛选、尺寸、图例绘制、坐标轴样式和标签格式化 |
| `graphics_repro.R`             | 图形复现代码                       |
| `export/plot_export.R`         | 图形导出                         |
| `export/table_export.R`        | 表格导出与样式注入                    |
| `storage_backend.R`            | 本地 / S3 数据存储抽象               |

### 9.2 当前共享层原则

- 共享层优先维护“统计口径、格式、元数据、导出、存储”这类跨模块不应分叉的逻辑。
- 子模块遇到公共需求时先扩展 common，再决定是否保留少量局部特例。
- 修改共享层时必须同步检查回归模块、图形模块和导出路径是否受影响。

### 9.3 当前可复用函数清单

| 主题                   | 文件                  | 当前可复用函数                                                                                                                                                                                                                                                                                                                                                          | 当前约束                                                                                                                                                                                                                                                       |
| -------------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 图例标题与位置枚举            | `graphics_common.R` | `graphics_resolve_legend_title()`、`graphics_legend_position_choices()`、`graphics_legend_controls_ui()`                                                                                                                                                                                                                                                           | 图例标题统一走 `custom > fallback > default`；位置值只能来自 common 枚举，子模块不得自造私有位置字符串                                                                                                                                                                                     |
| 图例锚点、ratio 滑条与辅助图例摆放 | `graphics_common.R` | `graphics_resolve_inside_anchor()`、`graphics_aux_legend_anchor_controls_ui()`、`graphics_place_aux_legend()`、`graphics_apply_legend_theme()`                                                                                                                                                                                                                      | 图内锚点必须先归一化；辅助图例位置、统计文本自定义坐标与 x/y/width/height ratio 控件优先复用 common；隐藏图例统一使用 `"none"`                                                                                                                                                                        |
| 辅助图例绘制器              | `graphics_common.R` | `graphics_aux_legend_compact_defaults`、`graphics_resolve_device_safe_family()`、`graphics_resolve_font_spec()`、`graphics_resolve_text_family()`、`graphics_build_legend_rows()`、`graphics_build_point_legend_plot()`、`graphics_build_line_legend_plot()`、`graphics_compose_stacked_legends()`                                                                      | 自绘辅助图例的行距、标题间距、外边距、组间 spacer 统一由 common 控制；收紧通用规则为所有图例的每个因子之间保持约一个字符大小的间距，且线条图例与删失图例必须复用同一 row-gap 约束；拼接多个辅助图例时必须按真实行数传入 `primary_rows / secondary_rows`，不得硬编码删失图例高度。涉及 `cowplot/grid` 组合测量时先做设备安全映射，再按文本内容选择拉丁/CJK 字体；单个文本 grob 若混排且无法拆分，应优先落到统一 CJK 覆盖字体 |
| 轴线、辅助线与标签格式          | `graphics_common.R` | `graphics_apply_axis_style()`、`graphics_collect_reference_line_spec()`、`graphics_add_reference_lines()`、`graphics_format_percent_labels()`、`graphics_format_number_labels()`                                                                                                                                                                                     | 经典 XY 轴样式、用户可配置辅助线、百分比显示、是否带 `%`、保留小数位数统一走 common；模块内不得各写一套刻度/辅助线拼装逻辑                                                                                                                                                                                      |
| 通用 UI 控件             | `common_ui_shell.R` | `graphics_reference_line_ui()`、`graphics_primary_action_button_ui()`、`graphics_output_action_bar_ui()`、`graphics_font_family_ui()`、`graphics_font_family_pair_ui()`、`graphics_export_size_controls_ui()`、`graphics_centered_output_container()`、`graphics_axis_range_controls_ui()`、`graphics_axis_tick_format_controls_ui()`、`graphics_time_axis_settings_ui()` | 高度重复的 UI 块（如参考线配置、主按钮、结果区动作条、字体族选择、尺寸/导出表单、输出区居中容器、坐标范围、刻度格式、时间轴单位换算）必须复用 common 控件，统一参数收集逻辑；复杂图形模块优先改用 `graphics_font_family_pair_ui()` 暴露“西文字体 + 中文字体”双配置，`graphics_font_family_ui()` 保留向后兼容与轻量场景                                                        |
| 通用 UI 状态收集           | `common_ui_shell.R` | `graphics_collect_axis_range_config()`、`graphics_collect_axis_tick_config()`、`graphics_collect_time_axis_config()`                                                                                                                                                                                                                                               | server 端若需收集上述 common UI 的值，应优先复用配套收集函数，避免模块内重复拼装输入解析                                                                                                                                                                                                      |
| 图形尺寸解析               | `graphics_common.R` | `graphics_px_to_in()`、`graphics_in_to_px()`、`graphics_scale_export_height()`、`resolve_plot_size_config()`、`graphics_collect_size_config()`、`graphics_apply_canvas_frame()`                                                                                                                                                                                       | 静态图、交互图、导出尺寸与画布边框/页面距统一从 common 解析；默认保持前端像素尺寸与导出英寸尺寸同步，模块内不得各自硬编码三套尺寸或手写导出高度换算                                                                                                                                                                             |
| 经典坐标轴线段              | `graphics_common.R` | `graphics_add_classic_axis_segments()`、`graphics_apply_axis_style()`                                                                                                                                                                                                                                                                                             | 需要自绘经典轴线或箭头轴线时，优先复用 common 线段拼装函数，避免模块继续复制 `annotate("segment") + lineend = "square"` 逻辑                                                                                                                                                                   |
| 图形说明文字               | `graphics_common.R` | `graphics_mapping_caption_line()`、`graphics_compose_caption()`、`graphics_append_bottom_caption()`                                                                                                                                                                                                                                                                | caption 统一由 common 拼接，禁止模块内再拼第二套底部说明逻辑                                                                                                                                                                                                                     |
| 元数据标签与类型             | `data_metadata.R`   | `metadata_get_var_label()`、`metadata_get_var_type()`、`metadata_build_column_choices()`、`metadata_attach_to_data()`                                                                                                                                                                                                                                               | 标签解析顺序固定为 `override > metadata表 > 列label > var_name`；元数据变更后必须重新回写到数据对象                                                                                                                                                                                     |
| 元数据底层推断              | `data_metadata.R`   | `metadata_determine_var_type()`、`metadata_coerce_var_data()`、`metadata_safe_numeric_range()`                                                                                                                                                                                                                                                                     | 字符变量低基数判定与日期/数值转换规则统一由 common 维护，子模块不得各写一套推断逻辑                                                                                                                                                                                                             |
| 统计格式化与复现模板           | `analysis_format.R` | `format_p_value_regression()`、`format_regression_stat()`、`build_repro_code_template()`                                                                                                                                                                                                                                                                           | 回归统计值、缺失占位符、复现代码模板统一走 common，禁止模块各自维护格式                                                                                                                                                                                                                    |
| 图形任务状态               | `graphics_common.R` | `graphics_build_task_state()`、`graphics_build_committed_task_state()`、`graphics_task_payload_input_state()`、`graphics_task_payload_extra_state()`、`graphics_restore_task_input_state()`                                                                                                                                                                        | 生成型图形应优先保存 committed 快照；需要保护已生成结果时，用 `graphics_build_committed_task_state()` 将已提交参数覆盖到 `input_state`，避免任务历史和复现代码保存未生成的 live input                                                                                                          |
| 图形复现代码               | `graphics_repro.R`  | `graphics_quote_value()`、`graphics_quote_vector()`、`graphics_quote_bool()`、`graphics_quote_bool_default()`、`graphics_quote_number()`、`graphics_quote_value_default()`、`graphics_first_non_null()`、`generate_graphics_repro_code()`                                                                                                                          | 图形复现代码输入必须来自 committed 状态快照；新增图形类型时必须补 common 入口分支。热图与相关矩阵复现代码必须与 UI 的 `stats::cor(..., use = "complete.obs")` 口径一致；热图聚类开关必须同步影响 UI 矩阵、数据表与复现代码；箱线图复现代码必须携带分组填色、调色板、线宽、线型与离群点大小；组合图复现代码必须使用真实 X/Y、分组、分面与动态图层样式，禁止生成 `aes(1, 1)` 占位图 |
| 表格样式与导出              | `table_export.R`    | `format_p_value_ama()`、`normalize_footnotes()`、`extract_table_dataframe()`、`apply_sci_gt_style()`                                                                                                                                                                                                                                                                | P 值显示、脚注清洗、gt 风格统一由 common 注入，禁止模块私有化导出样式                                                                                                                                                                                                                  |
| 图形导出                 | `plot_export.R`     | `build_plot_export_filename()`、`save_plot_export()`                                                                                                                                                                                                                                                                                                              | 导出文件名与支持格式统一由 common 维护；业务模块不得扩展不一致的私有导出参数                                                                                                                                                                                                                 |
| 存储抽象                 | `storage_backend.R` | `storage_backend_get()`、`storage_data_key_build()`、`storage_save_dataset()`、`storage_load_dataset()`、`storage_delete_dataset()`                                                                                                                                                                                                                                  | 数据体读写删除统一走 common；业务模块不得拼接本地/S3 细节路径                                                                                                                                                                                                                       |

### 9.4 后续开发收紧声明

- 发现图例、尺寸、P 值、标签、元数据、导出、存储需求时，先搜索 `modules/common/` 是否已有对应抽象；已有则必须复用，不得平行新建实现。
- 若现有 common 抽象只差少量参数或枚举，应优先扩展 common 函数签名，不得在子模块包一层同义变体长期并存。
- 子模块允许存在的特例，只限表现层细节且必须在指南中明确说明边界；一旦第二个模块需要同类能力，必须上提到 common。
- 新增或改动 common 函数时，至少同步更新本指南中的“可复用函数清单”和相关测试，确保后续开发按同一契约收紧。
- 若守卫测试或模块联调输出过长，优先采用“静态定位 + 最小验证”策略：先用 `Grep/Read` 锁定失败断言或可疑代码，再用 `testthat::test_file(..., reporter = "summary")` 跑目标测试文件，避免直接执行整份长输出脚本导致终端/沙盒卡住。
- 任务历史当前采用”共享模块先内嵌、一级导航后置”的演进策略：在统计图形/统计分析形成统一 `state/apply_state` 契约前，不直接迁移为左侧一级菜单。
- 任务历史载入的本质是”状态快照恢复”：当前由 `task_history.R` 解析 `state_payload`，再调用各业务模块的 `apply_state()` 回填控件；回填采用两阶段恢复策略——先设置模块类型触发动态 UI 渲染，再通过 `session$onFlushed()` 等待渲染完成后恢复子模块参数。
- 统计图形 9 个子模块、Tables 4 个子模块、统计分析 6 个子模块均已提供 `apply_state` 函数；统计分析模块的任务历史已从”仅保存方法类型”补齐为完整参数保存/回填（Review 7 修复）。
- `workspace_id` 现在根据当前用户的数据空间注册表自动解析，不再硬编码为 NULL。
- `analysis_states` 表新增 `source_info`（JSONB）字段用于记录任务创建时的来源数据集信息，`task_history_display_df` 在历史表格中展示”来源数据”列。
- 统一参数面板布局规范已按前端真实形态重置为“3 个顶层功能卡片 + 卡片内部子页签 + 独立结果区”，不允许再把 `数据与变量 / 图形与样式 / 输出与导出` 这 3 个顶层功能卡本身做成并列页签。
- 顶层功能卡固定为：
  - `数据与变量`：内部使用子页签承载 `核心映射` 与 `分组/分面/轨道/附加变量`。
  - `图形与样式`：内部使用子页签承载 `标题与说明 / 显示与坐标 / 图层样式 / 参考线与阈值`。
  - `输出与导出`：内部使用子页签承载 `尺寸与画布 / 导出参数`。
- 结果区固定为：
  - 动作条：`生成图形 / 下载图形`，统一放在结果区顶部，不放在参数区。
  - 结果页签：`静态图 / 交互图 / 数据 / 可复现代码`。
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
- 以下抽象块都必须遵循“归纳收紧”原则：
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
- 各模块当前状态摘要（详见 §7.7 现状表）：
  - `spider_plot.R`：普通面板已全部切换到 common，committed 参数快照已落地，三卡外层已回正。
  - `swimmer_plot.R`：committed 参数快照已落地，事件映射恢复链路已修复，三卡外层已回正。
  - `waterfall_plot.R`：committed 参数快照已落地，普通面板已全部切换到 common，三卡外层已回正。
  - `survival_analysis.R`：committed 参数边界已收紧，统计语义文案已明确，三卡外层已回正。
  - `boxplot.R`：三卡外层已回正，committed 快照已覆盖 task_history / 可复现代码状态；图形与样式控件覆盖分组填色、调色板、线宽、线型与离群点大小，固定 10×8 英寸导出。
  - `heatmap.R`：三卡外层已回正，committed 快照已覆盖 task_history / 数据表 / 可复现代码状态；聚类开关统一控制相关矩阵重排、数据表顺序与复现代码。
  - `correlation_matrix.R`：三卡外层已回正，committed 快照已覆盖 task_history / 数据表 / 可复现代码状态。
  - `combo_plot.R`：三卡外层已回正，committed 快照已覆盖 task_history / 可复现代码状态；复现代码使用真实 X/Y、分组、分面与动态图层样式，固定 12×8 英寸导出。
  - `forest_plot.R`：分析流水线完整下沉到 4 个 common helper，统一 result schema 已落地，`extra_state` 桥接 + pending restore 已建立。

### 7.7 UI 改进与职责边界现状

#### 7.7.1 UI 改进现状

各图形模块已按统一外层公共壳收口，现状如下：

| 模块 | 外层壳收口 | 参数卡片结构 | 结果区收口 | 任务历史回填 |
|------|----------|------------|---------|------------|
| statistical_graphics.R（总入口） | 统一入口壳 | 图形类型切换 + 代码卡 | 代码容器已收口 | 共享 `task_history` |
| survival_analysis.R（生存曲线） | 统一三卡外层 | 数据与变量 / 图形与样式 / 输出与导出 | 静态图/交互图/数据 | committed_params 快照 + apply_state 已标准化 |
| boxplot.R（箱线图） | 统一三卡外层 | 数据与变量 / 图形与样式 / 输出与导出 | 静态图/交互图/数据/可复现代码 | committed_params 快照 + apply_state 已标准化；样式状态进入复现代码 |
| forest_plot.R（森林图） | 统一三卡外层 | 数据与变量 / 图形与样式 / 输出与导出 | 静态图/交互图/数据（含数据预览/统计报告） | schema 桥接 |
| heatmap.R（热图） | 统一三卡外层 | 数据与变量 / 图形与样式 / 输出与导出 | 静态图/交互图/数据/可复现代码 | committed_params 快照 + apply_state 已标准化；聚类状态进入数据表与复现代码 |
| correlation_matrix.R（相关性矩阵） | 统一三卡外层 | 数据与变量 / 图形与样式 / 输出与导出 | 静态图/交互图/数据 | committed_params 快照 + apply_state 已标准化 |
| combo_plot.R（组合图） | 统一三卡外层 | 数据与变量 / 图形与样式 / 输出与导出 | 静态图/交互图/数据/可复现代码 | committed_params 快照 + apply_state 已标准化；动态图层状态进入复现代码 |
| swimmer_plot.R（泳道图） | 统一三卡外层 | 数据与变量 / 图形与样式 / 输出与导出 | 静态图/交互图/数据 | committed_params 快照 + apply_state 已标准化 |
| spider_plot.R（蜘蛛图） | 统一三卡外层 | 数据与变量 / 图形与样式 / 输出与导出 | 静态图/交互图/数据 | committed_params 快照 + apply_state 已标准化 |
| waterfall_plot.R（瀑布图） | 统一三卡外层 | 数据与变量 / 图形与样式 / 输出与导出 | 静态图/交互图/数据（瀑布数据/分组轨道数据） | committed_params 快照 + apply_state 已标准化 |
| tables.R（Tables 总入口） | 统一入口结果区 | 参数设置卡已收口 | 结果卡与导出说明已收口 | committed_params + task_history 已接入 |

#### 7.7.2 分析链路问题现状

**森林图边界最清晰**：已拆为 4 个 common helper 文件，主模块只保留 UI 编排、通知与结果消费，分析流水线已完整下沉。

**全部 9 个图形模块已具备 committed_params + apply_state 契约**：生存分析、箱线图、森林图最先标准化，随后蜘蛛图、泳道图、瀑布图跟进，组合图、热图和相关性矩阵最后补齐。所有模块均通过 `statistical_graphics.R` 路由器的 `task_history_server` 统一接入任务历史。

**仍存在的架构改进空间**：

1. **缺少统一结果 schema**：各子模块直接返回原始 plot 对象或内部散乱的 result list，无统一接口约束，导致跨模块复用困难。森林图已有 `forest_result_schema_helpers.R`，其余模块尚未跟进。
2. **分析链路耦合**：部分模块的 server 函数仍混有分析逻辑，尚未像森林图那样将分析流水线完整下沉到 common helper。
3. **公共 helper 利用率可继续提升**：图形参数抽象类（列映射、时间轴、导出）已在 common 层实现，部分模块仍有重复逻辑可继续收敛。

#### 7.7.3 改进优先级

**理想架构 vs 现状对比**：

| 层级 | 理想架构 | 当前现状 |
|------|---------|---------|
| UI 层 | 仅负责输入控件与布局编排 | 部分模块 server 仍混有分析逻辑 |
| 分析层 | 独立 helper 或 service，无状态依赖 | 森林图已完整下沉，其余模块仍有散落逻辑 |
| 结果层 | 统一 schema（如 forest_result_schema） | 各模块返回格式各异，无标准化消费接口 |
| 导出层 | 按当前画布高度同步扩展 | 组合图固定 12×8，其余模块已同步 |
| 任务历史 | 统一恢复契约 + schema 桥接 | 全部 9 个图形模块 + Tables 已接入 |

**改进优先级建议**：

- **短期**：各模块引入结果 normalizer，统一消费口径；参照森林图模式将分析链路逐步下沉到 common helper。
- **长期**：将高频调用的分析链路抽为 service（如 survival_analysis_pipeline）；进一步将 heatmap/correlation/combo 拆分为多个 common helper 文件。

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
| 分析状态    | PostgreSQL 表 `analysis_states`（含 `source_info` JSONB 来源数据集字段）          |
| 数据体     | 本地 `RDS` 文件或 S3 对象                                                             |
| 存储切换    | 通过 `STORAGE_BACKEND` 控制 `local` / `s3`                                         |
| S3 前置条件 | 必须安装 `aws.s3`，并设置 `STORAGE_S3_BUCKET`                                          |

### 10.2.0 数据库迁移

- 初始化建表由 `postgres/init.sql` 负责，仅在容器首次创建时通过 `/docker-entrypoint-initdb.d/` 自动执行。
- **增量迁移**由 `postgres/migrations/` 目录下的编号 SQL 文件承载，按序号顺序执行，每个迁移文件幂等（使用 `IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS` / DO 块守卫）。
- `postgres/migrate.ps1` 为迁移执行入口：自动检测运行中的 PostgreSQL 容器和凭据，逐文件应用 `migrations/` 下的 SQL，已应用的迁移自动跳过。
- 新增迁移文件命名规则：`NNN_descriptive_name.sql`（如 `001_analysis_states_schema.sql`），同时在 `migrate.ps1` 的迁移清单末尾追加新文件引用。

### 10.2.1 当前数据接入边界

- `database_manager.R` 当前支持单文件上传、批量上传和服务器目录导入。
- 服务器目录导入要求输入部署机器或容器可见的绝对路径，不等同于浏览器用户电脑上的本地目录。
- 服务器目录导入只面向系统管理员开放；在多用户能力真正落地前，不应向普通用户开放该入口。
- 当前仓库尚未实现 ZIP 数据空间导入；文档与功能描述不得把该能力写成已支持。

### 10.2.2 多用户目标边界

- 当前已支持用户自注册，并保留系统管理员账号。f
- 当前首期隔离粒度以“个人空间”为主，每个用户默认拥有独立数据空间边界。
- 架构上需预留后续按组织和项目扩展隔离的能力，但当前文档不得把组织/项目隔离写成既成事实。
- 数据权限首期落到 workspace 级别，再决定是否继续细化到 folder 或 dataset。
- 管理员初始化必须通过环境变量预置；当前不支持用“首个注册用户自动升级”为系统管理员。

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

测试资产按项目架构归类，完整索引、归类规则、回归入口与测试契约统一维护在 [TEST_GUIDE.md](TEST_GUIDE.md)。此处仅保留策略摘要：

- 新增功能或修改现有逻辑时，测试文件统一放在 `tests/`，并按项目架构落到对应子目录。
- 共享层改动至少要补一条可回归的最小测试；图形或统计口径改动优先补同口径断言。
- 统一回归入口：`run_auth_regression.ps1`（账号链路）、`run_app_test.ps1`（集成回归）。
- 索引校验：调整测试目录后执行 `Rscript tests/check_test_guide_index.R`。
- pre-commit 串联 `styler`、`lintr` 与守卫测试，前端文案守卫作为独立 hook 优先拦截。
- 当前缺口：`MMRM`/`MI` 占位菜单无对应测试（尚未落地）；2 个 legacy 脚本式验证待迁移为标准 testthat 用例。

## 12. 研发治理约束

### 12.1 架构红线

- 路由层保持轻量，不在 `statistical_analysis.R` 与 `statistical_graphics.R` 内堆叠复杂计算。
- 公共统计口径优先沉淀到 common 层，不允许多个子模块各自维护变体。
- 导出结果与页面结果保持同一语义、同一字段、同一排序逻辑。
- 新需求落地前先检索 common 抽象；若 common 已覆盖，不允许在子模块重写同义逻辑。

### 12.2 文档与测试红线

- 改实现必须同步改文档；改统计口径必须同步补测试。
- 新增测试文件统一进入 `tests/`，不新建 `test/` 目录。
- 共享层变更优先补回归测试，再做模块级功能扩展。
- 共享层新增或扩展函数时，必须同步更新 `PROJECT_GUIDE.md` 中的共享函数清单与使用约束。
- 图形模块如涉及尺寸、导出比例、页面距、画布边框或用户可配置辅助线，必须优先扩展 `graphics_common.R` / `common_ui_shell.R`，禁止在子模块单独维护另一套换算、容器样式或 `geom_hline/geom_vline` 拼装逻辑。

### 12.3 共享层优先级

1. `data_metadata.R` / `data_filter.R`：保证变量标签、类型、筛选逻辑一致。
2. `analysis_shared.R` / `analysis_format.R`：保证统计表口径与显示一致。
3. `graphics_common.R` / `common_ui_shell.R`：保证图形模块体验一致。
4. `storage_backend.R`：保证数据读写介质切换时业务模块无感。
