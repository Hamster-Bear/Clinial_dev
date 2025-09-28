# R Shiny Medical Analysis App - 项目结构

## 项目文件结构
```
AutoTFL/
├── app.R                    # 主应用文件
├── global.R                 # 全局变量和函数
├── requirements.R           # 包依赖管理
├── README.md               # 项目说明文档
├── data/                   # 示例数据目录
├── modules/                # 模块化组件
│   ├── data_preparation.R  # 数据准备模块
│   ├── exploratory_analysis.R  # 探索分析模块
│   ├── statistical_analysis.R  # 统计分析模块
│   └── statistical_graphics.R  # 统计图形模块
└── www/                    # 静态资源
    ├── style.css           # 自定义样式
    └── scripts.js          # 自定义JavaScript
```

## 技术栈
- **UI框架**: shinydashboard
- **可视化**: plotly, ggplot2
- **表格输出**: gt, DT
- **数据处理**: dplyr, readr, haven
- **交互增强**: shinyjs, shinyBS

## 核心功能模块

### 1. 数据准备模块 (Data Preparation)
- 多格式文件上传 (CSV, Excel, SPSS)
- 智能变量类型识别
- 数据匿名化处理
- 缺失值处理策略
- 动态数据筛选器

### 2. 探索分析模块 (Exploratory Analysis)  
- 变量托盘界面
- 拖放式图形映射
- 上下文感知逻辑
- 实时可视化更新

### 3. 统计分析模块 (Statistical Analysis)
- 多种统计方法支持
- 动态参数配置
- 出版级表格输出
- Word文档导出

### 4. 统计图形模块 (Statistical Graphics)
- 高级图形定制
- 医学期刊主题
- 高分辨率导出
- 专业图形配置