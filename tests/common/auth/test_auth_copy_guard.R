test_find_project_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_path <- sub(file_arg, "", args[grep(file_arg, args)])
  script_path <- if (length(script_path) > 0) script_path[[1]] else ""
  start_candidates <- unique(c(
    if (nzchar(script_path)) dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)) else character(0),
    normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  ))

  for (candidate in start_candidates) {
    current <- candidate
    repeat {
      if (file.exists(file.path(current, "app.R")) &&
          dir.exists(file.path(current, "modules")) &&
          dir.exists(file.path(current, "tests"))) {
        return(normalizePath(current, winslash = "/", mustWork = TRUE))
      }
      parent <- dirname(current)
      if (identical(parent, current)) break
      current <- parent
    }
  }

  stop("无法定位项目根目录。", call. = FALSE)
}

project_root <- test_find_project_root()
setwd(file.path(project_root, "tests"))

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

copy_text <- read_utf8("modules", "common", "auth", "auth_copy.R")
guide_text <- read_utf8("PROJECT_GUIDE.md")
spec_text <- read_utf8("PROJECT_SPEC.md")
if (!nzchar(copy_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(copy_text, "ACCOUNT_ENTRY_COPY <- list", "账号入口共享文案对象")
expect_contains(copy_text, "concept = \"用户和权限\"", "账号入口概念文案")
expect_contains(copy_text, "profile = \"用户信息\"", "账号入口用户信息文案")
expect_contains(copy_text, "permissions = \"权限管理\"", "账号入口权限管理文案")
expect_contains(copy_text, "logout = \"退出登录\"", "账号入口退出文案")
expect_contains(copy_text, "admin = \"系统管理\"", "账号入口系统管理文案")
expect_contains(copy_text, "db_manage = \"数据空间\"", "账号入口数据空间文案")
expect_contains(copy_text, "data_prep = \"临时上传\"", "账号入口临时上传文案")
expect_contains(copy_text, "overview_title = \"账号概览\"", "用户信息概览标题文案")
expect_contains(copy_text, "workbench_title = \"安全与验证\"", "用户信息工作台标题文案")
expect_contains(copy_text, "workbench_title = \"协作管理\"", "权限管理工作台标题文案")
expect_contains(copy_text, "ownership = \"负责人迁移\"", "权限管理负责人迁移标签页文案")
expect_contains(copy_text, "account_summary = ", "账号入口摘要文案")
expect_contains(copy_text, "doc_rule = ", "账号入口文档约束说明")
expect_contains(copy_text, "account_entry_copy_get <- function", "账号入口文案读取 helper")
expect_contains(guide_text, "ACCOUNT_ENTRY_COPY", "PROJECT_GUIDE 账号入口唯一文案源约束")
expect_contains(spec_text, "ACCOUNT_ENTRY_COPY", "PROJECT_SPEC 账号入口唯一文案源约束")

cat("Auth copy guard passed.\n")
