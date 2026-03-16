# R 包离线下载与维护脚本
# 作用：从 install_dependencies.R 读取依赖列表，并同步下载 Linux 源码包到 package/ 目录
# 确保 package/ 目录下的包与 install_dependencies.R 中定义的版本一致（源码包下载）

# 1. 设置镜像源（清华源）
options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"))
options(timeout = 600)

# 2. 定义目标目录
dest_dir <- "package"
if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE)

message("=== AutoTFL 离线包下载与维护工具 ===")
message("目标目录: ", normalizePath(dest_dir))
message("镜像源: ", getOption("repos")["CRAN"])

# 3. 从 install_dependencies.R 提取包列表
# 使用 parse() 读取文件但不执行，从而安全地提取变量
message("\n正在读取 install_dependencies.R ...")
dep_file <- "install_dependencies.R"
if (!file.exists(dep_file)) stop("找不到 install_dependencies.R 文件！")

# 解析文件内容
exprs <- parse(dep_file)
# 寻找 required_packages <- c(...) 赋值语句
pkgs_to_download <- NULL

for (expr in exprs) {
  # 检查是否是赋值语句且变量名为 required_packages
  if (is.call(expr) && (as.character(expr[[1]]) == "<-" || as.character(expr[[1]]) == "=")) {
    if (as.character(expr[[2]]) == "required_packages") {
      # 执行赋值语句以获取变量值（仅执行这一句，安全）
      eval(expr)
      pkgs_to_download <- required_packages
      break
    }
  }
}

if (is.null(pkgs_to_download)) {
  stop("无法从 install_dependencies.R 中解析出 required_packages 列表！")
}

message("已提取依赖包列表: ", length(pkgs_to_download), " 个")
# print(pkgs_to_download)

message("\n正在分析依赖关系（递归）...")

# 4. 获取依赖树
av <- available.packages()
pkg_deps <- tools::package_dependencies(pkgs_to_download, db = av, recursive = TRUE)
all_pkgs <- unique(c(pkgs_to_download, unlist(pkg_deps)))

message(sprintf("共需下载 %d 个包（包含依赖）", length(all_pkgs)))

# 5. 下载源码包 (type = "source")
# 无论在 Windows 还是 Linux 运行，都强制下载 source 包，确保 Linux/Docker 可用
message("\n检查本地包状态...")

# 获取本地现有包列表
local_files <- list.files(dest_dir, pattern = "\\.tar\\.gz$")
local_pkgs_map <- list()

if (length(local_files) > 0) {
  # 解析本地文件名: pkg_version.tar.gz
  for (f in local_files) {
    # 去掉 .tar.gz
    base <- sub("\\.tar\\.gz$", "", f)
    # 分割包名和版本号 (最后一个下划线分隔)
    # 注意：包名可能包含下划线吗？R 包名通常只有字母数字点，版本号用 _ 连接
    # 但实际上 R 源码包格式是 pkgname_version.tar.gz，pkgname 不含下划线（通常）
    # CRAN 规定包名只含字母、数字和点。所以第一个下划线就是分隔符？
    # 不一定，最好用正则匹配
    parts <- strsplit(base, "_")[[1]]
    if (length(parts) >= 2) {
      pkg_name <- parts[1]
      # 版本号可能是多个部分用 . 或 - 连接，但在这里被拆分了吗？
      # strsplit by "_" 会把 version 里的 _ 也拆分吗？版本号里没有 _。
      # 所以 parts[1] 是包名，parts[2] 是版本号。
      # 除非包名里有 _（非法）。
      pkg_ver <- parts[2]
      local_pkgs_map[[pkg_name]] <- pkg_ver
    }
  }
}

# 筛选需要下载的包
pkgs_to_fetch <- character(0)
pkgs_up_to_date <- character(0)

for (pkg in all_pkgs) {
  # 获取目标版本（从 CRAN 索引中）
  if (pkg %in% rownames(av)) {
    target_ver <- av[pkg, "Version"]
    
    # 检查本地是否有
    if (pkg %in% names(local_pkgs_map)) {
      local_ver <- local_pkgs_map[[pkg]]
      
      # 对比版本
      cmp <- utils::compareVersion(target_ver, local_ver)
      
      if (cmp > 0) {
        # CRAN 版本更高，需要更新
        message(sprintf("发现更新: %s (%s -> %s)", pkg, local_ver, target_ver))
        pkgs_to_fetch <- c(pkgs_to_fetch, pkg)
        
        # 删除旧版本文件（可选，保持目录整洁）
        old_file <- file.path(dest_dir, paste0(pkg, "_", local_ver, ".tar.gz"))
        if (file.exists(old_file)) unlink(old_file)
        
      } else {
        # 本地版本足够新，跳过
        # message(sprintf("跳过已存在: %s (%s)", pkg, local_ver))
        pkgs_up_to_date <- c(pkgs_up_to_date, pkg)
      }
    } else {
      # 本地没有，需要下载
      pkgs_to_fetch <- c(pkgs_to_fetch, pkg)
    }
  } else {
    message(sprintf("警告: CRAN 上未找到包 %s，跳过", pkg))
  }
}

message(sprintf("\n汇总: 共需检查 %d 个包", length(all_pkgs)))
message(sprintf("- 已是最新: %d 个", length(pkgs_up_to_date)))
message(sprintf("- 需要下载: %d 个", length(pkgs_to_fetch)))

if (length(pkgs_to_fetch) > 0) {
  message("\n开始下载源码包 (type = 'source')...")
  download.packages(pkgs_to_fetch, destdir = dest_dir, type = "source")
} else {
  message("\n所有包均为最新，无需下载。")
}

# 6. 生成索引文件
message("\n正在生成 PACKAGES 索引...")
tools::write_PACKAGES(dest_dir, type = "source", verbose = TRUE)

message("\n✅ 下载与同步完成！package/ 目录已更新。")
message("现在你可以直接部署，或将 package/ 目录复制到离线环境。")
