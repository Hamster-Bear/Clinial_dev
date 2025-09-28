# R包依赖管理

## 核心依赖包列表

### UI框架与交互
- **shiny**: 主应用框架
- **shinydashboard**: 仪表盘布局
- **shinyjs**: JavaScript交互增强
- **shinyBS**: Bootstrap组件和提示工具
- **bslib**: 现代UI组件和手风琴面板

### 数据处理与读取
- **dplyr**: 数据操作和转换
- **readr**: CSV文件读取
- **readxl**: Excel文件读取
- **haven**: SPSS文件读取
- **tibble**: 现代数据框处理

### 可视化与图形
- **ggplot2**: 基础图形系统
- **plotly**: 交互式图形
- **DT**: 交互式数据表格
- **gt**: 出版级表格输出

### 统计分析与建模
- **stats**: 基础统计函数
- **broom**: 模型结果整理
- **survival**: 生存分析（Cox回归）
- **lmtest**: 模型检验

### 工具与工具包
- **purrr**: 函数式编程
- **stringr**: 字符串处理
- **lubridate**: 日期时间处理
- **magrittr**: 管道操作符

## 安装脚本示例

```r
# 检查并安装缺失的包
required_packages <- c(
  "shiny", "shinydashboard", "shinyjs", "shinyBS", "bslib",
  "dplyr", "readr", "readxl", "haven", "tibble",
  "ggplot2", "plotly", "DT", "gt",
  "broom", "survival", "lmtest",
  "purrr", "stringr", "lubridate", "magrittr"
)

# 安装缺失的包
new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages)

# 加载所有包
lapply(required_packages, library, character.only = TRUE)
```

## 版本兼容性说明
- 所有包使用CRAN最新稳定版本
- 确保R版本 >= 4.0.0
- 图形输出需要Cairo或相关图形设备支持

## 可选增强包
- **rmarkdown**: 用于报告生成
- **flextable**: 替代表格输出
- **ggiraph**: 高级交互图形
- **patchwork**: 图形组合