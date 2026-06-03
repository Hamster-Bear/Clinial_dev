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
  "shinyWidgets",
  "waiter",
  "shinyalert",
  
  # 数据处理
  "dplyr",
  "readr",
  "readxl",
  "haven",
  "jsonlite",
  "purrr",
  "stringr",
  "vroom",
  "memoise",
  
  # 可视化
  "ggplot2",
  "plotly",
  "DT",
  "gt",
  "patchwork",
  "reactable",
  "cowplot",
  "gridExtra",
  "scales",
  "RColorBrewer",
  "showtext",
  "sysfonts",
  
  # 表格生成
  "cards",
  "gtsummary",
  "tfrmt",
  "forcats",
  "tidyr",
  "rlang",
  "rtables",
  "tern",
  
  # 统计分析
  "survival",
  "broom",
  "survminer",
  "corrplot",
  
  # 数据库连接
  "DBI",
  "RPostgres",
  "pool",
  
  # 颜色主题支持
  "ggsci",
  "colourpicker",
  
  # 数据安全
  "digest",
  "curl",
  
  # 列表处理与测试
  "rlistings",
  "r2rtf",
  "rmarkdown",
  "pagedown",
  "knitr",
  "flextable",
  "officer",
  "testthat",
  "lintr",
  "styler",
  "shinytest2",
  "shinyFiles"
)

# 安装缺失的包（pak 统一处理本地二进制 + 在线 PPM）
install_missing_packages <- function(packages) {
  installed <- installed.packages()[, "Package"]
  missing <- setdiff(packages, installed)

  if (length(missing) == 0) {
    message("所有必需的包都已安装。")
    return()
  }

  # 构建仓库列表：本地 package/ 优先（二进制包秒装），PPM 在线兜底
  repos <- c()
  if (dir.exists("package") && file.exists(file.path("package", "PACKAGES"))) {
    local_path <- gsub("\\\\", "/", normalizePath("package"))
    repos <- c(paste0("file:///", local_path))
    message("发现本地 package 仓库: ", local_path)
  }
  repos <- c(repos, "https://packagemanager.posit.co/cran/latest")

  # 确保 pak 可用（Dockerfile 已预装，此处兜底）
  if (!requireNamespace("pak", quietly = TRUE)) {
    install.packages("pak", repos = "https://cloud.r-project.org")
  }

  message("使用 pak 安装 ", length(missing), " 个缺失包: ",
          paste(missing, collapse = ", "))
  cat("仓库:", paste(repos, collapse = ", "), "\n")

  options(repos = repos, pkg.sysreqs = FALSE)
  pak::pak(missing, ask = FALSE)
  message("安装流程结束。")
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
  
  # 优先加载本地 package 目录
  # 在Docker构建时，/app/package 是临时目录，不应该作为运行时的库目录
  # 除非我们打算在运行时也使用它。
  # 但是，install.packages 需要写入权限。
  # 更好的做法是：不把 package 加入 libPaths，而是安装到系统库目录。
  
  # if (dir.exists("package")) {
  #   local_pkg <- normalizePath("package")
  #   message("使用本地库目录: ", local_pkg)
  #   .libPaths(c(local_pkg, .libPaths()))
  # }
  
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
