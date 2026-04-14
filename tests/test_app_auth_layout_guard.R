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

app_text <- read_utf8("app.R")
auth_manager_text <- read_utf8("modules", "auth_manager.R")
if (!nzchar(app_text) || !nzchar(auth_manager_text)) return(invisible(NULL))

expect_contains <- function(text, pattern, label) {
  if (!grepl(pattern, text, perl = TRUE)) {
    stop(sprintf("缺少预期内容: %s", label), call. = FALSE)
  }
}

expect_contains(app_text, "return\\(sidebarMenu\\(", "未登录侧边栏应立即返回登录注册菜单")
expect_contains(app_text, "selected = \"login\"", "未登录侧边栏默认选中登录页")
expect_contains(app_text, "title = \"Hamster Analysis · AutoTFL\"", "顶栏标题文本")
expect_contains(app_text, "uiOutput\\(\"sidebar_user_panel\"\\)", "侧边栏用户信息输出")
expect_contains(app_text, "sidebar-user-card", "侧边栏用户卡片样式")
expect_contains(app_text, "open_access_manage", "侧边栏用户卡片快捷权限入口")
expect_contains(app_text, "li\\[data-value='access_manage'\\]", "权限管理侧边栏隐藏样式")
expect_contains(app_text, "tabName = \"access_manage\"", "权限管理页签")
expect_contains(app_text, "workspace_access_manager_ui\\(\"access_manage\"\\)", "Owner 权限管理模块挂载")
expect_contains(app_text, "auth_manager_tabs\\(\"auth\"\\)", "认证页面模块挂载")
expect_contains(app_text, "auth_manager_server\\(", "认证服务模块挂载")
expect_contains(app_text, "do.call\\(tabItems, tab_nodes\\)", "业务 tab 使用列表方式渲染，避免非管理员报错")
expect_contains(app_text, "#shiny-notification-panel", "通知面板位置样式")
expect_contains(auth_manager_text, "auth-page-shell", "认证页面使用上下居中外层容器")
expect_contains(auth_manager_text, "欢迎进入 AutoTFL", "登录页欢迎卡片")
expect_contains(auth_manager_text, "创建账号", "注册页引导卡片")
expect_contains(auth_manager_text, "textInput\\(ns\\(\"login_identity\"\\), \"用户名或邮箱\"", "登录页支持用户名或邮箱")
expect_contains(auth_manager_text, "textInput\\(ns\\(\"register_email\"\\), \"邮箱\"", "注册页包含邮箱字段")
expect_contains(auth_manager_text, "goto_tab\\(\"login\"\\)", "注册成功后跳回登录")

cat("App auth layout guard passed.\n")
