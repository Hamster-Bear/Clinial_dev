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

### 当前访问与账号边界

- 当前 `/app/` 已实现应用内自注册、登录、退出与 workspace 级权限过滤。
- 当前登录与注册已拆为两个页面，并改为上下居中的单列卡片布局；登录支持用户名或邮箱，注册会采集邮箱并做格式校验，但暂未接入真实邮箱验证。
- 认证主体区域已抽到 `auth_manager.R`；当前用户信息、退出入口与普通用户的“权限管理”快捷入口已合并到侧边栏卡片中。
- 未登录状态下仅显示登录/注册入口；进入工作台前不展示业务侧边栏。
- 当前工具声明为：不负责数据安全、数据传到服务不保证安全，请使用方自行妥善保管数据；如需更高保障，可提供独立部署服务。
- 当前“服务器目录导入数据空间”仅适用于部署机器或容器内可见的绝对路径，不支持直接读取浏览器用户电脑上的本地文件夹，且该入口只面向系统管理员开放。
- 当前多用户实现为自注册 + 管理员账号 + 按个人隔离；后续预留组织和项目隔离扩展，数据权限先落到 workspace 级别。
- 可通过环境变量预置管理员用户名、邮箱和密码；若未预置，则首个注册用户会自动成为系统管理员。
- 当前已提供管理员操作入口；workspace、membership、invite 与 owner 迁移能力已统一下沉到 service 层。
- workspace 创建与删除也统一复用 `account_service.R`，避免数据库管理页继续直连 owner / membership 迁移细节。
- 普通用户可对自己拥有的数据空间进行权限管理，且授权、撤销与 owner 迁移统一通过邮箱输入完成，不通过下拉选择数据库中的用户。
- 管理员页保持独立系统入口，不并入侧边栏用户卡片；系统级协作授权、负责人绑定与账号状态调整仍集中在管理员页。
- 权限预览表与管理员 membership 预览表已改为面向业务的中文列名，不再直接暴露数据库字段名。
- 数据库管理页已按“空间与目录 / 上传与导入 / 结构总览”三段重组，减少单页堆叠操作。
- 数据库管理功能已增加账号级访问锁：普通账号默认锁定，需由管理员开放数据库管理权限后才可进入与操作。
- `run_app_test.ps1` 对应的测试环境变量示例已写入 `.env.test.example`；若数据库由 `docker-compose1.yml` 拉起，测试端口应使用 `55432`，默认管理员示例为 `admin / admin@example.com / admin123`。

### 当前阶段风险与优化建议

- 技术风险：当前权限粒度仍主要落在 workspace 级别，`viewer` / `editor` 在数据写操作上的边界尚未完全拉开；数据库管理锁目前仍是账号级开关。
- 维护风险：邮箱邀请已落地，但尚未接入真实邮箱验证与失效策略，存在误填邮箱后人工排障成本；普通用户与管理员两套权限入口也需要持续保持文案一致。
- 项目风险：owner 迁移与协作能力已进入主流程，若后续继续扩展共享模型，需要尽快补齐审计日志与操作留痕。
- 立即可做：补充 membership / invite / owner 迁移的数据库级集成测试，并明确 `viewer` / `editor` 的读写边界；继续验证新数据库管理布局与数据库管理锁在高频操作下的可达性。
- 中长期建议：引入邮箱验证、邀请有效期、操作审计日志，并评估组织级 / 项目级协作模型。
- 工具链建议：在现有 `tests/` 守卫测试之外补充基于 PostgreSQL 临时库的自动化回归，并接入 pre-commit 做文档与测试入口校验。

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
