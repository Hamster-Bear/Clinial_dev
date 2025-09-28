#!/usr/bin/env Rscript
# R Shiny医学数据分析应用 - 依赖管理脚本
# 此脚本用于自动安装和检查项目所需的所有R包

# 定义项目所需的包列表
required_packages <- c(
  # Shiny相关
  "shiny",
  "shinydashboard", 
  "shinyjs",
  "shinyBS",
  "bslib",
  
  # 数据处理
  "dplyr",
  "readr",
  "readxl",
  "haven",
  "purrr",
  "stringr",
  
  # 可视化
  "ggplot2",
  "plotly",
  "DT",
  "gt",
  "patchwork",
  
  # 统计分析
  "survival",
  "broom",
  "survminer",
  "corrplot",
  
  # 颜色主题支持
  "ggsci",
  
  # 数据安全
  "digest"
)

# 安装缺失的包
install_missing_packages <- function(packages) {
  # 获取已安装的包
  installed_packages <- installed.packages()[, "Package"]
  
  # 找出缺失的包
  missing_packages <- setdiff(packages, installed_packages)
  
  if (length(missing_packages) > 0) {
    message("正在安装缺失的包: ", paste(missing_packages, collapse = ", "))
    
    # 安装缺失的包
    install.packages(
      missing_packages,
      repos = "https://cloud.r-project.org/",
      dependencies = TRUE
    )
    
    message("安装完成!")
  } else {
    message("所有必需的包都已安装。")
  }
}

# 检查包是否加载成功
check_packages_loaded <- function(packages) {
  success <- TRUE
  for (pkg in packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      message("错误: 无法加载包 '", pkg, "'")
      success <- FALSE
    } else {
      # 尝试加载包到搜索路径
      if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
        message("错误: 无法加载包 '", pkg, "'到搜索路径")
        success <- FALSE
      } else {
        message("成功加载包: ", pkg)
      }
    }
  }
  return(success)
}

# 主函数
main <- function() {
  message("=== R Shiny医学数据分析应用 - 依赖检查 ===")
  message("开始时间: ", Sys.time())
  message("")
  
  # 安装缺失的包
  install_missing_packages(required_packages)
  
  message("")
  message("=== 检查包加载状态 ===")
  
  # 检查包加载
  loading_status <- check_packages_loaded(required_packages)
  
  message("")
  if (loading_status) {
    message("✅ 所有包都已成功安装和加载!")
    message("应用可以正常运行。")
  } else {
    message("❌ 有些包无法加载，请检查错误信息。")
  }
  
  message("")
  message("完成时间: ", Sys.time())
}

# 执行主函数
if (interactive()) {
  message("请在R控制台中运行: source('install_dependencies.R')")
} else {
  main()
}

# 导出包列表供其他脚本使用
if (!exists("required_packages_exported")) {
  required_packages_exported <- TRUE
  assign("REQUIRED_PACKAGES", required_packages, envir = .GlobalEnv)
}