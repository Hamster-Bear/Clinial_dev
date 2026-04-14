args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

read_utf8 <- function(...) {
  file_path <- file.path(project_root, ...)
  if (length(file_path) == 0 || !file.exists(file_path)) return("")
  paste(readLines(file_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

database_manager_text <- read_utf8("modules", "database_manager.R")
if (!nzchar(database_manager_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(database_manager_text, "title = \"数据空间工作台\"", "数据库管理页主标题")
expect_contains(database_manager_text, "uiOutput\\(ns\\(\"db_context_summary\"\\)\\)", "数据库管理页上下文摘要")
expect_contains(database_manager_text, "uiOutput\\(ns\\(\"db_gate_content\"\\)\\)", "数据库管理页访问锁内容输出")
expect_contains(database_manager_text, "tabBox\\(", "数据库管理页使用标签页布局")
expect_contains(database_manager_text, "\"空间与目录\"", "数据库管理页空间与目录标签")
expect_contains(database_manager_text, "\"上传与导入\"", "数据库管理页上传与导入标签")
expect_contains(database_manager_text, "\"结构总览\"", "数据库管理页结构总览标签")
expect_contains(database_manager_text, "title = \"数据空间\"", "数据库管理页数据空间区块")
expect_contains(database_manager_text, "title = \"目录管理\"", "数据库管理页目录区块")
expect_contains(database_manager_text, "title = \"数据集管理\"", "数据库管理页数据集区块")
expect_contains(database_manager_text, "数据库管理已锁定", "数据库管理页锁定提示标题")
expect_contains(database_manager_text, "refresh_workspace_choices <- function\\(selected = NULL\\)", "数据库管理页保留 workspace 选择值")
expect_contains(database_manager_text, "observeEvent\\(input\\$workspace_select", "数据库管理页 workspace 切换单独监听")
expect_contains(database_manager_text, "output\\$db_context_summary <- renderUI\\(", "数据库管理页上下文摘要服务")

cat("Database manager layout guard passed.\n")
