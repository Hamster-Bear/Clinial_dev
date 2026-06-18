# AutoTFL 项目技术规格书 (PROJECT_SPEC.md)

## 1. 项目愿景

AutoTFL 旨在为医学和临床数据分析提供一套自动化、可复现的 TFL (Table, Figure, Listing) 生成方案。仓库内实际应用入口仍为 `/app/`，而 Landing 对外产品口径为 Medev，用于承接简洁的前端产品说明与访问入口。

## 2. 核心架构

- **表现层**: R Shiny (shinydashboard + bslib)，采用模块化 (Shiny Modules) 开发。
- **逻辑层**: 纯 R 驱动，核心统计依赖 `survival`, `gtsummary`, `rtables`；图形渲染采用 `showtext` 以确保跨平台（如 Docker/Windows/Linux）中文字体显示一致性。应用入口需优先注册本地 CJK 字体别名 `Noto Sans SC`，Docker 镜像需内置 `fonts-noto-cjk` / `fonts-wqy-zenhei` 等离线可用字体；字体策略上需拆为三层：拉丁字体 `latin_family`、中文字体 `cjk_family`、版式测量字体 `layout_family`。`Arial` 等在 `cowplot` / `grid` 组合测量阶段先回退到 `layout_family`，包含 CJK 的绘图文本再优先选择已注册的 CJK 字体，避免同时出现 `PostScript` 字体告警与中文缺字。
- **图形共享层**: `graphics_common.R` 与 `common_ui_shell.R` 统一维护图形尺寸模式、画布边框、页面距、前端居中容器、参考线抽象以及 PX/英寸换算；默认按 `96 px = 1 in` 同步前端与导出比例，避免页面不截断但导出截断。
- **持久层**:
  - 元数据：PostgreSQL (管理 Workspace, Folder, Dataset 关系)。
  - 数据体：本地 RDS 文件或 AWS S3 对象存储。
- **网关层**: Nginx 处理反向代理、SSL 卸载及静态 Landing 页；Landing 页面只展示真实已落地能力，并为后续实际截图保留图片占位，不嵌入虚构图表或项目进度文案。

## 3. 功能边界

### 3.1 已实现模块

- **数据管理 (Database Manager)**: 支持单文件上传、批量上传及服务器目录导入。
- **数据准备 (Data Prep)**: 负责数据筛选、列映射及变量元数据（Label/Type）推断。
- **统计分析 (Statistical Analysis)**: 覆盖描述性统计、Cox/Logistic/线性回归、ANOVA、卡方/CMH。MMRM 与多重填补当前为菜单占位项，分析链路未实现。
- **统计图形 (Statistical Graphics)**: 提供生存分析图、森林图、泳道图、瀑布图、蜘蛛图、组合图、箱线图、热图、相关矩阵图等医学常用图形。
- **预设输出 (Tables)**: 人口统计学表 (`t_dm`)、不良事件汇总 (`t_ae_soc_pt`)、通用审阅清单 (`listing_general`)、AE 并列对比图 (`ae_sidebyside`)。
- **报表导出**: 支持 Word (RTF/DOCX), PDF, HTML 格式。

### 3.2 关键技术约束

- **图形输出一致性**: 统计图形模块需保证前端静态图、交互图与导出尺寸模式一致；带轨道/风险表的组合图在导出时需按当前前端画布高度同步扩展导出高度。
- **分析状态管理**: 通过 PostgreSQL `analysis_states` 表持久化图形子模块参数快照；状态快照只保存业务参数，不保存 DT/Plotly 派生交互输入或导航态；workspace 为空时保存为个人任务；覆盖保存通过 service 层显式查询后 update/insert，不依赖 `ON CONFLICT`。
- **图形参数抽象**: 首批共享参数卡片为列映射块、时间轴块、导出块三类；动态事件映射、复杂颜色映射等高动态区块留待后续抽象。
- **图形子模块统一布局**: `数据与变量 / 图形与样式 / 输出与导出` 三张顶层功能卡片 + 结果区动作条 + `静态图 / 交互图 / 数据` 结果页签。
- **common 目录归类**: `modules/common/` 按 `auth / data / analysis / graphics / export` 五类组织，全部已落地；新增共享逻辑优先进入对应子目录。
- **认证事务**: 所有事务型写操作必须统一走 `auth_with_transaction()`：`pool` 模式走 `poolWithTransaction`，直连模式走 `dbWithTransaction`。
- **用户管理事务**: workspace 创建、成员授权、Owner 迁移等写操作必须从 service 层进入，UI 层不得重新拼装事务细节。
- **P 值格式**: AMA 风格 — `<0.001`、`>0.99`、无法计算时显示 `—`。HR/OR/Beta 及 95% CI 保留 2 位小数。
- **回归变量约束**: 响应变量不得同时出现在预测变量中；预测变量不得与 split/facet/strata 重复；Cox 分析中时间/状态变量不应进入协变量集合。
- **缺失值处理**: 基于 complete cases；无法估计时返回可见错误或占位值。

## 4. 权限模型

- 采用基于 Workspace 的隔离机制。
- 系统角色：系统管理员与普通用户两类。
- 系统管理员负责账号状态、数据空间功能开通、数据库信息查看和服务器目录导入等系统级能力，但不得读取、浏览或导出其他用户数据空间中的实际数据。
- 普通用户默认按个人 Workspace 隔离；仅能访问自己拥有或被授权的数据空间。
- 普通用户未开通数据空间功能时，仅允许单文件临时上传；上传数据只用于当前会话分析，不写入持久化数据空间。
- 新注册账号允许先注册并直接登录；邮箱验证在登录后的用户信息区自助完成，验证码默认 6 位。测试环境通过 `EMAIL_DELIVERY_MODE=console` 暴露验证码，生产环境需接入真实邮件投递。
- 密码重置采用 6 位重置验证码闭环，过期时间由 `AUTH_PASSWORD_RESET_EXPIRE_MINUTES` 控制。
- 邮箱换绑采用"当前密码确认 + 新邮箱 6 位验证码确认"闭环；验证成功后更新主邮箱，并自动尝试认领该邮箱名下待领取的 workspace 邀请。
- 邮件投递通过独立 `email_service` 抽象承载，支持 `console / disabled / smtp` 三种模式。
- 管理员通过环境变量 `APP_ADMIN_USERNAME`、`APP_ADMIN_EMAIL`、`APP_ADMIN_PASSWORD` 预置，不支持首个注册用户自动升级。启动时若数据库中已存在同邮箱或同用户名账号，需同步校准；若邮箱与用户名分别命中不同账号，拒绝静默同步。
- 当前登录态定时刷新用户状态与数据库管理开关，确保管理员调整后用户侧菜单在当前会话内跟进。
- 侧边栏账号入口、用户信息与权限管理相关展示文案统一以 `ACCOUNT_ENTRY_COPY` 为唯一源，规格文档只记录结构职责与边界。
- 认证回归需至少保留一条 `pool` 模式集成测试，防止 `pool` / 普通连接两条路径行为分叉。

## 5. 未落地项

- MMRM 与多重填补（MI）：菜单可见，分析链路未实现。
- Kubernetes 部署：仓库中暂无相关编排或清单。
- 组织级/项目级隔离与更细粒度权限矩阵。
