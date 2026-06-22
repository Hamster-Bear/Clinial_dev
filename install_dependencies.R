#!/usr/bin/env Rscript
# R Shiny医学数据分析应用 - 依赖管理脚本
# 此脚本用于自动安装和检查项目所需的所有R包

# 定义项目所需的包列表
source("config/required_packages.R")
required_packages <- REQUIRED_PACKAGES

# 安装缺失的包（pak 统一处理本地二进制 + 在线 PPM）
install_missing_packages <- function(packages) {
  # find.package() 只检查磁盘上的安装路径，不加载命名空间，比 installed.packages() 快一个数量级
  installed <- vapply(packages, function(pkg) {
    path <- tryCatch(find.package(pkg, quiet = TRUE), error = function(e) character(0))
    isTRUE(nzchar(path[1]))
  }, logical(1))
  missing <- packages[!installed]

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
  repos <- c(repos, "https://mirrors.tuna.tsinghua.edu.cn/CRAN/")

  # 确保 pak 可用（Dockerfile 已预装，此处兜底）
  if (!requireNamespace("pak", quietly = TRUE)) {
    install.packages("pak", repos = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/")
  }

  message("使用 pak 安装 ", length(missing), " 个缺失包: ",
          paste(missing, collapse = ", "))
  cat("仓库:", paste(repos, collapse = ", "), "\n")

  options(repos = repos, pkg.sysreqs = FALSE)
  pak::pak(missing, ask = FALSE)
  message("安装流程结束。")
}

# 检查包是否可用（仅验证安装路径，不加载命名空间，不 attach）
# 命名空间加载和 attach 由 app.R 的 library() 统一处理
check_packages_loaded <- function(packages) {
  missing <- character(0)
  for (pkg in packages) {
    path <- tryCatch(find.package(pkg, quiet = TRUE), error = function(e) character(0))
    if (!isTRUE(nzchar(path[1]))) missing <- c(missing, pkg)
  }
  if (length(missing) > 0) {
    message("错误: 以下包未安装: ", paste(missing, collapse = ", "))
    return(FALSE)
  }
  message("所有 ", length(packages), " 个依赖包均已安装。")
  return(TRUE)
}

# 主函数
main <- function() {
  message("=== 依赖检查 ===")

  # 安装缺失的包
  install_missing_packages(required_packages)

  # 检查包是否均已安装
  loading_status <- check_packages_loaded(required_packages)

  if (!loading_status) {
    stop("部分依赖包未安装，请检查错误信息。")
  }

  message("✅ 依赖检查完成")
}

# 执行主函数（防止 run_app.R 中 source() + 显式 main() 导致重复执行）
if (interactive()) {
  message("请在R控制台中运行: source('install_dependencies.R')")
} else if (!exists(".__install_deps_main_called", envir = .GlobalEnv)) {
  assign(".__install_deps_main_called", TRUE, envir = .GlobalEnv)
  main()
}

# 导出包列表供其他脚本使用
if (!exists("required_packages_exported")) {
  required_packages_exported <- TRUE
  assign("REQUIRED_PACKAGES", required_packages, envir = .GlobalEnv)
}
