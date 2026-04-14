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
  "shinytest2"
)

# 安装缺失的包
install_missing_packages <- function(packages) {
  # 1. 优先从本地 package 目录安装
  if (dir.exists("package")) {
    local_pkg_dir <- normalizePath("package")
    message("正在扫描本地 package 目录: ", local_pkg_dir)
    
    # 检查本地是否有 PACKAGES 索引文件，如果有，直接作为仓库安装（自动处理依赖）
    if (file.exists(file.path(local_pkg_dir, "PACKAGES"))) {
      message("发现本地 PACKAGES 索引，使用仓库模式安装...")
      
      # 构造本地仓库 URL
      # 注意：Windows 下 normalizePath 返回反斜杠，需要转换为正斜杠
      # Linux 下 normalizePath 返回正斜杠，不需要转换
      local_path_fixed <- gsub("\\\\", "/", local_pkg_dir)
      repo_url <- paste0("file:///", local_path_fixed)
      
      # 获取当前已安装的包
      installed <- installed.packages()[, "Package"]
      missing <- setdiff(packages, installed)
      
      if (length(missing) > 0) {
        message("尝试从本地仓库安装缺失包: ", paste(missing, collapse = ", "))
        tryCatch({
           # 使用 contriburl 指定本地源码目录，让 R 自动解决依赖顺序
           # 在 Windows 下 file:///C:/... 是合法的
           # 在 Linux 下 file:////app/package 是合法的 (3个斜杠后接绝对路径 /app/package)
           # 所以 file:/// + /app/package = file:////app/package
           install.packages(missing, contriburl = repo_url, type = "source", dependencies = TRUE)
        }, error = function(e) {
           message("本地仓库安装部分失败（可能缺依赖），将尝试在线补齐: ", e$message)
        })
      }
    } else {
      # 没有索引文件，回退到逐个文件尝试安装（不推荐，无法解决依赖顺序）
      message("未找到 PACKAGES 索引，尝试生成并安装...")
      tryCatch({
        tools::write_PACKAGES(local_pkg_dir, type = "source")
        local_path_fixed <- gsub("\\\\", "/", local_pkg_dir)
        repo_url <- paste0("file:///", local_path_fixed)
        
        installed <- installed.packages()[, "Package"]
        missing <- setdiff(packages, installed)
        if (length(missing) > 0) {
          install.packages(missing, contriburl = repo_url, type = "source", dependencies = TRUE)
        }
      }, error = function(e) {
        message("生成索引或安装失败: ", e$message)
      })
    }
  }

  # 2. 再次检查缺失包，从在线源补齐
  installed_packages <- installed.packages()[, "Package"]
  missing_packages <- setdiff(packages, installed_packages)
  
  if (length(missing_packages) > 0) {
    message("正在从在线源安装剩余缺失包: ", paste(missing_packages, collapse = ", "))
    
    # 使用清华源，提高国内下载速度
    install.packages(
      missing_packages,
      repos = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/",
      dependencies = TRUE
    )
    
    message("在线安装流程结束。")
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
