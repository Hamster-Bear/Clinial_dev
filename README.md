# R Shiny医学数据分析应用

一个专业的医学数据分析平台，提供从数据准备到高级统计分析和可视化的完整工作流程。

## 功能特性

- **数据准备**: 支持CSV、Excel、SPSS格式，智能变量类型识别，数据匿名化处理
- **智能表格筛选**: Reactable表格支持智能列类型识别和专用筛选器，使用JavaScript高性能筛选引擎
- **探索分析**: 交互式可视化，支持散点图、箱线图、直方图、条形图
- **统计分析**: 包含描述性统计、Cox回归、逻辑回归、线性回归、ANOVA、卡方检验、CMH检验
- **统计图形**: 生存曲线、森林图、热图、相关性矩阵等出版级图形
- **导出功能**: 支持Word文档和高质量图片导出

图形显示口径、共享图例能力、风险表参数与 Y 轴格式规则请以 `PROJECT_GUIDE.md` 为准。

## 安装和运行

### 方法一：使用自动安装脚本（推荐）

1. **安装依赖包**:
   ```r
   source("install_dependencies.R")
   ```

2. **启动应用**:
   ```r
   source("run_app.R")
   ```

### 方法二：手动安装和运行

1. **手动安装所需包**:
   ```r
   install.packages(c(
     "shiny", "shinydashboard", "shinyjs", "shinyBS", "bslib",
     "dplyr", "readr", "readxl", "haven", "purrr", "stringr",
     "ggplot2", "plotly", "DT", "gt", "survival", "broom", 
     "survminer", "corrplot"
   ))
   ```

2. **运行应用**:
   ```r
   shiny::runApp("app.R")
   ```

### 方法三：部署入口摘要

Docker 与服务器部署细节已统一迁移到 `DEPLOYMENT_GUIDE.md`，README 只保留入口摘要：

| 场景 | 入口 | 访问方式 | 详细说明 |
| --- | --- | --- | --- |
| 本地开发直跑 | `run_app.R` | 默认 `http://127.0.0.1:8109` | 适合单机开发与问题定位 |
| 基础 Docker Compose | `docker-compose.yml` | `http://localhost` | 适合基础开发编排 |
| 本地联调 | `docker-compose.local.yml` | `http://localhost:8080` | 含 Landing 页，应用入口为 `/app/` |
| 服务器生产 | `docker-compose.server.yml` | `https://<domain>` | 需要证书、镜像与 `.env` |

#### 详细文档入口

- 部署细节、镜像构建与保存、目录结构、挂载关系、环境变量、服务器流程：`DEPLOYMENT_GUIDE.md`
- 项目架构、模块职责、部署矩阵与实现边界：`PROJECT_GUIDE.md`
- 测试资产索引、按架构归类的测试清单与回归入口：`TEST_GUIDE.md`

### 当前访问与账号边界

- 当前 `/app/` 已实现应用内自注册、登录、退出与 workspace 级权限过滤。
- 当前登录、注册与忘记密码已拆为独立页面状态；登录页仅保留登录主流程，注册页只负责创建账号，忘记密码改为独立找回流程。
- 登录页底部当前显式提供“注册账号 / 忘记密码”入口；“忘记密码”通过隐藏页签切到独立找回页，避免首页堆叠多张卡片。
- 登录页底部的“注册账号 / 忘记密码”当前已改为更明显的按钮式次级操作，提升首屏可发现性。
- 当前邮箱验证默认收口为“注册后生成 6 位验证码、登录前完成验证”；本地/测试环境默认通过 `EMAIL_DELIVERY_MODE=console` 输出验证码，可配合 `AUTH_DEV_SHOW_EMAIL_CODE=1` 直接在日志与提示中查看验证码。
- 当前邮箱验证已移到登录后的用户信息区，改为用户自行触发和完成，不再阻断注册或登录；本地/测试环境默认通过 `EMAIL_DELIVERY_MODE=console` 输出验证码，可配合 `AUTH_DEV_SHOW_EMAIL_CODE=1` 直接在日志与提示中查看验证码。
- 原“用户和权限”入口当前已拆为侧边栏个人信息卡中的两个独立按键：`用户信息` 与 `权限管理`，不再直接作为侧边栏菜单暴露。`用户信息` 页只保留基础用户信息与少量信息变更控件，如绑定邮箱、邮箱换绑和修改密码；`权限管理` 页按权限分支展示：Owner 继续看到 workspace 协作权限管理卡，被授予 viewer/editor 的普通用户会看到“我的已授权空间”信息卡；若两者都没有，页面会保留明确的非空态说明。
- 侧边栏个人信息卡当前已抽成独立模块，并在模块内维护隐藏内部页签的 CSS 守卫，避免 `用户信息` 与 `权限管理` 被误改成直接可见的侧边栏菜单项。
- 当前忘记密码已改为独立找回页：用户可申请 6 位重置验证码并完成重置；本地/测试环境同样通过 `EMAIL_DELIVERY_MODE=console` 输出验证码，过期时间由 `AUTH_PASSWORD_RESET_EXPIRE_MINUTES` 控制。
- 当前已支持登录后邮箱换绑：用户需先输入当前密码，再向新邮箱发送 6 位换绑验证码，验证成功后才会正式切换主邮箱；换绑成功后会自动尝试认领该邮箱名下待领取的协作邀请。
- 当前邮件投递已抽象为 `modules/common/auth/email_service.R`：默认保留 `console/disabled` 模式，并新增 `smtp` 模式；启用真实发信时需补齐 `EMAIL_FROM_ADDRESS`、`SMTP_HOST`、`SMTP_PORT`、`SMTP_USERNAME`、`SMTP_PASSWORD`、`SMTP_USE_SSL`。
- 管理员页现已补充 `SMTP 连通性测试` 卡片，可向测试邮箱发送探针邮件；建议在预发环境先验证 `smtp` 投递成功、失败提示和收件链路，再切正式环境。
- `SMTP 连通性测试` 卡片当前会保留最近一次探针结果，展示成功/失败状态、目标邮箱、执行时间与结果说明，方便部署验收和排障留痕。
- 认证主体区域已抽到 `auth_manager.R`；当前用户信息、退出入口与普通用户的“权限管理”快捷入口已合并到侧边栏卡片中。
- 登录页、找回密码页与侧边栏账号设置区现已对齐到与管理员页一致的公共卡片壳风格；后续凡新增认证、账号设置或系统入口相关 UI，默认都应复用 `modules/common/ui_shell.R` 的公共卡片壳与按钮语言，不再新增平行风格。
- 当前登录态会定时从数据库刷新用户状态与数据库管理开关；管理员刚调整权限后，用户侧菜单、默认落点与卡片快捷按钮会在当前会话内跟进，不再长期停留在旧登录快照。
- 侧边栏用户卡片右上角快捷按钮现统一收口为：系统管理员固定跳转“系统管理”，已开通数据空间功能的普通用户固定跳转“数据空间”，未开通时保留“临时上传”；若用户名下已有可管理数据空间，卡片底部继续保留“权限管理”入口。
- 未登录状态下仅显示登录/注册入口；进入工作台前不展示业务侧边栏。
- 当前工具声明为：不负责数据安全、数据传到服务不保证安全，请使用方自行妥善保管数据；如需更高保障，可提供独立部署服务。
- 当前“服务器目录导入数据空间”仅适用于部署机器或容器内可见的绝对路径，不支持直接读取浏览器用户电脑上的本地文件夹，且该入口只面向系统管理员开放。
- 当前系统角色口径仅保留系统管理员与普通用户；多用户实现默认按个人隔离，数据权限先落到 workspace 级别。
- 系统管理员负责账号状态、数据空间功能开通和服务器目录导入等系统级能力，但不得读取、浏览或导出其他用户数据空间中的实际数据；这条约束是上线后的服务层保密底线。
- 管理员账号必须通过环境变量预置 `APP_ADMIN_USERNAME`、`APP_ADMIN_EMAIL` 与 `APP_ADMIN_PASSWORD`；未配置时不自动提升首个注册用户。
- 管理员环境变量当前视为引导权威输入：启动时若数据库中已存在同邮箱或同用户名账号，会同步校准用户名、邮箱、密码摘要、管理员身份、数据库管理开关与 `active` 状态；若邮箱与用户名分别命中不同账号，则拒绝静默同步并要求先清理历史记录。
- 当前已提供管理员操作入口；workspace、membership、invite 与 owner 迁移能力已统一下沉到 service 层。
- workspace 创建与删除也统一复用 `modules/common/auth/account_service.R`，避免数据库管理页继续直连 owner / membership 迁移细节。
- 普通用户可对自己拥有的数据空间进行权限管理，且授权、撤销与 owner 迁移统一通过邮箱输入完成，不通过下拉选择数据库中的用户。
- 管理员页保持独立系统入口，不并入侧边栏用户卡片；账号状态调整与数据空间功能开关继续集中在管理员页，数据空间负责人迁移与协作授权现统一收口到单一“数据空间管理”卡片，且仍仅限当前管理员自己名下可管理的数据空间。
- 管理员页现补充信息型增强：顶部系统概览、运行环境摘要、目标账号状态卡片、操作影响预览，以及“我名下数据空间概览”，用于强化管理决策与排障信息，但不扩大权限边界。
- 管理员页前端展示现按“摘要优先、明细随后”收拢：顶部优先展示系统概览、异常态势与运行环境，中段展示注册账号总览，底部再承接具体管理动作与空间明细。
- 系统概览、异常态势摘要与账号状态管理中的状态卡现统一切到紧凑统计卡布局，在同等信息量下压缩留白并提高首屏可读性。
- 管理员页现已接入 `modules/common/ui_shell.R` 公共卡片壳：统一系统入口卡、摘要卡、说明块与主要管理卡片视觉，但保持现有摘要优先布局、账号总览联动逻辑与协作预览 tab 结构不变。
- 管理员页中的账号状态管理已与“所有注册账号总览”联动：系统管理员在总览表中选中账号后即可直接启用、停用或开关数据空间功能，不再手工输入邮箱定位账号。
- 管理员页现已补充“异常态势摘要”，集中展示停用账号、未设置邮箱账号、未开通数据空间功能账号、待领取邀请与未注册邀请邮箱等风险项，仍只基于元信息判断，不展示其他用户实际数据内容。
- 管理员页的异常态势摘要现支持页内快捷跳转，可直接定位到账号状态管理、数据空间管理与我名下数据空间概览；在数据空间管理场景下可进一步聚焦负责人邮箱或协作者邮箱输入框，并在协作相关场景切换到相关预览 tab，不新增任何权限入口。
- 管理员页现已补充“所有注册账号总览”，通过摘要卡、预设筛选按钮与总览表结合的方式展示所有已注册账号的元信息、数据空间功能状态、待领取邀请、名下数据空间数与当前可访问空间数；该总览只基于元信息，不展示其他用户实际数据内容。
- 权限预览表与管理员 membership 预览表已改为面向业务的中文列名，不再直接暴露数据库字段名。
- 数据库管理页已按“空间与目录 / 上传与导入 / 结构总览”三段重组，减少单页堆叠操作。
- 数据库管理功能已增加账号级访问锁：普通账号默认锁定，需由管理员开放数据库管理权限后才可进入与操作。
- 未开通数据空间功能的普通用户登录后默认落到“数据准备”页；侧边栏“数据空间”显示“需授权”，“数据准备”显示“临时上传”，数据库管理锁定卡片会提示改走临时上传链路。
- 普通用户在未开通数据空间功能时，只允许单文件临时上传；该数据仅用于当前会话分析，不写入持久化数据空间，服务重启或会话结束后不保证保留。
- 前端卡片样式开始收口到新的公共 UI 壳 `modules/common/ui_shell.R`；当前已从数据预备模块先接入，统一卡片标题、说明区、边框和留白，但暂不改变原有布局结构。
- 公共卡片壳现已继续接入数据库管理页：统一工作台主卡片、说明块、锁定提示、上下文摘要与结构总览摘要卡，但保持原有“空间与目录 / 上传与导入 / 结构总览”页签结构不变。
- 公共卡片壳现已继续接入数据库管理页：统一工作台主卡片、说明块、锁定提示、上下文摘要与结构总览摘要卡，但保持原有“空间与目录 / 上传与导入 / 结构总览”页签结构不变。
- 公共卡片壳现已继续接入统计分析总入口：统一全局筛选卡、方法选择卡、参数设置卡、结果卡与导出说明面板，但保持原有“统计表格 / 统计报告 / 可复现代码”结果结构以及各统计子模块参数 UI、分析逻辑不变。
- 统计分析子模块第三阶段样板已落到 `desc.R` 与 `cox.R`：统一参数区说明块与分组面板，但保留原有输入项、动态输出、tooltip、建模逻辑与结果链路不变。
- 统计分析回归类子模块样板已继续落到 `logistic.R` 与 `linear.R`：统一响应/分层、总计列或事件映射、预测变量与参考组分区，但保留原有输入项、动态输出、tooltip、建模逻辑与结果链路不变。
- 统计分析基础检验子模块样板已继续落到 `anova.R` 与 `chisq.R`：统一响应变量、分组因素或变量选择说明块，但保留原有输入项、检验逻辑与结果链路不变。
- 统计分析结果区当前已继续统一：`统计表格 / 统计报告 / 可复现代码` 三个 tab 现统一使用结果 panel 和空状态 helper，导出区也统一为结果区说明面板，但不调整结果对象、报告生成与导出逻辑。
- 第一批 UI 归一当前已接入公共扩散源：`modules/common/data_filter.R` 与 `modules/task_history.R` 已统一到公共壳下的可折叠工作台卡片，减少旧式 `box()` 壳继续扩散到统计分析、统计图形与 Tables 入口。
- 统计图形总入口当前已接入公共卡片壳：统一图形类型选择卡与可复现代码卡，直接复用已收口的全局筛选卡与任务历史卡，但保持原有图形子模块切换、任务历史回填和代码生成链路不变。
- 箱线图外层当前已接入公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有 X/Y 映射、固定 `10 x 8` 英寸导出与任务历史契约不变。
- 组合图外层当前已接入公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有高动态图层参数页签、两阶段任务历史恢复与固定 `12 x 8` 英寸导出链路不变。
- 生存分析外层当前已接入公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有风险表、统计报告、提交态快照与导出链路不变。
- 森林图外层当前已接入公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有 `precalculated/raw_data` 双模式、列配置、统计报告与导出链路不变。
- 蜘蛛图外层当前已接入公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有时间轴换算、点层/末次标签、RECIST 阈值与 committed 参数快照链路不变。
- 泳道图外层当前已接入公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有事件映射、轨道变量、committed 参数快照与导出链路不变。
- 瀑布图外层当前已接入公共卡片壳：将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块，但保持原有排序/轨道、RECIST 阈值、committed 参数快照与导出链路不变。
- Tables 总入口当前已接入公共卡片壳：直接复用已收口的全局筛选卡，并统一参数设置卡、结果卡与导出区说明块，但保持原有表格类型切换、动态参数 UI、生成与导出链路不变。
- 探索分析总入口当前已接入公共卡片壳：统一变量托盘、图形控制器与图形输出三块入口卡片，补充说明块与结果 panel，但保持原有变量映射、Plotly 输出与重置链路不变。
- `run_app_test.ps1` 对应的测试环境变量示例已写入 `.env.test.example`；`docker-compose.local.yml` 现直接读取 `.env.test`，与本机测试脚本共用同一套 PostgreSQL 与管理员参数；本地若使用 `docker-compose.local.yml` 或 `docker-compose1.yml` 拉起 PostgreSQL，宿主机测试端口统一使用 `5432`，默认管理员示例为 `admin / admin@example.com / admin123`。
- `docker-compose1.yml` 当前收口为轻量测试基础设施栈，只启动 PostgreSQL 与 Redis，并复用宿主机 `5432/6379`；用于项目更新期间避免反复重建整套应用镜像时，仍可让本机 `run_app.R` / `run_app_test.ps1` 直接连库跑业务测试。
- 账号与权限模块已补充 PostgreSQL 集成测试 `tests/common/auth/test_auth_access_postgres_integration.R`；测试会优先读取 `.env.test`，并在隔离 schema 中验证管理员初始化、workspace 访问边界与清理逻辑，避免污染现有数据。
- 管理员页另补充了按需启用的 `shinytest2` smoke test `tests/admin_manager/test_admin_manager_smoke_shinytest2.R`；仅在显式设置 `RUN_ADMIN_SMOKE=1` 且本地具备 `.env.test`、管理员账号与 `shinytest2` 依赖时运行，用于验证管理员登录、进入系统管理页与关键信息区块加载。
- 管理员页另补充了静态布局守卫 `tests/admin_manager/test_admin_manager_layout_guard.R`，用于约束“数据空间管理”卡片收口、紧凑统计卡样式与统一空间选择器不回退。
- 账号页另补充了按需启用的 `shinytest2` smoke test `tests/account_access/test_account_access_smoke_shinytest2.R`；仅在显式设置 `RUN_ACCOUNT_ACCESS_SMOKE=1` 且本地提供普通用户 smoke 账号环境变量时运行，用于验证登录后切换 `用户信息` / `权限管理` 以及聚合工作台可见性。
- 统计分析总入口当前补充了布局守卫 `tests/statistical_analysis/ui/test_statistical_analysis_layout_guard.R`，用于约束公共卡片壳接入后继续保留结果区页签结构、导出入口与动态参数输出链路。
- 统计分析子模块当前补充了 UI 守卫 `tests/statistical_analysis/ui/test_statistical_analysis_submodule_ui_guard.R`，用于约束 `desc.R` 与 `cox.R` 持续保留参数分区、动态输出与公共壳 helper 接入。
- 统计分析回归类子模块当前补充了 UI 守卫 `tests/statistical_analysis/ui/test_statistical_analysis_regression_submodule_ui_guard.R`，用于约束 `logistic.R` 与 `linear.R` 持续保留参数分区、动态输出与公共壳 helper 接入。
- 统计分析基础检验子模块当前补充了 UI 守卫 `tests/statistical_analysis/ui/test_statistical_analysis_basic_submodule_ui_guard.R`，用于约束 `anova.R` 与 `chisq.R` 持续保留最小参数分区与公共壳 helper 接入。
- 统计分析结果区当前补充了 UI 守卫 `tests/statistical_analysis/ui/test_statistical_analysis_result_ui_guard.R`，用于约束结果 tab、空状态与导出说明块继续复用统一 helper。
- 公共扩散源当前补充 UI 守卫 `tests/common/ui/test_data_filter_card_ui_guard.R` 与 `tests/common/ui/test_task_history_card_ui_guard.R`，用于约束 `data_filter.R`、`task_history.R` 持续保留公共壳、默认折叠行为与主要交互入口。
- 入口层当前补充 UI 守卫 `tests/statistical_graphics/ui/test_statistical_graphics_layout_guard.R` 与 `tests/tables/test_tables_layout_guard.R`，用于约束 `statistical_graphics.R` 与 `tables.R` 持续保留公共壳入口结构、复用公共筛选/任务历史模块，并避免回退为入口层裸 `box()`。
- 生存分析外层当前补充 UI 守卫 `tests/statistical_graphics/survival/test_survival_layout_guard.R`，用于约束 `survival_analysis.R` 持续保留三张顶层功能卡、结果区动作条与 `静态图 / 交互图 / 数据` 结构，并避免回退为外层裸 `box()` / `wellPanel()`。
- 组合图外层当前补充 UI 守卫 `tests/statistical_graphics/combo/test_combo_layout_guard.R`，用于约束 `combo_plot.R` 持续保留三张顶层功能卡、结果区动作条与 `静态图 / 交互图 / 数据` 结构，并避免回退为外层裸 `box()` / `wellPanel()`。
- 箱线图外层当前补充 UI 守卫 `tests/statistical_graphics/boxplot/test_boxplot_layout_guard.R`，用于约束 `boxplot.R` 持续保留三张顶层功能卡、结果区动作条与 `静态图 / 交互图 / 数据` 结构，并避免回退为外层裸 `box()` / `wellPanel()`。
- 森林图外层当前补充 UI 守卫 `tests/statistical_graphics/forest/test_forest_layout_guard.R`，用于约束 `forest_plot.R` 持续保留三张顶层功能卡、结果区动作条与 `静态图 / 交互图 / 数据` 结构，并避免回退为外层裸 `box()` / `wellPanel()`。
- 蜘蛛图外层当前补充 UI 守卫 `tests/statistical_graphics/spider/test_spider_layout_guard.R`，用于约束 `spider_plot.R` 持续保留三张顶层功能卡、结果区动作条与 `静态图 / 交互图 / 数据` 结构，并避免回退为外层裸 `box()` / `wellPanel()`。
- 泳道图外层当前补充 UI 守卫 `tests/statistical_graphics/swimmer/test_swimmer_layout_guard.R`，用于约束 `swimmer_plot.R` 持续保留三张顶层功能卡、结果区动作条与 `静态图 / 交互图 / 数据` 结构，并避免回退为外层裸 `box()` / `wellPanel()`。
- 瀑布图外层当前补充 UI 守卫 `tests/statistical_graphics/waterfall/test_waterfall_layout_guard.R`，用于约束 `waterfall_plot.R` 持续保留三张顶层功能卡、结果区动作条与 `静态图 / 交互图 / 数据` 结构，并避免回退为外层裸 `box()` / `wellPanel()`。
- 探索分析入口当前补充 UI 守卫 `tests/exploratory_analysis/test_exploratory_analysis_layout_guard.R`，用于约束 `exploratory_analysis.R` 持续保留三块入口卡、变量托盘输出、图形类型选择与 Plotly 输出链路，并避免回退为入口层裸 `box()`。
- 发布前可执行 `run_auth_regression.ps1` 作为账号模块统一回归入口；脚本会校验 `.env.test` 中的 PostgreSQL 与管理员变量，并按 `tests/common/auth/auth_regression_manifest.json` 的固定顺序运行账号 helper、文档守卫和 PostgreSQL 集成测试。

### 当前阶段风险与优化建议

- 技术风险：当前权限粒度仍主要落在 workspace 级别，`viewer` / `editor` 在数据写操作上的边界尚未完全拉开；数据库管理锁目前仍是账号级开关。
- 维护风险：邮箱邀请已落地，但尚未接入真实邮箱验证与失效策略，存在误填邮箱后人工排障成本；普通用户与管理员两套权限入口也需要持续保持文案一致。
- 项目风险：owner 迁移与协作能力已进入主流程，若后续继续扩展共享模型，需要尽快补齐审计日志与操作留痕。
- 立即可做：补充 membership / invite / owner 迁移的数据库级集成测试，并明确 `viewer` / `editor` 的读写边界；继续验证新数据库管理布局与数据库管理锁在高频操作下的可达性。
- 中长期建议：引入邮箱验证、邀请有效期、操作审计日志，并评估组织级 / 项目级协作模型。
- 工具链建议：在现有 `tests/` 守卫测试之外持续维护基于 PostgreSQL 测试库的自动化回归，并把 `run_auth_regression.ps1` 与 `check_test_guide_index.R` 一并纳入发布前固定校验入口。

## 依赖管理

项目提供了专门的依赖管理脚本来简化安装过程：

### install_dependencies.R
- 自动检查已安装的包
- 安装缺失的依赖包
- 验证包加载状态
- 可随时运行以确保环境完整

### run_app.R  
- 自动检查依赖并安装缺失包
- 加载所有必需的包
- 启动Shiny应用
- 设置默认端口(8109)和主机(127.0.0.1)

## 项目结构

完整目录结构、模块职责与部署边界请参考 `PROJECT_GUIDE.md`。README 只保留最小入口摘要：

```
AutoTFL/
├── app.R
├── install_dependencies.R
├── run_app.R
├── README.md
├── PROJECT_GUIDE.md
├── DEPLOYMENT_GUIDE.md
├── Dockerfile
├── docker-compose.yml
├── docker-compose.local.yml
├── docker-compose.server.yml
├── modules/
├── nginx/
├── postgres/
├── deploy/
└── tests/
```

## 更新依赖

当项目添加新功能或新的包依赖时，需要更新依赖管理脚本：

1. 编辑 `install_dependencies.R` 中的 `required_packages` 列表
2. 编辑 `run_app.R` 中的 `required_packages` 列表
3. 运行 `source("install_dependencies.R")` 来安装新依赖

## 使用示例

1. 上传数据文件（支持.csv, .xlsx, .sav格式）
2. 在数据准备页面进行变量类型确认和预处理
3. 在探索分析页面进行交互式数据探索
4. 在统计分析页面选择适当的统计方法进行分析
5. 在统计图形页面生成出版级可视化图形
6. 导出分析结果和图形

## 技术支持

如果遇到包安装问题，请确保：
- R版本 ≥ 4.0.0
- 有稳定的网络连接访问CRAN仓库
- 系统有足够的权限安装包

对于survminer包的安装问题，可能需要从GitHub安装：
```r
if (!require("survminer")) {
  install.packages("devtools")
  devtools::install_github("kassambara/survminer")
}
```

## 许可证

本项目仅供学习和研究使用。

