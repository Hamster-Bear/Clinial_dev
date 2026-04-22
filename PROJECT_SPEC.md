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
- **管理员页公共壳**: `admin_manager.R` 已接入 `modules/common/ui_shell.R` 公共卡片壳，统一系统入口卡、摘要卡、说明块与主要管理卡片视觉，但保持现有“摘要优先、明细随后”的信息结构、账号总览联动逻辑与协作预览 tab 结构不变。
- **统计分析总入口公共壳**: `statistical_analysis.R` 已接入 `modules/common/ui_shell.R` 公共卡片壳，统一全局筛选卡、方法选择卡、参数设置卡、结果卡与导出说明面板，但保持原有“统计表格 / 统计报告 / 可复现代码”结果结构，以及各统计子模块参数 UI 与分析逻辑不变。
- **统计分析子模块样板收口**: `desc.R` 与 `cox.R` 已作为第三阶段样板接入公共说明块与分组面板，当前只统一参数区视觉分组与说明，不调整输入项、动态输出、tooltip、建模逻辑或结果链路。
- **统计分析回归类子模块样板收口**: `logistic.R` 与 `linear.R` 已继续接入公共说明块与分组面板，当前只统一响应/分层、总计列或事件映射、预测变量与参考组等参数区视觉分组与说明，不调整输入项、动态输出、tooltip、建模逻辑或结果链路。
- **统计分析基础检验子模块样板收口**: `anova.R` 与 `chisq.R` 已继续接入公共说明块与分组面板，当前只统一响应变量、分组因素或变量选择等参数区视觉分组与说明，不调整输入项、检验逻辑或结果链路。
- **统计分析结果区收口**: `statistical_analysis.R` 的 `统计表格 / 统计报告 / 可复现代码` 三个结果 tab 与导出区已继续统一到结果 panel/空状态 helper；当前只统一结果容器、空状态与导出说明，不调整结果对象、报告生成或导出逻辑。
- **公共扩散源 UI 收口**: `modules/common/data_filter.R` 与 `modules/task_history.R` 作为多个入口复用的公共模块，当前已接入 `modules/common/ui_shell.R` 的公共卡片壳；本轮只统一可折叠工作台卡片、说明块与按钮区，不改变筛选语义、任务历史持久化与交互链路。
- **统计图形总入口公共壳**: `statistical_graphics.R` 已接入 `modules/common/ui_shell.R` 公共卡片壳，统一图形类型选择卡与可复现代码卡，并直接复用已收口的 `data_filter` / `task_history` 公共卡片；本轮只统一入口壳层与说明块，不调整图形子模块切换、任务历史回填或代码生成逻辑。
- **箱线图外层公共壳**: `boxplot.R` 应将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块；本轮只统一外层壳与结果容器，不调整 X/Y 映射、箱线图绘制、固定 `10 x 8` 英寸导出或任务历史契约。
- **生存分析外层公共壳**: `survival_analysis.R` 应将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块；本轮只统一外层壳与结果容器，不调整风险表、统计报告、提交态快照、任务历史或导出逻辑。
- **蜘蛛图外层公共壳**: `spider_plot.R` 应将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块；本轮只统一外层壳与结果容器，不调整时间轴换算、点层/末次标签、RECIST 阈值、committed 参数快照或导出逻辑。
- **泳道图外层公共壳**: `swimmer_plot.R` 应将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块；本轮只统一外层壳与结果容器，不调整事件映射、轨道变量、committed 参数快照、任务历史恢复或导出逻辑。
- **瀑布图外层公共壳**: `waterfall_plot.R` 应将参数区回正为 `数据与变量 / 图形与样式 / 输出与导出` 三张独立顶层卡片，并统一结果区卡片与说明块；本轮只统一外层壳与结果容器，不调整排序/轨道、RECIST 阈值、committed 参数快照、任务历史恢复或导出逻辑。
- **Tables 总入口公共壳**: `tables.R` 已接入 `modules/common/ui_shell.R` 公共卡片壳，直接复用已收口的全局筛选卡，并统一参数设置卡、结果卡与导出区说明块；本轮只统一入口壳层与说明块，不调整表格类型切换、动态参数 UI、生成或导出逻辑。
- **探索分析总入口公共壳**: `exploratory_analysis.R` 应统一变量托盘、图形控制器与图形输出三块入口卡片，并补充说明块与结果 panel；本轮只统一入口壳层与说明块，不调整变量映射、Plotly 渲染、错误提示或重置逻辑。
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
- **auth 服务域已落地**: 用户登录、注册、邮箱投递、workspace 授权与任务历史相关的共享后端能力，当前统一收口到 `modules/common/auth/`，至少包含 `auth.R`、`account_service.R`、`email_service.R`；新增认证/用户管理通用逻辑默认继续进入该目录，不再回铺到 `modules/common/` 根目录。
- **森林图图形 server 拆分暂缓**: 当前只收紧 helper 与目录声明，不直接改动图形模块内部 `server` 实现；后续若拆后端服务域，也优先进入 `modules/common/auth/` 等服务域目录，不再单独新增图形专属的 server 目录层级。
- **测试执行策略**: 对长输出守卫测试或联调脚本，优先采用“静态定位 + 最小验证”流程：先用代码检索定位失败范围，再使用 `testthat::test_file(..., reporter = "summary")` 执行目标测试文件，避免整份长输出脚本占满终端或造成沙盒卡住。
- **测试文档归类**: 整体性测试说明统一收口到根目录 `TEST_GUIDE.md`，按项目架构维护测试索引；`tests/` 目录只放测试代码、测试数据与少量待标准化的专项验证脚本，内部优先按项目结构分层到 `common / statistical_analysis / statistical_graphics / root / fixtures` 等同层语义目录。
- **测试索引校验**: 调整测试目录或新增测试后，需通过 `check_test_guide_index.R` 或对应守卫测试校验 `TEST_GUIDE.md` 与 `tests/` 实际文件是否一致，避免文档与目录漂移。
- **认证事务兼容边界**: 认证链路中的事务型写操作必须统一复用 `auth_with_transaction()`；应用运行时若传入 `pool::dbPool()`，内部需走 `pool::poolWithTransaction()`，测试脚本或迁移脚本传入普通连接时继续兼容 `DBI::dbWithTransaction()`，避免注册、邮箱验证、邮箱换绑与密码重置出现“实际已成功写入但界面误报失败”。
- **用户管理事务边界**: workspace 创建、成员授权、Owner 迁移、邀请登记/领取、账号状态开关、数据空间功能开关与任务历史覆盖保存等多步或状态型写操作，必须从 service 层进入并复用共享事务 helper；UI 层不得重新拼装事务细节。
- **认证回归补充要求**: 账号与认证回归除连接级 PostgreSQL 集成测试外，还应至少保留一条最小 `pool` 模式集成测试，优先覆盖注册及其他事务型写操作，防止 `pool` / 普通连接两条运行路径行为分叉。

## 3.1 研发工具链

- 当前仓库已补充 `.pre-commit-config.yaml`，用于串联 `styler`、`lintr` 与 `testthat` 守卫测试。
- `install_dependencies.R` 已将 `jsonlite`、`lintr`、`styler`、`shinytest2` 纳入开发依赖入口，便于本地和容器环境统一安装。

## 4. 权限模型

- 采用基于 Workspace 的隔离机制。
- 当前系统角色仅保留系统管理员与普通用户两类。
- 系统管理员负责账号状态、数据空间功能开通、数据库信息查看和服务器目录导入等系统级能力，但不得读取、浏览或导出其他用户数据空间中的实际数据；该限制是服务层保密底线。
- 普通用户默认按个人 Workspace 隔离；仅能访问自己拥有或被授权的数据空间。
- 普通用户未开通数据空间功能时，仅允许单文件临时上传；上传数据只用于当前会话分析，不写入持久化数据空间。
- 新注册账号当前允许先注册并直接登录；邮箱验证改为登录后的用户信息区自助完成，验证码默认 6 位，测试环境通过 `EMAIL_DELIVERY_MODE=console` 暴露，生产环境需在接入真实邮件投递后再开启外发。
- 认证相关事务写操作必须同时兼容应用运行时的 `pool` 和测试/脚本中的普通连接；新增注册、验证码、密码或用户状态相关写逻辑时，不得直接对 `pool` 调用 `DBI::dbWithTransaction()`。
- 登录页底部应将“注册账号 / 忘记密码”呈现为更明显的按钮式次级操作；登录后的侧边栏应保留“用户和权限”这一概念入口，但账号入口相关的按钮标签、卡片摘要与快捷按钮文案统一以 `modules/common/auth/auth_copy.R` 中的 `ACCOUNT_ENTRY_COPY` 为唯一源，规范文档只描述结构职责，不重复维护按钮或摘要原句。结构上，侧边栏入口必须收口到个人信息卡中，`user_profile` 只保留基础用户信息与少量信息变更控件，如绑定邮箱、邮箱换绑和修改密码；`access_permissions` 按权限分支展示协作权限或“我的已授权空间”，且无可管理空间时必须展示非空态说明。
- `用户信息` 与 `权限管理` 必须采用文件夹级模块拆分与独立渲染、独立兜底；任一侧的查询失败、组件异常或分支切换都不得导致另一侧卡片消失。
- 侧边栏个人信息卡必须抽成独立模块，并在模块内写入隐藏内部页签的 CSS 防误改规则；`user_profile` 与 `access_permissions` 只允许作为内部跳转目标，不允许重新外露为侧边栏菜单。
- 账号页前端布局应优先采用“概览优先 + 工作台聚合”模式：`user_profile` 首屏主卡必须直接展示页面说明与账号身份、邮箱、验证状态等概览统计，不得只保留标题说明卡；随后再用单一安全工作台聚合验证、换绑与改密。`access_permissions` 先用概览卡展示可管理/已授权空间摘要，再用单一协作工作台聚合成员协作、负责人迁移与成员/邀请预览，避免继续堆叠多张平行功能卡。
- 账号页聚合布局中的工作台标题、概览标题与标签页文案也必须继续复用 `modules/common/auth/auth_copy.R`，避免优化过程中重新引入多处平行文案源。
- 账号页工作台表单中的动作按钮必须优先采用公共紧凑动作区样式，与上方输入框保持同一卡片节奏；桌面端不得默认使用满宽按钮撑满整块表单，移动端可按响应式规则退化为整行堆叠。
- 认证页、账号设置区与系统管理页的新增 UI 默认必须复用 `modules/common/ui_shell.R` 的公共卡片壳、说明块与按钮语言；若确需偏离，必须先更新规范文档并同步守卫测试。
- 密码重置默认采用 6 位重置验证码闭环；测试环境通过 `EMAIL_DELIVERY_MODE=console` 暴露，过期时间由 `AUTH_PASSWORD_RESET_EXPIRE_MINUTES` 控制，生产环境需在接入真实邮件投递后再对外开放。
- 邮箱换绑默认采用“当前密码确认 + 新邮箱 6 位验证码确认”闭环；只有验证成功后才更新主邮箱，并应在切换后自动尝试认领该邮箱名下待领取的 workspace 邀请。
- 邮件投递基础设施需通过独立 `email_service` 抽象承载，至少支持 `console / disabled / smtp` 三种模式；认证流程不得直接在业务逻辑内硬编码控制台或 SMTP 调用。
- 系统管理员入口应提供 SMTP 连通性探针能力，用于向测试邮箱发送探针邮件并验证真实邮件投递配置与失败提示链路。
- SMTP 连通性探针界面应保留最近一次执行结果，至少展示状态、目标邮箱、执行时间与结果说明，避免部署验收只依赖瞬时弹窗。
- 管理员初始化必须通过环境变量 `APP_ADMIN_USERNAME`、`APP_ADMIN_EMAIL`、`APP_ADMIN_PASSWORD` 预置，不支持首个注册用户自动升级。
- 管理员环境变量视为引导权威输入：应用启动时若数据库中已存在同邮箱或同用户名账号，应同步校准用户名、邮箱、密码摘要、管理员身份、数据库管理开关与 `active` 状态；若邮箱与用户名分别命中不同账号，必须拒绝静默同步并先清理历史记录。
- 当前登录态应定时刷新用户状态与数据库管理开关，使管理员调整账号状态或数据空间功能开关后，用户侧菜单、默认落点与卡片快捷按钮能在当前会话内跟进。

## 5. 部署形态

- 容器化部署：提供 Docker Compose 编排文件（Local/Server 场景）。
- 离线支持：通过 `download_offline_packages.R` 支持内网环境依赖安装。
