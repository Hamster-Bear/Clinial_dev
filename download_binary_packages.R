#!/usr/bin/env Rscript
# AutoTFL 离线二进制包下载脚本
# 用途：从 PPM 预下载所有依赖的二进制包到 package/ 目录，用于离线/加速构建
# 用法：Rscript download_binary_packages.R

source("config/required_packages.R")
required_packages <- REQUIRED_PACKAGES

main <- function() {
  cat("=== AutoTFL 离线二进制包下载 ===\n")
  cat("开始时间:", format(Sys.time()), "\n\n")

  if (!requireNamespace("pak", quietly = TRUE)) {
    cat("正在安装 pak...\n")
    install.packages("pak", repos = "https://cloud.r-project.org")
  }
  library(pak)

  dir.create("package", showWarnings = FALSE)
  pkg_dir <- normalizePath("package")

  ppm_url <- "https://packagemanager.posit.co/cran/latest"

  cat("1/3 解析依赖树 (PPM:", ppm_url, ")...\n")
  deps <- pak::pkg_deps(required_packages, repos = ppm_url)
  all_pkgs <- unique(c(
    required_packages,
    deps$package[!is.na(deps$package)]
  ))
  cat("   共需下载", length(all_pkgs), "个包\n\n")

  existing <- list.files(pkg_dir, pattern = "\\.tar\\.gz$")
  to_dl <- setdiff(all_pkgs, sub("_.*", "", existing))

  if (length(to_dl) == 0) {
    cat("2/3 所有包已存在，跳过下载\n")
  } else {
    cat("2/3 下载", length(to_dl), "个包 (已有", length(existing), "个)...\n")
    for (i in seq_along(to_dl)) {
      pkg <- to_dl[i]
      cat(sprintf("    [%3d/%3d] %s ...", i, length(to_dl), pkg))
      tryCatch({
        dl <- download.packages(pkg, destdir = pkg_dir, repos = ppm_url,
                                quiet = TRUE)
        if (nrow(dl) > 0) {
          cat(" OK (", basename(dl[1, 2]), ")\n", sep = "")
        } else {
          cat(" FAILED\n")
        }
      }, error = function(e) {
        cat(" ERROR:", conditionMessage(e), "\n")
      })
    }
    cat("\n")
  }

  cat("3/3 生成 PACKAGES 索引...\n")
  tools::write_PACKAGES(pkg_dir, type = "source")
  cat("   完成\n\n")

  final <- list.files(pkg_dir, pattern = "\\.tar\\.gz$")
  cat("=== 下载完成 ===\n")
  cat("package/ 目录现有", length(final), "个二进制包\n")
  cat("结束时间:", format(Sys.time()), "\n")
}

if (!interactive()) {
  main()
}
