# R Shiny医学数据分析应用

一个专业的医学数据分析平台，提供从数据准备到高级统计分析和可视化的完整工作流程。

## 功能特性

- **数据准备**: 支持CSV、Excel、SPSS格式，智能变量类型识别，数据匿名化处理
- **智能表格筛选**: Reactable表格支持智能列类型识别和专用筛选器，使用JavaScript高性能筛选引擎
- **探索分析**: 交互式可视化，支持散点图、箱线图、直方图、条形图
- **统计分析**: 包含描述性统计、Cox回归、逻辑回归、线性回归、ANOVA、卡方检验、CMH检验
- **统计图形**: 生存曲线、森林图、热图、相关性矩阵等出版级图形
- **导出功能**: 支持Word文档和高质量图片导出

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
