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

module_text <- read_utf8("modules", "account_access", "permission_manager.R")
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

expect_contains(module_text, "permission_manager_ui <- function", "权限管理模块 UI 定义")
expect_contains(module_text, "permission_manager_server <- function", "权限管理模块 server 定义")
expect_contains(module_text, "title = \"权限管理\"", "权限管理模块标题")
expect_contains(module_text, "subtitle = \"数据空间协作与已授权空间\"", "权限管理模块副标题")
expect_contains(module_text, "uiOutput\\(ns\\(\"permission_notice\"\\)\\)", "权限管理模块说明输出")
expect_contains(module_text, "uiOutput\\(ns\\(\"permission_content\"\\)\\)", "权限管理模块主体输出")
expect_contains(module_text, "manageable_workspaces <- reactive", "权限管理模块可管理空间查询")
expect_contains(module_text, "accessible_workspaces <- reactive", "权限管理模块已授权空间查询")
expect_contains(module_text, "title = \"我的已授权空间\"", "权限管理模块普通成员信息卡")
expect_contains(module_text, "title = \"协作权限预览\"", "权限管理模块协作预览卡")
expect_contains(module_text, "当前账号名下还没有可管理的数据空间", "权限管理模块无空间非空态说明")
expect_contains(module_text, "权限管理数据加载失败", "权限管理模块权限数据失败兜底")
expect_contains(module_text, "service_list_manageable_workspaces\\(", "权限管理模块查询可管理空间")
expect_contains(module_text, "service_list_accessible_workspaces\\(", "权限管理模块查询已授权空间")
expect_contains(module_text, "service_list_workspace_access\\(", "权限管理模块查询空间协作明细")
expect_contains(module_text, "service_membership_preview_df\\(", "权限管理模块成员预览格式化")
expect_contains(module_text, "service_invite_preview_df\\(", "权限管理模块邀请预览格式化")
expect_contains(module_text, "service_grant_workspace_access_by_email\\(", "权限管理模块通过 service 授权")
expect_contains(module_text, "service_revoke_workspace_access_by_email\\(", "权限管理模块通过 service 撤销")
expect_contains(module_text, "service_transfer_workspace_owner_by_email\\(", "权限管理模块通过 service 迁移负责人")
expect_contains(module_text, "textInput\\(session\\$ns\\(\"target_email\"\\), \"协作者邮箱\"", "权限管理模块协作者邮箱输入")
expect_contains(module_text, "textInput\\(session\\$ns\\(\"owner_email\"\\), \"新负责人的邮箱\"", "权限管理模块负责人邮箱输入")
expect_contains(module_text, "selectInput\\(session\\$ns\\(\"managed_workspace_id\"\\), \"选择要管理的数据空间\"", "权限管理模块空间选择器")
expect_contains(module_text, "tabBox\\(", "权限管理模块预览使用标签页")
expect_contains(module_text, "accessible_workspace_table", "权限管理模块已授权空间表格")
expect_contains(module_text, "权限区渲染失败", "权限管理模块渲染失败兜底")
expect_not_contains(module_text, "isolate\\(current_user\\(\\)\\)", "权限管理模块不应隔离当前登录态")
expect_not_contains(module_text, "selectInput\\(session\\$ns\\(\"target_user", "权限管理模块不允许下拉选人")

cat("Permission manager guard passed.\n")
