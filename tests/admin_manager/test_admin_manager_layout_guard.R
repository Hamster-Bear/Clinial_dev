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

module_text <- read_utf8("modules", "admin_manager.R")
if (!nzchar(module_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_not_contains <- function(text, pattern, label) {
  if (grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("发现应移除内容: %s", label), call. = FALSE)
  }
}

expect_contains(module_text, "title = \"系统概览\"", "管理员页系统概览卡片")
expect_contains(module_text, "title = \"异常态势摘要\"", "管理员页异常态势摘要卡片")
expect_contains(module_text, "title = \"账号状态管理\"", "管理员页账号状态管理卡片")
expect_contains(module_text, "title = \"数据空间管理\"", "管理员页数据空间管理卡片")
expect_contains(module_text, "subtitle = \"合并处理我名下空间的负责人调整与协作授权\"", "管理员页合并后的数据空间管理副标题")
expect_contains(module_text, "selected_manage_workspace_id <- reactive", "管理员页统一数据空间选择器")
expect_contains(module_text, "if \\(length\\(workspace_ids\\) == 0\\) \\{[\\s\\S]*?return\\(\"\"\\)", "管理员页统一数据空间选择器为空 id 向量提供兜底")
expect_contains(module_text, "selectInput\\(session\\$ns\\(\"workspace_manage_select\"\\), \"选择目标数据空间\"", "管理员页统一数据空间下拉")
expect_contains(module_text, "uiOutput\\(session\\$ns\\(\"admin_workspace_manage_summary\"\\)\\)", "管理员页数据空间摘要输出")
expect_contains(module_text, "output\\$admin_workspace_manage_summary <- renderUI", "管理员页数据空间摘要渲染")
expect_contains(module_text, "class = \"admin-compact-grid\"", "管理员页紧凑统计卡样式")
expect_contains(module_text, "output\\$admin_system_overview <- renderUI\\([\\s\\S]*?class = \"admin-compact-grid\"", "系统概览使用紧凑统计卡")
expect_contains(module_text, "output\\$admin_risk_overview <- renderUI\\([\\s\\S]*?class = \"admin-compact-grid\"", "异常态势摘要使用紧凑统计卡")
expect_contains(module_text, "output\\$admin_user_meta_card <- renderUI\\([\\s\\S]*?class = \"admin-compact-grid\"", "账号状态管理使用紧凑统计卡")
expect_contains(module_text, "workspace_id <- selected_manage_workspace_id\\(\\)", "管理员页预览与操作统一复用数据空间选择器")
expect_contains(module_text, "session\\$ns\\(\"admin_workspace_manage_section\"\\)", "管理员页跳转锚点统一到数据空间管理卡片")
expect_contains(module_text, "去负责人迁移", "管理员页快捷跳转按钮文案")
expect_contains(module_text, "去空间协作", "管理员页快捷跳转按钮文案")
expect_not_contains(module_text, "owner_workspace_select", "管理员页不再使用旧负责人空间选择器")
expect_not_contains(module_text, "membership_workspace_select", "管理员页不再使用旧协作空间选择器")
expect_not_contains(module_text, "admin_owner_section", "管理员页不再保留旧负责人锚点")
expect_not_contains(module_text, "admin_membership_section", "管理员页不再保留旧协作锚点")

cat("Admin manager layout guard passed.\n")
