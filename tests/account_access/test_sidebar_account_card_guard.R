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

module_text <- read_utf8("modules", "account_access", "sidebar_account_card.R")
if (!nzchar(module_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(module_text, "sidebar_account_card_styles <- function", "侧边栏账号卡样式 helper")
expect_contains(module_text, "sidebar_account_card_ui <- function", "侧边栏账号卡 UI 定义")
expect_contains(module_text, "sidebar_account_card_server <- function", "侧边栏账号卡 server 定义")
expect_contains(module_text, "copy <- ACCOUNT_ENTRY_COPY", "侧边栏账号卡复用共享文案源")
expect_contains(module_text, "Hidden internal routes", "侧边栏账号卡隐藏页签 CSS 注释")
expect_contains(module_text, "li\\[data-value='user_profile'\\]", "侧边栏账号卡隐藏用户信息菜单项")
expect_contains(module_text, "li\\[data-value='access_permissions'\\]", "侧边栏账号卡隐藏权限管理菜单项")
expect_contains(module_text, "a\\[href='#shiny-tab-user_profile'\\]", "侧边栏账号卡隐藏用户信息链接")
expect_contains(module_text, "a\\[href='#shiny-tab-access_permissions'\\]", "侧边栏账号卡隐藏权限管理链接")
expect_contains(module_text, "actionLink\\(session\\$ns\\(\"open_user_profile\"\\), copy\\$actions\\$profile\\)", "侧边栏账号卡用户信息快捷入口")
expect_contains(module_text, "actionLink\\(session\\$ns\\(\"open_access_permissions\"\\), copy\\$actions\\$permissions\\)", "侧边栏账号卡权限管理快捷入口")
expect_contains(module_text, "actionLink\\(session\\$ns\\(\"logout_submit\"\\), copy\\$actions\\$logout\\)", "侧边栏账号卡退出入口")
expect_contains(module_text, "tags\\$strong\\(copy\\$status\\$database\\)", "侧边栏账号卡数据空间状态标签复用文案源")
expect_contains(module_text, "navigate_to\\(copy\\$page_keys\\$profile\\)", "侧边栏账号卡跳转用户信息")
expect_contains(module_text, "navigate_to\\(copy\\$page_keys\\$permissions\\)", "侧边栏账号卡跳转权限管理")
expect_contains(module_text, "navigate_to\\(copy\\$page_keys\\$db_manage\\)", "侧边栏账号卡跳转数据空间")
expect_contains(module_text, "navigate_to\\(copy\\$page_keys\\$data_prep\\)", "侧边栏账号卡跳转数据准备")
expect_contains(module_text, "navigate_to\\(copy\\$page_keys\\$admin\\)", "侧边栏账号卡跳转系统管理")
expect_contains(module_text, "service_list_manageable_workspaces\\(", "侧边栏账号卡统计可管理空间")
expect_contains(module_text, "auth_accessible_workspace_ids\\(", "侧边栏账号卡统计可访问空间")

cat("Sidebar account card guard passed.\n")
