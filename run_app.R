#!/usr/bin/env Rscript
# R Shiny医学数据分析应用 - 启动脚本
# 此脚本用于自动安装依赖并启动应用

cat("=== R Shiny医学数据分析应用 - 启动程序 ===\n")
cat("开始时间:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# 检查工作目录是否正确
cat("1. 检查工作目录...\n")
current_dir <- getwd()
cat("当前工作目录:", current_dir, "\n")

# 检查必要的文件是否存在
required_files <- c("app.R", "install_dependencies.R")
missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  cat("错误: 缺少必要的文件:", paste(missing_files, collapse = ", "), "\n")
  cat("请确保在项目根目录下运行此脚本\n")
  stop("文件路径错误")
}

cat("✅ 工作目录检查通过\n\n")

# 检查并安装依赖
cat("2. 检查项目依赖...\n")
if (!file.exists("install_dependencies.R")) {
  stop("无法找到 install_dependencies.R 文件")
}

# 使用 tryCatch 来处理源文件加载错误
tryCatch({
  source("install_dependencies.R", local = TRUE)
  cat("✅ 依赖检查完成\n\n")
}, error = function(e) {
  cat("错误: 无法加载 install_dependencies.R\n")
  cat("错误信息:", e$message, "\n")
  stop("依赖检查失败")
})

cat("3. 加载必需的包...\n")
# 加载所有必需的包
required_packages <- c(
  "shiny", "shinydashboard", "shinyjs", "shinyBS", "bslib",
  "dplyr", "readr", "readxl", "haven", "ggplot2", "plotly",
  "DT", "gt", "purrr", "stringr", "survival", "broom", "survminer",
  "corrplot", "ggsci", "patchwork", "digest", "colourpicker", "reactable",
  "waiter", "shinyalert", "scales", "gridExtra", "cowplot", "RColorBrewer",
  "tidyr", "vroom", "memoise", "shinyWidgets", "gtsummary"
)

successful_loads <- 0
for (pkg in required_packages) {
  # 首先检查包是否已安装
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("警告: 包 '", pkg, "' 未安装\n")
    cat("尝试安装包 '", pkg, "'...\n")
    install.packages(pkg, repos = "https://cloud.r-project.org/")
  }
  
  # 尝试加载包
  if (requireNamespace(pkg, quietly = TRUE)) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      cat("错误: 无法加载包 '", pkg, "' 到搜索路径\n")
    } else {
      cat("✅ 已加载:", pkg, "\n")
      successful_loads <- successful_loads + 1
    }
  } else { 
    cat("错误: 无法安装包 '", pkg, "'\n")
  }
}

if (successful_loads < length(required_packages)) {
  cat("警告: 部分包加载失败，应用可能无法正常工作\n")
}

cat("\n4. 启动Shiny应用...\n")
cat("应用将在浏览器中打开，请稍候...\n")
cat("按 Ctrl+C 停止应用\n\n")

# 设置启动选项
options(shiny.port = 8109)
options(shiny.host = "127.0.0.1")
# 设置最大上传文件大小为100MB
options(shiny.maxRequestSize = 100 * 1024^2)

# 检查app.R文件是否存在
if (!file.exists("app.R")) {
  stop("错误: 无法找到 app.R 文件")
}

# 启动应用
tryCatch({
  shiny::runApp("app.R", launch.browser = TRUE)
}, error = function(e) {
  cat("启动应用时出错:", e$message, "\n")
  cat("请检查app.R文件是否有语法错误\n")
})