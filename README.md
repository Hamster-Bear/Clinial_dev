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

### 方法三：使用 Docker 容器部署

本项目提供了 Docker 支持，可以快速构建和运行应用容器。

#### 1. 构建 Docker 镜像

使用提供的构建脚本，在项目根目录下执行：

**Linux/macOS:**
```bash
./build_docker_image.sh
```

**Windows:**
```bat
build_docker_image.bat
```

如果 Windows 批处理脚本出现乱码或闪退，可以使用 PowerShell 脚本（推荐）：
```powershell
.\build_docker_image.ps1
```

脚本会提示您输入：
- 镜像名称（默认为 `autotfl-shiny-app`）
- 镜像标签（默认为 `latest`）
- 容器映射端口（默认为 `3838`）

构建完成后，镜像将保存在本地 Docker 环境中。

#### 2. 运行容器

使用以下命令运行容器（将 `PORT` 替换为之前设置的端口）：
```bash
docker run -p PORT:3838 autotfl-shiny-app:latest
```

应用将在容器内启动，并可通过浏览器访问 `http://localhost:PORT`。

#### 3. 使用更新后的构建脚本

构建脚本已更新，支持交互式输入镜像名和端口。您也可以直接使用 Docker 命令构建：
```bash
docker build -t your-image-name:your-tag .
```

更多详细信息请参考项目根目录下的 `Dockerfile` 和构建脚本。

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
- 设置默认端口(8100)和主机(127.0.0.1)

## 项目结构

```
AutoTFL/
├── app.R                 # 主应用文件
├── install_dependencies.R # 依赖安装脚本
├── run_app.R            # 应用启动脚本
├── README.md            # 项目说明文档
├── style.css            # 自定义样式文件
├── sample_data.csv      # 示例数据文件
├── modules/
│   └── statistical_analysis.R # 统计分析模块
└── docs/                # 设计文档
    ├── project_structure.md
    ├── package_dependencies.md
    ├── app_design.md
    ├── data_upload_design.md
    ├── variable_type_system.md
    ├── data_anonymization.md
    ├── enhancements.md
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