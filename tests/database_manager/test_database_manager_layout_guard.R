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
      if (file.exists(file.path(current, "app.R")) && dir.exists(file.path(current, "modules")) && dir.exists(file.path(current, "tests"))) {
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
args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- test_find_project_root()
read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}
database_manager_text <- read_utf8("modules", "database_manager.R")
if (!nzchar(database_manager_text)) return(invisible(NULL))
expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
}
expect_not_contains <- function(text, pattern, label) {
  if (grepl(pattern, text, perl = TRUE)) stop(sprintf("不应包含内容: %s", label), call. = FALSE)
}
# 基础结构
expect_contains(database_manager_text, "title = \"数据空间管理\"", "主标题")
expect_contains(database_manager_text, "app_card_dependencies\\(\\)", "公共卡片依赖")
expect_contains(database_manager_text, "uiOutput\\(ns\\(\"db_gate_content\"\\)\\)", "访问锁输出")
# 左右分栏
expect_contains(database_manager_text, "db-main-row", "左右分栏布局")
expect_contains(database_manager_text, "db-panel", "面板容器")
# 左侧工具栏
expect_contains(database_manager_text, "db-toolbar", "顶部工具栏")
expect_contains(database_manager_text, "icon\\(\"plus\"\\)", "新建空间按钮")
expect_contains(database_manager_text, "icon\\(\"trash\"\\)", "删除空间按钮")
expect_contains(database_manager_text, "icon\\(\"folder-plus\"\\)", "创建目录按钮")
expect_contains(database_manager_text, "icon\\(\"folder-minus\"\\)", "删除目录按钮")
# 导航树
expect_contains(database_manager_text, "db-nav-tree", "导航树")
expect_contains(database_manager_text, "nav_click", "导航点击事件")
# 右侧上传页签
expect_contains(database_manager_text, "tabBox\\(", "使用 tabBox 页签")
expect_contains(database_manager_text, "\"单文件上传\"", "单文件上传页签")
expect_contains(database_manager_text, "\"批量导入\"", "批量导入页签")
expect_contains(database_manager_text, "\"服务器导入\"", "服务器导入页签")
expect_contains(database_manager_text, "db-upload-row", "上传行布局")
expect_contains(database_manager_text, "db-upload-encoding", "编码选择器区域")
expect_contains(database_manager_text, "db-upload-file", "文件选择器区域")
# 不应包含旧布局
expect_not_contains(database_manager_text, "\"空间与目录\"", "不应有旧的空间与目录标签")
expect_not_contains(database_manager_text, "\"结构总览\"", "不应有旧的结构总览标签")
# 锁定态
expect_contains(database_manager_text, "数据库管理已锁定", "锁定提示标题")
expect_contains(database_manager_text, "前往数据准备页", "锁定态跳转按钮")
cat("Database manager layout guard passed.\n")
